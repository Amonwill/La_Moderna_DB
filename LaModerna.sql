-- ===============================================
-- Creacion Base de Datos y Tablas para La Moderna
-- ===============================================

CREATE DATABASE La_Moderna
ON
(
	NAME = La_Moderna_dat,
	FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA\La_Moderna.mdf',
	SIZE = 100,
	MAXSIZE = 200,
	FILEGROWTH = 10
)
LOG ON
(
	NAME = La_Moderna_log,
	FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA\La_Moderna.ldf',
	SIZE = 50,
	MAXSIZE = 100,
	FILEGROWTH = 5
)
GO

USE La_Moderna
GO

-- =============================================
-- 1. TABLAS DE CATÁLOGO Y CONFIGURACIÓN
-- =============================================

CREATE TABLE Clientes_Cat (
    ID_Cliente          SMALLINT IDENTITY (1,1) PRIMARY KEY,
    Nombre              VARCHAR (30)    NOT NULL,
    Apellido_Paterno    VARCHAR (30)    NOT NULL,
    Apellido_Materno    VARCHAR (30)    NOT NULL,
    Numero_Telefono     VARCHAR (10)    NOT NULL,
    Cliente_Activo      BIT             NOT NULL DEFAULT 1
);

CREATE TABLE Proveedores_Cat (
    ID_Proveedor            SMALLINT IDENTITY (1,1) PRIMARY KEY,
    Nombre_Proveedor        VARCHAR (50)    NOT NULL,
    Descripcion_Proveedor   VARCHAR (100)   NOT NULL, 
    Telefono_Proveedor      VARCHAR (15)    NOT NULL,
    Correo_Proveedor        VARCHAR (50)    NOT NULL,
    Direccion_Completa      VARCHAR (150)   NOT NULL, 
    Ciudad_Estado           VARCHAR (50)    NOT NULL, 
    Proveedor_Activo        BIT             NOT NULL DEFAULT 1
);

CREATE TABLE Lotes_Cat (
    ID_Lote         SMALLINT IDENTITY (1,1) PRIMARY KEY,
    Num_Lote        VARCHAR (20)    NOT NULL,
    Fecha_Caducidad DATE            NOT NULL
);

CREATE TABLE Productos_Cat (
    ID_Producto             SMALLINT IDENTITY (1,1) PRIMARY KEY,
    Nombre_Producto         VARCHAR (50)    NOT NULL,
    Descripcion_Producto    VARCHAR (50)    NOT NULL,
    ID_Prove                SMALLINT        NOT NULL,
    Precio_Compra           DECIMAL (10,2)  NOT NULL, 
    Precio_Venta            DECIMAL (10,2)  NOT NULL,
    Cantidad                SMALLINT        NOT NULL,
    Lote                    SMALLINT        NOT NULL,
    Producto_Activo         BIT             NOT NULL,
    CONSTRAINT FK_Proveedor FOREIGN KEY (ID_Prove) REFERENCES Proveedores_Cat (ID_Proveedor),
    CONSTRAINT FK_Lote      FOREIGN KEY (Lote)     REFERENCES Lotes_Cat (ID_Lote)
);

CREATE TABLE Cajas_Cat (
    ID_Caja_Fisica  SMALLINT IDENTITY(1,1) PRIMARY KEY,
    Nombre_Caja     VARCHAR(20) NOT NULL,
    Ubicacion       VARCHAR(50),
    Activa          BIT DEFAULT 1
);

-- =============================================
-- 2. TABLAS DE OPERACIÓN (CAJA Y VENTAS)
-- =============================================

CREATE TABLE Caja_General (
    ID_Session      INT IDENTITY (1,1) PRIMARY KEY,
    ID_Caja_Fisica  SMALLINT NOT NULL,
    Fecha_Apertura  DATETIME DEFAULT GETDATE(),
    Fecha_Cierre    DATETIME NULL,
    Saldo_Inicial   DECIMAL (10,2) NOT NULL,
    Ingresos_Totales DECIMAL (10,2) DEFAULT 0,
    Egresos_Totales  DECIMAL (10,2) DEFAULT 0,
    Estado_Caja     BIT DEFAULT 1, 
    CONSTRAINT FK_Caja_Catalogo FOREIGN KEY (ID_Caja_Fisica) REFERENCES Cajas_Cat (ID_Caja_Fisica)
);

CREATE TABLE Ventas (
    ID_Venta                INT IDENTITY (1,1) PRIMARY KEY, 
    ID_Cliente              SMALLINT NOT NULL,   
    ID_Caja                 INT NOT NULL, 
    Fecha_y_Hora_Venta      DATETIME NOT NULL DEFAULT GETDATE(),
    Total                   DECIMAL (10,2) NOT NULL,
    Pago_Con                DECIMAL (10,2) NOT NULL,
    Cambio                  DECIMAL (10,2) NOT NULL,
    CONSTRAINT FK_Cliente FOREIGN KEY (ID_Cliente) REFERENCES Clientes_Cat (ID_Cliente),
    CONSTRAINT FK_Session_Venta FOREIGN KEY (ID_Caja) REFERENCES Caja_General (ID_Session)
);

CREATE TABLE Detalle_Venta (
    ID_Detalle_Venta    INT IDENTITY (1,1) PRIMARY KEY,
    ID_Venta            INT NOT NULL, 
    ID_Producto         SMALLINT NOT NULL,
    Cantidad            SMALLINT NOT NULL,
    Precio_Unitario     DECIMAL (10,2) NOT NULL, 
    CONSTRAINT FK_Venta_Relacion FOREIGN KEY (ID_Venta) REFERENCES Ventas (ID_Venta),
    CONSTRAINT FK_Producto_Relacion FOREIGN KEY (ID_Producto) REFERENCES Productos_Cat (ID_Producto)
);

CREATE TABLE Bandeja_Alertas (
    ID_Alerta       INT IDENTITY(1,1) PRIMARY KEY,
    Mensaje         VARCHAR (255),
    Tipo_Alerta     VARCHAR (20), 
    Fecha_Generada  DATETIME DEFAULT GETDATE()
);
GO

-- =============================================
-- 3. ÍNDICES Y TRIGGERS
-- =============================================

CREATE INDEX ix_Productos_Stock ON Productos_Cat(Cantidad);
CREATE INDEX ix_Ventas_Fecha ON Ventas(Fecha_y_Hora_Venta);
GO

CREATE OR ALTER TRIGGER tr_DevolverStockAlEliminarDetalleVenta
ON Detalle_Venta
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE P
    SET 
        P.Cantidad = P.Cantidad + D.Cantidad,
        P.Producto_Activo = CASE WHEN (P.Cantidad + D.Cantidad) > 0 THEN 1 ELSE 0 END
    FROM Productos_Cat AS P
    INNER JOIN deleted AS D ON P.ID_Producto = D.ID_Producto;
END
GO

-- =============================================
-- 4. PROCEDIMIENTOS ALMACENADOS
-- =============================================

-- Gestión de Inventario (Ver, Agregar, Actualizar, Eliminar)
CREATE OR ALTER PROCEDURE sp_gestion_inventario
    @accion           VARCHAR (10),
    @id_prod          SMALLINT        = NULL,
    @nombre           VARCHAR (50)    = NULL,
    @desc             VARCHAR (50)    = NULL,
    @p_compra         DECIMAL (10,2)  = NULL,
    @p_venta          DECIMAL (10,2)  = NULL,
    @cant             SMALLINT        = NULL,
    @num_lote         VARCHAR(20)     = NULL, 
    @caducidad        DATE            = NULL,
    @nombre_proveedor VARCHAR(50)     = NULL  
AS 
BEGIN
    SET NOCOUNT ON;
    DECLARE @id_lote_final AS SMALLINT;
    DECLARE @id_prov_final AS SMALLINT;

    -- Buscar o Crear Proveedor
    IF @nombre_proveedor IS NOT NULL AND @nombre_proveedor <> ''
    BEGIN
        SELECT @id_prov_final = ID_Proveedor FROM Proveedores_Cat WHERE Nombre_Proveedor = @nombre_proveedor;
        
        IF @id_prov_final IS NULL
        BEGIN   
            INSERT INTO Proveedores_Cat (Nombre_Proveedor, Descripcion_Proveedor, Proveedor_Activo) 
            VALUES (@nombre_proveedor, 'Proveedor registrado desde inventario', 1);
            
            SET @id_prov_final = SCOPE_IDENTITY();
        END
    END
    -- Agergar nuevo producto
    IF @accion = 'agregar'
    BEGIN
        -- Buscar o Crear Lote
        IF NOT EXISTS (SELECT 1 FROM Lotes_Cat WHERE Num_Lote = @num_lote)
        BEGIN
            INSERT INTO Lotes_Cat (Num_Lote, Fecha_Caducidad) VALUES (@num_lote, @caducidad);
            SET @id_lote_final = SCOPE_IDENTITY();
        END
        ELSE
            SELECT @id_lote_final = ID_Lote FROM Lotes_Cat WHERE Num_Lote = @num_lote;

        INSERT INTO Productos_Cat (Nombre_Producto, Descripcion_Producto, ID_Prove, Precio_Compra, Precio_Venta, Cantidad, Lote, Producto_Activo)
        VALUES (@nombre, @desc, @id_prov_final, @p_compra, @p_venta, @cant, @id_lote_final, CASE WHEN @cant > 0 THEN 1 ELSE 0 END);
    END


    -- Actualizar producto existente (Solo campos proporcionados)
    IF @accion = 'actualizar'
    BEGIN
        UPDATE Productos_Cat
        SET Nombre_Producto = ISNULL(@nombre, Nombre_Producto),
            Descripcion_Producto = ISNULL(@desc, Descripcion_Producto),
            Precio_Compra = ISNULL(@p_compra, Precio_Compra),
            Precio_Venta = ISNULL(@p_venta, Precio_Venta),
            Cantidad = ISNULL(@cant, Cantidad),
            ID_Prove = ISNULL(@id_prov_final, ID_Prove),
            Producto_Activo = CASE WHEN ISNULL(@cant, Cantidad) > 0 THEN 1 ELSE 0 END
        WHERE ID_Producto = @id_prod;
    END
    -- Eliminar producto 
    IF @accion = 'eliminar'
        UPDATE Productos_Cat SET Producto_Activo = 0, Cantidad = 0 WHERE ID_Producto = @id_prod;
    -- Ver productos (Todos o por ID)
    IF @accion = 'ver'
    BEGIN
        SELECT p.*, pr.Nombre_Proveedor, l.Num_Lote, l.Fecha_Caducidad 
        FROM Productos_Cat AS p
        LEFT JOIN Proveedores_Cat AS pr ON p.ID_Prove = pr.ID_Proveedor
        LEFT JOIN Lotes_Cat AS l ON p.Lote = l.ID_Lote
        WHERE (p.ID_Producto = @id_prod OR @id_prod IS NULL) AND p.Producto_Activo = 1;
    END
END
GO

-- Registrar Venta (Con validación de Caja y actualización de Ingresos)
CREATE OR ALTER PROCEDURE sp_registrar_venta
    @id_cliente     SMALLINT,
    @pago           DECIMAL (10,2),
    @id_producto    SMALLINT,
    @cantidad       SMALLINT,
    @id_session     INT 
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;
            DECLARE @precio DECIMAL(10,2), @stock SMALLINT, @total DECIMAL(10,2), @cambio DECIMAL(10,2), @idventa INT;

            IF NOT EXISTS (SELECT 1 FROM Caja_General WHERE ID_Session = @id_session AND Estado_Caja = 1)
                THROW 50003, 'Sesion de caja cerrada.', 1;

            SELECT @precio = Precio_Venta, @stock = Cantidad FROM Productos_Cat WHERE ID_Producto = @id_producto;

            IF @stock < @cantidad THROW 50001, 'Inventario insuficiente', 1;
            SET @total = @precio * @cantidad;
            IF @pago < @total THROW 50002, 'Pago insuficiente', 1;
            SET @cambio = @pago - @total;

            INSERT INTO Ventas (ID_Cliente, ID_Caja, Total, Pago_Con, Cambio)
            VALUES (@id_cliente, @id_session, @total, @pago, @cambio);
            
            SET @idventa = SCOPE_IDENTITY();
            INSERT INTO Detalle_Venta (ID_Venta, ID_Producto, Cantidad, Precio_Unitario)
            VALUES (@idventa, @id_producto, @cantidad, @precio);

            UPDATE Productos_Cat SET Cantidad = Cantidad - @cantidad WHERE ID_Producto = @id_producto;
            UPDATE Caja_General SET Ingresos_Totales = Ingresos_Totales + @total WHERE ID_Session = @id_session;

        COMMIT;
        SELECT @total AS total, @cambio AS cambio;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO


-- Corte por Caja (Individual o Global del día)
CREATE OR ALTER PROCEDURE sp_corte_por_caja
    @id_session INT = NULL 
AS
BEGIN
    SELECT 
        cc.Nombre_Caja, cg.ID_Session, cg.Fecha_Apertura, cg.Saldo_Inicial,
        cg.Ingresos_Totales, cg.Egresos_Totales,
        (cg.Saldo_Inicial + cg.Ingresos_Totales - cg.Egresos_Totales) AS Saldo_Actual,
        CASE WHEN cg.Estado_Caja = 1 THEN 'Abierta' ELSE 'Cerrada' END AS Estatus
    FROM Caja_General AS cg
    INNER JOIN Cajas_Cat AS cc ON cg.ID_Caja_Fisica = cc.ID_Caja_Fisica
    WHERE (@id_session IS NULL AND CAST(cg.Fecha_Apertura AS DATE) = CAST(GETDATE() AS DATE))
       OR (cg.ID_Session = @id_session);
END
GO


-- Generación de Alertas
CREATE OR ALTER PROCEDURE sp_generar_alertas
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM Bandeja_Alertas WHERE Fecha_Generada < DATEADD(DAY, -1, GETDATE());
    -- 1. Alerta de Stock Bajo (Menos de 5 unidades)
    INSERT INTO Bandeja_Alertas (Mensaje, Tipo_Alerta)
    SELECT '¡Stock crítico! ' + Nombre_Producto + ' solo tiene ' + CAST(Cantidad AS VARCHAR) + ' pzas.', 'Inventario'
    FROM Productos_Cat 
    WHERE Cantidad <= 5 AND Producto_Activo = 1
    AND NOT EXISTS (SELECT 1 FROM Bandeja_Alertas WHERE Mensaje LIKE '%' + Nombre_Producto + '%' AND Tipo_Alerta = 'Inventario');
    -- 2. Alerta de Caducidad (Próximos 7 días)
    INSERT INTO Bandeja_Alertas (Mensaje, Tipo_Alerta)
    SELECT 'Producto por caducar: ' + p.Nombre_Producto + ' (Lote: ' + l.Num_Lote + ')', 'Caducidad'
    FROM Productos_Cat AS p 
    INNER JOIN Lotes_Cat AS l ON p.Lote = l.ID_Lote
    WHERE l.Fecha_Caducidad <= DATEADD(DAY, 7, GETDATE())
    AND NOT EXISTS (SELECT 1 FROM Bandeja_Alertas WHERE Mensaje LIKE '%' + p.Nombre_Producto + '%' AND Tipo_Alerta = 'Caducidad');
END
GO


--  Metricas de Ventas 
CREATE OR ALTER PROCEDURE sp_metricas_ventas
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Hoy DATE = CAST(GETDATE() AS DATE);
    SELECT 
        ISNULL(SUM(Total), 0) AS TotalDinero,
        COUNT(ID_Venta) AS TotalVentas,
        CASE WHEN COUNT(ID_Venta) > 0 THEN SUM(Total) / COUNT(ID_Venta) ELSE 0 END AS TicketPromedio
    FROM Ventas
    WHERE CAST(Fecha_y_Hora_Venta AS DATE) = @Hoy;
    SELECT TOP 3 
        p.Nombre_Producto,
        SUM(dv.Cantidad) AS CantidadVendida
    FROM Detalle_Venta AS dv 
    INNER JOIN Productos_Cat AS p ON dv.ID_Producto = p.ID_Producto
    INNER JOIN Ventas AS v ON dv.ID_Venta = v.ID_Venta
    WHERE CAST(v.Fecha_y_Hora_Venta AS DATE) = @Hoy 
    GROUP BY p.Nombre_Producto
    ORDER BY CantidadVendida DESC;
END
GO


--Cortes de caja en pdf (Datos para reporte diario)
CREATE OR ALTER PROCEDURE sp_obtener_datos_corte_diario
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Hoy DATE = CAST(GETDATE() AS DATE);
    SELECT 
        cg.ID_Session,
        cc.Nombre_Caja,
        cg.Fecha_Apertura,
        cg.Saldo_Inicial,
        cg.Ingresos_Totales,
        cg.Egresos_Totales,
        (cg.Saldo_Inicial + cg.Ingresos_Totales - cg.Egresos_Totales) AS Saldo_Cierre_Teorico
    FROM Caja_General cg
    INNER JOIN Cajas_Cat cc ON cg.ID_Caja_Fisica = cc.ID_Caja_Fisica
    WHERE CAST(cg.Fecha_Apertura AS DATE) = @Hoy;
    SELECT 
        v.ID_Caja AS ID_Session,
        p.Nombre_Producto,
        SUM(dv.Cantidad) AS Cantidad,
        SUM(dv.Cantidad * dv.Precio_Unitario) AS Subtotal
    FROM Detalle_Venta AS dv
    INNER JOIN Productos_Cat AS p ON dv.ID_Producto = p.ID_Producto
    INNER JOIN Ventas AS v ON dv.ID_Venta = v.ID_Venta
    WHERE CAST(v.Fecha_y_Hora_Venta AS DATE) = @Hoy
    GROUP BY v.ID_Caja, p.Nombre_Producto;
END
GO


--Reporte semanal
CREATE OR ALTER PROCEDURE sp_reporte_semanal
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        CAST(Fecha_y_Hora_Venta AS DATE) AS Fecha,
        FORMAT(Fecha_y_Hora_Venta, 'dddd', 'es-MX') AS DiaNombre,
        SUM(Total) AS VentaDiaria,
        COUNT(ID_Venta) AS Operaciones
    FROM Ventas
    WHERE Fecha_y_Hora_Venta >= DATEADD(DAY, -7, GETDATE())
    GROUP BY CAST(Fecha_y_Hora_Venta AS DATE), FORMAT(Fecha_y_Hora_Venta, 'dddd', 'es-MX')
    ORDER BY Fecha ASC;
    SELECT TOP 5 
        p.Nombre_Producto,
        SUM(dv.Cantidad) AS CantidadTotal,
        SUM(dv.Cantidad * dv.Precio_Unitario) AS IngresoTotal
    FROM Detalle_Venta AS dv
    INNER JOIN Productos_Cat AS p ON dv.ID_Producto = p.ID_Producto
    INNER JOIN Ventas AS v ON dv.ID_Venta = v.ID_Venta
    WHERE v.Fecha_y_Hora_Venta >= DATEADD(DAY, -7, GETDATE())
    GROUP BY p.Nombre_Producto
    ORDER BY CantidadTotal DESC;
END
GO
