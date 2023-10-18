CREATE PROCEDURE spCFDICobroParcialMovimientosCxc  
	@Estacion			INT, 
	@Empresa			VARCHAR(5),
	@cID					INT = NULL,
	@Debug					BIT = NULL
--v.1.0 GON 24/05/2021 - Inicia integración de sp para CFDi v 4.0
AS  
BEGIN  
 DECLARE  
  @Folio    VARCHAR(50),  
  @Serie    VARCHAR(10),  
  @Mov    VARCHAR(20),  
  @MovID    VARCHAR(20),  
  @OrigenTipo   VARCHAR(10),  
  @Aplica    VARCHAR(20),  
  @AplicaID   VARCHAR(20),  
  @IDOrigen   INT,  
  @Clave    VARCHAR(10),  
  @MetodoDePagoDR  VARCHAR(5),  
  @ID     INT,  
  @FechaD    DATE = NULL,  
  @FechaH    DATE = NULL,  
  @Sucursal   INT = NULL,  
  @Cliente   VARCHAR(10),  
  @Modulo    VARCHAR(10),  
  @ClaveMov   VARCHAR(10),  
  @MovClave   VARCHAR(10),  
  @FEPOSC    DATETIME,  
  @FOPosE    DATETIME,  
  @LEPosC    VARCHAR(20),  
  @CtePosE   VARCHAR(20),  
  @FPPosC    VARCHAR(20),  
  @CMPosC    VARCHAR(20),  
  @TCPosC    FLOAT,  
  @CBEPosE   VARCHAR(20),  
  @CBCtePosC   VARCHAR(20),  
  @CBPosC    VARCHAR(20),  
  @CUBPosC   VARCHAR(20),  
        @ID_Anterior  INT,  
        @ID_SI    INT,  
        @IDDoc    INT,  
        @UsaHerramienta  BIT,  
        @AplicaD   VARCHAR(50),  
        @AplicaIDD   VARCHAR(20),  
        @IDAntes   INT,  
        @IDInicial   INT,  
        @ClaveDetalle  VARCHAR(20),  
        @AplicaFactor  FLOAT,  
        @MontoFactor  FLOAT,  
        @MontoCobro   FLOAT,  
        @MontoDocumento  FLOAT,  
        @ImporteD   FLOAT  ,

		@MetodoDePagoCFD	VARCHAR(100), --v.1.0 GON 24/05/2021 - Inicia integración de sp para CFDi v 4.0
		@ModuloOrigen		varchar(5)--v.1.0 GON 24/05/2021 - Inicia integración de sp para CFDi v 4.0

/*
LOG de Cambios por Integración

--v.1.0 GON 24/05/2021 - Inicia integración de sp para CFDi v 4.0

*/

 DECLARE @Movimientos TABLE (  
  OID   INT,  
  OModulo  VARCHAR(5),  
  OMov  VARCHAR(20),  
  OMovID  VARCHAR(20),  
  DID   INT,  
  DModulo  VARCHAR(5),  
  DMov  VARCHAR(20),  
  DMovID  VARCHAR(20),  
  Nivel  INT,  
  Clave  VARCHAR(10)   
 )  
 DECLARE @CxcDetalle TABLE (  
  Aplica  VARCHAR(30),  
  AplicaID VARCHAR(50)  
 )  
 DECLARE @CxcMovimientos TABLE (  
  ID    INT,  
  Mov    VARCHAR(30),  
  MovID   VARCHAR(50),  
  Clave   VARCHAR(10),  
  IDCobro   INT  
 )  
 DELETE FROM CFDICobroParcial WHERE Estacion = @Estacion  
 DELETE FROM CFDICobroVenta   WHERE Estacion = @Estacion  
 SET @UsaHerramienta = 0  
 
SELECT @FechaD = CONVERT(DATE, FechaEmision), @FechaH = CONVERT(DATE, FechaEmision), @Sucursal = Sucursal, @Cliente = Cliente  
 FROM CXC  
 WHERE ID = @cID AND Empresa = @Empresa  

 IF @Debug=1
 SELECT @FechaD, @FechaH, @Sucursal 
 
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
 
 IF  @Debug=1
 SELECT '@CxcDetalle',* FROM @CxcDetalle
 
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
   INSERT @CxcMovimientos ( ID, Mov,  MovID,  Clave  , IDCobro)  
   SELECT     @IDAntes , @AplicaD, @AplicaIDD, @MovClave ,@cID  
  END  
  ELSE  
  BEGIN  
   IF NOT EXISTS (SELECT * FROM @CxcMovimientos WHERE ID = @cID )  
   INSERT @CxcMovimientos ( ID, Mov, MovID,  Clave ,  IDCobro)  
   SELECT     c.ID, c.Mov, c.MovID, mt.Clave, @cID   
    FROM   Cxc AS c  
       INNER JOIN MovTipo  AS mt ON mt.Mov = c.Mov  
   WHERE c.ID = @cID  
    AND mt.Modulo = 'CXC'      
  END  
  FETCH NEXT FROM cCxcDetalle INTO @AplicaD, @AplicaIDD  
 END  
 CLOSE cCxcDetalle  
 DEALLOCATE cCxcDetalle  
 
 IF  @Debug=1
 SELECT '@CxcMovimientos',* FROM @CxcMovimientos
 
 IF  @Debug=1
  SELECT 'cCxc',A.ID, A.Mov, A.MovID, A.OrigenTipo, cm.Clave, cm.IDCobro  
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
  AND B.RecepcionPagosParcialidad = 1   --select * from MovTipo  
  AND cf.ModuloFactorajeID IS NULL  
 GROUP BY A.ID, A.Mov, A.MovID, A.OrigenTipo, A.FechaEmision, cm.Clave, cm.IDCobro  
 ORDER BY A.FechaEmision DESC   


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
  AND B.RecepcionPagosParcialidad = 1   --select * from MovTipo  
  AND cf.ModuloFactorajeID IS NULL  
 GROUP BY A.ID, A.Mov, A.MovID, A.OrigenTipo, A.FechaEmision, cm.Clave, cm.IDCobro  
 ORDER BY A.FechaEmision DESC   
 OPEN cCxc  
 FETCH NEXT FROM cCxc INTO @ID, @Mov, @MovID, @OrigenTipo, @ClaveMov ,@ID_Anterior  
 WHILE @@FETCH_STATUS = 0  
 BEGIN  

 IF @Debug=1
 SELECT @ID, @Mov, @MovID, @OrigenTipo, @ClaveMov ,@ID_Anterior  

 IF @ClaveMov IN ('CXC.D','CXC.DP')  
 BEGIN  
  SELECT @MontoDocumento = ISNULL (c.Importe,0) + ISNULL (c.Impuestos,0)  - ISNULL(c.Retencion, 0) - ISNULL(c.Retencion2, 0) - ISNULL(c.Retencion3, 0)
   FROM Cxc AS c  
   INNER JOIN CxcD AS cd ON c.ID=cd.ID  
  WHERE c.ID=@ID  
  SELECT @MontoCobro = cd.Importe FROM Cxc AS c  
  INNER JOIN CxcD AS cd ON c.ID=cd.ID  
  WHERE c.ID=@ID_Anterior  
  AND cd.Aplica=@Mov  
  AND cd.AplicaID=@MovID  
 END  
 ELSE  
 BEGIN  
  SELECT @MontoDocumento = cD.Importe FROM Cxc AS c  
  INNER JOIN CxcD AS cd ON c.ID=cd.ID  
  WHERE c.ID=@cID  
  AND cd.Aplica=@AplicaD  
  AND cd.AplicaID=@AplicaIDD  
  SELECT @MontoCobro = cd.Importe FROM Cxc AS c  
  INNER JOIN CxcD AS cd ON c.ID=cd.ID  
  WHERE c.ID=@cID  
  AND cd.Aplica=@AplicaD  
  AND cd.AplicaID=@AplicaIDD  
 END  


  SET @Folio = NULL  
  SET @Serie = NULL  
  SELECT @Folio = dbo.fnFolioConsecutivo(@MovID)  
  SELECT @Serie = REPLACE(@MovID, @Folio, '')  
  
  
 IF @Debug=1
 SELECT '@MontoDocumento',@MontoDocumento, @Folio, @Serie

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
   
   IF @Debug=1
   SELECT '@Movimientos',* FROM @Movimientos

   SELECT @IDOrigen = OID  
   FROM @Movimientos  
   WHERE Clave IN ('VTAS.F', 'VTAS.FB')  
   

   IF @Debug=1
   SELECT '@IDOrigen',@IDOrigen

IF @IDOrigen IS NOT NULL  
   BEGIN  
    SELECT @MetodoDePagoDR = SUBSTRING(Documento,CHARINDEX('MetodoPago=',Documento)+12,3) FROM CFD WHERE Modulo = 'VTAS' and ModuloID = @IDOrigen  

   IF @Debug=1
	SELECT '@MetodoDePagoDR',@MetodoDePagoDR

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
    IF @Clave IN ('CXC.F', 'CXC.CA', 'CXC.FB')  AND @MetodoDePagoDR <> 'PUE'  
      IF @ClaveMov IN ('CXC.DP','CXC.D')  
     BEGIN  
          INSERT CFDICobroVenta (Estacion, Empresa,  IDMovimiento,  IDCobro, IDVenta, EsSaldoInicial,AplicaFactor,MontoFactor, Doc, MovAplica, MovAplicaID)		
							  SELECT				@Estacion, @Empresa, @ID_Anterior,	@ID,     @IDOrigen,1, @AplicaFactor,@MontoFactor, 1, @Mov, @MovID
	END  
     ELSE  
       BEGIN  
         IF NOT EXISTS (SELECT * FROM CFDICobroVenta AS cv WHERE cv.IDCobro=@ID AND cv.IDVenta=@IDOrigen AND cv.IDMovimiento=@ID AND cv.Empresa=@Empresa AND cv.Estacion=@Estacion)  
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
  
  IF @Debug=1
		SELECT 'CFDICobroVenta',* FROM CFDICobroVenta WHERE Estacion = @Estacion AND Empresa = @Empresa AND IDCobro = @ID
		--select @OrigenTipo
	
IF EXISTS (SELECT * FROM CFDICobroVenta WHERE Estacion = @Estacion AND Empresa = @Empresa AND IDCobro = @ID)  
  BEGIN  -- Inicio IF EXISTS (SELECT * FROM CFDICobroVenta

 -- IF @OrigenTipo <> 'POS'  
  --v.1.0 GON 24/05/2021 - Inicia integración de sp para CFDi v 4.0
        --IF @ClaveMov IN ('CXC.DP','CXC.D')   -- Cobro Postfechado y Documento
        --BEGIN   --Inicio IF @ClaveMov IN ('CXC.DP','CXC.D')   
        --  IF NOT EXISTS (SELECT * FROM CFDICobroParcial AS cp WHERE cp.ID=@cID AND  cp.Empresa=@Empresa AND cp.Estacion= @Estacion)  
        --  BEGIN  --Inicio IF NOT EXISTS (SELECT * FROM CFDICobroParcial  
        --   INSERT INTO CFDICobroParcial(Estacion, Modulo, ID, Mov, MovID, Empresa, Sucursal, FechaEmision, FechaOriginal, LugarExpedicion, Cliente,  
        --       FormaPago, NumOperacion, ClaveMoneda, TipoCambio, Monto, ClaveBancoEmisor, CuentaBancariaCte, ClaveBanco, CuentaBancaria, Folio, Serie, ClabeCuenta, Tarjeta)  
        --    SELECT @Estacion, 'CXC', A.ID, A.Mov, A.MovID, A.Empresa, A.Sucursal, A.FechaEmision, NULLIF(A.FechaOriginal, ''), ISNULL(G.CodigoPostal, H.CodigoPostal), A.Cliente,  
        --       ISNULL(A.FormaCobro, cc.InfoFormaPago), A.Referencia, ISNULL(E.Clave, 'XXX'), A.TipoCambio, A.Importe + A.Impuestos, ISNULL(NULLIF(F.ClaveBanco, ''), NULLIF(cc.BancoCta, '')),  
        --       ISNULL(NULLIF(F.CtaBanco, ''), NULLIF(cc.Cta, '')), NULLIF(D.ClaveSAT, ''),  ISNULL( NULLIF(C.NumeroCta, ''), C.CLABE), a.MovID, NULLIF(@Serie, ''),  
        --       ISNULL(NULLIF(F.ClabeCuenta, ''), NULLIF(cc.ClabeCuenta, '')),ISNULL(NULLIF(F.Tarjeta, ''), NULLIF(cc.Tarjeta, ''))  
        --    FROM Cxc A  
        --     LEFT JOIN CtaDinero C ON A.CtaDinero = C.CtaDinero  
        --     LEFT JOIN CFDINominaInstitucionFin D ON C.BancoSucursal = D.Institucion  
        --     INNER JOIN Mon E ON A.Moneda = E.Moneda  
        --     INNER JOIN Cte F ON F.Cliente = A.Cliente  
        --     LEFT JOIN CteCFD AS cc ON cc.Cliente = F.Cliente  
        --     INNER JOIN Sucursal G ON G.Sucursal = A.Sucursal  
        --     INNER JOIN Empresa H ON A.Empresa = H.Empresa  
        --    WHERE A.ID = @ID_Anterior  AND ISNULL(a.FormaCobro,'')<>''
        --  END  -- FIN IF NOT EXISTS (SELECT * FROM CFDICobroParcial
        --END  -- FIN IF @ClaveMov IN ('CXC.DP','CXC.D')   
        --ELSE  --v.1.0 GON 24/05/2021 - Inicia integración de sp para CFDi v 4.0
 IF @OrigenTipo <> 'POS'  
     BEGIN   -- ELSE IF @ClaveMov IN ('CXC.DP','CXC.D') , es decir todos los demás  
          IF NOT EXISTS (SELECT * FROM CFDICobroParcial AS cp WHERE cp.ID=@cID AND  cp.Empresa=@Empresa AND cp.Estacion= @Estacion )  
			BEGIN  -- Incio IF NOT EXISTS (SELECT * FROM CFDICobroParcial
		--CASO 1. Desde el Cobro se indica la cuenta y la forma de pago

		--BEGIN TRY
			INSERT INTO CFDICobroParcial(Estacion, Modulo, ID, Mov, MovID, Empresa, Sucursal, FechaEmision, FechaOriginal, LugarExpedicion, Cliente,  
					 FormaPago, NumOperacion, ClaveMoneda, TipoCambio, Monto, ClaveBancoEmisor, CuentaBancariaCte, ClaveBanco, CuentaBancaria, Folio, Serie, 
					 ClabeCuenta, Tarjeta)  
				  SELECT @Estacion, 'CXC', A.ID, A.Mov, A.MovID, A.Empresa, A.Sucursal, A.FechaEmision, NULLIF(A.FechaOriginal, ''), ISNULL(G.CodigoPostal, H.CodigoPostal), A.Cliente,  
					 ISNULL(A.FormaCobro, cc.InfoFormaPago), A.Referencia, ISNULL(E.Clave, 'XXX'), A.TipoCambio, A.Importe + A.Impuestos, ISNULL(NULLIF(F.ClaveBanco, ''), NULLIF(cc.BancoCta, '')),  
					 ISNULL(NULLIF(F.CtaBanco, ''), NULLIF(cc.Cta, '')), NULLIF(D.ClaveSAT, ''),ISNULL( NULLIF(C.NumeroCta, ''), C.CLABE), @Folio, NULLIF(@Serie, ''),  
					 ISNULL(NULLIF(F.ClabeCuenta, ''), NULLIF(cc.ClabeCuenta, '')),ISNULL(NULLIF(F.Tarjeta, ''), NULLIF(cc.Tarjeta, ''))  
				  FROM Cxc A  
				   --LEFT JOIN CtaDinero C ON A.CtaDinero = C.CtaDinero  
				   INNER JOIN CtaDinero C ON A.CtaDinero = C.CtaDinero  -- Para asegurarse de que fue pagado --v.1.0 GON 24/05/2021 - Inicia integración de sp para CFDi v 4.0
				   LEFT JOIN CFDINominaInstitucionFin D ON C.BancoSucursal = D.Institucion  
				   INNER JOIN Mon E ON A.Moneda = E.Moneda  
				   INNER JOIN Cte F ON F.Cliente = A.Cliente  
				   LEFT JOIN CteCFD AS cc ON cc.Cliente = F.Cliente  
				   INNER JOIN Sucursal G ON G.Sucursal = A.Sucursal  
				   INNER JOIN Empresa H ON A.Empresa = H.Empresa  
				  WHERE A.ID = @ID   AND ISNULL(a.FormaCobro,'')<>''
		--	END TRY

			--BEGIN CATCH
			--SELECT 'Aqui está el problema',  @@Error, ERROR_MESSAGE()
			--END CATCH

			IF @Debug=1
			SELECT 'CFDICobroParcial',* FROM CFDICobroParcial AS cp WHERE cp.ID=@cID AND cp.Estacion= @Estacion 
			
			END   -- FIN IF NOT EXISTS (SELECT * FROM CFDICobroParcial
   
   				--Caso 2. Se realiza un Depósito Electrónico, Depósito o Ingreso al avanzar una Solicitud de Depósito en Tesorería
				DECLARE @TotalCobro MONEY, @TotalIngreso MONEY
				SELECT @TotalCobro = 0, @TotalIngreso =0

				SELECT @TotalCobro = ISNULL(A.Importe,0)+ISNULL(A.Impuestos,0) FROM CxC A WHERE ID=@ID


						DECLARE @CFDiDestino TABLE(
						IDCxC			INT,
						ID				INT,
						Modulo			CHAR(5),
						Mov				VARCHAR(20),
						MovID			VARCHAR(20)	
						)

				INSERT INTO @CFDiDestino
				SELECT DISTINCT @ID, ID,Modulo,Mov,MovID FROM dbo.fnBuscaOrigenDestino('CxC',@ID,@Empresa) a WHERE Modulo='DIN' 

				IF @Debug=1
				SELECT '@CFDiDestino',* FROM @CFDiDestino 

				--SELECT c.*, m.*
				--FROM CxC A JOIN @CFDiDestino c ON A.ID=c.IDCxC 
				--LEFT JOIN MovTipo m ON c.Modulo=m.Modulo AND  c.Mov = m.Mov
				--LEFT JOIN Dinero d ON c.ID=d.ID		    
				--WHERE c.Modulo='DIN' AND m.Clave IN ('DIN.D','DIN.DE', 'DIN.I')


					DECLARE @CFDiDinero TABLE(
						IDCxC			INT,
						ID				INT,
						Modulo			CHAR(5),
						Mov				VARCHAR(20),
						MovID			VARCHAR(20),
						IDDin			INT,
						MovDin			VARCHAR(20),
						MovIDDin		VARCHAR(20),
						CtaDinero		CHAR(10) ,
						FormaPago		VARCHAR(50),
						Importe			MONEY,
						Referencia		VARCHAR(50),
						Aplica			VARCHAR(20),
						AplicaID		VARCHAR(20)
						)
						
					DECLARE @CFDiDinero1 TABLE(
						IDCxC			INT,
						ID				INT,
						Modulo			CHAR(5),
						Mov				VARCHAR(20),
						MovID			VARCHAR(20),
						IDDin			INT,
						MovDin			VARCHAR(20),
						MovIDDin		VARCHAR(20),
						CtaDinero		CHAR(10) ,
						FormaPago		VARCHAR(50),
						Importe			MONEY,
						Referencia		VARCHAR(50),
						Aplica			VARCHAR(20),
						AplicaID		VARCHAR(20)
						)


					DECLARE @CFDiDineroa TABLE(
						IDCxC			INT,
						ID				INT,
						Modulo			CHAR(5),
						Mov				VARCHAR(20),
						MovID			VARCHAR(20),
						IDDin			INT,
						MovDin			VARCHAR(20),
						MovIDDin		VARCHAR(20),
						CtaDinero		CHAR(10) ,
						FormaPago		VARCHAR(50),
						Importe			MONEY,
						Referencia		VARCHAR(50),
						Aplica			VARCHAR(20),
						AplicaID		VARCHAR(20)
						)
						
				INSERT INTO @CFDiDinero1
				SELECT c.IDCxC, c.ID, c.Modulo, c.Mov, c.MovID, d.ID, d.Mov, d.MovID, d.CtaDinero, dd.FormaPago,dd.Importe,dd.Referencia, dd.Aplica, dd.AplicaID  
				FROM CxC A JOIN @CFDiDestino c ON A.ID=c.IDCxC 
				JOIN MovFlujo b ON c.ID=b.OID AND c.Modulo=b.OModulo
				LEFT JOIN MovTipo m ON b.DModulo=m.Modulo AND  b.DMov = m.Mov
				LEFT JOIN Dinero d ON b.DID=d.ID
			    LEFT JOIN DineroD dd ON d.ID=dd.ID
				WHERE b.DModulo='DIN' AND m.Clave IN ('DIN.D','DIN.DE', 'DIN.I')
				AND c.Mov=dd.Aplica AND c.MovID=dd.AplicaID
				AND d.Estatus='CONCLUIDO' -- 08/02/2018 GOJEDA

				IF @Debug=1
				BEGIN
				SELECT '@CFDiDinero1',* FROM @CFDiDinero1
				SELECT 'CFDICobroParcial',ID FROM CFDICobroParcial WHERE Estacion=@Estacion AND ID=@ID
				END

				IF EXISTS(SELECT ID FROM CFDICobroParcial WHERE Estacion=@Estacion AND ID=@ID) 
				INSERT INTO @CFDiDineroA
				SELECT c.IDCxC, c.ID, c.Modulo, c.Mov, c.MovID, d.ID, d.Mov, d.MovID, d.CtaDinero, d.FormaPago,ISNULL(d.Importe,0)+ISNULL(d.Impuestos,0),d.Referencia, NULL, NULL  
				FROM CxC A JOIN @CFDiDestino c ON A.ID=c.IDCxC 
				LEFT JOIN MovTipo m ON c.Modulo=m.Modulo AND  c.Mov = m.Mov
				LEFT JOIN Dinero d ON c.ID=d.ID		
				LEFT JOIN @CFDiDinero1 b  ON d.ID  = b.IDDin 
				WHERE c.Modulo='DIN' AND m.Clave IN ('DIN.D','DIN.DE', 'DIN.I') AND b.ID IS NULL
				AND d.Estatus='CONCLUIDO' -- 08/02/2018 GOJEDA

				INSERT INTO @CFDiDinero
				SELECT * FROM @CFDiDinero1
				UNION ALL
				SELECT * FROM @CFDiDineroA
				
				SELECT @TotalIngreso = SUM(ISNULL(Importe,0)) 
				FROM @CFDiDinero1 WHERE IDCxC=@ID GROUP BY IDCxC 
			
				IF @Debug=1
				SELECT '@TotalIngreso',@TotalIngreso, 'TotalCobro', ROUND(ISNULL(@TotalCobro,0),4)
				
				-- Revisar validar que el total del cobro, sea igual al total del ing
				IF ROUND(ISNULL(@TotalCobro,0),4) <>  ROUND(ISNULL(@TotalIngreso,0),4) 
				BEGIN

				IF @cID IS NOT NULL
				BEGIN
					DECLARE @MensajeError varchar(8000)
					SELECT @MensajeError='El Total del Cobro de CxC ( '+ CAST(ROUND(ISNULL(@TotalCobro,0),4) AS varchar)+' ), no corresponde con el Total Ingresado en Tesorería ( '+  CAST(ROUND(ISNULL(@TotalIngreso,0),4) AS varchar)+' )'
				    RAISERROR(@MensajeError,16,-1)

					CLOSE cCxc
					DEALLOCATE cCxc
					RETURN
				END
				ELSE
				FETCH NEXT FROM cCxc INTO @ID, @Mov, @MovID, @OrigenTipo, @ClaveMov ,@ID_Anterior  
				END
				ELSE
				BEGIN
				
				IF @Debug=1
				BEGIN
				SELECT Top 1 @Estacion, 'CxC', A.ID, A.Mov, A.MovID, A.Empresa, A.Sucursal, A.FechaEmision, NULLIF(A.FechaOriginal, ''), ISNULL(G.CodigoPostal, H.CodigoPostal), A.Cliente,  
					B.FormaPago, A.Referencia, ISNULL(E.Clave, 'XXX'), A.TipoCambio, ISNULL(A.Importe,0) + ISNULL(A.Impuestos,0), ISNULL(NULLIF(F.ClaveBanco, ''), cc.BancoCta), ISNULL(NULLIF(F.CtaBanco, ''), cc.Cta),
					 NULLIF(D.ClaveSAT, ''),ISNULL( NULLIF(C.NumeroCta, ''), C.CLABE), @Folio, NULLIF(@Serie, ''),  
					 ISNULL(NULLIF(F.ClabeCuenta, ''), NULLIF(cc.ClabeCuenta, '')),ISNULL(NULLIF(F.Tarjeta, ''), NULLIF(cc.Tarjeta, ''))  
				FROM Cxc A
				INNER JOIN @CFDiDinero B ON a.ID=b.IDCxC
					INNER JOIN CtaDinero C ON B.CtaDinero = C.CtaDinero -- Para asegurarse de que fue pagado
					LEFT JOIN CFDINominaInstitucionFin D ON C.BancoSucursal = D.Institucion
					INNER JOIN Mon E ON A.Moneda = E.Moneda
					INNER JOIN Cte F ON F.Cliente = A.Cliente
					LEFT JOIN CteCFD AS cc ON cc.Cliente = F.Cliente
					INNER JOIN Sucursal G ON G.Sucursal = A.Sucursal 
					INNER JOIN Empresa H ON A.Empresa = H.Empresa
				WHERE A.ID = @ID
				ORDER BY ISNULL(B.Importe,0) DESC

				SELECT 'Cobro Parcial'

				END

				BEGIN TRY
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
				IF NOT EXISTS (SELECT * FROM CFDICobroParcial WHERE Estacion=@Estacion AND ID=@ID)				
				INSERT INTO CFDICobroParcial(Estacion, Modulo, ID, Mov, MovID, Empresa, Sucursal, FechaEmision, FechaOriginal, LugarExpedicion, Cliente,  
					 FormaPago, NumOperacion, ClaveMoneda, TipoCambio, Monto, ClaveBancoEmisor, CuentaBancariaCte, ClaveBanco, 
					CuentaBancaria, Folio, Serie, ClabeCuenta, Tarjeta)  
				SELECT Top 1 @Estacion, 'CxC', A.ID, A.Mov, A.MovID, A.Empresa, A.Sucursal, A.FechaEmision, NULLIF(A.FechaOriginal, ''), ISNULL(G.CodigoPostal, H.CodigoPostal), A.Cliente,  
					B.FormaPago, A.Referencia, ISNULL(E.Clave, 'XXX'), A.TipoCambio, ISNULL(A.Importe,0) + ISNULL(A.Impuestos,0), ISNULL(NULLIF(F.ClaveBanco, ''), cc.BancoCta), ISNULL(NULLIF(F.CtaBanco, ''), cc.Cta),
					 NULLIF(D.ClaveSAT, ''),ISNULL( NULLIF(C.NumeroCta, ''), C.CLABE), @Folio, NULLIF(@Serie, ''),  
					 ISNULL(NULLIF(F.ClabeCuenta, ''), NULLIF(cc.ClabeCuenta, '')),ISNULL(NULLIF(F.Tarjeta, ''), NULLIF(cc.Tarjeta, ''))  
				FROM Cxc A
				INNER JOIN @CFDiDinero B ON a.ID=b.IDCxC
					INNER JOIN CtaDinero C ON B.CtaDinero = C.CtaDinero -- Para asegurarse de que fue pagado
					 LEFT OUTER JOIN InstitucionFin i ON C.Institucion = i.Institucion
					--LEFT JOIN CFDINominaInstitucionFin D ON C.BancoSucursal = D.Institucion
					LEFT OUTER JOIN CFDINominaSATInstitucionFin D ON i.Banco = D.Clave
					INNER JOIN Mon E ON A.Moneda = E.Moneda
					INNER JOIN Cte F ON F.Cliente = A.Cliente
					LEFT JOIN CteCFD AS cc ON cc.Cliente = F.Cliente
					INNER JOIN Sucursal G ON G.Sucursal = A.Sucursal 
					INNER JOIN Empresa H ON A.Empresa = H.Empresa
				WHERE A.ID = @ID
				ORDER BY ISNULL(B.Importe,0) DESC
        	END
        	END
				END TRY

				BEGIN CATCH
				SELECT 'Aquí esta el error 2', @@Error,  ERROR_MESSAGE()
				END CATCH
				IF @Debug=1
				BEGIN
				SELECT 'CFDICobroParcial'
				END


				END
   
   END  --FIN ELSE IF @ClaveMov IN ('CXC.DP','CXC.D')  
   --v.1.0 GON 24/05/2021 - Inicia integración de sp para CFDi v 4.0


   ELSE  
    IF NOT EXISTS (SELECT * FROM CFDICobroParcial AS cp WHERE cp.ID=@cID AND  cp.Empresa=@Empresa AND cp.Estacion= @Estacion)  
    BEGIN   
    INSERT INTO CFDICobroParcial(Estacion, Modulo, ID, Mov, MovID, Empresa, Sucursal, FechaEmision, FechaOriginal, LugarExpedicion, Cliente,  
       FormaPago, NumOperacion, ClaveMoneda, TipoCambio, Monto, ClaveBancoEmisor, CuentaBancariaCte, ClaveBanco, CuentaBancaria, Folio, Serie)  
    SELECT @Estacion, 'CXC', A.ID, A.Mov, A.MovID, A.Empresa, A.Sucursal, A.FechaEmision, NULLIF(A.FechaOriginal, ''), ISNULL(G.CodigoPostal, H.CodigoPostal), A.Cliente,  
       A.FormaCobro, A.Referencia, ISNULL(E.Clave, 'XXX'), A.TipoCambio, A.Importe + A.Impuestos, ISNULL(NULLIF(Z.ClaveBanco, ''),0), NULLIF(Z.CtaBanco, ''), NULLIF(D.ClaveSAT, ''),  
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

 IF @Debug=1
 SELECT * FROM CFDICobroParcial WHERE Estacion=@Estacion AND Modulo='CxC' AND ID =@ID

END   
GO