-- Fuzzy Match Query (Multi-Column Weighted)

-- We’ll calculate a similarity score using Levenshtein distance. fn_levenshtein

create or alter procedures dbo.prc_update_fuzzy_matches
as
begin 
        WITH CandidatePairs AS (
            SELECT
                t1.employee_id,
                t2.id AS matched_id,

                t1.full_name,
                t2.employee_name,

                t1.Supervisor_name,
                t2.Supv_name,

                t1.business_title,
                t2.business_title_clean,

                t1.location,
                t2.location AS matched_location,

                t1.start_date,
                t2.job_start_date,

                -- Name similarity
                100 - dbo.fn_levenshtein(t1.full_name, t2.employee_name) * 100
                    / NULLIF(GREATEST(LEN(t1.full_name), LEN(t2.employee_name)), 1)
                    AS name_score,

                -- Supervisor similarity
                100 - dbo.fn_levenshtein(t1.Supervisor_name, t2.Supv_name) * 100
                    / NULLIF(GREATEST(LEN(t1.Supervisor_name), LEN(t2.Supv_name)), 1)
                    AS supv_score,

                -- Title similarity
                100 - dbo.fn_levenshtein(t1.business_title, t2.business_title_clean) * 100
                    / NULLIF(GREATEST(LEN(t1.business_title), LEN(t2.business_title_clean)), 1)
                    AS title_score,

                CASE WHEN t1.start_date = t2.job_start_date THEN 100 ELSE 0 END AS date_score
            FROM table1 t1
            JOIN table2 t2
            ON t1.location = t2.location   -- BLOCKING (critical for performance)
        )
        SELECT *,
            (
                0.40 * name_score +
                0.20 * supv_score +
                0.20 * title_score +
                0.20 * date_score
            ) AS final_score
        FROM CandidatePairs
        WHERE
            (
            0.40 * name_score +
            0.20 * supv_score +
            0.20 * title_score +
            0.20 * date_score
            ) >= 80;

     -- Persist Results (Production Table)

    CREATE TABLE if not exists dbo.employee_fuzzy_match (
    employee_id INT,
    matched_id INT,
    full_name NVARCHAR(200),
    matched_full_name NVARCHAR(200),
    Supervisor_name NVARCHAR(200),
    matched_Supv_name NVARCHAR(200),
    business_title NVARCHAR(200),
    matched_business_title NVARCHAR(200),
    location NVARCHAR(100),
    start_date DATE,
    matched_job_start_date DATE,
    final_score DECIMAL(5,2),
    run_date DATETIME DEFAULT GETDATE()
     );


    INSERT INTO dbo.employee_fuzzy_match (
            employee_id,
            matched_id,
            full_name,
            matched_full_name,
            Supervisor_name,
            matched_Supv_name,
            business_title,
            matched_business_title,
            location,
            start_date,
            matched_job_start_date,
            final_score
        )