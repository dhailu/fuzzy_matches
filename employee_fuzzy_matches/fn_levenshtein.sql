-- #### Target archeticture recomended
-- ADF / Fabric / Azure Function (daily)
--         |
--         v
-- Azure SQL Database
--    - table1 (HR)
--    - table2 (System)
--    - fn_levenshtein()
--    - fuzzy_match_result

-- #### Create Levenshtein Function in Azure SQL (T-SQL)

-- This is safe, portable, and production-proven.



CREATE OR ALTER FUNCTION dbo.fn_levenshtein
(
    @s NVARCHAR(4000),
    @t NVARCHAR(4000)
)
RETURNS INT
AS
BEGIN
    DECLARE @d TABLE (i INT, j INT, cost INT);

    DECLARE @i INT = 0, @j INT, @slen INT, @tlen INT;
    SET @slen = LEN(@s);
    SET @tlen = LEN(@t);

    WHILE @i <= @slen
    BEGIN
        SET @j = 0;
        WHILE @j <= @tlen
        BEGIN
            INSERT INTO @d VALUES
            (
                @i,
                @j,
                CASE
                    WHEN @i = 0 THEN @j
                    WHEN @j = 0 THEN @i
                    ELSE 0
                END
            );
            SET @j += 1;
        END
        SET @i += 1;
    END

    SET @i = 1;
    WHILE @i <= @slen
    BEGIN
        SET @j = 1;
        WHILE @j <= @tlen
        BEGIN
            DECLARE @cost INT =
                CASE WHEN SUBSTRING(@s, @i, 1) = SUBSTRING(@t, @j, 1) THEN 0 ELSE 1 END;

            UPDATE d
            SET cost =
                (SELECT MIN(v)
                 FROM (VALUES
                     ((SELECT cost FROM @d WHERE i = @i - 1 AND j = @j) + 1),
                     ((SELECT cost FROM @d WHERE i = @i AND j = @j - 1) + 1),
                     ((SELECT cost FROM @d WHERE i = @i - 1 AND j = @j - 1) + @cost)
                 ) AS value(v))
            WHERE i = @i AND j = @j;

            SET @j += 1;
        END
        SET @i += 1;
    END

    RETURN (SELECT cost FROM @d WHERE i = @slen AND j = @tlen);
END;
GO
