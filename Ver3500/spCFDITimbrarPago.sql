CREATE PROC spCFDITimbrarPago
			@Modulo				VARCHAR(10),
			@ID					INT,
			@Empresa			VARCHAR(10),
			@AlmacenarRuta		VARCHAR(200),
			@CFDI				VARCHAR(MAX),
			@CFDITimbrado		VARCHAR(MAX) OUTPUT,
		    @CadenaOriginal		VARCHAR(MAX) OUTPUT,
			@Ok					INT			 OUTPUT,
			@OkRef				VARCHAR(MAX) OUTPUT,
			@TipoCFD			VARCHAR(10)
AS 
BEGIN
  DECLARE @ServidorPAC			VARCHAR(100),
  		@UsuarioPAC			VARCHAR(100),
		  @PaswordPAC			VARCHAR(100),
		  @AccionCFDI			VARCHAR(50),
		  @RutaCer				VARCHAR(200),
		  @RutaKey				VARCHAR(200),
		  @passKey				VARCHAR(100),
		  @RFC					VARCHAR(20),
		  @FechaTimbrado		VARCHAR(MAX),
		  @UUID					VARCHAR(50),
		  
		  @Documento			VARCHAR(MAX),
		  @RutaIntelisisCFDI	VARCHAR(255),
		  @CadenaConexion		VARCHAR(MAX),
		  @PswPFX				VARCHAR(30),
		  @DatosXMl				VARCHAR(MAX),
		  @RenglonDatos			VARCHAR(255),
		  @Error				BIT,
		  @RID					INT,
		  @Shell				VARCHAR(8000),
		  @r					VARCHAR(MAX),
		  @TimeOutTimbrado		INT,

		  @Timbrar				BIT,
		  @EsCadenaOriginal		BIT,
		  @ModoPruebas			BIT,
		  @Existe				INT,		  

		  @TokenCanPAC			VARCHAR(MAX),
		  @CuentaCanPAC			VARCHAR(MAX),
		  @UsuarioCanPAC		VARCHAR(50),
		  @PaswordCanPAC		VARCHAR(50),
		  @UsarFirmaSAT			BIT,
		  @RegistrarLog			BIT,
		  @Sucursal	        INT,
			@PassSello	      VARCHAR(200),
			@RutaLlave	      VARCHAR(100),
			@RutaCert	        VARCHAR(200),
			@SucursalCFDFlex  bit,
		  @ClienteCFDFlex   bit,
			@Cliente          varchar(20),
      @Lic                varchar(max)

  SELECT @Lic = LicenciaXML FROM Master.dbo.IntelisisMK 
  SELECT @Lic  = REPLACE(@Lic, CHAR(10), '')
  SELECT @Lic  = REPLACE(@Lic, CHAR(13), '')
  SELECT @Lic  = REPLACE(@Lic, CHAR(34), '&quot;') 
     
	DECLARE @Datos TABLE (ID int IDENTITY(1,1), Datos varchar(255))

	SELECT @RegistrarLog = 0

	--Se seleccionan todos los parametros correspondientes para generar la cadena de conexión
	SELECT @UUID = UUID, @Documento = Documento FROM CFDICobroParcialTimbrado 
		WHERE Modulo = @Modulo AND IDModulo = @ID AND Cancelado = 0
	
	SELECT @RFC = RFC FROM Empresa WHERE Empresa = @Empresa
	SELECT @RutaIntelisisCFDI	= RutaIntelisisCFDI,        
		   @TimeOutTimbrado		= CONVERT(VARCHAR(30), ISNULL(TimeOutTimbrado, 15000)),
		   @UsarFirmaSAT		= ISNULL(UsarFirmaSAT,0),
		   @RegistrarLog		= ISNULL(RegistrarLog, 0),
		   @ServidorPAC			= TimbrarCFDIServidor, 
		   @UsuarioPAC			= TimbrarCFDIUsuario, 
		   @PaswordPAC			= TimbrarCFDIPassword, 
		   @RutaCer				= CASE WHEN @TipoCFD = 'Flex' THEN RutaCertificado ELSE Certificado END,
		   @RutaKey				= Llave, 
		   @passKey				= CASE WHEN @TipoCFD = 'Flex' THEN ContrasenaSello ELSE ContrasenakeyCSD END,         
		   @ModoPruebas			= ModoPruebas,         
		   @TokenCanPAC			= ISNULL(CancelarCFDIToken,''),
		   @CuentaCanPAC		= ISNULL(CancelarCFDICuenta,''),
		   @UsuarioCanPAC		= ISNULL(CancelarCFDIUsuario ,''),
		   @PaswordCanPAC		= ISNULL(CancelarCFDIPassword  ,'')
	FROM EmpresaCFD 
	WHERE Empresa = @Empresa

	IF @UUID IS NOT NULL
		SELECT @Ok = 71680, @OkRef = 'El movimiento ya fue timbrado'

	SELECT @AccionCFDI = 'TIMBRAR', @PswPFX = 'Intelisis1234567', @Timbrar = 1


  SELECT @FechaTimbrado = CONVERT(VARCHAR(20), GETDATE(),127), @UUID = '0'
  
  --Se verifica que se cuenten con todas las variables requeridas para generar la cadena.
  IF @RutaIntelisisCFDI IS NULL SELECT @Ok = 10060, @OkRef = 'Dato Ruta Intelisis CFDI no puede estar vacío' ELSE
  IF @FechaTimbrado IS NULL SELECT @Ok = 10060, @OkRef = 'Dato Fecha de Timbrado no puede estar vacío' ELSE
  IF @ServidorPAC IS NULL SELECT @Ok = 10060, @OkRef = 'Dato Servidor PAC no puede estar vacío' ELSE    
  IF @RutaCer IS NULL SELECT @Ok = 10060, @OkRef = 'Dato Ruta Certificado CSD no puede estar vacío' ELSE 
  IF @RutaKey IS NULL SELECT @Ok = 10060, @OkRef = 'Dato Ruta Archivo Key no puede estar vacío' ELSE 
  IF @passKey IS NULL SELECT @Ok = 10060, @OkRef = 'Dato Password Key no puede estar vacío' ELSE 
  IF @UUID IS NULL SELECT @Ok = 10060, @OkRef = 'Dato Folio Fiscal UUID no puede estar vacío' ELSE 
  IF @RFC IS NULL SELECT @Ok = 10060, @OkRef = 'Dato RFC Empresa no puede estar vacío' ELSE 
  IF @AlmacenarRuta IS NULL SELECT @Ok = 10060, @OkRef = 'Dato Almacenar Ruta no puede estar vacío'


  ELSE IF @ServidorPAC='KONESH'
  BEGIN
	SET @UsuarioPAC=@UsuarioCanPAC 
	SET @PaswordPAC=@PaswordCanPAC
	IF @CuentaCanPAC IS NULL SELECT @Ok = 10060, @OkRef = 'Dato Cuenta PAC no puede estar vacío' ELSE 
    IF @TokencanPAC IS NULL SELECT @Ok = 10060, @OkRef = 'Dato Token PAC no puede estar vacío' 
  END
  
  IF @UsuarioPAC IS NULL SELECT @Ok = 10060, @OkRef = 'Dato Usuario PAC no puede estar vacío' ELSE 
  IF @PaswordPAC IS NULL SELECT @Ok = 10060, @OkRef = 'Dato Pasword PAC no puede estar Vacío' 
  
  IF @Ok IS NULL
  BEGIN

	  IF @Modulo='CXC'				
		  SELECT @Sucursal = Sucursal,
		         @Cliente = Cliente
			  FROM Cxc
			 WHERE ID = @ID
	
    ELSE IF @Modulo='DIN'
      SELECT @Sucursal = Sucursal,
		         @Cliente = Cliente
			  FROM Dinero
			 WHERE ID = @ID

	--	SELECT @SucursalCFDFlex = ISNULL(CFDFlex, 0) FROM Sucursal WHERE Sucursal = @Sucursal ---LOSD ERROR EN MOVTIPO POR CAMPO CFDFLEX

		-- Si el cliente tiene prendido el check de CFD Flex se usara el PAC que tiene configurado
		SELECT @ClienteCFDFlex = ISNULL(CFDFlex, 0) FROM CteCFD WHERE Cliente = @Cliente

		IF ISNULL(@ClienteCFDFlex, 0) = 1
		BEGIN
		  SELECT @ServidorPAC	= ISNULL(TimbrarCFDIServidor,''),
			     @UsuarioPAC	= ISNULL(TimbrarCFDIUsuario,''),
				 @PaswordPAC	= ISNULL(TimbrarCFDIPassword,''),
				 @CuentaCanPAC	= CancelarCFDICuenta,
				 @TokenCanPAC	= CancelarCFDIToken,
				 @ModoPruebas	= ISNULL(ModoPruebas,'')
			FROM CteCFD
		   WHERE Cliente = @Cliente
          
		  -- Verificar si los datos del Servidor, Usuario y Password del PAC del cliente tienen datos
		  IF @ServidorPAC IS NULL 
			SELECT @Ok = 10060, @OkRef = 'Dato Servidor PAC Del Cliente No puede Estar Vacio'
			 
		  ELSE IF @UsuarioPAC IS NULL 
			SELECT @Ok = 10060, @OkRef = 'Dato Usuario PAC Del Cliente No puede Estar Vacio' 
			 
		  ELSE IF @PaswordPAC IS NULL 
			SELECT @Ok = 10060, @OkRef = 'Dato Pasword PAC Del Cliente No puede Estar Vacio'  
			   
		  -- Verificar si los datos de Cuenta y Token tienen datos cuando el PAC del cliente es KONESH	
		  IF @ServidorPAC = 'KONESH' AND @CuentaCanPAC IS NULL 
			SELECT @Ok = 10060, @OkRef = 'Dato Cuenta PAC Del Cliente No puede Estar Vacio'
	  
		  ELSE IF @ServidorPAC = 'KONESH' AND @TokencanPAC IS NULL 
			SELECT @Ok = 10060, @OkRef = 'Dato Token PAC Del Cliente No puede Estar Vacio'    
		END

---LOSD ERROR EN MOVTIPO POR CAMPO CFDFLEX
			--valida si la sucursal tiene certificado para timbrar, si el check es =1 toma los datos para la cadena de conexion desde la sucursal
		--IF @SucursalCFDFlex = 1
		--	BEGIN
		--		SELECT @PassSello=ISNULL(ContrasenaSello,''),@RutaLlave=ISNULL(Llave,''),@RutaCert=ISNULL(RutaCertificado,'') FROM Sucursal AS s
		--		WHERE s.Sucursal=@Sucursal

		--		SELECT @CadenaConexion = '<IntelisisCFDI>'+
		--				'<IDSESION>'+CONVERT(varchar,@@SPID)+'</IDSESION>'+
		--				'<FECHA>'+@FechaTimbrado+'</FECHA>'+
		--				'<SERVIDOR>'+@ServidorPAC+'</SERVIDOR>'+
		--				'<USUARIO>'+@UsuarioPAC+'</USUARIO>'+
		--				'<PASSWORD>'+@PaswordPAC+'</PASSWORD>'+
		--				'<CUENTA>'+ISNULL(@CuentaCanPAC,'')+'</CUENTA>'+
		--				'<TOKEN>'+ISNULL(@TokenCanPAC,'')+'</TOKEN>'+
		--				'<ACCION>'+@AccionCFDI+'</ACCION>'+
		--				'<RUTACER>'+@RutaCert+'</RUTACER>'+--------
		--				'<RUTAKEY>'+@RutaLlave+'</RUTAKEY>'+-------
		--				'<PWDKEY>'+@PassSello+'</PWDKEY>'+---------
		--				'<PWDPFX>'+@PswPFX+'</PWDPFX>'+
		--				'<UUID>'+@UUID+'</UUID>'+
		--				'<RFC>'+@RFC+'</RFC>'+							 
		--				'<USARFIRMASAT>'+CONVERT(varchar(1),@UsarFirmaSAT)+'</USARFIRMASAT>'+
		--				'<TIMEOUT>'+CONVERT(varchar(30),@TimeOutTimbrado)+'</TIMEOUT>'+
		--				'<GUARDARLOG>'+CONVERT(varchar(1),@RegistrarLog)+'</GUARDARLOG>'+
		--				'<RUTAARCHIVO>'+@AlmacenarRuta+'</RUTAARCHIVO>'+
		--				'<MODOPRUEBAS>'+CONVERT(varchar(1),@ModoPruebas)+'</MODOPRUEBAS>'+
		--				'</IntelisisCFDI>'					
		--	END				
		--	ELSE
---LOSD ERROR EN MOVTIPO POR CAMPO CFDFLEX
      BEGIN
			  --si el check es =0 Se crea la cadena de conexión
	      --Se crea la cadena de conexión
	      SELECT @CadenaConexion = '<IntelisisCFDI>'+
							      '<IDSESION>'+CONVERT(varchar,@@SPID)+'</IDSESION>'+
							      '<FECHA>'+@FechaTimbrado+'</FECHA>'+
							      '<SERVIDOR>'+@ServidorPAC+'</SERVIDOR>'+
							      '<USUARIO>'+@UsuarioPAC+'</USUARIO>'+
							      '<PASSWORD>'+@PaswordPAC+'</PASSWORD>'+
							      '<CUENTA>'+ISNULL(@CuentaCanPAC,'')+'</CUENTA>'+
							      '<TOKEN>'+ISNULL(@TokenCanPAC,'')+'</TOKEN>'+
							      '<ACCION>'+@AccionCFDI+'</ACCION>'+
							      '<RUTACER>'+@RutaCer+'</RUTACER>'+
							      '<RUTAKEY>'+@RutaKey+'</RUTAKEY>'+
							      '<PWDKEY>'+@passKey+'</PWDKEY>'+
							      '<PWDPFX>'+@PswPFX+'</PWDPFX>'+
							      '<UUID>'+@UUID+'</UUID>'+
							      '<RFC>'+@RFC+'</RFC>'+							 
							      '<USARFIRMASAT>'+CONVERT(varchar(1),@UsarFirmaSAT)+'</USARFIRMASAT>'+
							      '<TIMEOUT>'+CONVERT(varchar(30),@TimeOutTimbrado)+'</TIMEOUT>'+
							      '<GUARDARLOG>'+CONVERT(varchar(1),@RegistrarLog)+'</GUARDARLOG>'+
							      '<RUTAARCHIVO>'+@AlmacenarRuta+'</RUTAARCHIVO>'+
							      '<MODOPRUEBAS>'+CONVERT(varchar(1),@ModoPruebas)+'</MODOPRUEBAS>'+
							      '</IntelisisCFDI>'
	    END

    SELECT @CadenaConexion = @CadenaConexion + @Lic
	--Se crea el comando para ejecutar en el CMD y se ejecuta
    SELECT @Shell = CHAR(34)+CHAR(34)+@RutaIntelisisCFDI+CHAR(34)+' '+CHAR(34)+@CadenaConexion+CHAR(34)+CHAR(34)
	
    INSERT @Datos
      EXEC @r =  xp_cmdshell @Shell--, no_output   
   
	--Se verifica el archivo generado    
    EXEC spVerificarArchivo @AlmacenarRuta, @Existe OUTPUT, @Ok OUTPUT, @OkRef OUTPUT  
	
	--Se borra el archivo .tmp generado en caso de no ser una ejecución de prueba
	--IF @RegistrarLog = 0
		IF @Existe = 1
			EXEC spEliminarArchivo @AlmacenarRuta, @Ok OUTPUT, @OkRef OUTPUT
  END

  --Se verifica si el pack o el componente regresaron algun tipo de error
  IF @Ok IS NULL
  BEGIN
    SELECT @DatosXMl = '', @CadenaOriginal = '', @EsCadenaOriginal = 0
    DECLARE crResultadoXMl CURSOR FOR
      SELECT Id, Datos FROM @Datos WHERE Datos IS NOT NULL ORDER BY ID Asc
    OPEN crResultadoXMl
    FETCH NEXT FROM crResultadoXMl INTO @RID, @RenglonDatos
      WHILE @@FETCH_STATUS <> -1
      BEGIN
        IF @@FETCH_STATUS <> -2 
        BEGIN  
            IF @RID = 1 AND CHARINDEX('<IntelisisCFDI><Error>',@RenglonDatos) >= 1
            SELECT @Error = 1

            IF @RID = 1 AND CHARINDEX('<',@RenglonDatos) = 0
              SELECT @Error = 1

            SELECT @DatosXMl = @DatosXML + @RenglonDatos
            
      END
    FETCH NEXT FROM crResultadoXMl INTO @RID, @RenglonDatos
      END
    CLOSE crResultadoXMl
    DEALLOCATE crResultadoXMl

	--Si regresó algún error, se presenta en pantalla con el mensaje correspondiente.
    IF @Error = 1
	BEGIN
	  SELECT @Ok = 71650,  @OkRef = @DatosXml
	END
    IF @r <> 0
      SELECT @OK = 71650, @OkREf = 'Error al Ejecutar IntelisisCFDI.exe '+ISNULL(@DatosXml,'')
    IF NULLIF(@DatosXMl,'') IS NULL SELECT @Ok = 71650, @OkRef = 'Se esperaba respuesta de IntelisisCFDI.exe' 

	--Se extrae la cadena original del timbre
    IF @Ok is NULL
    BEGIN
      IF CHARINDEX('<CADENAORIGINAL>', @DatosXML, 0) <> 0
      BEGIN
        SELECT @CadenaOriginal = SUBSTRING(@DatosXML, CHARINDEX('<CADENAORIGINAL>', @DatosXML, 0), LEN(@DatosXML) - CHARINDEX('<CADENAORIGINAL>', @DatosXML, 0) + 1)
        SELECT @DatosXML = SUBSTRING(@DatosXML, 1, CHARINDEX('<CADENAORIGINAL>', @DatosXML, 0) - 1)
      END
      ELSE
        SELECT @CadenaOriginal = ''

	  SELECT @CadenaOriginal = REPLACE(REPLACE(@CadenaOriginal,'<CADENAORIGINAL>',''),'</CADENAORIGINAL>','')


      IF @OK IS NULL 
      BEGIN

		--Se regresa el XML timbrado
		SELECT @CFDITimbrado = @DatosXML
      END
    END
  END
END
GO