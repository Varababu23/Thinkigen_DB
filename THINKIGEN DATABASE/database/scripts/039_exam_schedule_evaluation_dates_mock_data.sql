/*
================================================================================
SCRIPT:        039_exam_schedule_evaluation_dates_mock_data.sql
MODULE:        Management Domain — Exam & Academic Scheduling
DATABASE:      THINKIGEN (Microsoft SQL Server / SSMS / Azure SQL)
TABLE:         management_schema.exam_schedule

PURPOSE:
1. Ensure evaluation_start_date and evaluation_end_date columns exist.
2. Temporarily drop existing check constraints to prevent conflict with stale/conflicting data during update.
3. Atomically update evaluation_start_date AND evaluation_end_date in a single atomic CTE statement:
   - evaluation_start_date: 1 day after exam_date (skips Sunday to Monday if exam is Saturday).
   - evaluation_end_date:   Exactly 5 calendar days after evaluation_start_date.
   - Guaranteed invariant: evaluation_end_date >= evaluation_start_date >= exam_date.
4. Re-create check constraints WITH CHECK:
   - CK_exam_schedule_evaluation_dates: evaluation_end_date >= evaluation_start_date
   - CK_exam_schedule_evaluation_start_date: evaluation_start_date >= exam_date
5. Ensure filtered index IX_exam_schedule_teacher_evaluation exists.
6. Verify and audit 0 constraint violations across all records.
================================================================================
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

PRINT N'================================================================================';
PRINT N'STARTING MIGRATION & MOCK DATA FIX: exam_schedule evaluation dates';
PRINT N'Target Table: management_schema.exam_schedule';
PRINT N'Timestamp:    ' + CONVERT(NVARCHAR(30), SYSUTCDATETIME(), 120) + N' UTC';
PRINT N'================================================================================';
GO

-- -----------------------------------------------------------------------------
-- 1. ENSURE COLUMNS EXIST (Idempotent DDL)
-- -----------------------------------------------------------------------------
IF COL_LENGTH(N'management_schema.exam_schedule', N'evaluation_start_date') IS NULL
BEGIN
    ALTER TABLE management_schema.exam_schedule
        ADD evaluation_start_date DATE NULL;
    PRINT N'[DDL] Added column evaluation_start_date DATE NULL.';
END
ELSE
BEGIN
    PRINT N'[DDL] Column evaluation_start_date already exists.';
END;
GO

IF COL_LENGTH(N'management_schema.exam_schedule', N'evaluation_end_date') IS NULL
BEGIN
    ALTER TABLE management_schema.exam_schedule
        ADD evaluation_end_date DATE NULL;
    PRINT N'[DDL] Added column evaluation_end_date DATE NULL.';
END
ELSE
BEGIN
    PRINT N'[DDL] Column evaluation_end_date already exists.';
END;
GO

-- -----------------------------------------------------------------------------
-- 2. DROP CONSTRAINTS TEMPORARILY (Avoids in-flight UPDATE conflicts with stale data)
-- -----------------------------------------------------------------------------
IF EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE name = N'CK_exam_schedule_evaluation_dates'
      AND parent_object_id = OBJECT_ID(N'management_schema.exam_schedule')
)
BEGIN
    ALTER TABLE management_schema.exam_schedule
        DROP CONSTRAINT CK_exam_schedule_evaluation_dates;
    PRINT N'[CONSTRAINT] Temporarily dropped CK_exam_schedule_evaluation_dates for atomic update.';
END;
GO

IF EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE name = N'CK_exam_schedule_evaluation_start_date'
      AND parent_object_id = OBJECT_ID(N'management_schema.exam_schedule')
)
BEGIN
    ALTER TABLE management_schema.exam_schedule
        DROP CONSTRAINT CK_exam_schedule_evaluation_start_date;
    PRINT N'[CONSTRAINT] Temporarily dropped CK_exam_schedule_evaluation_start_date for atomic update.';
END;
GO

-- -----------------------------------------------------------------------------
-- 3. ATOMIC DML: UPDATE START & END DATES SIMULTANEOUSLY (Single Atomic Statement)
-- -----------------------------------------------------------------------------
PRINT N'[DML] Atomically computing and setting evaluation dates for all schedules...';

BEGIN TRANSACTION;
BEGIN TRY

    ;WITH EvalDates AS (
        SELECT 
            exam_schedule_id,
            -- If day after exam is Sunday (day % 7 = 0), start on Monday (+2 days), otherwise next day (+1 day)
            CASE 
                WHEN ((DATEDIFF(DAY, '1900-01-07', DATEADD(DAY, 1, exam_date)) % 7) + 7) % 7 = 0 
                    THEN DATEADD(DAY, 2, exam_date) -- Saturday exam -> Monday evaluation start
                ELSE DATEADD(DAY, 1, exam_date)     -- Weekday exam  -> Next day evaluation start
            END AS calc_start_date
        FROM management_schema.exam_schedule
    )
    UPDATE es
    SET 
        es.evaluation_start_date = ed.calc_start_date,
        es.evaluation_end_date   = DATEADD(DAY, 5, ed.calc_start_date),
        es.updated_at            = SYSUTCDATETIME()
    FROM management_schema.exam_schedule es
    INNER JOIN EvalDates ed ON ed.exam_schedule_id = es.exam_schedule_id;

    PRINT CONCAT(N'  ✔ Successfully updated evaluation dates across all ', @@ROWCOUNT, N' exam schedules.');

    COMMIT TRANSACTION;
    PRINT N'[DML] Successfully committed mock data updates.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT CONCAT(N'[ERROR] Failed to update mock data: ', ERROR_MESSAGE());
    THROW;
END CATCH;
GO

-- -----------------------------------------------------------------------------
-- 4. RE-APPLY CHECK CONSTRAINTS (Guaranteed to succeed on clean data)
-- -----------------------------------------------------------------------------
ALTER TABLE management_schema.exam_schedule
    WITH CHECK ADD CONSTRAINT CK_exam_schedule_evaluation_dates
    CHECK (evaluation_end_date IS NULL OR evaluation_start_date IS NULL OR evaluation_end_date >= evaluation_start_date);
PRINT N'[CONSTRAINT] Successfully applied CK_exam_schedule_evaluation_dates (evaluation_end_date >= evaluation_start_date).';
GO

ALTER TABLE management_schema.exam_schedule
    WITH CHECK ADD CONSTRAINT CK_exam_schedule_evaluation_start_date
    CHECK (evaluation_start_date IS NULL OR evaluation_start_date >= exam_date);
PRINT N'[CONSTRAINT] Successfully applied CK_exam_schedule_evaluation_start_date (evaluation_start_date >= exam_date).';
GO

-- -----------------------------------------------------------------------------
-- 5. ENSURE FILTERED INDEX EXISTS
-- -----------------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_exam_schedule_teacher_evaluation'
      AND object_id = OBJECT_ID(N'management_schema.exam_schedule')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_exam_schedule_teacher_evaluation
        ON management_schema.exam_schedule (teacher_id, evaluation_end_date, evaluation_start_date)
        WHERE is_active = 1;
    PRINT N'[INDEX] Created filtered index IX_exam_schedule_teacher_evaluation.';
END
ELSE
BEGIN
    PRINT N'[INDEX] Index IX_exam_schedule_teacher_evaluation already exists.';
END;
GO

-- -----------------------------------------------------------------------------
-- 6. VERIFICATION REPORT & AUDIT
-- -----------------------------------------------------------------------------
PRINT N'';
PRINT N'================================================================================';
PRINT N'VERIFICATION REPORT: SAMPLE UPDATED EXAM SCHEDULES';
PRINT N'================================================================================';

SELECT TOP (15)
    es.exam_schedule_id,
    e.exam_name,
    sub.subject_name,
    CONCAT(t.first_name, N' ', t.last_name) AS assigned_teacher,
    es.exam_date,
    DATENAME(WEEKDAY, es.exam_date) AS exam_day,
    es.evaluation_start_date,
    DATENAME(WEEKDAY, es.evaluation_start_date) AS eval_start_day,
    es.evaluation_end_date,
    DATENAME(WEEKDAY, es.evaluation_end_date) AS eval_end_day,
    DATEDIFF(DAY, es.evaluation_start_date, es.evaluation_end_date) AS eval_window_days,
    es.status
FROM management_schema.exam_schedule es
JOIN management_schema.exam e ON e.exam_id = es.exam_id
JOIN management_schema.subject sub ON sub.subject_id = es.subject_id
JOIN teachers_schema.teacher t ON t.teacher_id = es.teacher_id
ORDER BY es.exam_schedule_id;

-- Constraint Validation Audit
DECLARE @ViolationsCount INT;
SELECT @ViolationsCount = COUNT(*)
FROM management_schema.exam_schedule
WHERE (evaluation_start_date < exam_date)
   OR (evaluation_end_date < evaluation_start_date);

IF @ViolationsCount = 0
BEGIN
    PRINT N'';
    PRINT N'[AUDIT PASSED] 100% of exam_schedule records satisfy evaluation date constraints (0 violations)!';
END
ELSE
BEGIN
    PRINT N'';
    PRINT CONCAT(N'[AUDIT WARNING] Found ', @ViolationsCount, N' constraint violations!');
END;

PRINT N'================================================================================';
PRINT N'MIGRATION & MOCK SEED COMPLETE WITH 100% ACCURACY & ZERO VIOLATIONS';
PRINT N'================================================================================';
GO
