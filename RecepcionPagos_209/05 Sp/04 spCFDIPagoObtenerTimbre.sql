SET DATEFIRST 7
SET ANSI_NULLS OFF
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET LOCK_TIMEOUT -1
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF
SET ARITHABORT OFF
SET ANSI_WARNINGS OFF
GO

/************** spCFDIPagoObtenerTimbre *************/
if exists (select * from sysobjects where id = object_id('dbo.spCFDIPagoObtenerTimbre') and type = 'P') drop procedure dbo.spCFDIPagoObtenerTimbre
GO
CREATE PROCEDURE spCFDIPagoObtenerTimbre
		   @Documento			varchar(max),		   
		   @SelloSAT			varchar(max)	OUTPUT,
		   @SelloCFD			varchar(max)    OUTPUT,
		   @FechaTimbrado		varchar(max)	OUTPUT,
		   @UUID				varchar(50)		OUTPUT,
		   @TFDVersion			varchar(max)	OUTPUT,
		   @noCertificadoSAT	varchar(max)	OUTPUT,
		   @TFDCadenaOriginal	varchar(max)	OUTPUT,
		   @Ok					int				OUTPUT,
		   @OkRef				varchar(255)	OUTPUT

AS 
BEGIN
  DECLARE 
		  @iDatos				int,
		  @DocumentoXML			xml,
		  @PrefijoCFDI			varchar(255),
		  @RutaCFDI				varchar(255)



	SELECT @OkRef = NULL

	SELECT @Documento = REPLACE(REPLACE(@Documento,'encoding="UTF-8"','encoding="Windows-1252"'),'?<?xml','<?xml')

	IF  CHARINDEX('?XML version=', @Documento) = 0 AND CHARINDEX('encoding=', @Documento) = 0
		SELECT @Documento = '<?xml version="1.0" encoding="windows-1252"?>'+@Documento

	EXEC sp_xml_preparedocument @iDatos OUTPUT, @Documento
	SELECT @OkRef = MENSAJE FROM OPENXML (@iDatos, '/ERROR',2) WITH (MENSAJE  varchar(255))
	
	IF @OkRef IS NOT NULL 
		SELECT @OK = 71650
  
	EXEC sp_xml_removedocument @iDatos  

	--Se extrae la información correspondiente al nodo de timbra para posteriormente guardala en la tabla de timbrado de cobros.
	IF @OK IS NULL
	BEGIN
		SET @DocumentoXML = CONVERT(XML,@Documento)	

		SET @PrefijoCFDI = '<ns xmlns' + CHAR(58) + 'cfdi="http' + CHAR(58) + '//www.sat.gob.mx/cfd/4" xmlns' + CHAR(58) + 'tfd="http' + CHAR(58) + '//www.sat.gob.mx/TimbreFiscalDigital"/>'    
		EXEC sp_xml_preparedocument @iDatos OUTPUT, @DocumentoXML, @PrefijoCFDI
        
		SET @RutaCFDI = '/cfdi' + CHAR(58) + 'Comprobante/cfdi' + CHAR(58) + 'Complemento/tfd' + CHAR(58) + 'TimbreFiscalDigital'
		SELECT  
			@UUID = UUID
			FROM OPENXML (@iDatos, @RutaCFDI, 1) WITH (UUID uniqueidentifier)
     
		SET @RutaCFDI = '/cfdi' + CHAR(58) + 'Comprobante/cfdi' + CHAR(58) + 'Complemento/tfd' + CHAR(58) + 'TimbreFiscalDigital'
		SELECT  
			@SelloSAT = SelloSAT
			FROM OPENXML (@iDatos, @RutaCFDI, 1) WITH (SelloSAT varchar(max))

		SET @RutaCFDI = '/cfdi' + CHAR(58) + 'Comprobante/cfdi' + CHAR(58) + 'Complemento/tfd' + CHAR(58) + 'TimbreFiscalDigital'
		SELECT  
			@SelloCFD = SelloCFD
			FROM OPENXML (@iDatos, @RutaCFDI, 1) WITH (SelloCFD varchar(max))
      
		SET @RutaCFDI = '/cfdi' + CHAR(58) + 'Comprobante/cfdi' + CHAR(58) + 'Complemento/tfd' + CHAR(58) + 'TimbreFiscalDigital'
		SELECT  
			@TFDVersion = Version
			FROM OPENXML (@iDatos, @RutaCFDI, 1) WITH (Version varchar(max))
		SET @RutaCFDI = '/cfdi' + CHAR(58) + 'Comprobante/cfdi' + CHAR(58) + 'Complemento/tfd' + CHAR(58) + 'TimbreFiscalDigital'
		SELECT  
			@FechaTimbrado = FechaTimbrado
			FROM OPENXML (@iDatos, @RutaCFDI, 1) WITH (FechaTimbrado varchar(max))
	  
		SET @RutaCFDI = '/cfdi' + CHAR(58) + 'Comprobante/cfdi' + CHAR(58) + 'Complemento/tfd' + CHAR(58) + 'TimbreFiscalDigital'
		SELECT  
			@noCertificadoSAT = NoCertificadoSAT
			FROM OPENXML (@iDatos, @RutaCFDI, 1) WITH (NoCertificadoSAT varchar(max))

		SELECT @TFDCadenaOriginal = '||'+@TFDVersion+'|'+@UUID+'|'+@FechaTimbrado+'|'+@SelloCFD+'|'+@noCertificadoSAT+'||'
    
		EXEC sp_xml_removedocument @iDatos  
	END

	RETURN
END
GO
