-- exec dbo.usp_UpdateDynamicAuditTable_v3
-- select * from dbo.dynamic_audite_table;
CREATE OR ALTER PROCEDURE dbo.usp_UpdateDynamicAuditTable_v3
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Setup Priority Logic
    DECLARE @DatePriority TABLE (ColumnName SYSNAME, Priority INT);
    INSERT INTO @DatePriority (ColumnName, Priority)
    VALUES ('OrderDate', 1), ('ShipDate', 2), ('CreatedDate', 3);

    DECLARE @sql NVARCHAR(MAX) = N'';

    -- 2. Build the inner UNION ALL query
    SELECT @sql = STUFF((
        SELECT 
            CHAR(10) + ' UNION ALL ' + CHAR(10) +
            'SELECT ''' + QUOTENAME(table_schema) + '.' + QUOTENAME(table_name) + ''' AS source, ' +
            'YEAR(' + QUOTENAME(column_name) + ') AS YearValue, ' +
            'COUNT(*) AS total ' +
            'FROM ' + QUOTENAME(table_schema) + '.' + QUOTENAME(table_name) + ' ' +
            'WHERE ' + QUOTENAME(column_name) + ' IS NOT NULL ' +
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
              AND c.table_name <> 'dynamic_audite_table' 
        ) x
        WHERE rnum = 1
        FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 13, '');

    -- 3. Wrap in DROP and SELECT INTO with Percentage Math
    IF @sql <> ''
    BEGIN
        DECLARE @finalSql NVARCHAR(MAX) = N'
            IF OBJECT_ID(''dbo.dynamic_audite_table'', ''U'') IS NOT NULL 
                DROP TABLE dbo.dynamic_audite_table;

            WITH RawAuditData AS (
                ' + @sql + '
            ),
            LaggedData AS (
                SELECT 
                    source, 
                    YearValue, 
                    total,
                    LAG(total, 1) OVER (PARTITION BY source ORDER BY YearValue) AS prev_year_total,
                    LAG(total, 2) OVER (PARTITION BY source ORDER BY YearValue) AS two_years_ago_total
                FROM RawAuditData
            )
            SELECT 
                source,
                YearValue,
                total,
                -- 1 Year Lag Percentage Change
                CAST(CASE 
                    WHEN prev_year_total IS NULL OR prev_year_total = 0 THEN NULL 
                    ELSE ((total - prev_year_total) * 100.0 / prev_year_total) 
                END AS DECIMAL(10,2)) AS YearOverYearChange,
                -- 2 Year Lag Percentage Change
                CAST(CASE 
                    WHEN two_years_ago_total IS NULL OR two_years_ago_total = 0 THEN NULL 
                    ELSE ((total - two_years_ago_total) * 100.0 / two_years_ago_total) 
                END AS DECIMAL(10,2)) AS TwoYearChange,
                GETDATE() AS AuditRunDate
            INTO dbo.dynamic_audite_table 
            FROM LaggedData;';

        EXEC sp_executesql @finalSql;
    END
END;
GO