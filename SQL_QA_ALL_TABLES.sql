-- Crear una tabla temporal para almacenar los recuentos de valores únicos con esquema
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
    SET @SQLQuery = 'INSERT INTO #ValoresUnicos (SchemaName, TableName, ColumnName, UniqueValuesCount) ' +
                    'SELECT ''' + @SchemaName + ''', ''' + @TableName + ''', ''' + @ColumnName + ''', ' +
                    'COUNT(DISTINCT ' + QUOTENAME(@ColumnName) + ') ' +
                    'FROM ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName)

    EXEC sp_executesql @SQLQuery

    FETCH NEXT FROM TableCursor INTO @SchemaName, @TableName, @ColumnName
END

CLOSE TableCursor
DEALLOCATE TableCursor

-- Consulta para obtener la cantidad de filas por tabla en una base de datos
CREATE TABLE #ConteoFilas (
    Esquema NVARCHAR(255),
    Tabla NVARCHAR(255),
    CantidadFilas BIGINT
)

DECLARE @schema_name NVARCHAR(255)
DECLARE @table_name NVARCHAR(255)
DECLARE @sql NVARCHAR(MAX)

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
    SET @sql = 'INSERT INTO #ConteoFilas (Esquema, Tabla, CantidadFilas) SELECT ''' + @schema_name + ''', ''' + @table_name + ''', COUNT(*) FROM ' + QUOTENAME(@schema_name) + '.' + QUOTENAME(@table_name)
    EXEC sp_executesql @sql

    FETCH NEXT FROM table_cursor INTO @schema_name, @table_name
END

CLOSE table_cursor
DEALLOCATE table_cursor

-- Crear una tabla temporal para almacenar los ejemplos de cada columna en cada tabla
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

-- Consultar todas las tablas en la base de datos con su esquema
DECLARE table_cursor CURSOR FOR
SELECT TABLE_SCHEMA, TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'

OPEN table_cursor

FETCH NEXT FROM table_cursor INTO @SchemaName_2, @TableName_2

-- Recorrer cada tabla y obtener un ejemplo de cada campo
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
        SET @SQLQuery_2 = N'SELECT TOP 1 @ExampleValue = [' + @ColumnName_2 + N'] FROM [' + @SchemaName_2 + N'].[' + @TableName_2 + N']'
        DECLARE @ExampleColumn NVARCHAR(MAX)
        
        EXEC sp_executesql @SQLQuery_2, N'@ExampleValue NVARCHAR(MAX) OUTPUT', @ExampleValue = @ExampleColumn OUTPUT

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

