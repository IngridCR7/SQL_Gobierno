-- Crear una tabla temporal para almacenar los recuentos de valores únicos con esquema
IF OBJECT_ID('tempdb..#ValoresUnicos') IS NOT NULL
BEGIN
    DROP TABLE #ValoresUnicos
END

CREATE TABLE #ValoresUnicos (
    SchemaName NVARCHAR(128),
    TableName NVARCHAR(128),
    ColumnName NVARCHAR(128),
    UniqueValuesCount INT
)

-- Obtener recuentos de valores únicos por columna en cada tabla
DECLARE @SchemaName NVARCHAR(128)
DECLARE @TableName NVARCHAR(128)
DECLARE @ColumnName NVARCHAR(128)
DECLARE @SQLQuery NVARCHAR(MAX)

-- Definir un cursor para iterar a través de las tablas y columnas    
DECLARE TableCursor CURSOR FOR
SELECT 
    s.name AS SchemaName,
    t.name AS TableName,
    c.name AS ColumnName
FROM 
    sys.tables t
INNER JOIN 
    sys.columns c ON t.object_id = c.object_id
INNER JOIN 
    sys.schemas s ON t.schema_id = s.schema_id
ORDER BY 
    s.name, t.name, c.name

OPEN TableCursor

FETCH NEXT FROM TableCursor INTO @SchemaName, @TableName, @ColumnName

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Construir la consulta dinámica para obtener el recuento de valores únicos
    SET @SQLQuery = 'INSERT INTO #ValoresUnicos (SchemaName, TableName, ColumnName, UniqueValuesCount) ' +
                    'SELECT ''' + @SchemaName + ''', ''' + @TableName + ''', ''' + @ColumnName + ''', ' +
                    'COUNT(DISTINCT ' + QUOTENAME(@ColumnName) + ') ' +
                    'FROM ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName)
    -- Ejecutar la consulta dinámica
    EXEC sp_executesql @SQLQuery

    FETCH NEXT FROM TableCursor INTO @SchemaName, @TableName, @ColumnName
END

CLOSE TableCursor
DEALLOCATE TableCursor

--------------------------------------------------------------------------------------------------
-- Consulta para obtener la cantidad de filas por tabla en una base de datos
IF OBJECT_ID('tempdb..#ConteoFilas') IS NOT NULL
BEGIN
    DROP TABLE #ConteoFilas
END

CREATE TABLE #ConteoFilas (
    Esquema NVARCHAR(255),
    Tabla NVARCHAR(255),
    CantidadFilas BIGINT
)

DECLARE @schema_name NVARCHAR(255)
DECLARE @table_name NVARCHAR(255)
DECLARE @sql NVARCHAR(MAX)

-- Definir un cursor para iterar a través de los esquemas y tablas
DECLARE table_cursor CURSOR FOR
SELECT 
    s.name AS Esquema,
    t.name AS Tabla
FROM 
    sys.schemas s
JOIN 
    sys.tables t ON s.schema_id = t.schema_id

OPEN table_cursor

FETCH NEXT FROM table_cursor INTO @schema_name, @table_name

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Construir la consulta dinámica para obtener el recuento de filas
    SET @sql = 'INSERT INTO #ConteoFilas (Esquema, Tabla, CantidadFilas) SELECT ''' + @schema_name + ''', ''' + @table_name + ''', COUNT(*) FROM ' + QUOTENAME(@schema_name) + '.' + QUOTENAME(@table_name)
    EXEC sp_executesql @sql

    FETCH NEXT FROM table_cursor INTO @schema_name, @table_name
END

CLOSE table_cursor
DEALLOCATE table_cursor

    
--------------------------------------------------------------------------------------------------
-- Crear una tabla temporal para almacenar los ejemplos de cada columna en cada tabla
IF OBJECT_ID('tempdb..#Examples') IS NOT NULL
BEGIN
    DROP TABLE #Examples
END

CREATE TABLE #Examples (
    SchemaName NVARCHAR(100),
    TableName NVARCHAR(100),
    ColumnName NVARCHAR(100),
    ExampleValue NVARCHAR(MAX)
)

DECLARE @SchemaName_2 NVARCHAR(100)
DECLARE @TableName_2 NVARCHAR(100)
DECLARE @ColumnName_2 NVARCHAR(100)
DECLARE @SQLQuery_2 NVARCHAR(MAX)

-- Definir un cursor para iterar a través de las tablas y columnas utilizando INFORMATION_SCHEMA
DECLARE table_cursor CURSOR FOR
SELECT TABLE_SCHEMA, TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'

OPEN table_cursor

FETCH NEXT FROM table_cursor INTO @SchemaName_2, @TableName_2

WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE column_cursor CURSOR FOR
    SELECT COLUMN_NAME
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = @TableName_2 AND TABLE_SCHEMA = @SchemaName_2

    OPEN column_cursor

    FETCH NEXT FROM column_cursor INTO @ColumnName_2

    WHILE @@FETCH_STATUS = 0
    BEGIN
    -- Construir la consulta dinámica para obtener el ejemplo de cada columna omitiendo los nulls
        SET @SQLQuery_2 = N'
            DECLARE @TempTable TABLE (ExampleValue NVARCHAR(MAX))
            INSERT INTO @TempTable
            SELECT [' + @ColumnName_2 + N'] FROM [' + @SchemaName_2 + N'].[' + @TableName_2 + N']
            WHERE [' + @ColumnName_2 + N'] IS NOT NULL
            
            DECLARE @RowCount INT = (SELECT COUNT(*) FROM @TempTable)
            IF @RowCount > 0
                SELECT TOP 1 @ExampleValue = ExampleValue FROM @TempTable
            ELSE
                SELECT @ExampleValue = NULL
        '
        DECLARE @ExampleColumn NVARCHAR(MAX)

        -- Ejecutar la consulta dinámica y obtener el resultado
        EXEC sp_executesql @SQLQuery_2, N'@ExampleValue NVARCHAR(MAX) OUTPUT', @ExampleValue = @ExampleColumn OUTPUT

        -- Insertar el ejemplo en la tabla temporal
        INSERT INTO #Examples (SchemaName, TableName, ColumnName, ExampleValue)
        VALUES (@SchemaName_2, @TableName_2, @ColumnName_2, @ExampleColumn)

        FETCH NEXT FROM column_cursor INTO @ColumnName_2
    END

    CLOSE column_cursor
    DEALLOCATE column_cursor

    FETCH NEXT FROM table_cursor INTO @SchemaName_2, @TableName_2
END

CLOSE table_cursor
DEALLOCATE table_cursor


--------------------------------------------------------------------------------------------------
-- Mostrar los resultados finales
SELECT 
    U.SchemaName,
    U.TableName,
    U.ColumnName,
    U.UniqueValuesCount,
    F.CantidadFilas AS "NumberRows",
    E.ExampleValue
FROM 
    #ValoresUnicos U
LEFT JOIN 
    #ConteoFilas F ON U.SchemaName = F.Esquema AND U.TableName = F.Tabla
LEFT JOIN 
    #Examples E ON U.SchemaName = E.SchemaName AND U.TableName = E.TableName AND U.ColumnName = E.ColumnName

-- Eliminar las tablas temporales
DROP TABLE #ConteoFilas
DROP TABLE #ValoresUnicos
DROP TABLE #Examples

