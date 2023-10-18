SET DATEFIRST 7
SET ANSI_NULLS OFF
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET LOCK_TIMEOUT -1
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF
SET ARITHABORT OFF
SET ANSI_WARNINGS OFF
GO

/******************************* spCFDICobroParcialMovimientosCxcMontos *************************************************/
IF EXISTS (SELECT * FROM sysobjects WHERE id = object_id('dbo.spCFDICobroParcialMovimientosCxcMontos') AND TYPE = 'P')
DROP PROCEDURE spCFDICobroParcialMovimientosCxcMontos
GO
CREATE PROCEDURE spCFDICobroParcialMovimientosCxcMontos
	@Estacion			INT, 
	@Empresa			VARCHAR(5),
	@ID					INT ,
	@cID				INT ,
	@IDVenta			INT,
	@UUID				VARCHAR (50),
	@ModuloRelacionado	VARCHAR	(20),
	@MontoTotal			FLOAT,
	@MonedaDocto		VARCHAR(10),		
	@DecimalesDR		INT,
	@Modulo				VARCHAR(5),
	@TipoCambioDR		FLOAT,
	@TipoCambioP		FLOAT,
	@MonedaP			VARCHAR(4),
	@TipoCFD			VARCHAR(10),
	@NumParcialidadSI	INT,
	@EsSaldoinicial		BIT
	
--//WITH ENCRYPTION	
AS 
BEGIN

	DECLARE
		@Folio				        VARCHAR(50),
		@Serie				        VARCHAR(10),
		@MovID			  	        VARCHAR(20),
		@OrigenTipo		          	VARCHAR(10),
		@Aplica				        VARCHAR(20),
		@AplicaID			        VARCHAR(20),
		@Clave				        VARCHAR(10),
		@MetodoDePagoDR				VARCHAR(5),
		@Cliente			        VARCHAR(10),
		@AplicaIDD			        VARCHAR(20),
		@AplicaFactor		        FLOAT,
		@MontoFactor		        FLOAT,
		@MontoCobro			        FLOAT,
		@MontoDocumento		        FLOAT,
		@ImporteD			        FLOAT,
		@NumParcialidad		        INT,
		@NumParcialidadTimbrado		FLOAT,
		@NumParcialidadNoTimbrado	FLOAT,
		@MontoPagado		        FLOAT,
		@SaldoAnterior		        FLOAT,
		@ImpPagado			        FLOAT,
		@ImpSaldoInsoluto	        FLOAT,
		@MontoTotalTimbrado			FLOAT,
		@MontoTotalNoTimbrado		FLOAT,
		@Factoraje			        BIT,
		@MontoEgreso				FLOAT,
		@IDUltimoCobro				INT,
		@NumParcialidadEgreso		INT , 
		@Documento					BIT = 0,
		@IDDoc						INT,
		@AjustarN					BIT = 0,
		@ToleranciaN				FLOAT,
		@TieneAjusteNegativo		BIT = 0


		
	  DECLARE @Movimientos TABLE (
		  OID			INT,
		  OModulo		VARCHAR(5),
		  OMov			VARCHAR(20),
		  OMovID		VARCHAR(20),
		  DID			INT,
		  DModulo		VARCHAR(5),
		  DMov			VARCHAR(20),
		  DMovID		VARCHAR(20),
		  Nivel			INT,
		  Clave			VARCHAR(10)	
	  )
	
	  DECLARE @CFDIDocRelacionadoTimbrado TABLE
	  (
		  Modulo			VARCHAR(10),
		  IDModulo			INT,
		  IDCobro			INT,
		  UUID			    VARCHAR(50),
		  Serie				VARCHAR(20),
		  Folio				VARCHAR(20),
		  ImpPagado			FLOAT,
		  ImpSaldoAnt		FLOAT,
		  ImpSaldoInsoluto	FLOAT,
		  Moneda			VARCHAR(20),
		  TipoCambio		FLOAT,
		  NumParcialidad	INT,			
		  MetodoPago		VARCHAR(20),
		  Cancelado			BIT,
		  Consecutivo		INT 
	  )
	
	  DECLARE @PagosFactura TABLE
		(
			ID				    INT,
			MontoPagado		FLOAT,
			Clave			    VARCHAR(10),
			SubClave	  	VARCHAR(20),
			ClaveD		  	VARCHAR(20),
			CFD				    BIT,
			Parcialidad		BIT,
			FechaEmision  DATETIME NULL,
			FechaOriginal DATETIME NULL,
			AplicaD       VARCHAR(50) NULL,
			AplicaIDD     VARCHAR(50) NULL	
		)
		
	  DECLARE @PagosAplica TABLE
		  (
			Aplica			  VARCHAR(20),
			AplicaID		  VARCHAR(20),
			Parcialidad			BIT	
		  )
		
	  DECLARE @MontosXMLFactura TABLE 
	  (
		  IDVenta				INT ,
		  IDCobro				INT	,
		  NumParcialidad		INT	,
		  ImpPagado			    FLOAT,
		  ImpSaldoAnt			FLOAT,
		  ImpSaldoInsoluto		FLOAT,		
		  Cancelado			    BIT,
		  AplicaFactor			FLOAT,
		  Factoraje			    BIT
	  )

		DELETE FROM MontosXMLFactura WHERE Estacion= @Estacion AND Empresa=@Empresa
		DELETE FROM @CFDIDocRelacionadoTimbrado
		DELETE FROM @PagosAplica
		DELETE FROM @PagosFactura
		DELETE FROM @MontosXMLFactura


		SELECT @AjustarN = ISNULL(AjustarNegativosREP, 0) 
		 FROM EmpresaCFD
		WHERE Empresa = @Empresa 

		IF @AjustarN = 1 AND ( SELECT NULLIF(AjustarNegativosTolerancia, '') FROM CFDICobroParcial WHERE Empresa = @Empresa  AND ID = @ID AND Estacion = @Estacion) IS NOT NULL
			SELECT @ToleranciaN =  AjustarNegativosTolerancia
			 FROM CFDICobroParcial
			WHERE Empresa = @Empresa 
			AND ID = @ID
			AND Estacion = @Estacion
		ELSE
			SELECT @ToleranciaN =  AjustarNegativosTolerancia
			 FROM EmpresaCFD
			WHERE Empresa = @Empresa 

		IF @AjustarN = 1 AND SIGN(ROUND(@ToleranciaN, 2)) = 1
			SELECT @ToleranciaN = @ToleranciaN * -1

		SET @Documento = 0
		SET @IDDoc = NULL
		SET @TieneAjusteNegativo = 0

		--SE EXTRAEN TODOS LOS REGISTROS QUE SE HAYAN TIMMBRADO Y AFECTEN EL SALDO DE LA FACURA
		INSERT INTO @CFDIDocRelacionadoTimbrado (Modulo , IDModulo , IDCobro , UUID , Serie , Folio , ImpPagado , ImpSaldoAnt ,	ImpSaldoInsoluto , Moneda, TipoCambio ,
												NumParcialidad , MetodoPago , Cancelado,Consecutivo )
		SELECT									crt.Modulo,crt.IDModulo,crt.IDCobro,crt.UUID,crt.Serie,crt.Folio,crt.ImpPagado,crt.ImpSaldoAnt,crt.ImpSaldoInsoluto,crt.Moneda,crt.TipoCambio,
											crt.NumParcialidad,	crt.MetodoPago,	crt.Cancelado,crt.Consecutivo
		 FROM CFDIDocRelacionadoTimbrado AS crt
		WHERE crt.UUID=@UUID
		AND crt.Cancelado=0

		--SE EXTRAEN LOS MOVIMIENTOS QUE AFECTEN AL SALDO DE LA FACTURA
		;WITH FlujoPago
		AS (
			SELECT *
			FROM dbo.movflujo mf
			WHERE mf.OID = @IDVenta AND mf.OModulo = @ModuloRelacionado AND mf.Cancelado = 0 AND mf.Empresa = @Empresa
			UNION ALL
			SELECT e.*
			FROM dbo.movflujo AS e
				INNER JOIN FlujoPago AS fp ON e.OID = fp.DID AND e.OModulo = fp.DModulo AND e.Cancelado = 0
		)
		
		INSERT INTO @PagosAplica (Aplica, AplicaID)
		SELECT DISTINCT OMov, OMovID
		FROM FlujoPago AS fp
			INNER JOIN MovTipo AS mt ON mt.Mov = fp.DMov AND mt.Modulo = fp.DModulo
		WHERE mt.Clave IN ('CXC.C', 'CXC.ANC', 'CXC.NC', 'CXC.NET','CXC.DP','CXC.D')


		INSERT @PagosFactura (ID, MontoPagado, Clave,ClaveD, SubClave, CFD, Parcialidad, FechaEmision , FechaOriginal, AplicaD, AplicaIDD)
		SELECT cd.ID, ROUND(ISNULL(CASE WHEN e.Clave <> 'MXN' AND @MonedaDocto = 'MXN' THEN ROUND(cd.Importe, @DecimalesDR, 0) * (c.TipoCambio)	
									WHEN e.Clave = 'MXN' AND @MonedaDocto <> 'MXN' THEN ROUND(cd.Importe, @DecimalesDR, 0) / (c.ClienteTipoCambio)
									WHEN e.Clave = @MonedaDocto THEN ROUND(cd.Importe, @DecimalesDR, 0)
									ELSE ROUND(ROUND(cd.Importe, @DecimalesDR, 0) / ROUND(c.ClienteTipoCambio, @DecimalesDR, 0), @DecimalesDR, 0) *  ROUND(c.TipoCambio, @DecimalesDR, 0) 
								END, 0), @DecimalesDR, 0), mt.Clave, mtd.Clave, mt.SubClave, 
									CASE WHEN @TipoCFD  = 'Ant' THEN ISNULL(mt.CFD ,0) ELSE ISNULL(mt.CFDFlex, 0) END , ISNULL(mt.RecepcionPagosParcialidad, 1), c.FechaEmision, c.FechaOriginal, cd.Aplica, cd.AplicaID
		FROM CxcD AS cd
			INNER JOIN Cxc AS c ON c.ID = cd.ID
			INNER JOIN MovTipo AS mt ON mt.Mov = c.Mov AND mt.Modulo = 'CXC'
			INNER JOIN MovTipo AS mtd ON mtd.Mov = cd.Aplica AND mtd.Modulo = 'CXC'
			INNER JOIN Mon E ON c.Moneda = E.Moneda 
			INNER JOIN @PagosAplica AS t ON t.Aplica = cd.Aplica AND t.AplicaID = cd.AplicaID
		WHERE c.Estatus = 'CONCLUIDO' AND mt.Clave IN ('CXC.C', 'CXC.ANC', 'CXC.NC', 'CXC.NET'/*,'CXC.DP','CXC.D'*/) 
			AND c.Empresa = @Empresa

		--SE EXTRAE EL MONTO QUE SE PAGARA A LA FACTURA EN EL COBRO ACTUAL
		IF @Modulo='DIN' AND EXISTS (SELECT CV.IDAplicaCobro  FROM CFDICobroVenta AS cv WHERE cv.IDVenta = @IDVenta AND cv.IDAplicaCobro = @cID AND cv.IDMovimiento = @ID AND cv.Estacion = @Estacion AND cv.Empresa = @Empresa )
		BEGIN
			SELECT @MontoPagado = cv.MontoFactor,@AplicaFactor=cv.AplicaFactor,@Factoraje=cv.Factoraje
			FROM   CFDICobroVenta AS cv
			WHERE cv.IDVenta = @IDVenta
				  AND cv.IDAplicaCobro = @cID
				  AND cv.IDMovimiento = @ID
				  AND cv.Estacion = @Estacion
				  AND cv.Empresa = @Empresa
				  AND cv.EsSaldoInicial = ISNULL( @EsSaldoinicial,0)
		END
		ELSE		      
			SELECT @MontoPagado = cv.MontoFactor,@AplicaFactor=cv.AplicaFactor,@Factoraje=cv.Factoraje
			FROM   CFDICobroVenta AS cv
			WHERE cv.IDVenta = @IDVenta
				  AND cv.IDCobro = @cID
				  AND cv.IDMovimiento = @ID
				  AND cv.Estacion = @Estacion
				  AND cv.Empresa = @Empresa
				  AND NULLIF (cv.IDAplicaCobro ,'') IS NULL
				   AND cv.EsSaldoInicial = ISNULL( @EsSaldoinicial,0)

		---SE CALCULA EL SALDO ANTERIOR DE LA FACTURA
		SET @MontoTotalTimbrado=NULL
		SET @MontoTotalNoTimbrado=NULL
		SET @MontoEgreso= NULL
		

		IF @Modulo = 'CXC' AND  (SELECT mt.Clave FROM CXC  AS c JOIN MovTipo AS mt ON c.Mov = mt.Mov AND mt.Modulo = 'CXC' WHERE c.ID= @cID ) = 'CXC.D'
		BEGIN
			SELECT @IDDoc = @cID
			IF @IDDoc IS NOT NULL
				SET @Documento = 1 
				SELECT @cID= NULL 
			
			SELECT @cID = @ID
		END
		
		SELECT TOP 1 @MontoTotalTimbrado = ISNULL(crt.ImpSaldoInsoluto,0),@NumParcialidadTimbrado = ISNULL (crt.NumParcialidad,0),@SaldoAnterior= crt.ImpSaldoInsoluto,
					 @IDUltimoCobro = ISNULL(crt.IDCobro,0) 
			FROM @CFDIDocRelacionadoTimbrado AS crt 
		WHERE crt.UUID= @UUID
			AND crt.Cancelado<>1 
		ORDER BY crt.IDCobro DESC , crt.Consecutivo DESC

		IF @NumParcialidadTimbrado IS NOT NULL
		 SET @NumParcialidadSI = 0
		
		IF NULLIF(@IDUltimoCobro ,'') IS NULL
			SET @IDUltimoCobro=0 
		
		SELECT @MontoTotalNoTimbrado =ISNULL( SUM(MontoPagado),0) 
			FROM @PagosFactura AS pf
		LEFT JOIN CFDICobroParcialTimbrado AS cpt ON cpt.IDModulo = pf.ID
		LEFT JOIN CFDIDocRelacionadoTimbrado AS crt ON crt.IDCobro = pf.ID
		LEFT JOIN CFDICobroVenta AS cv ON pf.ID = cv.IDCobro
		WHERE ID <  @cID
			AND pf.ID > @IDUltimoCobro
			AND crt.IDCobro = NULL AND ISNULL(crt.Cancelado,0)= 0
			AND cpt.IDModulo = NULL AND ISNULL(cpt.Cancelado,0)=  0
			AND pf.CFD<>1
			AND ISNULL (cv.Factoraje,0) = 0
			AND ISNULL (cv.Estacion, @Estacion) = @Estacion
			AND ISNULL (cv.Empresa, @Empresa) = @Empresa
			AND pf.Clave <> 'CXC.C'
		   
		SELECT @MontoEgreso= SUM(ISNULL(MontoPagado , 0))
		  FROM @PagosFactura AS pf    
		LEFT JOIN CFDICobroParcialTimbrado AS cpt ON cpt.IDModulo = pf.ID
		WHERE pf.CFD = 1 
		AND cpt.IDModulo = NULL and ISNULL(cpt.Cancelado,0)=  0
		AND ID <  @cID
		AND pf.ID > @IDUltimoCobro

		--Se calcula el saldo anterior
		IF NULLIF(@SaldoAnterior,'') IS NULL
		  SELECT @SaldoAnterior = @MontoTotal
	
		SELECT @SaldoAnterior = @SaldoAnterior - ISNULL(@MontoTotalNoTimbrado , 0) - ISNULL (@MontoEgreso , 0)
		
		IF @MonedaP <> 'MXN' AND @MonedaDocto = 'MXN'
		BEGIN
			SELECT @SaldoAnterior = @SaldoAnterior * @TipoCambioDR
			SELECT @MontoPagado =	@MontoPagado * @TipoCambioP 
			--SELECT @MontoPagado = @MontoPagado  - 0.005
		END
		ELSE IF @MonedaP = 'MXN' AND @MonedaDocto <> 'MXN'
		BEGIN
			--SELECT @MontoPagado =  @MontoPagado * ROUND (@TipoCambioP / @TipoCambioDR, 6)
      SELECT @MontoPagado =  @MontoPagado*(@TipoCambioP/@TipoCambioDR)
		END
		ELSE IF @MonedaP <> 'MXN' AND @MonedaDocto <> 'MXN' AND @MonedaP <> @MonedaDocto
		BEGIN  
			SET @MontoPagado = (@MontoPagado * @TipoCambioP) / @TipoCambioDR
			--SELECT @MontoPagado = @MontoPagado - 0.005
		END

		SELECT @MontoPagado = ROUND(@MontoPagado,2)

		--SE CALCULA EL SALDO INSOLUTO
		SELECT @ImpSaldoInsoluto =  ISNULL(@SaldoAnterior,0) - ISNULL(@MontoPagado,0)
		
		IF ROUND(@ImpSaldoInsoluto,8) < 0 AND ROUND(@ImpSaldoInsoluto,8) > -0.09
		BEGIN
			SET @ImpSaldoInsoluto = 0.00
			SELECT @MontoPagado = @MontoPagado -.006
			SELECT @ImpSaldoInsoluto = 	ISNULL(@SaldoAnterior,0) - ISNULL(@MontoPagado,0)
		END

		--CAMBIO PARA AJUSTAR NEGATIVOS 
		IF @AjustarN = 1 AND @ToleranciaN IS NOT NULL
		BEGIN
	
			WHILE (ROUND(@ImpSaldoInsoluto,2) < 0 AND ROUND(@ImpSaldoInsoluto,2) > @ToleranciaN)
			BEGIN
				SET @ImpSaldoInsoluto = 0.00
				SELECT @MontoPagado = @MontoPagado -.01
				SELECT @ImpSaldoInsoluto = 	ISNULL(@SaldoAnterior,0) - ISNULL(@MontoPagado,0)
			
			END
			SET @TieneAjusteNegativo = 1
		END	


		--Se calcula el numero de parcialidad
		SELECT @NumParcialidadNoTimbrado= count(pf.ID)
			FROM @PagosFactura AS pf
			LEFT  JOIN CFDICobroParcialTimbrado AS cpt ON cpt.IDModulo = pf.ID
			LEFT JOIN CFDIDocRelacionadoTimbrado AS crt ON crt.IDCobro = pf.ID
			LEFT JOIN CFDICobroVenta AS cv ON pf.ID = cv.IDCobro
		WHERE ID <  @cID
			AND  pf.ID > @IDUltimoCobro
			AND cpt.IDModulo = NULL AND ISNULL(cpt.Cancelado,0)=  0
			AND crt.IDCobro = NULL AND ISNULL(crt.Cancelado,0)= 0
			AND pf.CFD<>1
			AND pf.Parcialidad = 1
			AND ISNULL (cv.Factoraje,0) = 0
			AND ISNULL (cv.Estacion, @Estacion) = @Estacion
			AND ISNULL (cv.Empresa, @Empresa) = @Empresa
			AND cv.CDevuelto <> 1
		
		SELECT @NumParcialidadEgreso = COUNT(pf.ID)
		  FROM @PagosFactura AS pf    
		LEFT JOIN CFDICobroParcialTimbrado AS cpt ON cpt.IDModulo = pf.ID
		WHERE pf.CFD = 1
		AND ISNULL (pf.Parcialidad,0) = 1
		AND cpt.IDModulo = NULL and ISNULL(cpt.Cancelado,0)=  0
		AND ID <  @cID
		AND pf.ID > @IDUltimoCobro
		
		IF @IDDoc IS NOT NULL AND @Documento = 1
			SELECT @cID = @IDDoc
		

		SELECT @NumParcialidad = ISNULL (@NumParcialidadTimbrado,0)+ ISNULL(@NumParcialidadNoTimbrado,0)+ ISNULL(@NumParcialidadEgreso, 0) + ISNULL (@NumParcialidadSI, 0) + 1

		--Tabla temporal de saldos
		INSERT @MontosXMLFactura		(IDVenta,IDCobro,NumParcialidad, ImpPagado,   ImpSaldoAnt,	ImpSaldoInsoluto,	AplicaFactor)
		SELECT							@IDVenta,@cID	,@NumParcialidad,@MontoPagado,@SaldoAnterior,@ImpSaldoInsoluto,@AplicaFactor
		
		INSERT MontosXMLFactura		(IDVenta,IDCobro,NumParcialidad, ImpPagado,   ImpSaldoAnt,	ImpSaldoInsoluto,	AplicaFactor, Estacion, Empresa, Factoraje, TieneAjusteNegativo )
		SELECT							@IDVenta,@cID	,@NumParcialidad,@MontoPagado,@SaldoAnterior,@ImpSaldoInsoluto,@AplicaFactor, @Estacion,@Empresa,@Factoraje, @TieneAjusteNegativo
		
END	
GO
