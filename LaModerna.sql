create database La_Moderna
on
(
	name = La_Moderna_dat,
	filename = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA\La_Moderna.mdf',
	size = 100,
	maxsize = 200,
	filegrowth = 10
)
log on
(
	name = La_Moderna_log,
	filename = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA\La_Moderna.ldf',
	size = 50,
	maxsize = 100,
	filegrowth = 5
)
go

use La_Moderna
go


--Creamos las tablas de la base de datos 
--Tabla de clientes 
create table Clientes_Cat (
    ID_Cliente          smallint identity (1,1) primary key,
    Nombre              varchar (30)    not null,
    Apellido_Paterno    varchar (30)    not null,
    Apellido_Materno    varchar (30)    not null,
    Numero_Telefono     varchar (10)    not null,
    Cliente_Activo      bit             not null
);

--Tabla de proveedores 
create table Proveedores_Cat (
    ID_Proveedor            smallint identity (1,1) primary key,
    Nombre_Proveedor        varchar (50)    not null,
    Descripcion_Proveedor   varchar (100)   not null, 
    Telefono_Proveedor      varchar (15)    not null,
    Calle                   varchar (50)    not null,
    Numero_Calle            varchar (10)    not null, 
    Codigo_Postal           int             not null,
    Ciudad_Delegacion       varchar (40)    not null,
    Proveedor_Activo        bit             not null
);

--Tabla de lote
create table Lotes_Cat
(
    ID_Lote         smallint identity (1,1) primary key,
    Num_Lote        varchar (20)            not null,
    Fecha_Caducidad date                    not null
);

--Tabla de productos 
create table Productos_Cat (
    ID_Producto             smallint identity (1,1) primary key,
    Nombre_Producto         varchar (50)    not null,
    Descripcion_Producto    varchar (50)   not null,
    ID_Prove                smallint        not null,
    Precio_Compra           decimal (10,2)  not null, 
    Precio_Venta            decimal (10,2)  not null,
    Cantidad                smallint        not null,
    Lote                    smallint        not null,
    Producto_Activo         bit             not null,
    constraint FK_Proveedor foreign key (ID_Prove) references Proveedores_Cat (ID_Proveedor),
    constraint FK_Lote      foreign key (Lote)     references Lotes_Cat (ID_Lote)
);


--Tabla de Ventas 
create table Ventas (
    ID_Venta                int identity (1,1) primary key, 
    ID_Cliente              smallint        not null,   
    Fecha_y_Hora_Venta      datetime        not null default getdate(),
    Total                   decimal (10,2)  not null,
    Pago                    decimal (10,2)  not null,
    Cambio                  decimal (10,2)  not null,
    constraint FK_Cliente foreign key (ID_Cliente) references Clientes_Cat (ID_Cliente)
);

--Tabla de Detalle Venta 
create table Detalle_Venta (
    ID_Detalle_Venta    int identity (1,1) primary key,
    ID_Venta            int             not null, 
    ID_Producto         smallint        not null,
    Cantidad            smallint        not null,
    Precio_Unitario     decimal (10,2)  not null, 
    constraint FK_Venta_Relacion foreign key (ID_Venta) references Ventas (ID_Venta),
    constraint FK_Producto_Relacion foreign key (ID_Producto) references Productos_Cat (ID_Producto)
)
go

--Tabla de la Bandeja de Alertas
create table Bandeja_Alertas (
    ID_Alerta       int identity(1,1) primary key,
    Mensaje         varchar (255),
    Tipo_Alerta     varchar (20), 
    Fecha_Generada  datetime default getdate()
)
go

--Creamos indices
create index ix_Productos_Stock on Productos_Cat(Cantidad)
go
create index ix_Ventas_Fecha on Ventas(Fecha_y_Hora_Venta)
go


--creamos los precedimiento y trigger necesarios para hacer las siguientes acciones:
--Ver, agregar, atualizar y eliminar productos
create or alter procedure sp_gestion_inventario
    @accion      varchar (10),
    @id_prod      smallint        = null,
    @nombre       varchar (50)    = null,
    @desc         varchar (50)    = null,
    @id_prov      smallint        = null,
    @p_compra     decimal (10,2)  = null,
    @p_venta      decimal (10,2)  = null,
    @cant         smallint        = null,
    @num_lote     varchar(20)     = null, 
    @caducidad    date            = null  
as
begin
    set nocount on;
    declare @id_lote_generado as smallint;

    if @accion = 'agregar'
    begin
        if not exists (select 1 from Lotes_Cat as lc where lc.Num_Lote = @num_lote)
        begin
            insert into Lotes_Cat (Num_Lote, Fecha_Caducidad)
            values (@num_lote, @caducidad);
            set @id_lote_generado = scope_identity();
        end
        else
        begin
            select @id_lote_generado = ID_Lote 
            from Lotes_Cat as lc
            where lc.Num_Lote = @num_lote;
        end

        insert into Productos_Cat (Nombre_Producto, 
                                   Descripcion_Producto, 
                                   ID_Prove, Precio_Compra, 
                                   Precio_Venta, 
                                   Cantidad, 
                                   Lote, 
                                   Producto_Activo)
        values (@nombre, 
                @desc, 
                @id_prov, 
                @p_compra, 
                @p_venta, 
                @cant, 
                @id_lote_generado, 
                case when @cant > 0 then 1 else 0 end);
    end

    if @accion = 'actualizar'
    begin
        update Productos_Cat
        set Nombre_Producto = isnull(@nombre, Nombre_Producto),
            Descripcion_Producto = isnull(@desc, Descripcion_Producto),
            Precio_Compra = isnull(@p_compra, Precio_Compra),
            Precio_Venta = isnull(@p_venta, Precio_Venta),
            Cantidad = isnull(@cant, Cantidad),
            Producto_Activo = case when isnull(@cant, Cantidad) > 0 then 1 else 0 end
        where ID_Producto = @id_prod;
    end

    if @accion = 'eliminar'
    begin
        update Productos_Cat 
        set Producto_Activo = 0, 
            Cantidad = 0 
        where ID_Producto = @id_prod;
    end

    if @accion = 'ver'
    begin
        --Lista de todos los productos que esten activos o no
        if @id_prod is null
        begin
            select 
                p.ID_Producto as ID_Producto,
                p.Nombre_Producto as Nombre_Producto,
                p.Descripcion_Producto as Descripcion_Producto,
                pr.Nombre_Proveedor as Nombre_Proveedor,
                p.Precio_Compra as Precio_Compra,
                p.Precio_Venta as Precio_Venta,
                p.Cantidad as Cantidad,
                l.Num_Lote as Num_Lote,
                l.Fecha_Caducidad as Fecha_Caducidad,
                case when p.Cantidad > 0 then 1 else 0 end as Producto_Activo
            from Productos_Cat as p
            inner join Proveedores_Cat as pr on p.ID_Prove = pr.ID_Proveedor
            inner join Lotes_Cat as l on p.Lote = l.ID_Lote;
        end
        
        --Un producto en especifico xd
        else
        begin
            declare @nombre_buscado as varchar(50);
            select @nombre_buscado = Nombre_Producto 
            from Productos_Cat as p 
            where p.ID_Producto = @id_prod;

            select 
                p.Nombre_Producto as Nombre_Producto,
                p.Descripcion_Producto as Descripcion_Producto,
                pr.Nombre_Proveedor as Nombre_Proveedor,
                p.Precio_Compra as Precio_Compra,
                p.Precio_Venta as Precio_Venta,
                p.Cantidad as Cantidad,
                l.Num_Lote as Lote_Asignado,
                l.Fecha_Caducidad as Fecha_Caducidad,
                case when p.Cantidad > 0 then 1 else 0 end as Estado_Lote
            from Productos_Cat as p
            inner join Proveedores_Cat as pr on p.ID_Prove = pr.ID_Proveedor
            inner join Lotes_Cat as l on p.Lote = l.ID_Lote
            where p.Nombre_Producto = @nombre_buscado;
        end
    end
end
go

/*
    procedimiento para:
        -generar ventas
        -verificar si hay existencia en el inventario
         en cantidad >= al solicitado en venta
        -actualizar el inventario automaticamente despues
         de una venta
*/
create or alter procedure sp_registrar_venta
    @id_cliente     smallint,
    @pago           decimal (10,2),
    @id_producto    smallint,
    @cantidad       smallint
as
    begin
        set nocount on;
        begin try
            begin tran;
                declare @precio     decimal (10,2), 
                        @stock      smallint, 
                        @total      decimal (10,2), 
                        @cambio     decimal (10,2), 
                        @idventa    int;

                select @precio = precio_venta,
                       @stock  = cantidad
                from productos_cat
                where id_producto = @id_producto;

                if @stock < @cantidad
                    throw 50001,'Inventario insuficiente',1;
                
                set @total = @precio * @cantidad;
                
                if @pago < @total
                    throw 50002, 'Pago insuficiente',1;
                
                set @cambio = @pago - @total;

                insert into ventas (id_cliente, total, pago, cambio)
                values (@id_cliente, @total, @pago, @cambio);
                
                set @idventa = scope_identity();

                insert into detalle_venta (id_venta, id_producto, cantidad, precio_unitario)
                values (@idventa, @id_producto, @cantidad, @precio);

                update productos_cat
                set cantidad = cantidad - @cantidad
                where id_producto = @id_producto;
                
            commit;
            select @total as total, @cambio as cambio;
        end try
        begin catch
            if @@trancount > 0 rollback;
            throw;
        end catch
    end
go

--procedimiento para corte de caja
create or alter procedure sp_corte_diario
as
    begin
        select
            cast(getdate() as date)     as fecha,
            count(distinct v.id_venta)  as total_transacciones,
            isnull(sum(dv.cantidad), 0) as unidades,
            isnull(sum(dv.cantidad * dv.precio_unitario), 0) as ingreso
        from ventas as v
        left join detalle_venta as dv on v.id_venta = dv.id_venta
        where cast(v.fecha_y_hora_venta as date) = cast(getdate() as date);
    end
go

--procedimiento para reporte semanal
create or alter procedure sp_reporte_semanal
as
    begin
        select
            cast(fecha_y_hora_venta as date) as fecha,
            sum(total) as venta_diaria
        from ventas
        where fecha_y_hora_venta >= dateadd(day, -7, getdate())
        group by cast(fecha_y_hora_venta as date);

        select
            nombre_producto, 
            cantidad,
            lote
        from productos_cat
        where producto_activo = 1; 

        select 
            sum(total) as ganancia_semanal
        from ventas
        where fecha_y_hora_venta >= dateadd(day, -7, getdate());
    end
go

/*
alertas 
procedimiento para generar alertas:
    -cuando un producto tiene unidades
     en stock <=5
    -cuando un produto esta a una semana
     o menos de caducar
*/
create or alter procedure sp_generar_alertas
as
    begin
        --alerta por stock bajo
        insert into bandeja_alertas (mensaje, tipo_alerta)
        select
            'inventario bajo: ' + nombre_producto,
            'inventario'
        from productos_cat as p
        where cantidad <= 5
        and not exists(
            select 1 
            from bandeja_alertas as b
            where b.mensaje like '%' + p.nombre_producto + '%'
            and b.tipo_alerta = 'inventario'
            and cast(b.fecha_generada as date) = cast(getdate() as date)
        );

        --alerta por caducidad 
        insert into bandeja_alertas (mensaje, tipo_alerta)
        select
            'caduca pronto: ' + p.nombre_producto,
            'caducidad'
        from productos_cat p
        inner join lotes_cat l on p.lote = l.id_lote
        where l.fecha_caducidad <= dateadd(day, 7, getdate())
        and not exists(
            select 1 
            from bandeja_alertas as b
            where b.mensaje like '%' + p.nombre_producto + '%'
            and b.tipo_alerta = 'caducidad'
            and cast(b.fecha_generada as date) = cast(getdate() as date)
        );
    end
go