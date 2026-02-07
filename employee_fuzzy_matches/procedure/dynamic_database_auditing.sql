create or alter procedure vw_database_auditing
as
-- Priority table
DECLARE @DatePriority TABLE (
    ColumnName SYSNAME,
    Priority   INT
);

INSERT INTO @DatePriority (ColumnName, Priority)
VALUES ('OrderDate', 1), ('ShipDate', 2), ('CreatedDate', 3);

DECLARE @sql NVARCHAR(MAX) = N'';

-- Build dynamic SQL for Yearly Grouping
SELECT @sql = STUFF((
    SELECT 
        CHAR(10) + ' UNION ALL ' + CHAR(10) +
        'SELECT ''' + QUOTENAME(table_schema) + '.' + QUOTENAME(table_name) + ''' AS source, ' +
        'YEAR(' + QUOTENAME(column_name) + ') AS YearValue, ' +
        'COUNT(*) AS total ' +
        'FROM ' + QUOTENAME(table_schema) + '.' + QUOTENAME(table_name) + ' ' +
        'WHERE ' + QUOTENAME(column_name) + ' IS NOT NULL ' + -- Added to filter out NULLs
        'GROUP BY YEAR(' + QUOTENAME(column_name) + ')'
    FROM (
        SELECT 
            c.table_schema, 
            c.table_name, 
            c.column_name,
            ROW_NUMBER() OVER (
                PARTITION BY c.table_schema, c.table_name 
                ORDER BY ISNULL(p.Priority, 999)
            ) AS rnum
        FROM INFORMATION_SCHEMA.COLUMNS c
        LEFT JOIN @DatePriority p ON c.column_name = p.ColumnName
        WHERE c.data_type IN ('date','datetime','datetime2')
          AND c.table_schema = 'dbo'
    ) x
    WHERE rnum = 1
    FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 13, '');

-- Execute
IF @sql <> ''
BEGIN
    -- Optional: Wrap the final result in an ORDER BY
    SET @sql = @sql + ' ORDER BY source, YearValue';
    EXEC sp_executesql @sql;
END
ELSE 
    PRINT 'No columns found matching the criteria.';