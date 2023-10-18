SET DATEFIRST 7
SET ANSI_NULLS OFF
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET LOCK_TIMEOUT -1
SET QUOTED_IDENTIFIER OFF
SET ARITHABORT OFF
SET ANSI_WARNINGS OFF
GO

/**************** spMovObjetoImpuesto ****************/
IF EXISTS (SELECT * FROM SYSOBJECTS WHERE id = object_id('dbo.spMovObjetoImpuesto') and type = 'P') 
  DROP PROCEDURE dbo.spMovObjetoImpuesto
GO
CREATE PROCEDURE spMovObjetoImpuesto
  @ID     int,
  @Modulo varchar(5),
  @Tipo   int = 0
AS BEGIN

  IF @Modulo = 'VTAS'
  BEGIN
    IF @Tipo = 0
    BEGIN
      DELETE FROM MovObjetoImpuesto WHERE ModuloID = @ID AND Modulo = @Modulo

      DECLARE @ObjetoImpuesto   VARCHAR(10),
              @Articulo         VARCHAR(20)

      SELECT @ObjetoImpuesto  = ObjetoImpuesto, 
             @Articulo        =  Articulo 
        FROM MovObjetoImpuestoFiltro 
       WHERE IDMov = @ID AND Modulo = @Modulo
      
      IF ISNULL(@Articulo, '') <> ''
        INSERT INTO MovObjetoImpuesto (Empresa, Modulo, ModuloID, Renglon, RenglonSub, RenglonID, Articulo, ObjetoImpuesto)
                                SELECT Empresa, @Modulo, @ID, d.Renglon, d.RenglonSub, d.RenglonID, d.Articulo, CASE WHEN d.Articulo = @Articulo THEN @ObjetoImpuesto ELSE (SELECT i.SatObjetoImp FROM SATArticuloInfo i WHERE i.Articulo = d.Articulo) END
                                  FROM VentaD d JOIN Venta v ON d.ID = v.ID 
                                  WHERE v.ID = @ID AND d.RenglonTipo <> 'C'
      ELSE
         INSERT INTO MovObjetoImpuesto (Empresa, Modulo, ModuloID, Renglon, RenglonSub, RenglonID, Articulo,    ObjetoImpuesto)
                                SELECT Empresa, @Modulo, @ID, d.Renglon, d.RenglonSub, d.RenglonID, d.Articulo, @ObjetoImpuesto
                                  FROM VentaD d JOIN Venta v ON d.ID = v.ID 
                                  WHERE v.ID = @ID AND d.RenglonTipo <> 'C'       
    END
    ELSE
    BEGIN

      IF EXISTS(SELECT 1 FROM VentaD d JOIN Venta v ON d.ID = v.ID WHERE v.ID = @ID AND d.DescuentoLinea = 100 ) AND NOT EXISTS (SELECT 1 FROM MovObjetoImpuesto WHERE ModuloID = @ID AND Modulo = @Modulo)
      BEGIN
        INSERT INTO MovObjetoImpuesto (Empresa, Modulo, ModuloID, Renglon, RenglonSub, RenglonID, Articulo, ObjetoImpuesto)
                                SELECT Empresa, @Modulo, @ID, d.Renglon, d.RenglonSub, d.RenglonID, d.Articulo, CASE WHEN d.DescuentoLinea = 100 THEN '01' ELSE (SELECT i.SatObjetoImp FROM SATArticuloInfo i WHERE i.Articulo = d.Articulo) END
                                  FROM VentaD d JOIN Venta v ON d.ID = v.ID 
                                  WHERE v.ID = @ID AND d.RenglonTipo <> 'C'
      END
    END
  END

END
GO