SET DATEFIRST 7
SET ANSI_NULLS OFF
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET LOCK_TIMEOUT -1
SET QUOTED_IDENTIFIER OFF
SET ARITHABORT OFF
SET ANSI_WARNINGS OFF
GO


/**************** fnXMLEquivalenciaDecimal ****************/
IF EXISTS (SELECT name FROM sysobjects WHERE name = 'fnXMLEquivalenciaDecimal') DROP FUNCTION fnXMLEquivalenciaDecimal
GO
CREATE FUNCTION fnXMLEquivalenciaDecimal (@Parametro varchar(255), @Valor float, @Decimales int)
RETURNS varchar(255)
--//WITH ENCRYPTION
AS BEGIN
  DECLARE
    @Resultado	varchar(255),
    @Valor2 varchar(100)
    
  IF @Valor IS NULL
    SELECT @Resultado = ''
  ELSE
  BEGIN
    IF @Decimales = 1 SELECT @Valor2 = CONVERT(Decimal(38,1),@Valor)
    IF @Decimales = 2 SELECT @Valor2 = CONVERT(Decimal(38,2),@Valor)
    IF @Decimales = 3 SELECT @Valor2 = CONVERT(Decimal(38,3),@Valor)
    IF @Decimales = 4 SELECT @Valor2 = CONVERT(Decimal(38,4),@Valor)
    IF @Decimales = 5 SELECT @Valor2 = CONVERT(Decimal(38,5),@Valor)
    IF @Decimales = 6 SELECT @Valor2 = CONVERT(Decimal(38,6),@Valor)
	IF @Decimales >= 7 SELECT @Valor2 = CONVERT(Decimal(38,10),@Valor)
    SELECT @Resultado = ' '+dbo.fnXMLParametro(@Parametro)+'="'+CONVERT(varchar,@Valor2)+'"'
  END

  RETURN(@Resultado)
END
GO



/**************** fnCobroParcialObjetoImp ****************/
IF EXISTS (SELECT name FROM sysobjects WHERE name = 'fnCobroParcialObjetoImp') DROP FUNCTION fnCobroParcialObjetoImp
GO
CREATE FUNCTION fnCobroParcialObjetoImp (@IDVenta	INT, @SaldoInicial BIT = 0)
RETURNS varchar(5)
--//WITH ENCRYPTION
AS BEGIN
	 DECLARE	@ObjetoImpuesto	VARCHAR(5)



	 IF @SaldoInicial = 1
	 BEGIN 
		SELECT @ObjetoImpuesto = co.SATObjetoImp 
		 FROM CXC AS c 
		INNER JOIN Concepto as co ON c.Concepto = co.Concepto AND Modulo = 'CXC'
		WHERE ID = @IDVenta 
	 END
	 ELSE
	 BEGIN
		 IF EXISTS (SELECT 1 FROM MovObjetoImpuesto WHERE Modulo = 'VTAS' AND ModuloID = @IDVenta)
		 BEGIN
		
			IF EXISTS (SELECT * FROM MovObjetoImpuesto WHERE Modulo = 'VTAS' AND ModuloID = @IDVenta AND ObjetoImpuesto = '02')
				SET @ObjetoImpuesto = '02'
			ELSE IF NOT EXISTS (SELECT * FROM MovObjetoImpuesto WHERE Modulo = 'VTAS' AND ModuloID = @IDVenta AND ObjetoImpuesto = '02') 
				SELECT TOP 1 @ObjetoImpuesto = ObjetoImpuesto
					FROM MovObjetoImpuesto 
				WHERE Modulo = 'VTAS' AND ModuloID = @IDVenta
		 END

		 IF NULLIF(@ObjetoImpuesto,'') IS NULL
		 BEGIN
			IF EXISTS (SELECT SATObjetoImp 
							FROM VentaD AS vd 
					   INNER JOIN SATArticuloInfo AS sai ON vd.Articulo = sai.Articulo 
					   WHERE VD.ID = @IDVenta AND SatObjetoImp = '02'
					   )
				SET @ObjetoImpuesto = '02' 

			ELSE IF NOT EXISTS(SELECT SATObjetoImp 
									FROM VentaD AS vd 
							   INNER JOIN SATArticuloInfo AS sai ON vd.Articulo = sai.Articulo 
							   WHERE VD.ID = @IDVenta AND SatObjetoImp = '02'
							   )
					SELECT TOP 1 @ObjetoImpuesto =  SATObjetoImp 
						FROM VentaD AS vd 
					INNER JOIN SATArticuloInfo AS sai ON vd.Articulo = sai.Articulo 
					WHERE VD.ID = @IDVenta

		END
	END

	 RETURN(@ObjetoImpuesto)
END
GO