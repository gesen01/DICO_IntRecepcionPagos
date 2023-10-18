/*
* Este sp es el encardado de seleccionar los movimientos de Tesoreria que se pueden timbrar en la herramienta
* */

SET DATEFIRST 7
SET ANSI_NULLS OFF
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET LOCK_TIMEOUT -1
SET QUOTED_IDENTIFIER OFF
GO

/************** spContSATRefrescarInfoAdiIngreso *************/ -- BUG 16152
IF EXISTS (SELECT * FROM sysobjects WHERE id = object_id('dbo.spContSATRefrescarInfoAdiIngreso') AND type = 'P') DROP PROCEDURE dbo.spContSATRefrescarInfoAdiIngreso
GO
CREATE PROCEDURE spContSATRefrescarInfoAdiIngreso
	@ID			INT,
	@Clave		VARCHAR(30),
	@CtaOrigen	VARCHAR(50),
	@CtaBanco	VARCHAR(50)

AS BEGIN
		
	IF EXISTS (SELECT * FROM ContSAtInfoAdiIngreso WHERE ID = @ID)
	BEGIN
		UPDATE ContSAtInfoAdiIngreso
		SET Clave= @Clave, CtaOrigen= @CtaOrigen, BanOrigen= @CtaBanco
		WHERE ID = @ID	 
	END
END 
GO


/******************************* spCFDICobroParcialMovimientos *************************************************/
IF EXISTS (SELECT * FROM sysobjects WHERE id = object_id('dbo.spCFDICobroParcialMovimientos') AND TYPE = 'P')
DROP PROCEDURE spCFDICobroParcialMovimientos
GO
CREATE PROCEDURE spCFDICobroParcialMovimientos
	@Estacion			INT, 
	@Empresa			VARCHAR(5)
AS
BEGIN
	DECLARE

		@cID				INT,
		@cModulo			VARCHAR(5),
		@cFechaEmision		DATETIME,
		@cImporte			MONEY,
		@cMovID				VARCHAR(20),
		@IDCxc				INT,
		@MovCxc				VARCHAR(20),
		@MovIDCxc			VARCHAR(20),
		@Cliente			VARCHAR(10),
		@CuentaCte			VARCHAR(50),
		@ClaveBanco			VARCHAR(3),
		@FormaPago			VARCHAR(50),
		
		@Folio				VARCHAR(50),
		@Serie				VARCHAR(10),

		@OrigenTipo			VARCHAR(10),
		@CtaBanco			VARCHAR(50),
		@CveBanco			INT,
		@NumeroCta			VARCHAR(100),
		@ClaveSAT			INT,
		
		@Aplica				VARCHAR(20),
		@AplicaID			VARCHAR(20),
		@IDOrigen			INT,
		@Clave				VARCHAR(10),
		@MetodoDePagoDR		VARCHAR(5),
		
		@FechaD				DATE = NULL,
		@FechaH				DATE = NULL,
		@Sucursal			INT = NULL,
		@ClaveCP			VARCHAR(10),
		@IDCP				INT,
		@IDMovAntes			INT,
		@IDMovDespues		INT,
		@ValidarClave		VARCHAR(10),
		@ClaveDetalle		VARCHAR(10),
		@IDCPA				INT,
		@ClaveDCursor		VARCHAR(20),
		@Timbrado			BIT,
		@AplicaFactor		FLOAT,
        @MontoFactor		FLOAT,
        @MontoCobro			FLOAT,
        @MontoDocumento		FLOAT,
        @ImporteD			FLOAT,
        @AplicaD			VARCHAR(30),
        @AplicaIDD			VARCHAR(30)
	DECLARE @Movimientos TABLE (
		OID			INT,
		OModulo		VARCHAR(5),
		OMov		VARCHAR(20),
		OMovID		VARCHAR(20),
		DID			INT,
		DModulo		VARCHAR(5),
		DMov		VARCHAR(20),
		DMovID		VARCHAR(20),
		Nivel		INT,
		Clave		VARCHAR(10)	
	)	
	
	DECLARE @MovimientosCxc TABLE (
		IDCxc			INT,
		OrigenTipo		VARCHAR(10)
		
	)	
	
	
		DECLARE @MovimientosCxcD TABLE (
		IDCxcD			INT,
		OrigenTipoD		VARCHAR(10),
		AplicaD			VARCHAR(30),
		AplicaDD		VARCHAR(30),
		ClaveD			VARCHAR(10),
		IDCobro			INT
		
		
	)	
		
	-----------------------------------------------------------------------------------------------
	DELETE FROM CFDICobroParcial WHERE Estacion = @Estacion
	DELETE FROM CFDICobroVenta	 WHERE Estacion = @Estacion
	
	
	--Se seleccionan los valor de los filtros
	SELECT @FechaD = CONVERT(DATE, FechaD), @FechaH = CONVERT(DATE, FechaH), @Sucursal = Sucursal, @Cliente = Cliente
	FROM CFDICobroParcialFiltros
	WHERE Estacion = @Estacion

	--Se realiza la busqueda de los movimientos en Tesoreria para analizar cuales cumplen con los criterios para ser timbrados o si el movimiento ya fué timbrado
	DECLARE cTesoreria CURSOR LOCAL FOR
		SELECT DISTINCT 'DIN', A.ID, A.FechaEmision, A.MovID
		FROM Dinero A 
			INNER JOIN MovTipo B ON B.Modulo = 'DIN' AND A.Mov = B.Mov
			INNER JOIN DineroD C ON A.ID = C.ID
			LEFT JOIN CFDICobroParcialTimbrado AS cpt ON cpt.IDModulo = A.ID AND cpt.Modulo = 'DIN'
		WHERE A.Estatus IN( 'CONCLUIDO', 'CONCILIADO') AND A.FechaEmision BETWEEN @FechaD AND @FechaH AND B.Clave IN ('DIN.D','DIN.DE')
			AND A.Empresa = @Empresa 
			AND A.Contacto = ISNULL(@Cliente, A.Contacto)
			AND A.Sucursal = ISNULL(@Sucursal ,A.Sucursal)
			AND (cpt.IDModulo IS NULL OR cpt.Cancelado = 1)
		ORDER BY A.FechaEmision DESC
	OPEN cTesoreria
	FETCH NEXT FROM cTesoreria INTO @cModulo, @cID, @cFechaEmision, @cMovID
	WHILE @@FETCH_STATUS = 0
	BEGIN
		
		SET @Cliente = NULL
		SET @ClaveBanco = NULL
		SET @CuentaCte = NULL
		SET @IDCxc = NULL 
		SET @MovCxc = NULL
		SET @MovIDCxc = NULL
		SET @Folio = NULL
		SET @Serie = NULL
		SET @Timbrado = 0
		
		DELETE FROM @MovimientosCxc
		
		SELECT @Folio = dbo.fnFolioConsecutivo(@cMovID)
		SELECT @Serie = REPLACE(@cMovID, @Folio, '')
		
		-- Se realiza una busqueda recursiva para encontrar el origen de los movimientos
		;WITH Cte
		AS (
			SELECT OID, OModulo, OMov, OMovID, DID, DModulo, DMov, DMovID, 1 AS Nivel
			FROM dbo.movflujo
			WHERE DID = @cID AND DModulo = @cModulo AND Empresa = @Empresa AND Cancelado = 0
			UNION ALL
			SELECT e.OID, e.OModulo, e.OMov, e.OMovID, e.DID, e.DModulo, e.DMov, e.DMovID, 1+Cte.Nivel
			FROM dbo.movflujo AS e
				INNER JOIN cte ON e.DID = cte.OID AND e.DModulo = cte.OMODULO AND e.Cancelado = 0
		)

	-----------------------------------------------------------------------------------------------		  
		--Se extraen los movimientos que tengan como origen un cobro
		INSERT INTO @MovimientosCxc (IDCxc, OrigenTipo)
		SELECT DISTINCT  A.ID, A.OrigenTipo
		FROM Cte AS B 
			INNER JOIN Cxc AS A ON A.ID = B.OID AND B.OModulo = 'CXC'
			INNER JOIN MovTipo AS mt ON mt.Mov = A.Mov
		WHERE  mt.Clave IN ('CXC.C')
			
		DELETE FROM @MovimientosCxcD		
		
		INSERT INTO @MovimientosCxcD (IDCxcD, OrigenTipoD,AplicaD,AplicaDD,ClaveD,IDCobro)
		SELECT mf.OID,'CXC', mf.OMov,mf.OMovID, Clave ,mf.DID
		 FROM  MovTipo AS mt 
				JOIN MovFlujo AS mf on mt.Mov=mf.OMov
				JOIN @MovimientosCxc as c ON c.IDCxc=mf.DID
			WHERE mf.DModulo='CXC'
				AND mf.Cancelado=0
				AND mt.Modulo='CXC'
				
			IF EXISTS (SELECT * FROM @MovimientosCxcD WHERE ClaveD IN ('CXC.D','CXC.DP'))
			BEGIN
				DECLARE ActualizaMov CURSOR LOCAL FOR
					SELECT IDCxcD, ClaveD,ClaveD
					FROM @MovimientosCxcD

				OPEN ActualizaMov
				FETCH NEXT FROM ActualizaMov INTO @IDCP,@ValidarClave,@ClaveDCursor
				WHILE @@FETCH_STATUS = 0
				BEGIN
					
					IF @ValidarClave IN ('CXC.DP','CXC.D')
					BEGIN
						INSERT @MovimientosCxc (IDCxc, OrigenTipo)
						SELECT IDCxcD, OrigenTipoD
						FROM @MovimientosCxcD WHERE IDCxcD=@IDCP 
					END

					FETCH NEXT FROM ActualizaMov INTO @IDCP,@ValidarClave,@ClaveDCursor
				END
				CLOSE ActualizaMov
				DEALLOCATE ActualizaMov
			END	
			
	-----------------------------------------------------------------------------------------------
		--Se verifica que hayan movimiento con origen en un cobro.			
		IF EXISTS (SELECT * FROM @MovimientosCxc)
		BEGIN
			
			DECLARE cMovCxc CURSOR FOR
			SELECT IDCxc
			FROM @MovimientosCxc
			OPEN cMovCxc
			FETCH NEXT FROM cMovCxc INTO @IDCxc
			WHILE @@FETCH_STATUS = 0 AND @Timbrado = 0
			BEGIN

				SET @IDMovAntes=NULL
				SET @ClaveCP=NULL
			
				SELECT @ClaveCP = Clave FROM MovTipo AS mt 
				JOIN Cxc AS c ON c.Mov = mt.Mov
				WHERE c.ID = @IDCxc 
				 AND mt.Modulo='CXC'
				 AND  c.Estatus<>'CANCELADO'

				IF @ClaveCP IN ('CXC.D','CXC.DP')
				BEGIN
			
				SELECT @IDMovAntes = @IDCxc 

				SELECT @IdCxc = DID
				FROM   MovFlujo AS mf
				 JOIN Cxc AS c ON C.ID= mf.DID	
				WHERE  OID = @IdCxc
				 AND mf.DModulo = 'CXC'
				 AND mf.Cancelado <> 1

				SELECT @IDMovDespues=@IDCxc
				
				END

			--Se verifica que el cobro no haya sido timbrado desde el módulo de CXC
			IF NOT EXISTS (SELECT * FROM CFDIDocRelacionadoTimbrado WHERE IDCobro = @IDCxc AND Cancelado = 0) --AND NOT EXISTS (SELECT * FROM CFDIDocRelacionadoTimbrado WHERE IDCobro = @IDMovAntes AND Cancelado = 0)
			BEGIN

				IF @ClaveCP IN ('CXC.D','CXC.DP')
					SELECT @IDCxc=@IDMovAntes
			
				DECLARE CMovimientos CURSOR FOR
					SELECT Aplica, AplicaID,cd.Importe FROM CxcD AS cd
					INNER JOIN MovTipo AS mt ON mt.Mov = cd.Aplica
					WHERE ID = @IDCxc 
					AND mt.Modulo='CXC'
					AND mt.Clave<>'CXC.D'
					AND mt.Clave<>'CXC.DP'
					AND NULLIF (cd.AplicaID, '') <> NULL
				OPEN CMovimientos
				FETCH NEXT FROM CMovimientos INTO @Aplica, @AplicaID,@ImporteD
				WHILE @@FETCH_STATUS = 0
				BEGIN

					SET @ClaveDetalle=null

					SELECT @ClaveDetalle=MT.Clave 
						FROM MovTipo AS mt WHERE mt.Mov=@Aplica
					AND mt.Modulo='CXC'
			
					IF @ClaveCP IN ('CXC.D','CXC.DP')
					BEGIN
						SELECT @MontoDocumento = ISNULL (c.Importe,0) + ISNULL (c.Impuestos,0) - ISNULL(c.Retencion, 0) - ISNULL(c.Retencion2, 0) - ISNULL(c.Retencion3, 0)
							FROM Cxc AS c 
							INNER JOIN CxcD AS cd ON c.ID=cd.ID
						WHERE c.ID=@IDMovAntes

						SELECT @AplicaD=AplicaD,@AplicaIDD=AplicaDD 
						  FROM @MovimientosCxcD
						WHERE IDCxcD=@IDMovAntes

						SELECT @MontoCobro = cd.Importe FROM Cxc AS c 
						INNER JOIN CxcD AS cd ON c.ID=cd.ID
						WHERE c.ID=@IDMovDespues
						AND cd.Aplica=@AplicaD
						AND cd.AplicaID=@AplicaIDD
					END
					ELSE
					BEGIN

						SELECT @MontoDocumento = cD.Importe FROM Cxc AS c 
						INNER JOIN CxcD AS cd ON c.ID=cd.ID
						WHERE --c.ID=--@cID
						 cd.Aplica=@Aplica
						AND cd.AplicaID=@AplicaID
				
						SELECT @MontoCobro = cd.Importe FROM Cxc AS c 
						INNER JOIN CxcD AS cd ON c.ID=cd.ID
						WHERE --c.ID=@cID
						 cd.Aplica=@Aplica
						AND cd.AplicaID=@AplicaID
					END

					SET @MetodoDePagoDR = NULL
					SET @IDOrigen = NULL 
					SET @Clave = NULL 
					DELETE FROM @Movimientos

					IF @ClaveCP IN ('CXC.D','CXC.DP')
						SELECT @IDCxc=@IDMovAntes

					-- Se realiza una busqueda recursiva para encontrar el origen de los cobros
					;WITH Movimientos 
					AS (
						SELECT OID, OModulo, OMov, OMovID, DID, DModulo, DMov, DMovID,  1 AS Nivel
						FROM dbo.movflujo
						WHERE DID = @IDCxc AND DModulo = 'CXC' AND OMov = @Aplica AND OMovID = @AplicaID AND Empresa = @Empresa AND Cancelado = 0
						UNION ALL
						SELECT e.OID, e.OModulo, e.OMov, e.OMovID, e.DID, e.DModulo, e.DMov, e.DMovID, 1 + Movimientos.Nivel
						FROM dbo.movflujo AS e
							INNER JOIN Movimientos ON e.DID = Movimientos.OID AND e.DModulo = Movimientos.OModulo AND e.Cancelado = 0
					)

					INSERT @Movimientos 
					SELECT OID, OModulo, OMov, OMovID, DID, DModulo, DMov, DMovID, Nivel, mt.Clave
					FROM Movimientos AS m
						INNER JOIN MovTipo AS mt ON m.OModulo = mt.Modulo AND m.OMov = mt.Mov
					ORDER BY Nivel DESC

					SELECT @AplicaFactor = @MontoCobro/@MontoDocumento
					SELECT @MontoFactor  = @ImporteD * @AplicaFactor
						
					--Se extraen los movimientos que tengan como origen una factura
					SELECT @IDOrigen = OID
					FROM @Movimientos
					WHERE Clave IN ('VTAS.F', 'VTAS.FB') 

					--Se extraen la forma de pago del Deposito
					IF @ClaveCP IN ('CXC.D','CXC.DP')
						SELECT @IDCxc= @IDMovDespues

					SELECT @FormaPago = d.FormaPago 
					FROM MovFlujo AS mf
						INNER JOIN DineroD AS d ON d.Aplica = mf.DMov AND d.AplicaID = mf.DMovID
					WHERE OID = @IDCxc AND d.ID = @cID AND mf.Cancelado = 0 AND mf.Empresa = @Empresa  
					
					--Si @IDOrigen es null, quiere decir que el movimiento tiene como origen CXC, sino el movimiento viene de VTAS	
					IF @IDOrigen IS NOT NULL
					BEGIN 

						IF @ClaveCP IN ('CXC.D','CXC.DP')
							SELECT @IDCxc= @IDMovDespues
								
						--Se extrae el metodo de pago del módulo de VTAS
						SELECT @MetodoDePagoDR = mp.IDClave
						FROM Venta AS v
							LEFT JOIN Condicion AS c ON c.Condicion = v.Condicion 
							LEFT JOIN SATMetodoPago AS mp ON mp.Clave = c.CFD_metodoDePago
						WHERE ID = @IDOrigen 
						--Para que un movimiento pueda ser considerado para timbrar, el metodo de pago de la factura no debe ser PUE
						IF @MetodoDePagoDR <> 'PUE'

							IF @ClaveCP IN ('CXC.D','CXC.DP') AND @ClaveDetalle <> 'CXC.D'  AND @ClaveDetalle <> 'CXC.DP'
							BEGIN

								IF NOT EXISTS (SELECT * FROM CFDICobroVenta AS cv WHERE cv.IDMovimiento=@cID AND cv.IDCobro=@IDCxc AND cv.IDVenta=@IDOrigen AND cv.IDAplicaCobro=@IDMovAntes AND cv.Empresa=@Empresa AND cv.Estacion=@Estacion AND EsSaldoInicial = 0)
								INSERT CFDICobroVenta (Estacion, Empresa, IDMovimiento, IDCobro, IDVenta, FormaPago,IDAplicaCobro,AplicaFactor,MontoFactor , Doc, MovAplica, MovAplicaID)	
								SELECT					@Estacion,@Empresa,@cID,		@IDCxc,	 @IDOrigen,@FormaPago, @IDMovAntes,@AplicaFactor,@MontoFactor , 1, @AplicaD, @AplicaIDD

							END
							ELSE
							BEGIN
	
							IF @ClaveDetalle <>'CXC.D'
							BEGIN
								
								IF NOT EXISTS ( SELECT * FROM CFDICobroVenta AS cv WHERE cv.IDCobro=@IDCxc AND cv.IDVenta=@IDOrigen AND cv.IDAplicaCobro IS NULL AND cv.Empresa=@Empresa AND cv.Estacion=@Estacion AND EsSaldoInicial = 0)
								INSERT CFDICobroVenta (Estacion, Empresa, IDMovimiento, IDCobro, IDVenta, FormaPago,AplicaFactor,MontoFactor, MovAplica, MovAplicaID)	
								SELECT					@Estacion,@Empresa,@cID,		@IDCxc,	 @IDOrigen,@FormaPago,@AplicaFactor,@MontoFactor, @Aplica, @AplicaID
							END

							END
					END 
					ELSE  
					BEGIN 
						--Se extrae la clave del movimiento para determinar el origen
						SELECT TOP 1 @Clave = Clave, @IDOrigen = OID
						FROM @Movimientos 
						ORDER BY Nivel DESC
						
						--Si el movimiento tiene como origen una Factura en CXC, se considera para timbrar
						IF @Clave IN ('CXC.F', 'CXC.CA', 'CXC.FB') 
						BEGIN
						----Bug  16156 no se debe considerar saldos iniciales con metodo de pago PUE
								SELECT  @MetodoDePagoDR=mp.IDClave
								FROM CXC AS v
								LEFT JOIN Condicion AS c ON c.Condicion = v.Condicion 
								LEFT JOIN SATMetodoPago AS mp ON mp.Clave = c.CFD_metodoDePago
								WHERE ID = @IDOrigen
				
							IF @MetodoDePagoDR <> 'PUE'
							BEGIN
								IF @ClaveCP IN ('CXC.D','CXC.DP') AND @ClaveDetalle <> 'CXC.D'  AND @ClaveDetalle <> 'CXC.DP'
								BEGIN
									IF NOT EXISTS(SELECT * FROM CFDICobroVenta AS cv WHERE cv.IDMovimiento = @cID AND cv.IDCobro = @IDCxc AND cv.IDVenta = @IDOrigen AND cv.IDAplicaCobro = @IDMovAntes AND cv.EsSaldoInicial = 1 AND cv.Empresa = @Empresa AND cv.Estacion = @Estacion)
									INSERT CFDICobroVenta (Estacion, Empresa, IDMovimiento, IDCobro, IDVenta, FormaPago,IDAplicaCobro, EsSaldoInicial,AplicaFactor,MontoFactor, Doc, MovAplica, MovAplicaID)	
									SELECT					@Estacion, @Empresa, @cID,		@IDCxc, @IDOrigen, @FormaPago, @IDMovAntes,1,@AplicaFactor,@MontoFactor , 1,			    @AplicaD, @AplicaIDD

								END
								ELSE
								BEGIN
									
								IF @ClaveDetalle <>'CXC.D'
									IF NOT EXISTS (SELECT * FROM CFDICobroVenta AS cv WHERE cv.IDCobro=@IDCxc AND cv.IDVenta= @IDOrigen AND cv.EsSaldoInicial = 1 AND cv.Estacion=@Estacion AND cv.Empresa=@Empresa)
										INSERT CFDICobroVenta (Estacion, Empresa, IDMovimiento, IDCobro, IDVenta, EsSaldoInicial, FormaPago,AplicaFactor,MontoFactor, MovAplica, MovAplicaID)	
										SELECT					@Estacion, @Empresa, @cID, @IDCxc, @IDOrigen, 1, @FormaPago,@AplicaFactor,@MontoFactor, @Aplica, @AplicaID

								END
							END
								
						END	
					END 
		
					FETCH NEXT FROM CMovimientos INTO @Aplica, @AplicaID,@ImporteD
		
				END
	
				CLOSE CMovimientos
				DEALLOCATE CMovimientos

			END
			ELSE
			BEGIN
				SET @Timbrado = 1
					
				DELETE FROM CFDICobroVenta
				WHERE Estacion = @Estacion AND Empresa = @Empresa AND IDMovimiento = @cID
			END
				
			FETCH NEXT FROM cMovCxc INTO @IDCxc
			
		END
			
		CLOSE cMovCxc
		DEALLOCATE cMovCxc
			
		--Si hay registros en la tabla CFDICobroVenta asociados al movimiento de Deposito, quiere decir que esté movimiento se puede timbrar 			
		IF EXISTS (SELECT * FROM CFDICobroVenta WHERE Estacion = @Estacion AND Empresa = @Empresa AND IDMovimiento = @cID)
		BEGIN 

				SELECT @OrigenTipo = OrigenTipo FROM @MovimientosCxc
				WHERE OrigenTipo = 'POS'
				
				--Se procede a llenar la tabla de paso para timbrar teniendo en cuenta el origen del movimiento para determinar de que tablas se extraen los valores correspondiente	
				IF @OrigenTipo = 'POS'
				BEGIN
					SELECT @CtaBanco = NULL, @CveBanco = NULL, @NumeroCta = NULL, @ClaveSAT = NULL
					SELECT @CtaBanco = a.CtaBanco, @CveBanco = a.ClaveBanco, @NumeroCta = b.NumeroCta, @ClaveSAT = c.ClaveSAT
						FROM POSCFDIRecepcionPagos a
							LEFT JOIN CtaDinero b ON a.CtaDinero = b.CtaDinero
							LEFT JOIN CFDINominaInstitucionFin c ON b.BancoSucursal = c.Institucion
						WHERE a.ID = @IDCxc

					INSERT INTO CFDICobroParcial(Estacion, Modulo, ID, Mov, MovID, Empresa, Sucursal, FechaEmision, LugarExpedicion,
								Cliente, FormaPago, NumOperacion, ClaveMoneda, TipoCambio, Monto, ClaveBancoEmisor, CuentaBancariaCte, ClaveBanco, 
								CuentaBancaria, Folio, Serie)
					SELECT TOP 1 @Estacion, 'DIN', A.ID, A.Mov, A.MovID, A.Empresa, A.Sucursal, A.FechaEmision, ISNULL(G.CodigoPostal, H.CodigoPostal), A.Contacto, 
									ISNULL(ISNULL(B.FormaPago, A.FormaPago), cc.InfoFormaPago), A.Referencia, ISNULL(E.Clave, 'XXX'), A.TipoCambio, A.Importe, ISNULL(NULLIF(@CveBanco, ''),0), NULLIF(@CtaBanco, ''), NULLIF(@ClaveSAT, ''), 
									NULLIF(@NumeroCta, ''), @Folio, NULLIF(@Serie, '')
					FROM Dinero A
						INNER JOIN DineroD B ON A.ID = B.ID
						LEFT JOIN CtaDinero C ON A.CtaDinero = C.CtaDinero
						LEFT JOIN CFDINominaInstitucionFin D ON C.BancoSucursal = D.Institucion
						LEFT JOIN Mon E ON A.Moneda = E.Moneda
						INNER JOIN Cte F ON F.Cliente = A.Contacto
						LEFT JOIN CteCFD AS cc ON cc.Cliente = F.Cliente
						INNER JOIN Sucursal G ON G.Sucursal = A.Sucursal 
						INNER JOIN Empresa H ON A.Empresa = H.Empresa
					WHERE A.ID = @cID 
					ORDER BY B.Importe DESC

				END ELSE 
				BEGIN
				-- BUG 16152 
					SELECT @CtaBanco = NULL, @CveBanco = NULL, @NumeroCta = NULL				

					SELECT @NumeroCta = ISNULL(NULLIF(F.CtaBanco, ''), ISNULL(NULLIF(CSII.CtaOrigen, ''), NULLIF(cc.Cta, ''))), 
							@CveBanco = ISNULL(NULLIF(F.ClaveBanco, ''), ISNULL(NULLIF(CSII.Clave, ''), NULLIF(cc.BancoCta, ''))) 
						FROM Dinero A
					LEFT JOIN ContSAtInfoAdiIngreso CSII ON A.ID = CSII.ID
				INNER JOIN Cte F ON F.Cliente = A.Contacto
					LEFT JOIN CteCFD AS cc ON cc.Cliente = F.Cliente
						WHERE A.ID = @cID 

					SELECT @CtaBanco= Nombre FROM CFDINominaSATInstitucionFin WHERE Clave= @CveBanco
					
					
				IF NOT EXISTS (SELECT * FROM CFDICobroParcial AS cp
        								JOIN Dinero AS a ON a.ID=@cID WHERE cp.Estacion=@Estacion 
        								AND cp.ID=a.ID)	  
										
					INSERT INTO CFDICobroParcial(Estacion, Modulo, ID, Mov, MovID, Empresa, Sucursal, FechaEmision, LugarExpedicion,
								Cliente, FormaPago, NumOperacion, ClaveMoneda, TipoCambio, Monto, ClaveBancoEmisor, CuentaBancariaCte, ClaveBanco, 
								CuentaBancaria, Folio, Serie,ClabeCuenta, Tarjeta)
					SELECT TOP 1 @Estacion, 'DIN', A.ID, A.Mov, A.MovID, A.Empresa, A.Sucursal, A.FechaEmision, ISNULL(G.CodigoPostal, H.CodigoPostal), A.Contacto, 
									ISNULL(ISNULL(B.FormaPago, A.FormaPago), cc.InfoFormaPago), A.Referencia, ISNULL(E.Clave, 'XXX'), A.TipoCambio, A.Importe, ISNULL(@CveBanco,''), ISNULL(@NumeroCta, ''), 
									NULLIF(D.ClaveSAT, ''), ISNULL( NULLIF(C.NumeroCta, ''), C.CLABE), @Folio, NULLIF(@Serie, ''),ISNULL(NULLIF(F.ClabeCuenta, ''), NULLIF(cc.ClabeCuenta, '')),ISNULL(NULLIF(F.Tarjeta, ''), NULLIF(cc.Tarjeta, ''))
					FROM Dinero A
						INNER JOIN DineroD B ON A.ID = B.ID
						LEFT JOIN CtaDinero C ON A.CtaDinero = C.CtaDinero
						LEFT JOIN CFDINominaInstitucionFin D ON C.BancoSucursal = D.Institucion
						LEFT JOIN Mon E ON A.Moneda = E.Moneda
						INNER JOIN Cte F ON F.Cliente = A.Contacto
						LEFT JOIN CteCFD AS cc ON cc.Cliente = F.Cliente
						INNER JOIN Sucursal G ON G.Sucursal = A.Sucursal 
						INNER JOIN Empresa H ON A.Empresa = H.Empresa
					WHERE A.ID = @cID 
					ORDER BY B.Importe DESC
			
			-- Se actualiza la informacion de la cuenta del cliente de Información Adicional para que coincida el ingreso. BUG 16152													
					EXEC spContSATRefrescarInfoAdiIngreso @cID, @CveBanco, @NumeroCta, @CtaBanco

				END
				
		END
	END	
		

	FETCH NEXT FROM cTesoreria INTO @cModulo, @cID, @cFechaEmision, @cMovID
		
	END	
	-----------------------------------------------------------------------------------------------	
	CLOSE cTesoreria
	DEALLOCATE cTesoreria
END	
GO	
