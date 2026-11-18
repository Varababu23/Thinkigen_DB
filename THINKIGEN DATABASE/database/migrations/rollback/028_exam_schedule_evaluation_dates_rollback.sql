/* Module: 028_exam_schedule_evaluation_dates_rollback (management domain) */
/*
    Rollback:  028_exam_schedule_evaluation_dates_rollback
    Purpose:   Reverts evaluation_start_date and evaluation_end_date columns, constraints,
               and indexes added to management_schema.exam_schedule.
*/

IF EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_exam_schedule_teacher_evaluation'
      AND object_id = OBJECT_ID(N'management_schema.exam_schedule')
)
BEGIN
    DROP INDEX IX_exam_schedule_teacher_evaluation ON management_schema.exam_schedule;
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
END;
GO

IF EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE name = N'CK_exam_schedule_evaluation_dates'
      AND parent_object_id = OBJECT_ID(N'management_schema.exam_schedule')
)
BEGIN
    ALTER TABLE management_schema.exam_schedule
        DROP CONSTRAINT CK_exam_schedule_evaluation_dates;
END;
GO

IF COL_LENGTH(N'management_schema.exam_schedule', N'evaluation_start_date') IS NOT NULL
BEGIN
    ALTER TABLE management_schema.exam_schedule
        DROP COLUMN evaluation_start_date;
END;
GO

IF COL_LENGTH(N'management_schema.exam_schedule', N'evaluation_end_date') IS NOT NULL
BEGIN
    ALTER TABLE management_schema.exam_schedule
        DROP COLUMN evaluation_end_date;
END;
GO
