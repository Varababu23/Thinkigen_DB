/* Module: 028_exam_schedule_evaluation_dates (management domain) */
/*
    Migration: 028_exam_schedule_evaluation_dates
    Purpose:   Add paper evaluation start date (when teachers start evaluating papers for that subject/section)
               and paper evaluation deadline end date to management_schema.exam_schedule.

    Hierarchy:
    school_id -> branch_id -> academic_year_id -> class_id -> section_id -> exam_id -> subject_id

    Design notes:
    - evaluation_start_date DATE NULL: Date teacher begins paper evaluation.
    - evaluation_end_date DATE NULL: Deadline date for completing paper evaluation.
    - Check constraint CK_exam_schedule_evaluation_dates: evaluation_end_date >= evaluation_start_date
    - Check constraint CK_exam_schedule_evaluation_start_date: evaluation_start_date >= exam_date
    - Nullable for backward compatibility with pending/unconfigured evaluation deadlines.
    - Filtered index IX_exam_schedule_teacher_evaluation on (teacher_id, evaluation_end_date, evaluation_start_date)
      for fast teacher deadline tracking and alerts.

    Rollback:
    - See database/migrations/rollback/028_exam_schedule_evaluation_dates_rollback.sql
*/

IF COL_LENGTH(N'management_schema.exam_schedule', N'evaluation_start_date') IS NULL
BEGIN
    ALTER TABLE management_schema.exam_schedule
        ADD evaluation_start_date DATE NULL;
END;
GO

IF COL_LENGTH(N'management_schema.exam_schedule', N'evaluation_end_date') IS NULL
BEGIN
    ALTER TABLE management_schema.exam_schedule
        ADD evaluation_end_date DATE NULL;
END;
GO

-- Backfill evaluation dates for any existing rows before enabling constraints
UPDATE es
SET 
    evaluation_start_date = DATEADD(DAY, 1, es.exam_date),
    evaluation_end_date   = DATEADD(DAY, 6, es.exam_date),
    updated_at            = SYSUTCDATETIME()
FROM management_schema.exam_schedule es
WHERE es.evaluation_start_date IS NULL OR es.evaluation_end_date IS NULL;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE name = N'CK_exam_schedule_evaluation_dates'
      AND parent_object_id = OBJECT_ID(N'management_schema.exam_schedule')
)
BEGIN
    ALTER TABLE management_schema.exam_schedule
        ADD CONSTRAINT CK_exam_schedule_evaluation_dates
        CHECK (evaluation_end_date IS NULL OR evaluation_start_date IS NULL OR evaluation_end_date >= evaluation_start_date);
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE name = N'CK_exam_schedule_evaluation_start_date'
      AND parent_object_id = OBJECT_ID(N'management_schema.exam_schedule')
)
BEGIN
    ALTER TABLE management_schema.exam_schedule
        ADD CONSTRAINT CK_exam_schedule_evaluation_start_date
        CHECK (evaluation_start_date IS NULL OR evaluation_start_date >= exam_date);
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_exam_schedule_teacher_evaluation'
      AND object_id = OBJECT_ID(N'management_schema.exam_schedule')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_exam_schedule_teacher_evaluation
        ON management_schema.exam_schedule (teacher_id, evaluation_end_date, evaluation_start_date)
        WHERE is_active = 1;
END;
GO
