/* ============================================================================
   Rollback Script: 027_teacher_attendance_rollback.sql
   Target: Teacher Attendance Management (teachers_schema)
   Purpose: Safely rolls back teachers_schema.teacher_attendance created or
            modified in Migration 027.
   ============================================================================ */

SET NOCOUNT ON;
GO

PRINT N'========================================================================';
PRINT N'Rolling back Migration 027: Teacher Attendance Single Table Module...';
PRINT N'========================================================================';
GO

IF OBJECT_ID(N'teachers_schema.teacher_attendance', N'U') IS NOT NULL
BEGIN
    PRINT N'Dropping table teachers_schema.teacher_attendance...';
    DROP TABLE teachers_schema.teacher_attendance;
END;
GO

PRINT N'========================================================================';
PRINT N'Rollback of Migration 027 completed successfully.';
PRINT N'========================================================================';
GO
