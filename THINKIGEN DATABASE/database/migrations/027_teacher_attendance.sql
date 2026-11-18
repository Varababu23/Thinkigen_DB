/*
================================================================================
THINKIGEN ERP - PRODUCTION DATABASE MIGRATION SCRIPT
================================================================================
Migration File:    027_teacher_attendance.sql
Schema / Module:   teachers_schema (Teacher Portal Daily Attendance Management)
Target Database:   Microsoft SQL Server 2019+ / Azure SQL Database
Deployment Mode:   Idempotent, Transactional, Audited, Non-Destructive

MANDATORY ARCHITECTURE PRINCIPLES (STRICT SEPARATION OF CONCERNS):
- SQL Server: Exclusively maintains tables, columns, primary keys, foreign keys,
  unique constraints, check constraints, default constraints, nonclustered indexes,
  and rowversion concurrency tokens.
- FastAPI Backend: Exclusively owns all business logic, check-in/out workflows,
  duration calculations, status classification (PRESENT, ABSENT, HALF_DAY, etc.),
  and transaction orchestration.
- STRICTLY PROHIBITED & ABSENT:
  * ZERO SQL Triggers.
  * ZERO Stored Procedures.
  * ZERO User-Defined Functions.
  * ZERO Database-Side Business Logic.
  * ZERO Modifications to Unrelated Parent Master Tables.
  * ZERO Hardcoded User IDs / Fabricated Audit Identities.
  * ZERO Executable References to Obsolete Columns (marked_by, corrected_by, etc.).
  * ZERO Unsafe Automatic In-Transaction Drops of Existing Unique Constraints or Indexes.

TABLE SCOPE & ARCHITECTURE (EXACTLY 17 REQUIRED COLUMNS):
  1. teacher_attendance_id      BIGINT IDENTITY(1,1) NOT NULL (PK)
  2. school_id                  BIGINT NOT NULL (FK)
  3. branch_id                  BIGINT NOT NULL (FK)
  4. academic_year_id           BIGINT NOT NULL (FK)
  5. teacher_id                 BIGINT NOT NULL (FK)
  6. attendance_date            DATE NOT NULL
  7. attendance_status          VARCHAR(20) NOT NULL
  8. check_in_time              DATETIME2(0) NULL
  9. check_out_time             DATETIME2(0) NULL
  10. total_worked_minutes      INT NULL
  11. remarks                   NVARCHAR(500) NULL
  12. is_active                 BIT NOT NULL DEFAULT (1)
  13. created_at                DATETIME2(0) NOT NULL DEFAULT (SYSUTCDATETIME())
  14. created_by                BIGINT NOT NULL (FK)
  15. updated_at                DATETIME2(0) NOT NULL DEFAULT (SYSUTCDATETIME())
  16. updated_by                BIGINT NULL (FK)
  17. row_version               ROWVERSION NOT NULL

VERIFIED FOREIGN KEY & CANDIDATE KEY ARCHITECTURE:
- teachers_schema.teacher defines teacher_id as BIGINT IDENTITY(1,1) CLUSTERED PRIMARY KEY (PK_teacher).
- teacher_id is strictly globally unique across the institution.
- Therefore, attendance uses the clean single-column FK:
  FK_teacher_attendance_teacher (teacher_id) REFERENCES teachers_schema.teacher(teacher_id).
- Composite tenant foreign keys enforce institutional boundary integrity:
  * FK_teacher_attendance_school -> management_schema.school(school_id)
  * FK_teacher_attendance_branch_scope -> management_schema.branch(school_id, branch_id)
  * FK_teacher_attendance_academic_year_scope -> management_schema.academic_year(school_id, academic_year_id)
- Natural uniqueness per day:
  * UQ_teacher_attendance_teacher_date UNIQUE NONCLUSTERED (teacher_id, attendance_date)

LEGACY / OBSOLETE COLUMNS POLICY:
- Obsolete columns (marked_by, corrected_by, break_minutes, is_late, etc.) are NOT dropped
  automatically to prevent accidental data loss. They are preserved on disk, ignored by the ERP,
  and reported separately in the post-deployment verification gate.

SECURITY POLICY:
- ZERO permissions are granted or denied to the 'public' database role.
================================================================================
*/

-- Reset NOEXEC state from any previous session failure
SET NOEXEC OFF;
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

PRINT N'================================================================================';
PRINT N'STARTING MIGRATION 027: Audited Teacher Daily Attendance Table Deployment';
PRINT N'Target: Thinkigen School ERP (teachers_schema.teacher_attendance - 17 Columns)';
PRINT N'Timestamp: ' + CONVERT(NVARCHAR(30), SYSUTCDATETIME(), 126);
PRINT N'================================================================================';
GO

-- =============================================================================
-- STEP 1: READ-ONLY PREFLIGHT VALIDATION & SCHEMA-DRIFT DETECTION
-- Note: Zero DDL statements are executed in this batch.
-- All existing table checks use dynamic SQL with strict column-existence guards.
-- =============================================================================
DECLARE @preflight_failed BIT = 0;
DECLARE @preflight_error_msg NVARCHAR(MAX) = N'';
DECLARE @dyn_sql NVARCHAR(MAX);
DECLARE @dyn_int INT;

-- -----------------------------------------------------------------------------
-- 1.1 Verify Required Schemas Exist
-- -----------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'teachers_schema')
BEGIN
    SET @preflight_failed = 1;
    SET @preflight_error_msg += NCHAR(10) + N'[SCHEMA MISSING] Required schema teachers_schema does not exist.';
END;
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'management_schema')
BEGIN
    SET @preflight_failed = 1;
    SET @preflight_error_msg += NCHAR(10) + N'[SCHEMA MISSING] Required schema management_schema does not exist.';
END;
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'security_schema')
BEGIN
    SET @preflight_failed = 1;
    SET @preflight_error_msg += NCHAR(10) + N'[SCHEMA MISSING] Required schema security_schema does not exist.';
END;

-- -----------------------------------------------------------------------------
-- 1.2 Verify Required Master Parent Tables Exist
-- -----------------------------------------------------------------------------
IF OBJECT_ID(N'management_schema.school', N'U') IS NULL
BEGIN
    SET @preflight_failed = 1;
    SET @preflight_error_msg += NCHAR(10) + N'[TABLE MISSING] Parent table management_schema.school does not exist.';
END;
IF OBJECT_ID(N'management_schema.branch', N'U') IS NULL
BEGIN
    SET @preflight_failed = 1;
    SET @preflight_error_msg += NCHAR(10) + N'[TABLE MISSING] Parent table management_schema.branch does not exist.';
END;
IF OBJECT_ID(N'management_schema.academic_year', N'U') IS NULL
BEGIN
    SET @preflight_failed = 1;
    SET @preflight_error_msg += NCHAR(10) + N'[TABLE MISSING] Parent table management_schema.academic_year does not exist.';
END;
IF OBJECT_ID(N'teachers_schema.teacher', N'U') IS NULL
BEGIN
    SET @preflight_failed = 1;
    SET @preflight_error_msg += NCHAR(10) + N'[TABLE MISSING] Parent table teachers_schema.teacher does not exist.';
END;
IF OBJECT_ID(N'security_schema.users', N'U') IS NULL
BEGIN
    SET @preflight_failed = 1;
    SET @preflight_error_msg += NCHAR(10) + N'[TABLE MISSING] Parent table security_schema.users does not exist.';
END;

-- -----------------------------------------------------------------------------
-- 1.3 Verify Exact Column Existence and Data Types on Parent Tables
-- -----------------------------------------------------------------------------
IF OBJECT_ID(N'management_schema.school', N'U') IS NOT NULL
BEGIN
    IF COL_LENGTH(N'management_schema.school', N'school_id') IS NULL
       OR NOT EXISTS (SELECT 1 FROM sys.columns c JOIN sys.types t ON c.user_type_id = t.user_type_id WHERE c.object_id = OBJECT_ID(N'management_schema.school') AND c.name = N'school_id' AND t.name = N'bigint')
    BEGIN
        SET @preflight_failed = 1;
        SET @preflight_error_msg += NCHAR(10) + N'[COLUMN ERROR] management_schema.school.school_id must exist as BIGINT.';
    END;
END;

IF OBJECT_ID(N'management_schema.branch', N'U') IS NOT NULL
BEGIN
    IF COL_LENGTH(N'management_schema.branch', N'branch_id') IS NULL
       OR NOT EXISTS (SELECT 1 FROM sys.columns c JOIN sys.types t ON c.user_type_id = t.user_type_id WHERE c.object_id = OBJECT_ID(N'management_schema.branch') AND c.name = N'branch_id' AND t.name = N'bigint')
    BEGIN
        SET @preflight_failed = 1;
        SET @preflight_error_msg += NCHAR(10) + N'[COLUMN ERROR] management_schema.branch.branch_id must exist as BIGINT.';
    END;

    IF COL_LENGTH(N'management_schema.branch', N'school_id') IS NULL
       OR NOT EXISTS (SELECT 1 FROM sys.columns c JOIN sys.types t ON c.user_type_id = t.user_type_id WHERE c.object_id = OBJECT_ID(N'management_schema.branch') AND c.name = N'school_id' AND t.name = N'bigint')
    BEGIN
        SET @preflight_failed = 1;
        SET @preflight_error_msg += NCHAR(10) + N'[COLUMN ERROR] management_schema.branch.school_id must exist as BIGINT.';
    END;
END;

IF OBJECT_ID(N'management_schema.academic_year', N'U') IS NOT NULL
BEGIN
    IF COL_LENGTH(N'management_schema.academic_year', N'academic_year_id') IS NULL
       OR NOT EXISTS (SELECT 1 FROM sys.columns c JOIN sys.types t ON c.user_type_id = t.user_type_id WHERE c.object_id = OBJECT_ID(N'management_schema.academic_year') AND c.name = N'academic_year_id' AND t.name = N'bigint')
    BEGIN
        SET @preflight_failed = 1;
        SET @preflight_error_msg += NCHAR(10) + N'[COLUMN ERROR] management_schema.academic_year.academic_year_id must exist as BIGINT.';
    END;

    IF COL_LENGTH(N'management_schema.academic_year', N'school_id') IS NULL
       OR NOT EXISTS (SELECT 1 FROM sys.columns c JOIN sys.types t ON c.user_type_id = t.user_type_id WHERE c.object_id = OBJECT_ID(N'management_schema.academic_year') AND c.name = N'school_id' AND t.name = N'bigint')
    BEGIN
        SET @preflight_failed = 1;
        SET @preflight_error_msg += NCHAR(10) + N'[COLUMN ERROR] management_schema.academic_year.school_id must exist as BIGINT.';
    END;
END;

IF OBJECT_ID(N'teachers_schema.teacher', N'U') IS NOT NULL
BEGIN
    IF COL_LENGTH(N'teachers_schema.teacher', N'teacher_id') IS NULL
       OR NOT EXISTS (SELECT 1 FROM sys.columns c JOIN sys.types t ON c.user_type_id = t.user_type_id WHERE c.object_id = OBJECT_ID(N'teachers_schema.teacher') AND c.name = N'teacher_id' AND t.name = N'bigint')
    BEGIN
        SET @preflight_failed = 1;
        SET @preflight_error_msg += NCHAR(10) + N'[COLUMN ERROR] teachers_schema.teacher.teacher_id must exist as BIGINT.';
    END;
END;

IF OBJECT_ID(N'security_schema.users', N'U') IS NOT NULL
BEGIN
    IF COL_LENGTH(N'security_schema.users', N'user_id') IS NULL
       OR NOT EXISTS (SELECT 1 FROM sys.columns c JOIN sys.types t ON c.user_type_id = t.user_type_id WHERE c.object_id = OBJECT_ID(N'security_schema.users') AND c.name = N'user_id' AND t.name = N'bigint')
    BEGIN
        SET @preflight_failed = 1;
        SET @preflight_error_msg += NCHAR(10) + N'[COLUMN ERROR] security_schema.users.user_id must exist as BIGINT.';
    END;
END;

-- -----------------------------------------------------------------------------
-- 1.4 Validate All Six Foreign Key Targets & Parent Candidate Keys
-- (Migration 027 does NOT alter parent tables; it strictly checks prerequisites)
-- -----------------------------------------------------------------------------

-- Target 1: management_schema.school (school_id)
IF OBJECT_ID(N'management_schema.school', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM sys.indexes i
        WHERE i.object_id = OBJECT_ID(N'management_schema.school')
          AND (i.is_unique = 1 OR i.is_primary_key = 1)
          AND i.is_disabled = 0
          AND i.has_filter = 0
          AND (
              SELECT STRING_AGG(c.name, ',') WITHIN GROUP (ORDER BY ic.key_ordinal)
              FROM sys.index_columns ic
              JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
              WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 0
          ) = 'school_id'
    )
    BEGIN
        SET @preflight_failed = 1;
        SET @preflight_error_msg += NCHAR(10) + N'[PREREQUISITE MISSING] Candidate key on management_schema.school (school_id) is missing or incompatible. Ensure primary key PK_school exists and is enabled.';
    END;
END;

-- Target 2: management_schema.branch (school_id, branch_id)
IF OBJECT_ID(N'management_schema.branch', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM sys.indexes i
        WHERE i.object_id = OBJECT_ID(N'management_schema.branch')
          AND (i.is_unique = 1 OR i.is_primary_key = 1)
          AND i.is_disabled = 0
          AND i.has_filter = 0
          AND (
              SELECT STRING_AGG(c.name, ',') WITHIN GROUP (ORDER BY ic.key_ordinal)
              FROM sys.index_columns ic
              JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
              WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 0
          ) = 'school_id,branch_id'
    )
    BEGIN
        SET @preflight_failed = 1;
        SET @preflight_error_msg += NCHAR(10) + N'[PREREQUISITE MISSING] Required candidate key on management_schema.branch (school_id, branch_id) is missing or incompatible. Ensure prerequisite unique constraint UQ_branch_school_scope is deployed in management_schema.';
    END;
END;

-- Target 3: management_schema.academic_year (school_id, academic_year_id)
IF OBJECT_ID(N'management_schema.academic_year', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM sys.indexes i
        WHERE i.object_id = OBJECT_ID(N'management_schema.academic_year')
          AND (i.is_unique = 1 OR i.is_primary_key = 1)
          AND i.is_disabled = 0
          AND i.has_filter = 0
          AND (
              SELECT STRING_AGG(c.name, ',') WITHIN GROUP (ORDER BY ic.key_ordinal)
              FROM sys.index_columns ic
              JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
              WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 0
          ) = 'school_id,academic_year_id'
    )
    BEGIN
        SET @preflight_failed = 1;
        SET @preflight_error_msg += NCHAR(10) + N'[PREREQUISITE MISSING] Required candidate key on management_schema.academic_year (school_id, academic_year_id) is missing or incompatible. Ensure prerequisite unique constraint UQ_academic_year_school_scope is deployed in management_schema.';
    END;
END;

-- Target 4: teachers_schema.teacher (teacher_id)
IF OBJECT_ID(N'teachers_schema.teacher', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM sys.indexes i
        WHERE i.object_id = OBJECT_ID(N'teachers_schema.teacher')
          AND (i.is_unique = 1 OR i.is_primary_key = 1)
          AND i.is_disabled = 0
          AND i.has_filter = 0
          AND (
              SELECT STRING_AGG(c.name, ',') WITHIN GROUP (ORDER BY ic.key_ordinal)
              FROM sys.index_columns ic
              JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
              WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 0
          ) = 'teacher_id'
    )
    BEGIN
        SET @preflight_failed = 1;
        SET @preflight_error_msg += NCHAR(10) + N'[PREREQUISITE MISSING] Primary key PK_teacher on teachers_schema.teacher (teacher_id) is missing or disabled.';
    END;
END;

-- Target 5 & 6: security_schema.users (user_id) for created_by and updated_by
IF OBJECT_ID(N'security_schema.users', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM sys.indexes i
        WHERE i.object_id = OBJECT_ID(N'security_schema.users')
          AND (i.is_unique = 1 OR i.is_primary_key = 1)
          AND i.is_disabled = 0
          AND i.has_filter = 0
          AND (
              SELECT STRING_AGG(c.name, ',') WITHIN GROUP (ORDER BY ic.key_ordinal)
              FROM sys.index_columns ic
              JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
              WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 0
          ) = 'user_id'
    )
    BEGIN
        SET @preflight_failed = 1;
        SET @preflight_error_msg += NCHAR(10) + N'[PREREQUISITE MISSING] Primary key PK_users on security_schema.users (user_id) is missing or disabled.';
    END;
END;

-- -----------------------------------------------------------------------------
-- 1.5 Inspect Existing Table Structure and Detect Incompatibilities & Anomalies
-- (All column checks and data checks use strict compilation-safe dynamic SQL)
-- -----------------------------------------------------------------------------
IF OBJECT_ID(N'teachers_schema.teacher_attendance', N'U') IS NOT NULL
BEGIN
    -- 1.5.1 Validate Primary Key / Identity Configuration
    IF COL_LENGTH(N'teachers_schema.teacher_attendance', N'teacher_attendance_id') IS NOT NULL
    BEGIN
        IF NOT EXISTS (
            SELECT 1 FROM sys.columns c
            JOIN sys.types t ON c.user_type_id = t.user_type_id
            WHERE c.object_id = OBJECT_ID(N'teachers_schema.teacher_attendance')
              AND c.name = N'teacher_attendance_id'
              AND t.name = N'bigint'
              AND c.is_identity = 1
        )
        BEGIN
            SET @preflight_failed = 1;
            SET @preflight_error_msg += NCHAR(10) + N'[COLUMN INCOMPATIBILITY] Column teacher_attendance_id exists but is not configured as BIGINT IDENTITY(1,1). Manual table recreation required.';
        END;
    END;

    -- 1.5.2 Validate Core Dimension Column Types if Present
    IF COL_LENGTH(N'teachers_schema.teacher_attendance', N'attendance_date') IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM sys.columns c JOIN sys.types t ON c.user_type_id = t.user_type_id WHERE c.object_id = OBJECT_ID(N'teachers_schema.teacher_attendance') AND c.name = N'attendance_date' AND t.name = N'date')
    BEGIN
        SET @preflight_failed = 1;
        SET @preflight_error_msg += NCHAR(10) + N'[COLUMN INCOMPATIBILITY] Column attendance_date exists but is not DATE.';
    END;

    IF COL_LENGTH(N'teachers_schema.teacher_attendance', N'attendance_status') IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM sys.columns c JOIN sys.types t ON c.user_type_id = t.user_type_id WHERE c.object_id = OBJECT_ID(N'teachers_schema.teacher_attendance') AND c.name = N'attendance_status' AND t.name = N'varchar' AND c.max_length = 20)
    BEGIN
        SET @preflight_failed = 1;
        SET @preflight_error_msg += NCHAR(10) + N'[COLUMN INCOMPATIBILITY] Column attendance_status exists but is not VARCHAR(20).';
    END;

    IF COL_LENGTH(N'teachers_schema.teacher_attendance', N'check_in_time') IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM sys.columns c JOIN sys.types t ON c.user_type_id = t.user_type_id WHERE c.object_id = OBJECT_ID(N'teachers_schema.teacher_attendance') AND c.name = N'check_in_time' AND t.name = N'datetime2' AND c.scale = 0)
    BEGIN
        SET @preflight_failed = 1;
        SET @preflight_error_msg += NCHAR(10) + N'[COLUMN INCOMPATIBILITY] Column check_in_time exists but is not DATETIME2(0).';
    END;

    IF COL_LENGTH(N'teachers_schema.teacher_attendance', N'check_out_time') IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM sys.columns c JOIN sys.types t ON c.user_type_id = t.user_type_id WHERE c.object_id = OBJECT_ID(N'teachers_schema.teacher_attendance') AND c.name = N'check_out_time' AND t.name = N'datetime2' AND c.scale = 0)
    BEGIN
        SET @preflight_failed = 1;
        SET @preflight_error_msg += NCHAR(10) + N'[COLUMN INCOMPATIBILITY] Column check_out_time exists but is not DATETIME2(0).';
    END;

    IF COL_LENGTH(N'teachers_schema.teacher_attendance', N'row_version') IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM sys.columns c JOIN sys.types t ON c.system_type_id = t.system_type_id WHERE c.object_id = OBJECT_ID(N'teachers_schema.teacher_attendance') AND c.name = N'row_version' AND t.name = N'timestamp')
    BEGIN
        SET @preflight_failed = 1;
        SET @preflight_error_msg += NCHAR(10) + N'[COLUMN INCOMPATIBILITY] Column row_version exists but is not of type ROWVERSION / timestamp.';
    END;

    -- 1.5.3 Dynamic SQL Data Anomaly Checks (All columns strictly guarded)
    -- Check for duplicate records on (teacher_id, attendance_date)
    IF COL_LENGTH(N'teachers_schema.teacher_attendance', N'teacher_id') IS NOT NULL
       AND COL_LENGTH(N'teachers_schema.teacher_attendance', N'attendance_date') IS NOT NULL
    BEGIN
        SET @dyn_sql = N'SELECT @found = CASE WHEN EXISTS (
            SELECT teacher_id, attendance_date FROM teachers_schema.teacher_attendance GROUP BY teacher_id, attendance_date HAVING COUNT(*) > 1
        ) THEN 1 ELSE 0 END';
        SET @dyn_int = 0;
        EXEC sp_executesql @dyn_sql, N'@found INT OUTPUT', @found = @dyn_int OUTPUT;
        IF @dyn_int = 1
        BEGIN
            SET @preflight_failed = 1;
            SET @preflight_error_msg += NCHAR(10) + N'[DUPLICATE DATA] Duplicate (teacher_id, attendance_date) records exist in teachers_schema.teacher_attendance.';
        END;
    END;

    -- Check for negative or out-of-range total_worked_minutes
    IF COL_LENGTH(N'teachers_schema.teacher_attendance', N'total_worked_minutes') IS NOT NULL
    BEGIN
        SET @dyn_sql = N'SELECT @found = CASE WHEN EXISTS (
            SELECT 1 FROM teachers_schema.teacher_attendance WHERE total_worked_minutes < 0 OR total_worked_minutes > 1440
        ) THEN 1 ELSE 0 END';
        SET @dyn_int = 0;
        EXEC sp_executesql @dyn_sql, N'@found INT OUTPUT', @found = @dyn_int OUTPUT;
        IF @dyn_int = 1
        BEGIN
            SET @preflight_failed = 1;
            SET @preflight_error_msg += NCHAR(10) + N'[DATA ANOMALY] teachers_schema.teacher_attendance contains total_worked_minutes outside allowable range [0, 1440].';
        END;
    END;

    -- Check temporal order: check_out_time earlier than check_in_time
    IF COL_LENGTH(N'teachers_schema.teacher_attendance', N'check_in_time') IS NOT NULL
       AND COL_LENGTH(N'teachers_schema.teacher_attendance', N'check_out_time') IS NOT NULL
    BEGIN
        SET @dyn_sql = N'SELECT @found = CASE WHEN EXISTS (
            SELECT 1 FROM teachers_schema.teacher_attendance WHERE check_in_time IS NOT NULL AND check_out_time IS NOT NULL AND check_out_time < check_in_time
        ) THEN 1 ELSE 0 END';
        SET @dyn_int = 0;
        EXEC sp_executesql @dyn_sql, N'@found INT OUTPUT', @found = @dyn_int OUTPUT;
        IF @dyn_int = 1
        BEGIN
            SET @preflight_failed = 1;
            SET @preflight_error_msg += NCHAR(10) + N'[DATA ANOMALY] teachers_schema.teacher_attendance contains check_out_time earlier than check_in_time.';
        END;

        -- Check for check_out_time populated without check_in_time
        SET @dyn_sql = N'SELECT @found = CASE WHEN EXISTS (
            SELECT 1 FROM teachers_schema.teacher_attendance WHERE check_out_time IS NOT NULL AND check_in_time IS NULL
        ) THEN 1 ELSE 0 END';
        SET @dyn_int = 0;
        EXEC sp_executesql @dyn_sql, N'@found INT OUTPUT', @found = @dyn_int OUTPUT;
        IF @dyn_int = 1
        BEGIN
            SET @preflight_failed = 1;
            SET @preflight_error_msg += NCHAR(10) + N'[DATA ANOMALY] teachers_schema.teacher_attendance contains check_out_time without check_in_time.';
        END;
    END;

    -- Check for check_out_time populated without total_worked_minutes
    IF COL_LENGTH(N'teachers_schema.teacher_attendance', N'check_out_time') IS NOT NULL
       AND COL_LENGTH(N'teachers_schema.teacher_attendance', N'total_worked_minutes') IS NOT NULL
    BEGIN
        SET @dyn_sql = N'SELECT @found = CASE WHEN EXISTS (
            SELECT 1 FROM teachers_schema.teacher_attendance WHERE check_out_time IS NOT NULL AND total_worked_minutes IS NULL
        ) THEN 1 ELSE 0 END';
        SET @dyn_int = 0;
        EXEC sp_executesql @dyn_sql, N'@found INT OUTPUT', @found = @dyn_int OUTPUT;
        IF @dyn_int = 1
        BEGIN
            SET @preflight_failed = 1;
            SET @preflight_error_msg += NCHAR(10) + N'[DATA ANOMALY] teachers_schema.teacher_attendance contains completed check-outs with NULL total_worked_minutes.';
        END;
    END;

    -- Check for unrecognized status values
    IF COL_LENGTH(N'teachers_schema.teacher_attendance', N'attendance_status') IS NOT NULL
    BEGIN
        SET @dyn_sql = N'SELECT @found = CASE WHEN EXISTS (
            SELECT 1 FROM teachers_schema.teacher_attendance WHERE attendance_status NOT IN (''PRESENT'', ''ABSENT'', ''HALF_DAY'', ''ON_LEAVE'', ''WEEKLY_OFF'', ''HOLIDAY'')
        ) THEN 1 ELSE 0 END';
        SET @dyn_int = 0;
        EXEC sp_executesql @dyn_sql, N'@found INT OUTPUT', @found = @dyn_int OUTPUT;
        IF @dyn_int = 1
        BEGIN
            SET @preflight_failed = 1;
            SET @preflight_error_msg += NCHAR(10) + N'[DATA ANOMALY] teachers_schema.teacher_attendance contains unrecognized attendance_status values.';
        END;

        -- Check for PRESENT without check_in_time
        IF COL_LENGTH(N'teachers_schema.teacher_attendance', N'check_in_time') IS NOT NULL
        BEGIN
            SET @dyn_sql = N'SELECT @found = CASE WHEN EXISTS (
                SELECT 1 FROM teachers_schema.teacher_attendance WHERE attendance_status = ''PRESENT'' AND check_in_time IS NULL
            ) THEN 1 ELSE 0 END';
            SET @dyn_int = 0;
            EXEC sp_executesql @dyn_sql, N'@found INT OUTPUT', @found = @dyn_int OUTPUT;
            IF @dyn_int = 1
            BEGIN
                SET @preflight_failed = 1;
                SET @preflight_error_msg += NCHAR(10) + N'[DATA ANOMALY] teachers_schema.teacher_attendance contains PRESENT status records without check_in_time.';
            END;
        END;

        -- Check for timestamps on inactive / absent days (Guards BOTH check_in_time and check_out_time)
        IF COL_LENGTH(N'teachers_schema.teacher_attendance', N'check_in_time') IS NOT NULL
           AND COL_LENGTH(N'teachers_schema.teacher_attendance', N'check_out_time') IS NOT NULL
        BEGIN
            SET @dyn_sql = N'SELECT @found = CASE WHEN EXISTS (
                SELECT 1 FROM teachers_schema.teacher_attendance 
                WHERE attendance_status IN (''ABSENT'', ''ON_LEAVE'', ''WEEKLY_OFF'', ''HOLIDAY'') 
                  AND (check_in_time IS NOT NULL OR check_out_time IS NOT NULL)
            ) THEN 1 ELSE 0 END';
            SET @dyn_int = 0;
            EXEC sp_executesql @dyn_sql, N'@found INT OUTPUT', @found = @dyn_int OUTPUT;
            IF @dyn_int = 1
            BEGIN
                SET @preflight_failed = 1;
                SET @preflight_error_msg += NCHAR(10) + N'[DATA ANOMALY] teachers_schema.teacher_attendance contains inactive/absent status records with check-in or checkout timestamps.';
            END;
        END
        ELSE IF COL_LENGTH(N'teachers_schema.teacher_attendance', N'check_in_time') IS NOT NULL
        BEGIN
            SET @dyn_sql = N'SELECT @found = CASE WHEN EXISTS (
                SELECT 1 FROM teachers_schema.teacher_attendance 
                WHERE attendance_status IN (''ABSENT'', ''ON_LEAVE'', ''WEEKLY_OFF'', ''HOLIDAY'') 
                  AND check_in_time IS NOT NULL
            ) THEN 1 ELSE 0 END';
            SET @dyn_int = 0;
            EXEC sp_executesql @dyn_sql, N'@found INT OUTPUT', @found = @dyn_int OUTPUT;
            IF @dyn_int = 1
            BEGIN
                SET @preflight_failed = 1;
                SET @preflight_error_msg += NCHAR(10) + N'[DATA ANOMALY] teachers_schema.teacher_attendance contains inactive/absent status records with check-in timestamps.';
            END;
        END
        ELSE IF COL_LENGTH(N'teachers_schema.teacher_attendance', N'check_out_time') IS NOT NULL
        BEGIN
            SET @dyn_sql = N'SELECT @found = CASE WHEN EXISTS (
                SELECT 1 FROM teachers_schema.teacher_attendance 
                WHERE attendance_status IN (''ABSENT'', ''ON_LEAVE'', ''WEEKLY_OFF'', ''HOLIDAY'') 
                  AND check_out_time IS NOT NULL
            ) THEN 1 ELSE 0 END';
            SET @dyn_int = 0;
            EXEC sp_executesql @dyn_sql, N'@found INT OUTPUT', @found = @dyn_int OUTPUT;
            IF @dyn_int = 1
            BEGIN
                SET @preflight_failed = 1;
                SET @preflight_error_msg += NCHAR(10) + N'[DATA ANOMALY] teachers_schema.teacher_attendance contains inactive/absent status records with check-out timestamps.';
            END;
        END;

        -- Check for positive worked minutes on ABSENT
        IF COL_LENGTH(N'teachers_schema.teacher_attendance', N'total_worked_minutes') IS NOT NULL
        BEGIN
            SET @dyn_sql = N'SELECT @found = CASE WHEN EXISTS (
                SELECT 1 FROM teachers_schema.teacher_attendance WHERE attendance_status = ''ABSENT'' AND total_worked_minutes > 0
            ) THEN 1 ELSE 0 END';
            SET @dyn_int = 0;
            EXEC sp_executesql @dyn_sql, N'@found INT OUTPUT', @found = @dyn_int OUTPUT;
            IF @dyn_int = 1
            BEGIN
                SET @preflight_failed = 1;
                SET @preflight_error_msg += NCHAR(10) + N'[DATA ANOMALY] teachers_schema.teacher_attendance contains ABSENT records with positive worked minutes.';
            END;
        END;
    END;

    -- 1.5.4 Audit Identity Verification (Zero Guessing / Zero Derivation)
    IF COL_LENGTH(N'teachers_schema.teacher_attendance', N'created_by') IS NULL
    BEGIN
        SET @dyn_sql = N'SELECT @cnt = COUNT(*) FROM teachers_schema.teacher_attendance';
        SET @dyn_int = 0;
        EXEC sp_executesql @dyn_sql, N'@cnt INT OUTPUT', @cnt = @dyn_int OUTPUT;

        IF @dyn_int > 0
        BEGIN
            SET @preflight_failed = 1;
            SET @preflight_error_msg += NCHAR(10) + N'[AUDIT RECONCILIATION REQUIRED] teachers_schema.teacher_attendance contains ' 
                + CAST(@dyn_int AS NVARCHAR(10)) 
                + N' existing row(s) but lacks the required created_by column. Audit identities cannot be fabricated or derived from removed columns. Perform manual data reconciliation before running Migration 027.';
        END;
    END
    ELSE
    BEGIN
        SET @dyn_sql = N'SELECT @found = CASE WHEN EXISTS (SELECT 1 FROM teachers_schema.teacher_attendance WHERE created_by IS NULL) THEN 1 ELSE 0 END';
        SET @dyn_int = 0;
        EXEC sp_executesql @dyn_sql, N'@found INT OUTPUT', @found = @dyn_int OUTPUT;
        IF @dyn_int = 1
        BEGIN
            SET @preflight_failed = 1;
            SET @preflight_error_msg += NCHAR(10) + N'[DATA ANOMALY] teachers_schema.teacher_attendance contains records where created_by is NULL.';
        END;
    END;

    -- 1.5.5 Check Definition of Existing Unique Constraint If Present
    -- (Fail safely with clear remediation rather than unsafe automatic drop)
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UQ_teacher_attendance_teacher_date' AND object_id = OBJECT_ID(N'teachers_schema.teacher_attendance'))
    BEGIN
        IF NOT EXISTS (
            SELECT 1 FROM sys.indexes i
            WHERE i.object_id = OBJECT_ID(N'teachers_schema.teacher_attendance')
              AND i.name = N'UQ_teacher_attendance_teacher_date'
              AND i.is_unique = 1 AND i.has_filter = 0 AND i.is_disabled = 0
              AND (
                  SELECT STRING_AGG(c.name, ',') WITHIN GROUP (ORDER BY ic.key_ordinal)
                  FROM sys.index_columns ic
                  JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
                  WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 0
              ) = 'teacher_id,attendance_date'
        )
        BEGIN
            SET @preflight_failed = 1;
            SET @preflight_error_msg += NCHAR(10) + N'[INCOMPATIBLE CONSTRAINT] Constraint UQ_teacher_attendance_teacher_date exists with an incompatible definition. Automatic replacement is disabled to prevent accidental data loss. Remediation: Inspect and manually drop or rename the conflicting constraint before running Migration 027.';
        END;
    END;

    -- 1.5.6 Check Definition of Existing Reporting Indexes If Present
    -- Index 1: IX_teacher_attendance_branch_daily
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_teacher_attendance_branch_daily' AND object_id = OBJECT_ID(N'teachers_schema.teacher_attendance'))
    BEGIN
        IF NOT EXISTS (
            SELECT 1 FROM sys.indexes i
            WHERE i.object_id = OBJECT_ID(N'teachers_schema.teacher_attendance')
              AND i.name = N'IX_teacher_attendance_branch_daily'
              AND i.is_unique = 0 AND i.has_filter = 0 AND i.is_disabled = 0
              AND (
                  SELECT STRING_AGG(c.name, ',') WITHIN GROUP (ORDER BY ic.key_ordinal)
                  FROM sys.index_columns ic
                  JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
                  WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 0
              ) = 'school_id,branch_id,attendance_date,attendance_status'
              AND (
                  SELECT STRING_AGG(c.name, ',') WITHIN GROUP (ORDER BY ic.index_column_id)
                  FROM sys.index_columns ic
                  JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
                  WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 1
              ) = 'teacher_id,check_in_time,check_out_time,total_worked_minutes'
        )
        BEGIN
            SET @preflight_failed = 1;
            SET @preflight_error_msg += NCHAR(10) + N'[INCOMPATIBLE INDEX] Index IX_teacher_attendance_branch_daily exists with an incompatible definition. Remediation: Manually inspect and drop or rename the index before re-running.';
        END;
    END;

    -- Index 2: IX_teacher_attendance_teacher_history
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_teacher_attendance_teacher_history' AND object_id = OBJECT_ID(N'teachers_schema.teacher_attendance'))
    BEGIN
        IF NOT EXISTS (
            SELECT 1 FROM sys.indexes i
            WHERE i.object_id = OBJECT_ID(N'teachers_schema.teacher_attendance')
              AND i.name = N'IX_teacher_attendance_teacher_history'
              AND i.is_unique = 0 AND i.has_filter = 0 AND i.is_disabled = 0
              AND (
                  SELECT STRING_AGG(c.name + CASE WHEN ic.is_descending_key = 1 THEN ' DESC' ELSE ' ASC' END, ',') WITHIN GROUP (ORDER BY ic.key_ordinal)
                  FROM sys.index_columns ic
                  JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
                  WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 0
              ) = 'teacher_id ASC,attendance_date DESC'
              AND (
                  SELECT STRING_AGG(c.name, ',') WITHIN GROUP (ORDER BY ic.index_column_id)
                  FROM sys.index_columns ic
                  JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
                  WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 1
              ) = 'attendance_status,check_in_time,check_out_time,total_worked_minutes'
        )
        BEGIN
            SET @preflight_failed = 1;
            SET @preflight_error_msg += NCHAR(10) + N'[INCOMPATIBLE INDEX] Index IX_teacher_attendance_teacher_history exists with an incompatible definition. Remediation: Manually inspect and drop or rename the index before re-running.';
        END;
    END;

    -- 1.5.7 Informational check: Report legacy/obsolete columns if present
    DECLARE @obsolete_cols NVARCHAR(MAX) = N'';
    SELECT @obsolete_cols += c.name + N', '
    FROM sys.columns c
    WHERE c.object_id = OBJECT_ID(N'teachers_schema.teacher_attendance')
      AND c.name IN (
          N'effective_worked_minutes', N'leave_application_id', N'marked_by',
          N'is_late', N'late_by_minutes', N'is_early_departure', N'early_by_minutes',
          N'break_minutes', N'is_corrected', N'correction_reason', N'corrected_by',
          N'corrected_at', N'shift_policy_id', N'check_in_source', N'check_out_source',
          N'total_worked_hours', N'total_break_minutes', N'is_late_arrival',
          N'late_arrival_minutes', N'early_departure_minutes', N'is_half_day'
      );

    IF LEN(@obsolete_cols) > 0
    BEGIN
        SET @obsolete_cols = LEFT(@obsolete_cols, LEN(@obsolete_cols) - 1);
        PRINT N'[NOTICE] Preserved legacy columns detected on existing table: ' + @obsolete_cols + N'. (Non-destructive policy: these will not be deleted).';
    END;
END;

-- -----------------------------------------------------------------------------
-- 1.6 Halt Migration If Preflight Validation Failed
-- -----------------------------------------------------------------------------
IF @preflight_failed = 1
BEGIN
    PRINT N'';
    PRINT N'********************************************************************************';
    PRINT N'PREFLIGHT CHECK FAILED. Deployment halted to protect database integrity.';
    PRINT @preflight_error_msg;
    PRINT N'';
    PRINT N'RECOVERY INSTRUCTIONS FOR SSMS / AZURE DATA STUDIO:';
    PRINT N'1. Review and resolve the prerequisite failures or data anomalies listed above.';
    PRINT N'2. Session has been placed in NOEXEC mode to prevent execution of subsequent steps.';
    PRINT N'3. To reset your session, execute: SET NOEXEC OFF;';
    PRINT N'4. Re-run this migration after prerequisites are satisfied.';
    PRINT N'********************************************************************************';
    SET NOEXEC ON;
    RAISERROR(N'Preflight validation failed. Aborting deployment.', 16, 1);
END
ELSE
BEGIN
    PRINT N'Preflight check PASSED. All 6 foreign key targets and environment preconditions met.';
END;
GO

-- =============================================================================
-- STEP 2: TRANSACTIONAL DDL & OBJECT RECONCILIATION
-- Note: Exactly one table is managed (teachers_schema.teacher_attendance).
-- Zero modifications are performed on parent master tables.
-- =============================================================================
BEGIN TRY
    BEGIN TRANSACTION;

    -- -------------------------------------------------------------------------
    -- 2.1 CLEAN UP RETIRED CONSTRAINTS & RETIRED INDEXES ON EXISTING TABLE
    -- -------------------------------------------------------------------------
    IF OBJECT_ID(N'teachers_schema.teacher_attendance', N'U') IS NOT NULL
    BEGIN
        -- Drop retired reporting indexes if present
        IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_teacher_attendance_late_reporting' AND object_id = OBJECT_ID(N'teachers_schema.teacher_attendance'))
        BEGIN
            PRINT N'Dropping retired index IX_teacher_attendance_late_reporting...';
            DROP INDEX IX_teacher_attendance_late_reporting ON teachers_schema.teacher_attendance;
        END;

        IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_teacher_attendance_leave_reconciliation' AND object_id = OBJECT_ID(N'teachers_schema.teacher_attendance'))
        BEGIN
            PRINT N'Dropping retired index IX_teacher_attendance_leave_reconciliation...';
            DROP INDEX IX_teacher_attendance_leave_reconciliation ON teachers_schema.teacher_attendance;
        END;

        -- Drop retired foreign keys if present
        IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_teacher_attendance_leave_scope' AND parent_object_id = OBJECT_ID(N'teachers_schema.teacher_attendance'))
        BEGIN
            PRINT N'Dropping retired foreign key FK_teacher_attendance_leave_scope...';
            ALTER TABLE teachers_schema.teacher_attendance DROP CONSTRAINT FK_teacher_attendance_leave_scope;
        END;

        IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_teacher_attendance_marked_by' AND parent_object_id = OBJECT_ID(N'teachers_schema.teacher_attendance'))
        BEGIN
            PRINT N'Dropping retired foreign key FK_teacher_attendance_marked_by...';
            ALTER TABLE teachers_schema.teacher_attendance DROP CONSTRAINT FK_teacher_attendance_marked_by;
        END;

        IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_teacher_attendance_corrected_by' AND parent_object_id = OBJECT_ID(N'teachers_schema.teacher_attendance'))
        BEGIN
            PRINT N'Dropping retired foreign key FK_teacher_attendance_corrected_by...';
            ALTER TABLE teachers_schema.teacher_attendance DROP CONSTRAINT FK_teacher_attendance_corrected_by;
        END;

        IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_teacher_attendance_shift_policy' AND parent_object_id = OBJECT_ID(N'teachers_schema.teacher_attendance'))
        BEGIN
            PRINT N'Dropping retired foreign key FK_teacher_attendance_shift_policy...';
            ALTER TABLE teachers_schema.teacher_attendance DROP CONSTRAINT FK_teacher_attendance_shift_policy;
        END;

        -- Drop legacy composite teacher FK if present (replaced by clean single-column FK)
        IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_teacher_attendance_teacher_scope' AND parent_object_id = OBJECT_ID(N'teachers_schema.teacher_attendance'))
        BEGIN
            PRINT N'Dropping legacy composite teacher foreign key FK_teacher_attendance_teacher_scope...';
            ALTER TABLE teachers_schema.teacher_attendance DROP CONSTRAINT FK_teacher_attendance_teacher_scope;
        END;

        -- Drop retired check constraints if present
        IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_teacher_attendance_late_consistency' AND parent_object_id = OBJECT_ID(N'teachers_schema.teacher_attendance'))
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance DROP CONSTRAINT CK_teacher_attendance_late_consistency;
        END;

        IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_teacher_attendance_early_consistency' AND parent_object_id = OBJECT_ID(N'teachers_schema.teacher_attendance'))
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance DROP CONSTRAINT CK_teacher_attendance_early_consistency;
        END;

        IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_teacher_attendance_correction_audit' AND parent_object_id = OBJECT_ID(N'teachers_schema.teacher_attendance'))
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance DROP CONSTRAINT CK_teacher_attendance_correction_audit;
        END;

        IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_teacher_attendance_durations' AND parent_object_id = OBJECT_ID(N'teachers_schema.teacher_attendance'))
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance DROP CONSTRAINT CK_teacher_attendance_durations;
        END;

        IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_teacher_attendance_check_in_pair' AND parent_object_id = OBJECT_ID(N'teachers_schema.teacher_attendance'))
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance DROP CONSTRAINT CK_teacher_attendance_check_in_pair;
        END;

        IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_teacher_attendance_check_out_pair' AND parent_object_id = OBJECT_ID(N'teachers_schema.teacher_attendance'))
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance DROP CONSTRAINT CK_teacher_attendance_check_out_pair;
        END;

        IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_teacher_attendance_check_in_source' AND parent_object_id = OBJECT_ID(N'teachers_schema.teacher_attendance'))
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance DROP CONSTRAINT CK_teacher_attendance_check_in_source;
        END;

        IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_teacher_attendance_check_out_source' AND parent_object_id = OBJECT_ID(N'teachers_schema.teacher_attendance'))
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance DROP CONSTRAINT CK_teacher_attendance_check_out_source;
        END;

        IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_teacher_attendance_absent_no_worked_minutes' AND parent_object_id = OBJECT_ID(N'teachers_schema.teacher_attendance'))
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance DROP CONSTRAINT CK_teacher_attendance_absent_no_worked_minutes;
        END;
    END;

    -- -------------------------------------------------------------------------
    -- 2.2 CREATE TABLE OR RECONCILE EXACT 17 REQUIRED COLUMNS
    -- -------------------------------------------------------------------------
    IF OBJECT_ID(N'teachers_schema.teacher_attendance', N'U') IS NULL
    BEGIN
        PRINT N'Creating table teachers_schema.teacher_attendance with exact 17 columns...';
        CREATE TABLE teachers_schema.teacher_attendance
        (
            -- 1. Primary Key
            teacher_attendance_id       BIGINT          NOT NULL IDENTITY(1, 1),

            -- 2-5. Tenant Scope & Teacher Identifier
            school_id                   BIGINT          NOT NULL,
            branch_id                   BIGINT          NOT NULL,
            academic_year_id            BIGINT          NOT NULL,
            teacher_id                  BIGINT          NOT NULL,

            -- 6-7. Attendance Date and Status
            attendance_date             DATE            NOT NULL,
            attendance_status           VARCHAR(20)     NOT NULL,

            -- 8-9. Check-In & Check-Out Timestamps
            check_in_time               DATETIME2(0)    NULL,
            check_out_time              DATETIME2(0)    NULL,

            -- 10. Working Duration (Managed by FastAPI backend)
            total_worked_minutes        INT             NULL,

            -- 11. Operational Remarks
            remarks                     NVARCHAR(500)   NULL,

            -- 12-16. Standard Audit Columns
            is_active                   BIT             NOT NULL CONSTRAINT DF_teacher_attendance_is_active DEFAULT (1),
            created_at                  DATETIME2(0)    NOT NULL CONSTRAINT DF_teacher_attendance_created_at DEFAULT (SYSUTCDATETIME()),
            created_by                  BIGINT          NOT NULL,
            updated_at                  DATETIME2(0)    NOT NULL CONSTRAINT DF_teacher_attendance_updated_at DEFAULT (SYSUTCDATETIME()),
            updated_by                  BIGINT          NULL,

            -- 17. Concurrency Token
            row_version                 ROWVERSION      NOT NULL,

            -- Primary Key & Natural Unique Constraint
            CONSTRAINT PK_teacher_attendance PRIMARY KEY CLUSTERED (teacher_attendance_id),
            CONSTRAINT UQ_teacher_attendance_teacher_date UNIQUE NONCLUSTERED (teacher_id, attendance_date),

            -- 7 Core CHECK Constraints
            CONSTRAINT CK_teacher_attendance_status CHECK
                (attendance_status IN ('PRESENT', 'ABSENT', 'HALF_DAY', 'ON_LEAVE', 'WEEKLY_OFF', 'HOLIDAY')),

            CONSTRAINT CK_teacher_attendance_checkout_requires_checkin CHECK
                (check_out_time IS NULL OR check_in_time IS NOT NULL),

            CONSTRAINT CK_teacher_attendance_time_order CHECK
                (check_out_time IS NULL OR check_in_time IS NULL OR check_out_time >= check_in_time),

            CONSTRAINT CK_teacher_attendance_worked_minutes CHECK
                (total_worked_minutes IS NULL OR (total_worked_minutes >= 0 AND total_worked_minutes <= 1440)),

            CONSTRAINT CK_teacher_attendance_checkout_requires_duration CHECK
                (check_out_time IS NULL OR total_worked_minutes IS NOT NULL),

            CONSTRAINT CK_teacher_attendance_present_requires_checkin CHECK
                (attendance_status <> 'PRESENT' OR check_in_time IS NOT NULL),

            CONSTRAINT CK_teacher_attendance_inactive_no_timestamps CHECK
                (attendance_status NOT IN ('ABSENT', 'ON_LEAVE', 'WEEKLY_OFF', 'HOLIDAY') OR (check_in_time IS NULL AND check_out_time IS NULL)),

            -- Exactly 6 Foreign Keys
            CONSTRAINT FK_teacher_attendance_school FOREIGN KEY (school_id)
                REFERENCES management_schema.school (school_id) ON DELETE NO ACTION,

            CONSTRAINT FK_teacher_attendance_branch_scope FOREIGN KEY (school_id, branch_id)
                REFERENCES management_schema.branch (school_id, branch_id) ON DELETE NO ACTION,

            CONSTRAINT FK_teacher_attendance_academic_year_scope FOREIGN KEY (school_id, academic_year_id)
                REFERENCES management_schema.academic_year (school_id, academic_year_id) ON DELETE NO ACTION,

            CONSTRAINT FK_teacher_attendance_teacher FOREIGN KEY (teacher_id)
                REFERENCES teachers_schema.teacher (teacher_id) ON DELETE NO ACTION,

            CONSTRAINT FK_teacher_attendance_created_by FOREIGN KEY (created_by)
                REFERENCES security_schema.users (user_id) ON DELETE NO ACTION,

            CONSTRAINT FK_teacher_attendance_updated_by FOREIGN KEY (updated_by)
                REFERENCES security_schema.users (user_id) ON DELETE NO ACTION
        );
    END
    ELSE
    BEGIN
        PRINT N'Reconciling existing table teachers_schema.teacher_attendance...';

        -- Safe column additions for core 17 columns if missing
        IF COL_LENGTH(N'teachers_schema.teacher_attendance', N'total_worked_minutes') IS NULL
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance ADD total_worked_minutes INT NULL;
        END;

        IF COL_LENGTH(N'teachers_schema.teacher_attendance', N'remarks') IS NULL
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance ADD remarks NVARCHAR(500) NULL;
        END;

        IF COL_LENGTH(N'teachers_schema.teacher_attendance', N'is_active') IS NULL
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance
                ADD is_active BIT NOT NULL CONSTRAINT DF_teacher_attendance_is_active DEFAULT (1);
        END;

        IF COL_LENGTH(N'teachers_schema.teacher_attendance', N'created_at') IS NULL
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance
                ADD created_at DATETIME2(0) NOT NULL CONSTRAINT DF_teacher_attendance_created_at DEFAULT (SYSUTCDATETIME());
        END;

        IF COL_LENGTH(N'teachers_schema.teacher_attendance', N'created_by') IS NULL
        BEGIN
            -- Table was verified empty in preflight if created_by was missing
            ALTER TABLE teachers_schema.teacher_attendance ADD created_by BIGINT NOT NULL;
        END;

        IF COL_LENGTH(N'teachers_schema.teacher_attendance', N'updated_at') IS NULL
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance
                ADD updated_at DATETIME2(0) NOT NULL CONSTRAINT DF_teacher_attendance_updated_at DEFAULT (SYSUTCDATETIME());
        END;

        IF COL_LENGTH(N'teachers_schema.teacher_attendance', N'updated_by') IS NULL
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance ADD updated_by BIGINT NULL;
        END;

        IF COL_LENGTH(N'teachers_schema.teacher_attendance', N'row_version') IS NULL
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance ADD row_version ROWVERSION NOT NULL;
        END;

        -- Ensure Defaults Exist
        IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE parent_object_id = OBJECT_ID(N'teachers_schema.teacher_attendance') AND name = N'DF_teacher_attendance_is_active')
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance ADD CONSTRAINT DF_teacher_attendance_is_active DEFAULT (1) FOR is_active;
        END;

        IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE parent_object_id = OBJECT_ID(N'teachers_schema.teacher_attendance') AND name = N'DF_teacher_attendance_created_at')
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance ADD CONSTRAINT DF_teacher_attendance_created_at DEFAULT (SYSUTCDATETIME()) FOR created_at;
        END;

        IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE parent_object_id = OBJECT_ID(N'teachers_schema.teacher_attendance') AND name = N'DF_teacher_attendance_updated_at')
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance ADD CONSTRAINT DF_teacher_attendance_updated_at DEFAULT (SYSUTCDATETIME()) FOR updated_at;
        END;

        -- Reconcile Primary Key
        IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'teachers_schema.teacher_attendance') AND is_primary_key = 1)
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance
                ADD CONSTRAINT PK_teacher_attendance PRIMARY KEY CLUSTERED (teacher_attendance_id);
        END;

        -- Reconcile Unique Constraint: (teacher_id, attendance_date)
        -- (If it exists, preflight verified its definition; if not, create it)
        IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UQ_teacher_attendance_teacher_date' AND object_id = OBJECT_ID(N'teachers_schema.teacher_attendance'))
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance
                ADD CONSTRAINT UQ_teacher_attendance_teacher_date UNIQUE NONCLUSTERED (teacher_id, attendance_date);
        END;

        -- Reconcile All 7 Core Check Constraints (Idempotent Add + WITH CHECK Validation)
        IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_teacher_attendance_status' AND parent_object_id = OBJECT_ID(N'teachers_schema.teacher_attendance'))
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance WITH CHECK
                ADD CONSTRAINT CK_teacher_attendance_status CHECK
                    (attendance_status IN ('PRESENT', 'ABSENT', 'HALF_DAY', 'ON_LEAVE', 'WEEKLY_OFF', 'HOLIDAY'));
        END
        ELSE
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance WITH CHECK CHECK CONSTRAINT CK_teacher_attendance_status;
        END;

        IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_teacher_attendance_checkout_requires_checkin' AND parent_object_id = OBJECT_ID(N'teachers_schema.teacher_attendance'))
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance WITH CHECK
                ADD CONSTRAINT CK_teacher_attendance_checkout_requires_checkin CHECK
                    (check_out_time IS NULL OR check_in_time IS NOT NULL);
        END
        ELSE
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance WITH CHECK CHECK CONSTRAINT CK_teacher_attendance_checkout_requires_checkin;
        END;

        IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_teacher_attendance_time_order' AND parent_object_id = OBJECT_ID(N'teachers_schema.teacher_attendance'))
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance WITH CHECK
                ADD CONSTRAINT CK_teacher_attendance_time_order CHECK
                    (check_out_time IS NULL OR check_in_time IS NULL OR check_out_time >= check_in_time);
        END
        ELSE
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance WITH CHECK CHECK CONSTRAINT CK_teacher_attendance_time_order;
        END;

        IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_teacher_attendance_worked_minutes' AND parent_object_id = OBJECT_ID(N'teachers_schema.teacher_attendance'))
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance WITH CHECK
                ADD CONSTRAINT CK_teacher_attendance_worked_minutes CHECK
                    (total_worked_minutes IS NULL OR (total_worked_minutes >= 0 AND total_worked_minutes <= 1440));
        END
        ELSE
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance WITH CHECK CHECK CONSTRAINT CK_teacher_attendance_worked_minutes;
        END;

        IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_teacher_attendance_checkout_requires_duration' AND parent_object_id = OBJECT_ID(N'teachers_schema.teacher_attendance'))
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance WITH CHECK
                ADD CONSTRAINT CK_teacher_attendance_checkout_requires_duration CHECK
                    (check_out_time IS NULL OR total_worked_minutes IS NOT NULL);
        END
        ELSE
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance WITH CHECK CHECK CONSTRAINT CK_teacher_attendance_checkout_requires_duration;
        END;

        IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_teacher_attendance_present_requires_checkin' AND parent_object_id = OBJECT_ID(N'teachers_schema.teacher_attendance'))
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance WITH CHECK
                ADD CONSTRAINT CK_teacher_attendance_present_requires_checkin CHECK
                    (attendance_status <> 'PRESENT' OR check_in_time IS NOT NULL);
        END
        ELSE
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance WITH CHECK CHECK CONSTRAINT CK_teacher_attendance_present_requires_checkin;
        END;

        IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_teacher_attendance_inactive_no_timestamps' AND parent_object_id = OBJECT_ID(N'teachers_schema.teacher_attendance'))
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance WITH CHECK
                ADD CONSTRAINT CK_teacher_attendance_inactive_no_timestamps CHECK
                    (attendance_status NOT IN ('ABSENT', 'ON_LEAVE', 'WEEKLY_OFF', 'HOLIDAY') OR (check_in_time IS NULL AND check_out_time IS NULL));
        END
        ELSE
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance WITH CHECK CHECK CONSTRAINT CK_teacher_attendance_inactive_no_timestamps;
        END;

        -- Reconcile Exactly 6 Required Foreign Keys
        -- 1. FK_teacher_attendance_school
        IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_teacher_attendance_school' AND parent_object_id = OBJECT_ID(N'teachers_schema.teacher_attendance'))
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance WITH CHECK
                ADD CONSTRAINT FK_teacher_attendance_school FOREIGN KEY (school_id)
                    REFERENCES management_schema.school (school_id) ON DELETE NO ACTION;
        END
        ELSE
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance WITH CHECK CHECK CONSTRAINT FK_teacher_attendance_school;
        END;

        -- 2. FK_teacher_attendance_branch_scope
        IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_teacher_attendance_branch_scope' AND parent_object_id = OBJECT_ID(N'teachers_schema.teacher_attendance'))
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance WITH CHECK
                ADD CONSTRAINT FK_teacher_attendance_branch_scope FOREIGN KEY (school_id, branch_id)
                    REFERENCES management_schema.branch (school_id, branch_id) ON DELETE NO ACTION;
        END
        ELSE
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance WITH CHECK CHECK CONSTRAINT FK_teacher_attendance_branch_scope;
        END;

        -- 3. FK_teacher_attendance_academic_year_scope
        IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_teacher_attendance_academic_year_scope' AND parent_object_id = OBJECT_ID(N'teachers_schema.teacher_attendance'))
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance WITH CHECK
                ADD CONSTRAINT FK_teacher_attendance_academic_year_scope FOREIGN KEY (school_id, academic_year_id)
                    REFERENCES management_schema.academic_year (school_id, academic_year_id) ON DELETE NO ACTION;
        END
        ELSE
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance WITH CHECK CHECK CONSTRAINT FK_teacher_attendance_academic_year_scope;
        END;

        -- 4. FK_teacher_attendance_teacher (Single-Column FK)
        IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_teacher_attendance_teacher' AND parent_object_id = OBJECT_ID(N'teachers_schema.teacher_attendance'))
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance WITH CHECK
                ADD CONSTRAINT FK_teacher_attendance_teacher FOREIGN KEY (teacher_id)
                    REFERENCES teachers_schema.teacher (teacher_id) ON DELETE NO ACTION;
        END
        ELSE
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance WITH CHECK CHECK CONSTRAINT FK_teacher_attendance_teacher;
        END;

        -- 5. FK_teacher_attendance_created_by
        IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_teacher_attendance_created_by' AND parent_object_id = OBJECT_ID(N'teachers_schema.teacher_attendance'))
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance WITH CHECK
                ADD CONSTRAINT FK_teacher_attendance_created_by FOREIGN KEY (created_by)
                    REFERENCES security_schema.users (user_id) ON DELETE NO ACTION;
        END
        ELSE
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance WITH CHECK CHECK CONSTRAINT FK_teacher_attendance_created_by;
        END;

        -- 6. FK_teacher_attendance_updated_by
        IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_teacher_attendance_updated_by' AND parent_object_id = OBJECT_ID(N'teachers_schema.teacher_attendance'))
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance WITH CHECK
                ADD CONSTRAINT FK_teacher_attendance_updated_by FOREIGN KEY (updated_by)
                    REFERENCES security_schema.users (user_id) ON DELETE NO ACTION;
        END
        ELSE
        BEGIN
            ALTER TABLE teachers_schema.teacher_attendance WITH CHECK CHECK CONSTRAINT FK_teacher_attendance_updated_by;
        END;
    END;

    -- -------------------------------------------------------------------------
    -- 2.3 REPORTING INDEXES (Branch Daily & Teacher History)
    -- (Idempotent creation; preflight already verified definition compatibility)
    -- -------------------------------------------------------------------------

    -- 1. Branch Daily Attendance Dashboard Index
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_teacher_attendance_branch_daily' AND object_id = OBJECT_ID(N'teachers_schema.teacher_attendance'))
    BEGIN
        PRINT N'Creating nonclustered index IX_teacher_attendance_branch_daily...';
        CREATE NONCLUSTERED INDEX IX_teacher_attendance_branch_daily
            ON teachers_schema.teacher_attendance (school_id, branch_id, attendance_date, attendance_status)
            INCLUDE (teacher_id, check_in_time, check_out_time, total_worked_minutes);
    END
    ELSE
    BEGIN
        PRINT N'Index IX_teacher_attendance_branch_daily already exists and verified. Skipping creation.';
    END;

    -- 2. Teacher Attendance History & Monthly Ledger Index
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_teacher_attendance_teacher_history' AND object_id = OBJECT_ID(N'teachers_schema.teacher_attendance'))
    BEGIN
        PRINT N'Creating nonclustered index IX_teacher_attendance_teacher_history...';
        CREATE NONCLUSTERED INDEX IX_teacher_attendance_teacher_history
            ON teachers_schema.teacher_attendance (teacher_id, attendance_date DESC)
            INCLUDE (attendance_status, check_in_time, check_out_time, total_worked_minutes);
    END
    ELSE
    BEGIN
        PRINT N'Index IX_teacher_attendance_teacher_history already exists and verified. Skipping creation.';
    END;

    -- -------------------------------------------------------------------------
    -- 2.4 SECURITY POLICY DOCUMENTATION
    -- Least-Privilege Role-Based Assignment:
    -- - ZERO permissions are granted to the 'public' database role.
    -- - Apply application role permissions via deployment administrator runbook:
    --
    --   GRANT SELECT, INSERT, UPDATE ON teachers_schema.teacher_attendance TO [<Thinkigen_App_Role>];
    --   DENY DELETE ON teachers_schema.teacher_attendance TO [<Thinkigen_App_Role>];
    -- -------------------------------------------------------------------------

    -- -------------------------------------------------------------------------
    -- 2.5 POST-DEPLOYMENT VERIFICATION GATE
    -- (The deployment transaction commits ONLY after all objects are strictly validated)
    -- -------------------------------------------------------------------------
    DECLARE @verification_failed BIT = 0;
    DECLARE @verification_error NVARCHAR(MAX) = N'';

    -- 1. Verify Table Exists
    IF OBJECT_ID(N'teachers_schema.teacher_attendance', N'U') IS NULL
    BEGIN
        SET @verification_failed = 1;
        SET @verification_error += NCHAR(10) + N'[VERIFICATION ERROR] Table teachers_schema.teacher_attendance does not exist.';
    END;

    -- 2. Verify all 17 required columns exist with exact data type, scale, precision, and nullability
    DECLARE @req_cols TABLE (
        col_name NVARCHAR(100),
        expected_type NVARCHAR(50),
        expected_nullable BIT,
        expected_max_len SMALLINT,
        expected_scale TINYINT,
        expected_identity BIT
    );
    INSERT INTO @req_cols VALUES
        ('teacher_attendance_id', 'bigint',    0, 8,    0, 1),
        ('school_id',             'bigint',    0, 8,    0, 0),
        ('branch_id',             'bigint',    0, 8,    0, 0),
        ('academic_year_id',      'bigint',    0, 8,    0, 0),
        ('teacher_id',            'bigint',    0, 8,    0, 0),
        ('attendance_date',       'date',      0, 3,    0, 0),
        ('attendance_status',     'varchar',   0, 20,   0, 0),
        ('check_in_time',         'datetime2', 1, 6,    0, 0),
        ('check_out_time',        'datetime2', 1, 6,    0, 0),
        ('total_worked_minutes',  'int',       1, 4,    0, 0),
        ('remarks',               'nvarchar',  1, 1000, 0, 0),
        ('is_active',             'bit',       0, 1,    0, 0),
        ('created_at',            'datetime2', 0, 6,    0, 0),
        ('created_by',            'bigint',    0, 8,    0, 0),
        ('updated_at',            'datetime2', 0, 6,    0, 0),
        ('updated_by',            'bigint',    1, 8,    0, 0),
        ('row_version',           'timestamp', 0, 8,    0, 0);

    IF EXISTS (
        SELECT 1 FROM @req_cols rc
        LEFT JOIN sys.columns c ON c.object_id = OBJECT_ID(N'teachers_schema.teacher_attendance') AND c.name = rc.col_name
        LEFT JOIN sys.types t ON c.user_type_id = t.user_type_id
        WHERE c.column_id IS NULL
           OR t.name <> rc.expected_type
           OR c.is_nullable <> rc.expected_nullable
           OR c.max_length <> rc.expected_max_len
           OR (rc.expected_type = 'datetime2' AND c.scale <> rc.expected_scale)
           OR c.is_identity <> rc.expected_identity
    )
    BEGIN
        SET @verification_failed = 1;
        SET @verification_error += NCHAR(10) + N'[VERIFICATION ERROR] Column specification mismatch on one or more of the 17 core columns.';
    END;

    -- 3. Verify Required Defaults Exist
    IF NOT EXISTS (
        SELECT 1 FROM sys.default_constraints
        WHERE parent_object_id = OBJECT_ID(N'teachers_schema.teacher_attendance')
          AND parent_column_id = COLUMNPROPERTY(OBJECT_ID(N'teachers_schema.teacher_attendance'), N'is_active', N'ColumnId')
    ) OR NOT EXISTS (
        SELECT 1 FROM sys.default_constraints
        WHERE parent_object_id = OBJECT_ID(N'teachers_schema.teacher_attendance')
          AND parent_column_id = COLUMNPROPERTY(OBJECT_ID(N'teachers_schema.teacher_attendance'), N'created_at', N'ColumnId')
    ) OR NOT EXISTS (
        SELECT 1 FROM sys.default_constraints
        WHERE parent_object_id = OBJECT_ID(N'teachers_schema.teacher_attendance')
          AND parent_column_id = COLUMNPROPERTY(OBJECT_ID(N'teachers_schema.teacher_attendance'), N'updated_at', N'ColumnId')
    )
    BEGIN
        SET @verification_failed = 1;
        SET @verification_error += NCHAR(10) + N'[VERIFICATION ERROR] Required default constraint missing on is_active, created_at, or updated_at.';
    END;

    -- 4. Verify Primary Key is Clustered on teacher_attendance_id
    IF NOT EXISTS (
        SELECT 1 FROM sys.indexes i
        JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
        JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
        WHERE i.object_id = OBJECT_ID(N'teachers_schema.teacher_attendance')
          AND i.is_primary_key = 1 AND i.type_desc = N'CLUSTERED'
          AND c.name = N'teacher_attendance_id' AND ic.key_ordinal = 1
    )
    BEGIN
        SET @verification_failed = 1;
        SET @verification_error += NCHAR(10) + N'[VERIFICATION ERROR] Clustered primary key PK_teacher_attendance on teacher_attendance_id is missing.';
    END;

    -- 5. Verify Unique Constraint (teacher_id, attendance_date)
    IF NOT EXISTS (
        SELECT 1 FROM sys.indexes i
        WHERE i.object_id = OBJECT_ID(N'teachers_schema.teacher_attendance')
          AND i.name = N'UQ_teacher_attendance_teacher_date'
          AND i.is_unique = 1 AND i.is_disabled = 0 AND i.has_filter = 0
          AND (
              SELECT STRING_AGG(c.name, ',') WITHIN GROUP (ORDER BY ic.key_ordinal)
              FROM sys.index_columns ic
              JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
              WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 0
          ) = 'teacher_id,attendance_date'
    )
    BEGIN
        SET @verification_failed = 1;
        SET @verification_error += NCHAR(10) + N'[VERIFICATION ERROR] Unique constraint UQ_teacher_attendance_teacher_date on (teacher_id, attendance_date) is missing or disabled.';
    END;

    -- 6. Verify Each of the Exact 6 Foreign Keys Individually (Enabled & Trusted)
    -- FK 1: school
    IF NOT EXISTS (
        SELECT 1 FROM sys.foreign_keys fk
        JOIN sys.tables rt ON fk.referenced_object_id = rt.object_id
        JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
        JOIN sys.columns pc ON fkc.parent_object_id = pc.object_id AND fkc.parent_column_id = pc.column_id
        JOIN sys.columns rc ON fkc.referenced_object_id = rc.object_id AND fkc.referenced_column_id = rc.column_id
        WHERE fk.parent_object_id = OBJECT_ID(N'teachers_schema.teacher_attendance')
          AND fk.name = N'FK_teacher_attendance_school'
          AND rt.name = N'school' AND SCHEMA_NAME(rt.schema_id) = N'management_schema'
          AND pc.name = N'school_id' AND rc.name = N'school_id'
          AND fk.is_disabled = 0 AND fk.is_not_trusted = 0
    )
    BEGIN
        SET @verification_failed = 1;
        SET @verification_error += NCHAR(10) + N'[VERIFICATION ERROR] Active, trusted foreign key FK_teacher_attendance_school is missing or untrusted.';
    END;

    -- FK 2: branch scope
    IF NOT EXISTS (
        SELECT 1 FROM sys.foreign_keys fk
        JOIN sys.tables rt ON fk.referenced_object_id = rt.object_id
        WHERE fk.parent_object_id = OBJECT_ID(N'teachers_schema.teacher_attendance')
          AND fk.name = N'FK_teacher_attendance_branch_scope'
          AND rt.name = N'branch' AND SCHEMA_NAME(rt.schema_id) = N'management_schema'
          AND fk.is_disabled = 0 AND fk.is_not_trusted = 0
          AND (
              SELECT STRING_AGG(pc.name, ',') WITHIN GROUP (ORDER BY fkc.constraint_column_id)
              FROM sys.foreign_key_columns fkc
              JOIN sys.columns pc ON fkc.parent_object_id = pc.object_id AND fkc.parent_column_id = pc.column_id
              WHERE fkc.constraint_object_id = fk.object_id
          ) = 'school_id,branch_id'
          AND (
              SELECT STRING_AGG(rc.name, ',') WITHIN GROUP (ORDER BY fkc.constraint_column_id)
              FROM sys.foreign_key_columns fkc
              JOIN sys.columns rc ON fkc.referenced_object_id = rc.object_id AND fkc.referenced_column_id = rc.column_id
              WHERE fkc.constraint_object_id = fk.object_id
          ) = 'school_id,branch_id'
    )
    BEGIN
        SET @verification_failed = 1;
        SET @verification_error += NCHAR(10) + N'[VERIFICATION ERROR] Active, trusted foreign key FK_teacher_attendance_branch_scope is missing or untrusted.';
    END;

    -- FK 3: academic year scope
    IF NOT EXISTS (
        SELECT 1 FROM sys.foreign_keys fk
        JOIN sys.tables rt ON fk.referenced_object_id = rt.object_id
        WHERE fk.parent_object_id = OBJECT_ID(N'teachers_schema.teacher_attendance')
          AND fk.name = N'FK_teacher_attendance_academic_year_scope'
          AND rt.name = N'academic_year' AND SCHEMA_NAME(rt.schema_id) = N'management_schema'
          AND fk.is_disabled = 0 AND fk.is_not_trusted = 0
          AND (
              SELECT STRING_AGG(pc.name, ',') WITHIN GROUP (ORDER BY fkc.constraint_column_id)
              FROM sys.foreign_key_columns fkc
              JOIN sys.columns pc ON fkc.parent_object_id = pc.object_id AND fkc.parent_column_id = pc.column_id
              WHERE fkc.constraint_object_id = fk.object_id
          ) = 'school_id,academic_year_id'
          AND (
              SELECT STRING_AGG(rc.name, ',') WITHIN GROUP (ORDER BY fkc.constraint_column_id)
              FROM sys.foreign_key_columns fkc
              JOIN sys.columns rc ON fkc.referenced_object_id = rc.object_id AND fkc.referenced_column_id = rc.column_id
              WHERE fkc.constraint_object_id = fk.object_id
          ) = 'school_id,academic_year_id'
    )
    BEGIN
        SET @verification_failed = 1;
        SET @verification_error += NCHAR(10) + N'[VERIFICATION ERROR] Active, trusted foreign key FK_teacher_attendance_academic_year_scope is missing or untrusted.';
    END;

    -- FK 4: teacher (single-column FK to teachers_schema.teacher)
    IF NOT EXISTS (
        SELECT 1 FROM sys.foreign_keys fk
        JOIN sys.tables rt ON fk.referenced_object_id = rt.object_id
        JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
        JOIN sys.columns pc ON fkc.parent_object_id = pc.object_id AND fkc.parent_column_id = pc.column_id
        JOIN sys.columns rc ON fkc.referenced_object_id = rc.object_id AND fkc.referenced_column_id = rc.column_id
        WHERE fk.parent_object_id = OBJECT_ID(N'teachers_schema.teacher_attendance')
          AND fk.name = N'FK_teacher_attendance_teacher'
          AND rt.name = N'teacher' AND SCHEMA_NAME(rt.schema_id) = N'teachers_schema'
          AND pc.name = N'teacher_id' AND rc.name = N'teacher_id'
          AND fk.is_disabled = 0 AND fk.is_not_trusted = 0
    )
    BEGIN
        SET @verification_failed = 1;
        SET @verification_error += NCHAR(10) + N'[VERIFICATION ERROR] Active, trusted single-column foreign key FK_teacher_attendance_teacher is missing or untrusted.';
    END;

    -- FK 5: created_by
    IF NOT EXISTS (
        SELECT 1 FROM sys.foreign_keys fk
        JOIN sys.tables rt ON fk.referenced_object_id = rt.object_id
        JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
        JOIN sys.columns pc ON fkc.parent_object_id = pc.object_id AND fkc.parent_column_id = pc.column_id
        JOIN sys.columns rc ON fkc.referenced_object_id = rc.object_id AND fkc.referenced_column_id = rc.column_id
        WHERE fk.parent_object_id = OBJECT_ID(N'teachers_schema.teacher_attendance')
          AND fk.name = N'FK_teacher_attendance_created_by'
          AND rt.name = N'users' AND SCHEMA_NAME(rt.schema_id) = N'security_schema'
          AND pc.name = N'created_by' AND rc.name = N'user_id'
          AND fk.is_disabled = 0 AND fk.is_not_trusted = 0
    )
    BEGIN
        SET @verification_failed = 1;
        SET @verification_error += NCHAR(10) + N'[VERIFICATION ERROR] Active, trusted foreign key FK_teacher_attendance_created_by is missing or untrusted.';
    END;

    -- FK 6: updated_by
    IF NOT EXISTS (
        SELECT 1 FROM sys.foreign_keys fk
        JOIN sys.tables rt ON fk.referenced_object_id = rt.object_id
        JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
        JOIN sys.columns pc ON fkc.parent_object_id = pc.object_id AND fkc.parent_column_id = pc.column_id
        JOIN sys.columns rc ON fkc.referenced_object_id = rc.object_id AND fkc.referenced_column_id = rc.column_id
        WHERE fk.parent_object_id = OBJECT_ID(N'teachers_schema.teacher_attendance')
          AND fk.name = N'FK_teacher_attendance_updated_by'
          AND rt.name = N'users' AND SCHEMA_NAME(rt.schema_id) = N'security_schema'
          AND pc.name = N'updated_by' AND rc.name = N'user_id'
          AND fk.is_disabled = 0 AND fk.is_not_trusted = 0
    )
    BEGIN
        SET @verification_failed = 1;
        SET @verification_error += NCHAR(10) + N'[VERIFICATION ERROR] Active, trusted foreign key FK_teacher_attendance_updated_by is missing or untrusted.';
    END;

    -- 7. Verify All 7 Core CHECK Constraints Exist, are Enabled, and are Trusted
    DECLARE @req_cks TABLE (ck_name NVARCHAR(100));
    INSERT INTO @req_cks VALUES
        ('CK_teacher_attendance_status'),
        ('CK_teacher_attendance_checkout_requires_checkin'),
        ('CK_teacher_attendance_time_order'),
        ('CK_teacher_attendance_worked_minutes'),
        ('CK_teacher_attendance_checkout_requires_duration'),
        ('CK_teacher_attendance_present_requires_checkin'),
        ('CK_teacher_attendance_inactive_no_timestamps');

    IF EXISTS (
        SELECT 1 FROM @req_cks rck
        LEFT JOIN sys.check_constraints cc ON cc.parent_object_id = OBJECT_ID(N'teachers_schema.teacher_attendance') AND cc.name = rck.ck_name
        WHERE cc.object_id IS NULL OR cc.is_disabled = 1 OR cc.is_not_trusted = 1
    )
    BEGIN
        SET @verification_failed = 1;
        SET @verification_error += NCHAR(10) + N'[VERIFICATION ERROR] One or more of the 7 core CHECK constraints are missing, disabled, or untrusted.';
    END;

    -- 8. Verify Reporting Indexes Exist, are Enabled, and are Non-Filtered
    IF NOT EXISTS (
        SELECT 1 FROM sys.indexes 
        WHERE object_id = OBJECT_ID(N'teachers_schema.teacher_attendance')
          AND name = N'IX_teacher_attendance_branch_daily'
          AND is_disabled = 0 AND has_filter = 0
    ) OR NOT EXISTS (
        SELECT 1 FROM sys.indexes 
        WHERE object_id = OBJECT_ID(N'teachers_schema.teacher_attendance')
          AND name = N'IX_teacher_attendance_teacher_history'
          AND is_disabled = 0 AND has_filter = 0
    )
    BEGIN
        SET @verification_failed = 1;
        SET @verification_error += NCHAR(10) + N'[VERIFICATION ERROR] Required reporting indexes are missing or disabled.';
    END;

    -- 9. Verify Zero SQL Triggers
    IF EXISTS (
        SELECT 1 FROM sys.triggers 
        WHERE parent_id = OBJECT_ID(N'teachers_schema.teacher_attendance')
    )
    BEGIN
        SET @verification_failed = 1;
        SET @verification_error += NCHAR(10) + N'[VERIFICATION ERROR] SQL triggers detected on teachers_schema.teacher_attendance.';
    END;

    -- 10. Verify Zero Permissions to 'public' Role
    IF EXISTS (
        SELECT 1 FROM sys.database_permissions p
        JOIN sys.database_principals dp ON p.grantee_principal_id = dp.principal_id
        WHERE p.major_id = OBJECT_ID(N'teachers_schema.teacher_attendance')
          AND dp.name = N'public'
    )
    BEGIN
        SET @verification_failed = 1;
        SET @verification_error += NCHAR(10) + N'[SECURITY VIOLATION] Permissions detected granted to public role.';
    END;

    -- Halt transaction if any verification item failed
    IF @verification_failed = 1
    BEGIN
        RAISERROR(@verification_error, 16, 1);
        RETURN;
    END;

    -- Informational reporting on physical column inventory vs preserved legacy columns
    DECLARE @total_phys_cols INT = (SELECT COUNT(*) FROM sys.columns WHERE object_id = OBJECT_ID(N'teachers_schema.teacher_attendance'));
    DECLARE @legacy_report NVARCHAR(MAX) = N'';
    SELECT @legacy_report += c.name + N', '
    FROM sys.columns c
    WHERE c.object_id = OBJECT_ID(N'teachers_schema.teacher_attendance')
      AND c.name NOT IN (SELECT col_name FROM @req_cols);

    COMMIT TRANSACTION;
    PRINT N'';
    PRINT N'================================================================================';
    PRINT N'MIGRATION 027 DEPLOYMENT COMPLETED SUCCESSFULLY.';
    PRINT N'Table teachers_schema.teacher_attendance verified with all 17 required columns,';
    PRINT N'clustered primary key, UQ_teacher_attendance_teacher_date,';
    PRINT N'6 foreign keys (enabled & trusted), 7 check constraints (enabled & trusted),';
    PRINT N'2 reporting indexes, and zero triggers or stored procedures.';

    IF LEN(@legacy_report) > 0
    BEGIN
        SET @legacy_report = LEFT(@legacy_report, LEN(@legacy_report) - 1);
        PRINT N'Physical column count: ' + CAST(@total_phys_cols AS NVARCHAR(10)) + N' (17 core columns + preserved legacy columns: ' + @legacy_report + N').';
    END
    ELSE
    BEGIN
        PRINT N'Physical column count: 17 (clean table conforming to canonical schema).';
    END;
    PRINT N'================================================================================';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    DECLARE @error_msg NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @error_severity INT = ERROR_SEVERITY();
    DECLARE @error_state INT = ERROR_STATE();
    DECLARE @error_line INT = ERROR_LINE();

    PRINT N'';
    PRINT N'********************************************************************************';
    PRINT N'MIGRATION 027 TRANSACTION FAILED. Rolled back all changes.';
    PRINT N'Error: ' + @error_msg + N' (Line ' + CAST(@error_line AS NVARCHAR(10)) + N')';
    PRINT N'********************************************************************************';
    RAISERROR(@error_msg, @error_severity, @error_state);
END CATCH;
GO

-- Re-enable statement execution for subsequent scripts in SSMS
SET NOEXEC OFF;
GO
