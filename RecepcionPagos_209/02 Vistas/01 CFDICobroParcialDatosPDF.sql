SET DATEFIRST 7
SET ANSI_NULLS OFF
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET LOCK_TIMEOUT -1
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF
SET ARITHABORT OFF
SET ANSI_WARNINGS OFF
GO

IF EXISTS(SELECT * FROM sysobjects WHERE id = OBJECT_ID('dbo.CFDICobroParcialDatosPDF') AND type = 'V') 
  DROP VIEW CFDICobroParcialDatosPDF
GO    
CREATE VIEW CFDICobroParcialDatosPDF AS
	 SELECT pdf.Estacion															AS Estacion, 
			pdf.ID																	AS ID, 
			pdf.IDModulo															AS ModuloID,
			pdf.Modulo																AS Modulo,
			e.RFC																	AS RFCEmisor,
			e.Nombre																AS Emisor,
			cpt.RFC																	AS RFCReceptor,
      CONVERT(varchar(40), cpt.UUID)          AS UUID,
			c.Nombre																AS Receptor,
      c.CodigoPostal                          AS ReceptorCodigoPostal,
      c.FiscalRegimen                         AS ReceptorRegimenFiscal,
      CASE WHEN ISNULL(fr.Extranjero, 0) = 1 THEN cc.NumRegIdTrib ELSE NULL END AS ReceptorNumRegIdTrib,
      fr.Extranjero,
			CASE WHEN cp.FechaOriginal IS NOT NULL THEN cp.FechaOriginal 
			ELSE cp.FechaEmision END												AS FechaPago,
			CASE WHEN sfp.Clave='17' THEN sfp.Descripcion ELSE cp.FormaPago END		AS FormaPago,
			cp.NumOperacion															AS NumOperacion,
			CASE WHEN SFP.Bancarizado = 1 THEN be.Rfc ELSE NULL END					AS RFCBancoEmisor,
			CASE WHEN SFP.Bancarizado = 1 THEN be.Nombre ELSE NULL END				AS BancoOrdenante,
			CASE WHEN SFP.Bancarizado = 1 THEN
				(CASE WHEN sfp.Clave IN ('02','03') THEN cpt.ClabeCuentaCte
					  WHEN sfp.Clave IN ('05','06') THEN cpt.CuentaBancariaCte
					  WHEN sfp.Clave IN ('04','28','29') THEN cpt.TarjetaCte 
					  ELSE cpt.CuentaBancariaCte END)
					  ELSE NULL END													AS CuentaOrdenante,
			CASE WHEN SFP.Bancarizado = 1 THEN bo.RFC ELSE NULL END					AS RFCBancoBeneficiario,
			CASE WHEN SFP.Bancarizado = 1 THEN bo.Nombre ELSE NULL END				AS BancoBeneficiario,
			CASE WHEN SFP.Bancarizado = 1 THEN cpt.CtaBeneficiaria ELSE NULL END	AS CuentaBeneficiaria,
			--CASE WHEN drt.Moneda='MXN' AND cp.ClaveMoneda='MXN' THEN ROUND(cp.Monto,2)
			--ELSE  isnull(ROUND(cpt.MontoTP,2),ROUND(cp.Monto,2)) END				AS MontoPago,
			--ROUND (cpt.Importe*cpt.TipoCambio, 2, 1)								AS MontoPago,
      CONVERT(float, ROUND(cpt.Importe*cpt.TipoCambio, 2))								AS MontoPago,
			cp.ClaveMoneda															AS MonedaPago,
			cp.TipoCambio															AS TipoCambioPago,
      cp.AgenteACuentaTerceros                  AS ACuentaTerceros,
      a.Nombre                                  AS ACuentaTercerosNombre,
      a.RFC                                     AS ACuentaTercerosRFC,
      a.FiscalRegimen                           AS ACuentaTercerosRegimenFiscal,
      a.CodigoPostal                            AS ACuentaTercerosCodigoPostal,
			cpt.TFDCadenaOriginal													AS Cadenaoriginal,
			cpt.Sello																AS SelloEmisor,
			cpt.SelloSAT															AS SelloSAT,
      cpt.Folio,
			drt.UUID																AS IDDR,
			drt.Serie																AS SerieDR,
			drt.Folio																AS FolioDR,
			drt.Moneda																AS MonedaDR,
			drt.TipoCambio															AS TipoCambioDR,
      drt.ObjetoImpDR,
      drt.EquivalenciaDR,
			mp.Clave																AS MetodoPagoDR,
			drt.NumParcialidad														AS Parcialidad,
			CONVERT (FLOAT,drt.ImpPagado)											AS ImportePagado,
			CONVERT (FLOAT,drt.ImpSaldoAnt)											AS SaldoAnterior,
			CONVERT (FLOAT,drt.ImpSaldoInsoluto)									AS SaldoInsoluto,
			ISNULL(cpt.FechaEmisionCFDI,
			SUBSTRING( Documento, CHARINDEX ('Fecha=',Documento)+7, 19))			AS FechaEmisionCFDIm,
      drt.IDCobro AS IDcobro,
      drt.Consecutivo,
      ri.Tipo,
      ri.TipoFactor,
      ri.TasaOCuota,
      ri.Impuesto,
      ri.Importe,
      ri.Base,
      CASE ri.Impuesto WHEN '001' THEN 'ISR' WHEN '002' THEN 'IVA' WHEN '003' THEN 'IEPS' END AS ImpuestoDescripcion
	FROM CFDICobroParcialPDF AS pdf
		INNER JOIN CFDICobroParcialTimbrado AS cpt ON cpt.Modulo = pdf.Modulo AND cpt.IDModulo = pdf.IDModulo
		INNER JOIN CFDIDocRelacionadoTimbrado AS drt ON drt.Modulo = cpt.Modulo AND drt.IDModulo = cpt.IDModulo
    INNER JOIN CFDIDocRelacionadoImpuestos AS ri ON ri.Modulo = pdf.Modulo AND ri.IDModulo = pdf.IDModulo AND drt.UUID = ri.UUID AND drt.NumParcialidad = ri.NumParcialidad AND drt.IDD = ri.IDCobro--AND drt.Consecutivo = ISNULL(ri.Consecutivo, drt.Consecutivo)
		INNER JOIN CFDICobroParcial AS cp ON cp.ID = pdf.IDModulo AND cp.Estacion = pdf.Estacion
		INNER JOIN Empresa AS e ON e.Empresa = cpt.Empresa
		INNER JOIN Cte AS c ON cp.Cliente = c.Cliente
    LEFT OUTER JOIN FiscalRegimen fr ON c.FiscalRegimen = fr.FiscalRegimen
		LEFT JOIN CteCFD AS cc ON cc.Cliente=c.Cliente
		LEFT JOIN CFDINominaSATInstitucionFin AS be ON be.Clave = cpt.ClaveBancoCte
		LEFT JOIN CFDINominaSATInstitucionFin AS bo ON bo.Clave = cp.ClaveBanco
		INNER JOIN SATMetodoPago AS mp ON mp.IDClave = drt.MetodoPago
		INNER JOIN FormaPago AS fp ON fp.FormaPago = cp.FormaPago	
		INNER JOIN SATFormaPago AS sfp ON sfp.Clave = FP.ClaveSAT
    LEFT OUTER JOIN Agente a ON cp.AgenteACuentaTerceros = a.Agente
	 WHERE drt.Cancelado = 0 AND cpt.Cancelado = 0
GO
