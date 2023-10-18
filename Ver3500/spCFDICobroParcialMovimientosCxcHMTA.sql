CREATE PROCEDURE  spCFDICobroParcialMovimientosCxcHMTA  
@Estacion   INT,  
@Empresa   VARCHAR(5),  
@cID    INT = NULL  
AS  
BEGIN  
DECLARE  
@Folio    VARCHAR(50),  
@Serie    VARCHAR(10),  
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
@ClaveDetalle     VARCHAR(20),  
@AplicaFactor  FLOAT,  
@MontoFactor  FLOAT,  
@MontoCobro   FLOAT,  
@MontoDocumento  FLOAT,  
@ImporteD   FLOAT,  
@AplicaD   VARCHAR(20),  
@AplicaIDD   VARCHAR(20)  
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
DELETE FROM CFDICobroParcial WHERE Estacion = @Estacion  
DELETE FROM CFDICobroVenta   WHERE Estacion = @Estacion  
SET @UsaHerramienta = 0  
IF @cID IS NULL  
BEGIN  
SELECT @FechaD = CONVERT(DATE, FechaD), @FechaH = CONVERT(DATE, FechaH), @Sucursal = Sucursal, @Cliente = Cliente  
FROM CFDICobroParcialFiltros  
WHERE Estacion = @Estacion  
SET @UsaHerramienta = 1  
END  
ELSE  
SELECT @FechaD = CONVERT(DATE, FechaEmision), @FechaH = CONVERT(DATE, FechaEmision), @Sucursal = Sucursal, @Cliente = Cliente  
FROM CXC  
WHERE ID = @cID AND Empresa = @Empresa  
SELECT @ClaveMov=Clave FROM MovTipo AS mt  
JOIN MovFlujo AS mf on mt.Mov=mf.OMov  
WHERE mf.DID=@cID  
AND mt.Modulo='CXC'  
AND mf.Cancelado=0  
IF @ClaveMov IN ('CXC.DP','CXC.D')  
BEGIN  
SELECT @ID_Anterior = @cID  
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
SELECT @cID=oid FROM MovFlujo  
WHERE dID=@cID  
AND DModulo='CXC'  
AND Cancelado=0  
END  
SELECT @FechaD = CONVERT(DATE, FechaEmision), @FechaH = CONVERT(DATE, FechaEmision), @Sucursal = Sucursal, @Cliente = Cliente  
FROM CXC  
WHERE ID = @cID AND Empresa = @Empresa  
DECLARE cCxc CURSOR FOR  
SELECT A.ID, A.MovID, A.OrigenTipo,cd.Aplica,cd.AplicaID  
FROM Cxc AS A  
JOIN CxcD AS cd ON a.ID=cd.ID  
INNER JOIN MovTipo AS B ON B.Modulo = 'CXC' AND A.Mov = B.Mov  
LEFT JOIN CFDIDocRelacionadoTimbrado AS cpt ON cpt.IDMODULO = A.ID  
LEFT JOIN CFDIDocRelacionadoTimbrado AS cp ON cp.IDCobro = A.ID  
LEFT JOIN CFDICobroFactoraje AS cf ON cf.ModuloFactorajeID=A.ID  
WHERE A.Estatus = 'CONCLUIDO'  
AND A.FechaEmision BETWEEN @FechaD AND @FechaH  
AND B.Clave IN ('CXC.C', 'CXC.ANC', 'CXC.NET'/*,'CXC.DP','CXC.D'*/)  
AND A.Empresa = @Empresa  
AND A.ID = ISNULL(@cID, A.ID)  
AND A.Cliente = ISNULL(@Cliente, A.Cliente)  
AND  (cpt.IDMODULO IS NULL OR cpt.Cancelado = 1)  
AND cp.IDCobro IS NULL  
AND B.RecepcionPagosParcialidad = 1  
AND A.Sucursal = ISNULL(@Sucursal ,A.Sucursal)  
AND cf.ModuloFactorajeID IS NULL  
GROUP BY A.ID, A.MovID, A.OrigenTipo, A.FechaEmision,cd.Aplica,cd.AplicaID  
ORDER BY A.FechaEmision DESC  
OPEN cCxc  
FETCH NEXT FROM cCxc INTO @ID, @MovID, @OrigenTipo,@Aplica,@AplicaID  
WHILE @@FETCH_STATUS = 0  
BEGIN  
SELECT @AplicaD = @Aplica, @AplicaIDD = @AplicaID  
SET @Folio = NULL  
SET @Serie = NULL  
SELECT @Folio = dbo.fnFolioConsecutivo(@MovID)  
SELECT @Serie = REPLACE(@MovID, @Folio, '')  
IF @UsaHerramienta = 1  AND @cID IS NULL  
BEGIN  
SELECT @ClaveMov=Clave FROM MovTipo AS mt  
JOIN MovFlujo AS mf on mt.Mov=mf.OMov  
WHERE mf.DID=@ID  
AND mt.Modulo='CXC'  
AND mf.Cancelado=0  
AND mf.OMov=@Aplica  
AND mf.OMovID=@AplicaID  
IF @ClaveMov IN ('CXC.DP','CXC.D')  
BEGIN  
SELECT @ID_Anterior = @ID  
SELECT @ID=oid FROM MovFlujo  AS mf  
WHERE dID=@ID  
AND Cancelado=0  
AND DModulo='CXC'  
AND mf.OMov=@Aplica  
AND mf.OMovID=@AplicaID  
END  
END  
DECLARE CMovimientos CURSOR FOR  
SELECT  Aplica, AplicaID,cd.Importe FROM CxcD AS cd  
INNER JOIN MovTipo AS mt ON mt.Mov = cd.Aplica  
WHERE ID = @ID  
AND mt.Modulo='CXC'  
AND mt.Clave<>'CXC.D'  
AND mt.Clave<>'CXC.DP'  
AND NULLIF(cd.AplicaID ,'') <> NULL  
OPEN CMovimientos  
FETCH NEXT FROM CMovimientos INTO @Aplica, @AplicaID, @ImporteD  
WHILE @@FETCH_STATUS = 0  
BEGIN  
SET @IDOrigen = NULL  
SET @Clave = NULL  
SET @MetodoDePagoDR = NULL  
SET @AplicaFactor = NULL  
SET @MontoFactor = NULL  
SET @MontoCobro = NULL  
SET @MontoCobro = NULL  
DELETE FROM @Movimientos  
IF @ClaveMov IN ('CXC.D','CXC.DP')  
BEGIN  
SELECT @MontoDocumento = ISNULL (c.Importe,0) + ISNULL (c.Impuestos,0)  
FROM Cxc AS c  
INNER JOIN CxcD AS cd ON c.ID=cd.ID  
WHERE c.ID=@ID  
SELECT @MontoCobro = cd.Importe FROM Cxc AS c  
INNER JOIN CxcD AS cd ON c.ID=cd.ID  
WHERE c.ID=@ID_Anterior  
AND cd.Aplica=@AplicaD  
AND cd.AplicaID=@AplicaIDD  
END  
ELSE  
BEGIN  
SELECT @MontoDocumento = cD.Importe FROM Cxc AS c  
INNER JOIN CxcD AS cd ON c.ID=cd.ID  
WHERE c.ID=@ID  
AND cd.Aplica=@Aplica  
AND cd.AplicaID=@AplicaID  
SELECT @MontoCobro = cd.Importe FROM Cxc AS c  
INNER JOIN CxcD AS cd ON c.ID=cd.ID  
WHERE c.ID=@ID  
AND cd.Aplica=@Aplica  
AND cd.AplicaID=@AplicaID  
END  
SELECT @ClaveDetalle=mt.Clave  
FROM MovTipo AS mt WHERE mt.Mov=@Aplica  
AND mt.Modulo='CXC'  
IF @ClaveDetalle IN ('CXC.D','CXC.DP')  
BEGIN  
FETCH NEXT FROM CMovimientos INTO @Aplica, @AplicaID, @ImporteD  
END  
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
SELECT @IDOrigen = OID  
FROM @Movimientos  
WHERE Clave IN ('VTAS.F', 'VTAS.FB')  
IF @IDOrigen IS NOT NULL  
BEGIN  
SELECT @MetodoDePagoDR = SUBSTRING(Documento,CHARINDEX('MetodoPago=',Documento)+12,3) FROM CFD WHERE Modulo = 'VTAS' and ModuloID = @IDOrigen  
IF @MetodoDePagoDR <> 'PUE'  
BEGIN  
IF @ClaveMov IN ('CXC.DP','CXC.D')  
BEGIN  
IF NOT EXISTS (SELECT * FROM CFDICobroVenta AS cv WHERE cv.IDCobro=@ID AND cv.IDVenta=@IDOrigen AND cv.Empresa=@Empresa AND cv.Estacion=@Estacion)  
BEGIN  
INSERT CFDICobroVenta (Estacion, Empresa, IDMovimiento, IDCobro, IDVenta,AplicaFactor, MontoFactor, Doc)  
SELECT @Estacion, @Empresa, @ID_Anterior, @ID, @IDOrigen,@AplicaFactor,@MontoFactor, 1  
END  
END  
ELSE  
BEGIN  
IF NOT EXISTS (SELECT * FROM CFDICobroVenta AS cv WHERE cv.IDCobro=@ID AND cv.IDVenta=@IDOrigen AND cv.Empresa=@Empresa AND cv.Estacion=@Estacion )  
IF @ClaveDetalle <>'CXC.D' AND @ClaveDetalle <>'CXC.DP'  
BEGIN  
INSERT CFDICobroVenta (Estacion,  Empresa,  IDMovimiento, IDCobro, IDVenta, AplicaFactor, MontoFactor)  
SELECT                 @Estacion, @Empresa, @ID,          @ID,     @IDOrigen,@AplicaFactor,@MontoFactor  
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
INSERT CFDICobroVenta (Estacion, Empresa,  IDMovimiento,  IDCobro, IDVenta, EsSaldoInicial,AplicaFactor,MontoFactor, Doc)  
SELECT    @Estacion, @Empresa, @ID_Anterior,   @ID,     @IDOrigen,1,@AplicaFactor,@MontoFactor, 1  
ELSE  
IF NOT EXISTS (SELECT * FROM CFDICobroVenta AS cv WHERE cv.IDCobro=@ID AND cv.IDVenta=@IDOrigen AND cv.IDMovimiento=@ID AND cv.Empresa=@Empresa AND cv.Estacion=@Estacion)  
INSERT CFDICobroVenta (Estacion, Empresa,  IDMovimiento,  IDCobro, IDVenta, EsSaldoInicial, AplicaFactor, MontoFactor)  
SELECT    @Estacion, @Empresa, @ID,   @ID,     @IDOrigen,1, @AplicaFactor,@MontoFactor  
END  
FETCH NEXT FROM CMovimientos INTO @Aplica, @AplicaID, @ImporteD  
END  
CLOSE CMovimientos  
DEALLOCATE CMovimientos  
IF EXISTS (SELECT * FROM CFDICobroVenta WHERE Estacion = @Estacion AND Empresa = @Empresa AND IDCOBRO = @ID)  
BEGIN  
IF @OrigenTipo <> 'POS'  
IF @ClaveMov IN ('CXC.DP','CXC.D')  
BEGIN  
IF NOT EXISTS (SELECT * FROM CFDICobroParcial AS cp  
JOIN CXC AS a ON a.ID=@ID_Anterior WHERE cp.Estacion=@Estacion  
AND cp.ID=a.ID AND a.Empresa=@Empresa)  
INSERT INTO CFDICobroParcial(Estacion, Modulo, ID, Mov, MovID, Empresa, Sucursal, FechaEmision, FechaOriginal, LugarExpedicion, Cliente,  
FormaPago, NumOperacion, ClaveMoneda, TipoCambio, Monto, ClaveBancoEmisor, CuentaBancariaCte, ClaveBanco, CuentaBancaria, Folio, Serie, ClabeCuenta, Tarjeta)  
SELECT @Estacion, 'CXC', A.ID, A.Mov, A.MovID, A.Empresa, A.Sucursal, A.FechaEmision, NULLIF(A.FechaOriginal, ''), ISNULL(G.CodigoPostal, H.CodigoPostal), A.Cliente,  
ISNULL(A.FormaCobro, cc.InfoFormaPago), A.Referencia, ISNULL(E.Clave, 'XXX'), A.TipoCambio, A.Importe + A.Impuestos, ISNULL(NULLIF(F.ClaveBanco, ''), NULLIF(cc.BancoCta, '')),  
ISNULL(NULLIF(F.CtaBanco, ''), NULLIF(cc.Cta, '')), NULLIF(D.ClaveSAT, ''),  ISNULL( NULLIF(C.NumeroCta, ''), C.CLABE), a.MovID, NULLIF(@Serie, ''),  
ISNULL(NULLIF(F.ClabeCuenta, ''), NULLIF(cc.ClabeCuenta, '')),ISNULL(NULLIF(F.Tarjeta, ''), NULLIF(cc.Tarjeta, ''))  
FROM Cxc A  
LEFT JOIN CtaDinero C ON A.CtaDinero = C.CtaDinero  
LEFT JOIN CFDINominaInstitucionFin D ON C.BancoSucursal = D.Institucion  
INNER JOIN Mon E ON A.Moneda = E.Moneda  
INNER JOIN Cte F ON F.Cliente = A.Cliente  
LEFT JOIN CteCFD AS cc ON cc.Cliente = F.Cliente  
INNER JOIN Sucursal G ON G.Sucursal = A.Sucursal  
INNER JOIN Empresa H ON A.Empresa = H.Empresa  
WHERE A.ID = @ID_Anterior  
END  
ELSE  
IF NOT EXISTS (SELECT * FROM CFDICobroParcial AS cp  
JOIN CXC AS a ON a.ID=cp.ID WHERE cp.Estacion=@Estacion  
AND cp.ID=@ID AND a.Empresa=@Empresa)  
BEGIN  
INSERT INTO CFDICobroParcial(Estacion, Modulo, ID, Mov, MovID, Empresa, Sucursal, FechaEmision, FechaOriginal, LugarExpedicion, Cliente,  
FormaPago, NumOperacion, ClaveMoneda, TipoCambio, Monto, ClaveBancoEmisor, CuentaBancariaCte, ClaveBanco, CuentaBancaria, Folio, Serie, ClabeCuenta, Tarjeta)  
SELECT @Estacion, 'CXC', A.ID, A.Mov, A.MovID, A.Empresa, A.Sucursal, A.FechaEmision , NULLIF(A.FechaOriginal, ''), ISNULL(G.CodigoPostal, H.CodigoPostal), A.Cliente,  
ISNULL(A.FormaCobro, cc.InfoFormaPago), A.Referencia, ISNULL(E.Clave, 'XXX'), A.TipoCambio, A.Importe + A.Impuestos, ISNULL(NULLIF(F.ClaveBanco, ''), NULLIF(cc.BancoCta, '')),  
ISNULL(NULLIF(F.CtaBanco, ''), NULLIF(cc.Cta, '')), NULLIF(D.ClaveSAT, ''),ISNULL( NULLIF(C.NumeroCta, ''), C.CLABE), @Folio, NULLIF(@Serie, ''),  
ISNULL(NULLIF(F.ClabeCuenta, ''), NULLIF(cc.ClabeCuenta, '')),ISNULL(NULLIF(F.Tarjeta, ''), NULLIF(cc.Tarjeta, ''))  
FROM Cxc A  
LEFT JOIN CtaDinero C ON A.CtaDinero = C.CtaDinero  
LEFT JOIN CFDINominaInstitucionFin D ON C.BancoSucursal = D.Institucion  
INNER JOIN Mon E ON A.Moneda = E.Moneda  
INNER JOIN Cte F ON F.Cliente = A.Cliente  
LEFT JOIN CteCFD AS cc ON cc.Cliente = F.Cliente  
INNER JOIN Sucursal G ON G.Sucursal = A.Sucursal  
INNER JOIN Empresa H ON A.Empresa = H.Empresa  
WHERE A.ID = @ID  
END  
ELSE  
IF NOT EXISTS (SELECT * FROM CFDICobroParcial AS cp  
JOIN CXC AS a ON a.ID=cp.ID WHERE cp.Estacion=@Estacion  
AND cp.ID=a.ID AND a.Empresa=@Empresa)  
BEGIN  
INSERT INTO CFDICobroParcial(Estacion, Modulo, ID, Mov, MovID, Empresa, Sucursal, FechaEmision, FechaOriginal, LugarExpedicion, Cliente,  
FormaPago, NumOperacion, ClaveMoneda, TipoCambio, Monto, ClaveBancoEmisor, CuentaBancariaCte, ClaveBanco, CuentaBancaria, Folio, Serie)  
SELECT @Estacion, 'CXC', A.ID, A.Mov, A.MovID, A.Empresa, A.Sucursal, A.FechaEmision, NULLIF(A.FechaOriginal, ''), ISNULL(G.CodigoPostal, H.CodigoPostal), A.Cliente,  
A.FormaCobro, A.Referencia, ISNULL(E.Clave, 'XXX'), A.TipoCambio, A.Importe + A.Impuestos, ISNULL(NULLIF(Z.ClaveBanco, ''),0), NULLIF(Z.CtaBanco, ''), NULLIF(D.ClaveSAT, ''),  
NULLIF(C.NumeroCta, ''), @Folio, NULLIF(@Serie, '')  
FROM Cxc A  
LEFT JOIN POSCFDIRecepcionPagos Z ON A.ID = Z.ID  
LEFT JOIN CtaDinero C ON A.CtaDinero = Z.CtaDinero  
LEFT JOIN CFDINominaInstitucionFin D ON C.BancoSucursal = D.Institucion  
INNER JOIN Mon E ON A.Moneda = E.Moneda  
INNER JOIN Sucursal G ON G.Sucursal = A.Sucursal  
INNER JOIN Empresa H ON A.Empresa = H.Empresa  
WHERE A.ID = @ID  
END  
END  
FETCH NEXT FROM cCxc INTO @ID, @MovID, @OrigenTipo,@Aplica,@AplicaID  
END  
CLOSE cCxc  
DEALLOCATE cCxc  
END

GO