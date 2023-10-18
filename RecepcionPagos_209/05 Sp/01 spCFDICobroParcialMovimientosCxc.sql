SET DATEFIRST 7
SET ANSI_NULLS OFF
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET LOCK_TIMEOUT -1
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF
SET ARITHABORT OFF
SET ANSI_WARNINGS OFF
GO

/******************************* spCFDICobroParcialMovimientosCxc *************************************************/
IF EXISTS (SELECT * FROM sysobjects WHERE id = object_id('dbo.spCFDICobroParcialMovimientosCxc') AND TYPE = 'P')
DROP PROCEDURE spCFDICobroParcialMovimientosCxc
GO
CREATE PROCEDURE spCFDICobroParcialMovimientosCxc
	@Estacion			INT, 
	@Empresa			VARCHAR(5),
	@cID				INT = NULL
	
AS 
BEGIN

	DECLARE
		@Folio				VARCHAR(50),
		@Serie				VARCHAR(10),
		@Mov				VARCHAR(20),
		@MovID				VARCHAR(20),
		@OrigenTipo			VARCHAR(10),
		@Aplica				VARCHAR(20),
		@AplicaID			VARCHAR(20),
		@IDOrigen			INT,
		@Clave				VARCHAR(10),
		@MetodoDePagoDR		VARCHAR(5),
		@ID					INT,
		
		@FechaD				DATE = NULL,
		@FechaH				DATE = NULL,
		@Sucursal			INT = NULL,
		@Cliente			VARCHAR(10),
		@Modulo				VARCHAR(10),
		@ClaveMov			VARCHAR(10),
		@MovClave			VARCHAR(10),
		@FEPOSC				DATETIME,
		@FOPosE				DATETIME,
		@LEPosC				VARCHAR(20),
		@CtePosE			VARCHAR(20),
		@FPPosC				VARCHAR(20),
		@CMPosC				VARCHAR(20),
		@TCPosC				FLOAT,
		@CBEPosE			VARCHAR(20),
		@CBCtePosC			VARCHAR(20),
		@CBPosC				VARCHAR(20),
		@CUBPosC			VARCHAR(20),
        @ID_Anterior		INT,
        @ID_SI				INT,
        @IDDoc				INT,
        @UsaHerramienta		BIT,
        @AplicaD			VARCHAR(50),
        @AplicaIDD			VARCHAR(20),
        @IDAntes			INT,
        @IDInicial			INT,
        @ClaveDetalle		VARCHAR(20),
        @AplicaFactor		FLOAT,
        @MontoFactor		FLOAT,
        @MontoCobro			FLOAT,
        @MontoDocumento		FLOAT,
        @ImporteD			FLOAT,
        @ClaveMovD			VARCHAR(10)
		
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
	
	
	DECLARE @CxcDetalle TABLE (
		Aplica		VARCHAR(30),
		AplicaID	VARCHAR(50)
	)
	
	DECLARE @CxcMovimientos TABLE (
		ID				INT,
		Mov				VARCHAR(30),
		MovID			VARCHAR(50),
		Clave			VARCHAR(10),
		IDCobro			INT
		
	)
	
	
		
	DELETE FROM CFDICobroParcial WHERE Estacion = @Estacion
	DELETE FROM CFDICobroVenta   WHERE Estacion = @Estacion
	SET @UsaHerramienta = 0
 
	
	--Se seleccionan los valor de los filtros, verificando si se está ejecutando la herramienta desde el módulo de CXC o desde el menú de herramientas
	SELECT @FechaD = CONVERT(DATE, FechaEmision), @FechaH = CONVERT(DATE, FechaEmision), @Sucursal = Sucursal, @Cliente = Cliente
	FROM CXC
	WHERE ID = @cID AND Empresa = @Empresa
	
	SELECT @FEPOSC=  A.FechaEmision, @FOPosE = NULLIF(A.FechaOriginal, ''), @LEPosC = ISNULL(G.CodigoPostal, H.CodigoPostal),@CtePosE = A.Cliente, 
		  		 @FPPosC = ISNULL(A.FormaCobro, cc.InfoFormaPago),@CMPosC = ISNULL(E.Clave, 'XXX'),@TCPosC = A.TipoCambio,@CBEPosE = ISNULL(NULLIF(F.ClaveBanco, ''), NULLIF(cc.BancoCta, '')), 
				 @CBCtePosC = ISNULL(NULLIF(F.CtaBanco, ''), NULLIF(cc.Cta, '')), @CBPosC = NULLIF(D.ClaveSAT, ''),@CUBPosC = NULLIF(C.NumeroCta, '')
			FROM Cxc A
			   	 LEFT JOIN CtaDinero C ON A.CtaDinero = C.CtaDinero
				 LEFT JOIN CFDINominaInstitucionFin D ON C.BancoSucursal = D.Institucion
				 INNER JOIN Mon E ON A.Moneda = E.Moneda
				 INNER JOIN Cte F ON F.Cliente = A.Cliente
				 LEFT JOIN CteCFD AS cc ON cc.Cliente = F.Cliente
				 INNER JOIN Sucursal G ON G.Sucursal = A.Sucursal 
				 INNER JOIN Empresa H ON A.Empresa = H.Empresa
			WHERE A.ID = @cID	
	
	
	INSERT @CxcDetalle (Aplica,AplicaID)	
	SELECT A.Aplica, A.AplicaID
		FROM CxcD AS A 
			INNER JOIN MovTipo AS B ON B.Modulo = 'CXC' AND A.Aplica = B.Mov
		WHERE A.ID=@cID 
			AND NULLIF(A.AplicaID ,'')<>NULL 
		GROUP BY A.ID, A.Aplica, A.AplicaID	
		
	
	DECLARE cCxcDetalle CURSOR LOCAL FOR
		SELECT A.Aplica, A.AplicaID
		FROM @CxcDetalle AS A
	OPEN cCxcDetalle
	FETCH NEXT FROM cCxcDetalle INTO @AplicaD, @AplicaIDD
	WHILE @@FETCH_STATUS = 0
	BEGIN
				
		SELECT @IDAntes = mf.OID  
		 FROM MovFlujo AS mf 
		WHERE Did=@cID
		 AND mf.DModulo='CXC'
		 AND mf.OMov=@AplicaD
		 AND mf.OMovID=@AplicaIDD

		SELECT @MovClave=Clave FROM MovTipo AS mt 
		WHERE  mt.Mov = @AplicaD
		AND mt.Modulo='CXC'

		IF @MovClave IN ('CXC.D','CXC.DP')
		BEGIN
			INSERT @CxcMovimientos ( ID,	Mov,		MovID,		Clave		, IDCobro)
			SELECT				 @IDAntes ,	@AplicaD,	@AplicaIDD,	@MovClave	,@cID
		END
		ELSE
		BEGIN
			IF NOT EXISTS (SELECT * FROM @CxcMovimientos WHERE ID = @cID )
			INSERT @CxcMovimientos ( ID,	Mov,	MovID,	 Clave	,  IDCobro)
			SELECT					c.ID,	c.Mov,	c.MovID, mt.Clave, @cID	
				FROM   Cxc AS c
			    INNER JOIN MovTipo  AS mt ON mt.Mov = c.Mov
			WHERE c.ID = @cID
				AND mt.Modulo = 'CXC'				
		END
		
	 FETCH NEXT FROM cCxcDetalle INTO @AplicaD, @AplicaIDD
	
	END
	CLOSE cCxcDetalle
	DEALLOCATE cCxcDetalle
	
	
	


	--Se realiza la busqueda de los movimientos en CXC para analizar cuales cumplen con los criterios para ser timbrados o si el movimiento ya fué timbrado
	DECLARE cCxc CURSOR FOR
	SELECT A.ID, A.Mov, A.MovID, A.OrigenTipo, cm.Clave, cm.IDCobro
	FROM Cxc AS A 
		INNER JOIN @CxcMovimientos AS cm ON cm.ID = A.ID
		INNER JOIN MovTipo AS B ON B.Modulo = 'CXC' AND A.Mov = B.Mov
		LEFT JOIN CFDIDocRelacionadoTimbrado AS cpt ON cpt.IDCobro = @cID
		LEFT JOIN CFDICobroFactoraje AS cf ON cf.ModuloFactorajeID=A.ID
	WHERE A.Estatus IN ('CONCLUIDO','PENDIENTE') 
		AND B.Clave IN ('CXC.C', 'CXC.ANC', 'CXC.NET','CXC.DP','CXC.D')
		AND A.Empresa = @Empresa AND A.ID = cm.ID 
		AND A.Cliente = ISNULL(@Cliente, A.Cliente)  
		AND (cpt.IDCobro IS NULL OR cpt.Cancelado = 1)
		AND B.RecepcionPagosParcialidad = 1
		AND cf.ModuloFactorajeID IS NULL
	GROUP BY A.ID, A.Mov, A.MovID, A.OrigenTipo, A.FechaEmision, cm.Clave, cm.IDCobro
	ORDER BY A.FechaEmision DESC	
	OPEN cCxc
	FETCH NEXT FROM cCxc INTO @ID, @Mov, @MovID, @OrigenTipo, @ClaveMov ,@ID_Anterior
	WHILE @@FETCH_STATUS = 0
	BEGIN
	IF @ClaveMov IN ('CXC.D','CXC.DP')
	BEGIN
		SELECT @MontoDocumento = ISNULL (c.Importe,0) + ISNULL (c.Impuestos,0)  - ISNULL(c.Retencion, 0) - ISNULL(c.Retencion2, 0) - ISNULL(c.Retencion3, 0)
			FROM Cxc AS c 
			INNER JOIN CxcD AS cd ON c.ID=cd.ID
		WHERE c.ID=@ID

		SELECT @MontoCobro = cd.Importe 
		 FROM Cxc AS c 
		INNER JOIN CxcD AS cd ON c.ID=cd.ID
		WHERE c.ID=@ID_Anterior
		AND cd.Aplica=@Mov
		AND cd.AplicaID=@MovID
	END
	ELSE
	BEGIN
		SELECT @MontoDocumento = cD.Importe 
		 FROM Cxc AS c  
		INNER JOIN CxcD AS cd ON c.ID=cd.ID
		WHERE c.ID=@cID
		AND cd.Aplica=@AplicaD
		AND cd.AplicaID=@AplicaIDD
				
		SELECT @MontoCobro = cd.Importe 
		 FROM Cxc AS c 
		INNER JOIN CxcD AS cd ON c.ID=cd.ID
		WHERE c.ID=@cID
		AND cd.Aplica=@AplicaD
		AND cd.AplicaID=@AplicaIDD
	END
	
		SET @Folio	= NULL
		SET @Serie	= NULL

		SELECT @Folio = dbo.fnFolioConsecutivo(@MovID)
		SELECT @Serie = REPLACE(@MovID, @Folio, '') 

		DECLARE CMovimientos CURSOR FOR
			SELECT Aplica, AplicaID, Importe FROM CxcD
			WHERE ID = @ID
			
		OPEN CMovimientos
		FETCH NEXT FROM CMovimientos INTO @Aplica, @AplicaID,@ImporteD
		WHILE @@FETCH_STATUS = 0
		BEGIN
			
			SELECT @ClaveMovD = mt.Clave
				FROM MovTipo AS mt
			WHERE mt.Mov = @Aplica
			AND mt.Modulo = 'CXC'
			
			SET @IDOrigen = NULL
			SET @Clave = NULL
			SET @MetodoDePagoDR = NULL
			DELETE FROM @Movimientos

			SELECT @ClaveDetalle=mt.Clave 
			FROM MovTipo AS mt WHERE mt.Mov=@Aplica
				AND mt.Modulo='CXC'

			;WITH Movimientos
			AS (
				SELECT OID, OModulo, OMov, OMovID, DID, DModulo, DMov, DMovID,  1 AS Nivel
				FROM dbo.movflujo
				WHERE DID = @ID AND DModulo = 'CXC' AND OMov = @Aplica AND OMovID = @AplicaID AND Empresa = @Empresa AND Cancelado = 0
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
			
			--Si @IDOrigen es null, quiere decir que el movimiento tiene como origen CXC, sino el movimiento viene de VTAS
			IF @IDOrigen IS NOT NULL
			BEGIN 
				--Se extrae el metodo de pago del Documento timbrado de VTAS
				SELECT @MetodoDePagoDR = SUBSTRING(Documento,CHARINDEX('MetodoPago=',Documento)+12,3) FROM CFD WHERE Modulo = 'VTAS' and ModuloID = @IDOrigen
		--Para que un movimiento pueda ser considerado para timbrar, el metodo de pago de la factura no debe ser PUE
			IF @MetodoDePagoDR <> 'PUE'	
			BEGIN 
				
				IF @ClaveMov IN ('CXC.DP','CXC.D')	
				BEGIN 
					  INSERT CFDICobroVenta (Estacion, Empresa, IDMovimiento, IDCobro,		IDVenta,		AplicaFactor,MontoFactor, Doc, MovAplica, MovAplicaID)	
					  SELECT				@Estacion, @Empresa, @ID_Anterior,@ID		,	@IDOrigen,		@AplicaFactor,@MontoFactor, 1 , @Mov, @MovID
				END
				ELSE
				BEGIN
					
          			IF NOT  EXISTS ( SELECT * FROM @Movimientos WHERE Clave='CXC.D')
          			BEGIN
          				IF NOT EXISTS (SELECT * from CFDICobroVenta WHERE IDVenta=@IDOrigen AND IDCobro=@ID AND Empresa=@Empresa AND Estacion=@Estacion AND EsSaldoInicial = 0)	
							  INSERT CFDICobroVenta (Estacion,  Empresa,  IDMovimiento, IDCobro, IDVenta,	AplicaFactor,MontoFactor, MovAplica, MovAplicaID)		
							  SELECT                 @Estacion, @Empresa, @ID,          @ID,     @IDOrigen,	@AplicaFactor,@MontoFactor, @Mov, @MovID
			
				 	END
        
				END
			END
			END 
			ELSE  
			BEGIN 
			--Se extrae la clave del movimiento para determinar el origen
				SELECT TOP 1 @Clave = Clave, @IDOrigen = OID
				FROM @Movimientos 
				ORDER BY Nivel DESC
				
				IF @MetodoDePagoDR IS NULL
				BEGIN
					SELECT  @MetodoDePagoDR=mp.IDClave
					FROM CXC AS v
					LEFT JOIN Condicion AS c ON c.Condicion = v.Condicion 
					LEFT JOIN SATMetodoPago AS mp ON mp.Clave = c.CFD_metodoDePago
					WHERE ID = @IDOrigen
				END
				
				--Si el movimiento tiene como origen una Factura en CXC, se considera para timbrar
				IF @Clave IN ('CXC.F', 'CXC.CA', 'CXC.FB')  AND @MetodoDePagoDR <> 'PUE' 
				  IF @ClaveMov IN ('CXC.DP','CXC.D')
					BEGIN  
						
							  INSERT CFDICobroVenta (Estacion, Empresa,  IDMovimiento,  IDCobro, IDVenta, EsSaldoInicial,AplicaFactor,MontoFactor, Doc, MovAplica, MovAplicaID)		
							  SELECT				@Estacion, @Empresa, @ID_Anterior,	@ID,     @IDOrigen,1, @AplicaFactor,@MontoFactor, 1, @Mov, @MovID
					END
					ELSE
				  	BEGIN 
				  			IF NOT EXISTS (SELECT * FROM CFDICobroVenta AS cv WHERE cv.IDCobro=@ID AND cv.IDVenta=@IDOrigen AND cv.IDMovimiento=@ID AND cv.Empresa=@Empresa AND cv.Estacion=@Estacion AND cv.EsSaldoInicial= 1) 	
				  				IF @ClaveDetalle <>	'CXC.DP' AND @ClaveDetalle <>'CXC.D'						  
				  			INSERT CFDICobroVenta (Estacion, Empresa,  IDMovimiento,  IDCobro, IDVenta, EsSaldoInicial,AplicaFactor,MontoFactor, MovAplica, MovAplicaID)	
							  SELECT				@Estacion, @Empresa, @ID,			@ID,     @IDOrigen,1,			@AplicaFactor,@MontoFactor, @Mov, @MovID	

				  	END
			END
			--DES flujo de cheque devuelto
			IF @ClaveMovD = 'CXC.CD'
			BEGIN
				DECLARE cDevuelto CURSOR FOR
				 SELECT  vod.IdOrigen,  1, ISNULL(vod.MontoDevolucion,0)
					FROM VentaOrigenDevolucion AS vod
				WHERE vod.Id = @ID
					AND vod.Modulo = 'CXC'
				OPEN cDevuelto
				FETCH NEXT FROM cDevuelto INTO @IDOrigen, @AplicaFactor,@MontoFactor
				WHILE @@FETCH_STATUS = 0
				BEGIN
					SELECT @Clave = mt.Clave
					FROM MovTipo AS mt 
					INNER JOIN Venta AS v ON mt.Mov = v.Mov
					WHERE v.ID = @IDOrigen
						AND mt.Modulo = 'VTAS'

					SELECT @MetodoDePagoDR = SUBSTRING(Documento,CHARINDEX('MetodoPago=',Documento)+12,3) FROM CFD WHERE Modulo = 'VTAS' and ModuloID = @IDOrigen

					SELECT @Clave,@MetodoDePagoDR
				
					IF @Clave IN ('VTAS.F')  AND @MetodoDePagoDR <> 'PUE' 
					BEGIN

						INSERT CFDICobroVenta (Estacion,  Empresa,  IDMovimiento, IDCobro, IDVenta,	AplicaFactor,MontoFactor, MovAplica, MovAplicaID, CDevuelto)		
						SELECT                 @Estacion, @Empresa, @ID,          @ID,     @IDOrigen,	@AplicaFactor,@MontoFactor, @Mov, @MovID, 1
					END
					
					
				
				FETCH NEXT FROM cDevuelto INTO @IDOrigen, @AplicaFactor,@MontoFactor
				END
				CLOSE cDevuelto
				DEALLOCATE cDevuelto
				
			END
			 
		
			FETCH NEXT FROM CMovimientos INTO @Aplica, @AplicaID,@ImporteD
		END
		CLOSE CMovimientos
		DEALLOCATE CMovimientos

		--Si hay registros en la tabla CFDICobroVenta asociados al movimiento de Cobro, quiere decir que esté movimiento se puede timbrar 			
		IF EXISTS (SELECT * FROM CFDICobroVenta WHERE Estacion = @Estacion AND Empresa = @Empresa AND IDCobro = @ID)
		BEGIN 
			--Se procede a llenar la tabla de paso para timbrar teniendo en cuenta el origen del movimiento para determinar de que tablas se extraen los valores correspondiente	
		IF @OrigenTipo <> 'POS'
        IF @ClaveMov IN ('CXC.DP','CXC.D')	
        BEGIN	
 
				IF NOT EXISTS (SELECT * FROM CFDICobroParcial AS cp WHERE cp.ID=@cID AND  cp.Empresa=@Empresa AND cp.Estacion= @Estacion)
				BEGIN		    
				  INSERT INTO CFDICobroParcial(Estacion, Modulo, ID, Mov, MovID, Empresa, Sucursal, FechaEmision, FechaOriginal, LugarExpedicion, Cliente, 
							  FormaPago, NumOperacion, ClaveMoneda, TipoCambio, Monto, ClaveBancoEmisor, CuentaBancariaCte, ClaveBanco, CuentaBancaria, Folio, Serie, ClabeCuenta, Tarjeta)
				  SELECT @Estacion, 'CXC', A.ID, A.Mov, A.MovID, A.Empresa, A.Sucursal, A.FechaEmision, NULLIF(A.FechaOriginal, ''), ISNULL(G.CodigoPostal, H.CodigoPostal), A.Cliente, 
							  ISNULL(A.FormaCobro, cc.InfoFormaPago), A.Referencia, ISNULL(E.Clave, 'XXX'), A.TipoCambio, A.Importe + A.Impuestos, ISNULL(NULLIF(F.ClaveBanco, ''), NULLIF(cc.BancoCta, '')), 
							  ISNULL(NULLIF(F.CtaBanco, ''), NULLIF(cc.Cta, '')), D.Clave, /*NULLIF(D.ClaveSAT, ''),  */ISNULL( NULLIF(C.NumeroCta, ''), C.CLABE), a.MovID, NULLIF(@Serie, ''),
							  ISNULL(NULLIF(F.ClabeCuenta, ''), NULLIF(cc.ClabeCuenta, '')),ISNULL(NULLIF(F.Tarjeta, ''), NULLIF(cc.Tarjeta, ''))
				  FROM Cxc A
					  LEFT JOIN CtaDinero C ON A.CtaDinero = C.CtaDinero
            LEFT OUTER JOIN InstitucionFin i ON C.Institucion = i.Institucion
					  --LEFT JOIN CFDINominaInstitucionFin D ON C.BancoSucursal = D.Institucion
            LEFT OUTER JOIN CFDINominaSATInstitucionFin D ON i.Banco = D.Clave
					  INNER JOIN Mon E ON A.Moneda = E.Moneda
					  INNER JOIN Cte F ON F.Cliente = A.Cliente
					  LEFT JOIN CteCFD AS cc ON cc.Cliente = F.Cliente
					  INNER JOIN Sucursal G ON G.Sucursal = A.Sucursal 
					  INNER JOIN Empresa H ON A.Empresa = H.Empresa
				  WHERE A.ID = @ID_Anterior
          --update CFDICobroVenta SET IDCobro = @ID_Anterior WHERE Estacion = @Estacion AND Empresa = @Empresa AND IDCobro = @ID
			 END
        END
        ELSE
        	BEGIN	
        		IF NOT EXISTS (SELECT * FROM CFDICobroParcial AS cp WHERE cp.ID=@cID AND  cp.Empresa=@Empresa AND cp.Estacion= @Estacion )
				BEGIN	
				  INSERT INTO CFDICobroParcial(Estacion, Modulo, ID, Mov, MovID, Empresa, Sucursal, FechaEmision, FechaOriginal, LugarExpedicion, Cliente, 
							  FormaPago, NumOperacion, ClaveMoneda, TipoCambio, Monto, ClaveBancoEmisor, CuentaBancariaCte, ClaveBanco, CuentaBancaria, Folio, Serie, ClabeCuenta, Tarjeta)
				  SELECT @Estacion, 'CXC', A.ID, A.Mov, A.MovID, A.Empresa, A.Sucursal, A.FechaEmision, NULLIF(A.FechaOriginal, ''), ISNULL(G.CodigoPostal, H.CodigoPostal), A.Cliente, 
							  ISNULL(A.FormaCobro, cc.InfoFormaPago), A.Referencia, ISNULL(E.Clave, 'XXX'), A.TipoCambio, A.Importe + A.Impuestos, ISNULL(NULLIF(F.ClaveBanco, ''), NULLIF(cc.BancoCta, '')), 
							  ISNULL(NULLIF(F.CtaBanco, ''), NULLIF(cc.Cta, '')), D.Clave, /*NULLIF(D.ClaveSAT, ''),*/ISNULL( NULLIF(C.NumeroCta, ''), C.CLABE), @Folio, NULLIF(@Serie, ''),
							  ISNULL(NULLIF(F.ClabeCuenta, ''), NULLIF(cc.ClabeCuenta, '')),ISNULL(NULLIF(F.Tarjeta, ''), NULLIF(cc.Tarjeta, ''))
				  FROM Cxc A
					  LEFT JOIN CtaDinero C ON A.CtaDinero = C.CtaDinero
            LEFT OUTER JOIN InstitucionFin i ON C.Institucion = i.Institucion
					  --LEFT JOIN CFDINominaInstitucionFin D ON C.BancoSucursal = D.Institucion
            LEFT OUTER JOIN CFDINominaSATInstitucionFin D ON i.Banco = D.Clave
					  INNER JOIN Mon E ON A.Moneda = E.Moneda
					  INNER JOIN Cte F ON F.Cliente = A.Cliente
					  LEFT JOIN CteCFD AS cc ON cc.Cliente = F.Cliente
					  INNER JOIN Sucursal G ON G.Sucursal = A.Sucursal 
					  INNER JOIN Empresa H ON A.Empresa = H.Empresa
				  WHERE A.ID = @ID  
				END  
			  END       
			ELSE
			 IF NOT EXISTS (SELECT * FROM CFDICobroParcial AS cp WHERE cp.ID=@cID AND  cp.Empresa=@Empresa AND cp.Estacion= @Estacion)
			 BEGIN	
				INSERT INTO CFDICobroParcial(Estacion, Modulo, ID, Mov, MovID, Empresa, Sucursal, FechaEmision, FechaOriginal, LugarExpedicion, Cliente, 
							FormaPago, NumOperacion, ClaveMoneda, TipoCambio, Monto, ClaveBancoEmisor, CuentaBancariaCte, ClaveBanco, CuentaBancaria, Folio, Serie)
				SELECT @Estacion, 'CXC', A.ID, A.Mov, A.MovID, A.Empresa, A.Sucursal, A.FechaEmision, NULLIF(A.FechaOriginal, ''), ISNULL(G.CodigoPostal, H.CodigoPostal), A.Cliente, 
							A.FormaCobro, A.Referencia, ISNULL(E.Clave, 'XXX'), A.TipoCambio, A.Importe + A.Impuestos, ISNULL(NULLIF(Z.ClaveBanco, ''),0), NULLIF(Z.CtaBanco, ''), D.Clave /*NULLIF(D.ClaveSAT, '')*/, 
							NULLIF(C.NumeroCta, ''), @Folio, NULLIF(@Serie, '')
				FROM Cxc A
					LEFT JOIN POSCFDIRecepcionPagos Z ON A.ID = Z.ID
					LEFT JOIN CtaDinero C ON A.CtaDinero = Z.CtaDinero
          LEFT OUTER JOIN InstitucionFin i ON C.Institucion = i.Institucion
					--LEFT JOIN CFDINominaInstitucionFin D ON C.BancoSucursal = D.Institucion
          LEFT OUTER JOIN CFDINominaSATInstitucionFin D ON i.Banco = D.Clave
					INNER JOIN Mon E ON A.Moneda = E.Moneda
					INNER JOIN Sucursal G ON G.Sucursal = A.Sucursal 
					INNER JOIN Empresa H ON A.Empresa = H.Empresa
				WHERE A.ID = @ID 
				END
			
		END
		FETCH NEXT FROM cCxc INTO @ID, @Mov, @MovID, @OrigenTipo, @ClaveMov ,@ID_Anterior
	END
	CLOSE cCxc
	DEALLOCATE cCxc

END	
GO
