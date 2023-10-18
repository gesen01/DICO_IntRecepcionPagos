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
		
		@Folio				INT,
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
		@ModuloOrigen		varchar(5),
		@MetodoDePagoCFD	VARCHAR(100)
		
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
		
	-----------------------------------------------------------------------------------------------
	DELETE FROM CFDICobroParcial WHERE Estacion = @Estacion
	DELETE FROM CFDICobroVenta	 WHERE Estacion = @Estacion
	
	DECLARE cTesoreria CURSOR FOR
		SELECT 'DIN', A.ID, A.FechaEmision, SUM(ISNULL(A.Importe, C.Importe)), A.MovID
		FROM Dinero A 
			INNER JOIN MovTipo B ON B.Modulo = 'DIN' AND A.Mov = B.Mov
			INNER JOIN DineroD C ON A.ID = C.ID
			LEFT JOIN CFDICobroParcialTimbrado AS cpt ON cpt.IDModulo = A.ID AND cpt.Modulo = 'DIN'
			WHERE A.Estatus = 'CONCLUIDO' AND A.FechaEmision >= '01/06/2017' AND B.Clave IN ('DIN.D','DIN.DE','DIN.I') --AND B.SubClave IS NULL
				AND A.Empresa = @Empresa  AND cpt.IDModulo IS NULL
		GROUP BY A.ID, A.FechaEmision, A.MovID
		ORDER BY A.FechaEmision DESC
	  
	OPEN cTesoreria
	FETCH NEXT FROM cTesoreria INTO @cModulo, @cID, @cFechaEmision, @cImporte, @cMovID
	
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
		
		SELECT @Folio = dbo.fnFolioConsecutivo(@cMovID)
		SELECT @Serie = REPLACE(@cMovID, @Folio, '')


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
		  
		SELECT @IDCxc= A.ID, @MovCxc = A.Mov, @MovIDCxc = A.MovID, @OrigenTipo = A.OrigenTipo
		FROM Cte AS B 
			INNER JOIN Cxc AS A ON A.ID = B.OID AND B.OModulo = 'CXC'
			INNER JOIN MovTipo AS mt ON mt.Mov = A.Mov
		WHERE mt.Clave = 'CXC.C'
	

	-----------------------------------------------------------------------------------------------
		IF @IDCxc IS NOT NULL AND NOT EXISTS (SELECT * FROM CFDICobroParcialTimbrado WHERE MovIDOrigen = @IDCxc AND Cancelado = 0) 
		BEGIN
				
				--IF @IDCxc=689237
				--SELECT Aplica, AplicaID,* FROM CxcD
				--WHERE ID = @IDCxc

			DECLARE CMovimientos CURSOR FOR
				SELECT Aplica, AplicaID FROM CxcD
				WHERE ID = @IDCxc
	
			OPEN CMovimientos
			FETCH NEXT FROM CMovimientos INTO @Aplica, @AplicaID
			WHILE @@FETCH_STATUS = 0
			BEGIN
				
				SET @MetodoDePagoDR = NULL
				SET @IDOrigen = NULL 
				SET @Clave = NULL 
				DELETE FROM @Movimientos
				
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


			
				SELECT @IDOrigen = OID, @ModuloOrigen =OModulo
				FROM @Movimientos
				WHERE Clave = 'VTAS.F'   
		
				IF @IDOrigen IS NOT NULL
				BEGIN 
					

				SELECT @MetodoDePagoCFD = MetodoPago FROM CFD WHERE Modulo=@ModuloOrigen AND ModuloID=@IDOrigen

				SELECT @MetodoDePagoDR = CASE WHEN UPPER(@MetodoDePagoCFD) = 'PAGO EN UNA SOLA EXHIBICION' THEN 'PUE' ELSE 'PPD' END

				--SELECT @MetodoDePagoDR = mp.IDClave
				--FROM Venta AS v
				--	LEFT JOIN Condicion AS c ON c.Condicion = v.Condicion 
				--	LEFT JOIN SATMetodoPago AS mp ON mp.Clave = c.CFD_metodoDePago
				--WHERE ID = @IDOrigen
							
					IF @MetodoDePagoDR <> 'PUE'
						INSERT CFDICobroVenta (Estacion, Empresa, IDCobro, IDVenta)	
						SELECT @Estacion, @Empresa, @cID, @IDOrigen
				END 
				ELSE  
				BEGIN 
				
					SELECT TOP 1 @Clave = Clave, @IDOrigen = OID
					FROM @Movimientos 
					ORDER BY Nivel DESC
				
					IF @Clave IN ('CXC.F', 'CXC.NC')
						INSERT CFDICobroVenta (Estacion, Empresa, IDCobro, IDVenta, EsSaldoInicial)	
						SELECT @Estacion, @Empresa, @cID, @IDOrigen, 1
				END 
		
				FETCH NEXT FROM CMovimientos INTO @Aplica, @AplicaID
		
			END
	
			CLOSE CMovimientos
			DEALLOCATE CMovimientos
				
			IF EXISTS (SELECT * FROM CFDICobroVenta WHERE Estacion = @Estacion AND Empresa = @Empresa AND IDCobro = @cID)
			BEGIN 
					
				IF @OrigenTipo = 'POS'
				BEGIN
					SELECT @CtaBanco = NULL, @CveBanco = NULL, @NumeroCta = NULL, @ClaveSAT = NULL
					SELECT @CtaBanco = a.CtaBanco, @CveBanco = a.ClaveBanco, @NumeroCta = b.NumeroCta, @ClaveSAT = c.ClaveSAT
						FROM POSCFDIRecepcionPagos a
							LEFT JOIN CtaDinero b ON a.CtaDinero = b.CtaDinero
							LEFT JOIN CFDINominaInstitucionFin c ON b.BancoSucursal = c.Institucion
						WHERE a.ID = @IDCxc

					INSERT INTO CFDICobroParcial(Estacion, ID, Mov, MovID, IDCxc, MovCxc, MovIDCxc, Empresa, Sucursal, FechaEmision, LugarExpedicion,
								Cliente, FormaPago, NumOperacion, ClaveMoneda, TipoCambio, Monto, ClaveBancoEmisor, CuentaBancariaCte, ClaveBanco, 
								CuentaBancaria, Folio, Serie)
					SELECT TOP 1 @Estacion, A.ID, A.Mov, A.MovID, @IDCxc, @MovCxc, @MovIDCxc, A.Empresa, A.Sucursal, A.FechaEmision, ISNULL(G.CodigoPostal, H.CodigoPostal), A.Contacto, 
									ISNULL(B.FormaPago, A.FormaPago), ISNULL(A.Referencia, B.Referencia), ISNULL(E.Clave, 'XXX'), A.TipoCambio, @cImporte, ISNULL(@CveBanco,0), @CtaBanco, @ClaveSAT, @NumeroCta, @Folio, NULLIF(@Serie, '')
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

				END ELSE 
				BEGIN
					INSERT INTO CFDICobroParcial(Estacion, ID, Mov, MovID, IDCxc, MovCxc, MovIDCxc, Empresa, Sucursal, FechaEmision, LugarExpedicion,
								Cliente, FormaPago, NumOperacion, ClaveMoneda, TipoCambio, Monto, ClaveBancoEmisor, CuentaBancariaCte, ClaveBanco, 
								CuentaBancaria, Folio, Serie)
					SELECT TOP 1 @Estacion, A.ID, A.Mov, A.MovID, @IDCxc, @MovCxc, @MovIDCxc, A.Empresa, A.Sucursal, A.FechaEmision, ISNULL(G.CodigoPostal, H.CodigoPostal), A.Contacto, 
									ISNULL(B.FormaPago, A.FormaPago), ISNULL(A.Referencia, B.Referencia), ISNULL(E.Clave, 'XXX'), A.TipoCambio, @cImporte, ISNULL(NULLIF(F.ClaveBanco, ''), cc.BancoCta), ISNULL(NULLIF(F.CtaBanco, ''), cc.Cta), D.ClaveSAT, C.NumeroCta, @Folio, NULLIF(@Serie, '')
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
	
				END
				
			END

		END

		FETCH NEXT FROM cTesoreria INTO @cModulo, @cID, @cFechaEmision, @cImporte, @cMovID
		
	END	
	-----------------------------------------------------------------------------------------------	
	CLOSE cTesoreria
	DEALLOCATE cTesoreria

END	
GO