# Sistema de Gestión de Inventario y Ventas - "La Moderna"

Repositorio dedicado al diseño y administración de la base de datos para la tienda "La Moderna". Incluye la estructura relacional, procedimientos almacenados avanzados y un sistema de alertas automáticas.

## Características Principales
* **Arquitectura Relacional:** Tablas normalizadas para Clientes, Proveedores, Lotes, Productos y Ventas.
* **Gestión de Inventario:** Procedimiento `sp_gestion_inventario` para realizar operaciones CRUD completas.
* **Sistema de Ventas:** Lógica transaccional con manejo de errores (`TRY/CATCH`) y actualización automática de stock.
* **Bandeja de Alertas:** Generación automática de notificaciones para productos con stock bajo (<= 5 unidades) o próximos a caducar (7 días).

## Requisitos
* **Gestor:** SQL Server 2022 (o superior).
* **Herramienta:** SQL Server Management Studio (SSMS) o Azure Data Studio.

## Instalación
1. Ejecutar el script `La_Moderna.sql` en tu instancia de SQL Server.
2. Verificar la creación de los archivos físicos `.mdf` y `.ldf` (ajustar rutas en el script si es necesario).
3. Ejecutar el procedimiento de alertas para inicializar la bandeja:
   ```sql
   exec sp_generar_alertas;
