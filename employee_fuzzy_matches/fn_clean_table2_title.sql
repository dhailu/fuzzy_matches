CREATE OR ALTER FUNCTION dbo.fn_clean_table2_title
(
    @title NVARCHAR(500)
)
RETURNS NVARCHAR(500)
AS
BEGIN
    IF @title IS NULL RETURN NULL;

    -- remove trailing parentheses
    SET @title = RTRIM(
        LEFT(@title, LEN(@title) - CHARINDEX('(', REVERSE(@title)) + 1)
    );

    -- remove trailing dash codes
    IF RIGHT(@title, 1) = ')'
        SET @title = LEFT(@title, CHARINDEX('(', @title) - 1);

    IF RIGHT(@title, 1) LIKE '[A-Z0-9]'
        SET @title = LEFT(@title, LEN(@title) - CHARINDEX('-', REVERSE(@title)) + 1);

    RETURN RTRIM(@title);
END;
GO
-- Normalize Data (Computed Columns – Optional but FAST)
-- ALTER TABLE table2
-- ADD business_title_clean AS dbo.fn_clean_table2_title(business_title);