
if not exists (select * from sysobjects where id = object_id('dbo.CFDIDocRelacionadoImpuestos') and type = 'U') 
CREATE TABLE dbo.CFDIDocRelacionadoImpuestos(
	Modulo          varchar(5),
  IDModulo        int,
  UUID            varchar(36),
  ID              int     IDENTITY,
  Tipo            varchar(15), -- RetencionDR, TrasladoDR, RetencionP, TrasladoP
  TipoFactor      varchar(6)  NULL,
  TasaOCuota      float       NULL,
  Impuesto        varchar(3)  NULL,
  Importe         float       NULL,
  Base            float       NULL,
  NumParcialidad  int         NULL,
	CONSTRAINT priCFDIDocRelacionadoImpuestos PRIMARY KEY  CLUSTERED (IDModulo, Modulo, UUID, ID, Tipo)
)
GO

EXEC spALTER_TABLE 'Agente', 'FiscalRegimen', 'varchar(30) NULL'
EXEC spALTER_TABLE 'CFDICobroParcial', 'AgenteACuentaTerceros', 'varchar(10) NULL'
EXEC spALTER_TABLE 'CFDIDocRelacionadoTimbrado', 'ObjetoImpDR', 'varchar(3) NULL'
EXEC spALTER_TABLE 'CFDIDocRelacionadoTimbrado', 'EquivalenciaDR', 'float NULL'
EXEC spALTER_TABLE 'CFDIDocRelacionadoTimbrado', 'IDD', 'int NULL'
EXEC spALTER_TABLE 'CFDIDocRelacionadoImpuestos', 'IDCobro', 'int NULL'
EXEC spALTER_TABLE 'EmpresaCFD', 'MontoMovREP', 'BIT DEFAULT 0'
EXEC spALTER_TABLE 'AnexoMov', 'FS', 'UNIQUEIDENTIFIER NULL'
GO


/** MovObjetoImpuesto **/
IF NOT EXISTS(SELECT * FROM SysTabla where SysTabla = 'MovObjetoImpuesto')
  INSERT INTO SysTabla (SysTabla,Tipo) VALUES ('MovObjetoImpuesto','Maestro')
IF NOT EXISTS (SELECT * FROM sysobjects where id = object_id('dbo.MovObjetoImpuesto') and type = 'U') 
CREATE TABLE dbo.MovObjetoImpuesto (
    ID              int IDENTITY(1,1),
    Empresa         varchar(10)  NULL,
    Modulo          varchar(20)  NULL,
    ModuloID        int          NULL,
	  Renglon         float        NULL,
    RenglonSub      int          NULL,
    RenglonID       int          NULL,
	  Articulo        varchar(20)  NULL,
    ObjetoImpuesto  varchar(10)  NULL,
    		
CONSTRAINT priMovObjetoImpuesto PRIMARY KEY CLUSTERED ( ID )
)
GO 

/*** MovObjetoImpuestoFiltro ***/
IF NOT EXISTS(SELECT * FROM SysTabla where SysTabla = 'MovObjetoImpuestoFiltro')
  INSERT INTO SysTabla (SysTabla,Tipo) VALUES ('MovObjetoImpuestoFiltro','Maestro')
IF NOT EXISTS (SELECT * FROM sysobjects where id = object_id('dbo.MovObjetoImpuestoFiltro') and type = 'U') 
CREATE TABLE dbo.MovObjetoImpuestoFiltro (
    IDMov           int,
    Modulo          varchar(20),
    ObjetoImpuesto  varchar(10) NULL,
    Articulo        varchar(20) NULL
CONSTRAINT priMovObjetoImpuestoFiltro PRIMARY KEY CLUSTERED (IDMov, Modulo )
)
GO

EXEC spALTER_TABLE 'MovObjetoImpuestoFiltro', 'Articulo', 'varchar(20) NULL'
GO


EXEC spALTER_TABLE 'EmpresaCFD', 'AjustarNegativosREP', 'BIT DEFAULT 0 NULL'
EXEC spALTER_TABLE 'EmpresaCFD', 'AjustarNegativosTolerancia', 'FLOAT NULL'
EXEC spALTER_TABLE 'EmpresaCFD', 'AjustarMontoTotalPagos', 'BIT DEFAULT 0 NULL'
GO

EXEC spALTER_TABLE 'CFDICobroParcial', 'AjustarMontoTotalPagos', 'FLOAT NULL'
EXEC spALTER_TABLE 'CFDICobroParcial', 'AjustarTotalTrasladosImpuestoIVA16', 'FLOAT NULL'
EXEC spALTER_TABLE 'CFDICobroParcial', 'AjustarNegativosTolerancia', 'FLOAT NULL'
EXEC spALTER_TABLE 'CFDICobroParcial', 'AjustarTotalTrasladosBaseIVA16', 'FLOAT NULL'
GO


EXEC spALTER_TABLE 'MontosXMLFactura', 'TieneAjusteNegativo', 'Bit Default 0'
GO

EXEC spALTER_TABLE  'CFDICobroParcialTimbrado', 'AjusteMontoTotal', 'FLOAT NULL'
GO


EXEC spALTER_TABLE 'CFDIDocRelacionadoTimbrado', 'TieneAjusteNegativo', 'Bit Default 0'
GO