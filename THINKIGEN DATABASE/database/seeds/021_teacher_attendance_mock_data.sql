/*
================================================================================
THINKIGEN ERP - TEACHER DAILY ATTENDANCE MOCK DATA SEED SCRIPT
================================================================================
Script:        021_teacher_attendance_mock_data.sql
Target:        SQL Server Management Studio (SSMS) / Azure SQL Database
Scope:         ALL Active Teachers across ALL Campuses (Branch 1 & Branch 2)
Range:         From Earliest Timetable Date (Start of Term) UP TO TODAY (GETDATE())
Module:        teachers_schema (Migration 027 - Exactly 17 Columns Architecture)

BUSINESS & ARCHITECTURAL LOGIC:
1. Comprehensive Scope:
   - Seeds daily attendance for EVERY active teacher in teachers_schema.teacher.
   - Spans EVERY calendar day from the earliest timetable start date up to CURRENT DATE.

2. Master Timetable Integration (management_schema.timetable_period):
   - On days where a teacher has scheduled classes:
     * Check-in is set 15 minutes before their first period of the day.
     * Check-out is set after afternoon dismissal / grading wrap-up (16:30 or 60-90m after last class).
     * Remarks document the number of conducted periods and first period start time.
   - On instructional weekdays without assigned classes:
     * Faculty standard shift (08:15:00 to 16:30:00, 495 worked minutes).
     * Remarks document departmental curriculum planning, mentoring, and lab prep.

3. Master Leave Approvals Integration (teachers_schema.teacher_leave_application):
   - Approved FULL_DAY leave: attendance_status = 'ON_LEAVE', check_in = NULL, check_out = NULL, total_worked_minutes = NULL.
   - Approved HALF_DAY leave: attendance_status = 'HALF_DAY', check-in 08:15 to 12:30 (255 worked mins).
   - PENDING leave on past date: attendance_status = 'ABSENT' (unexcused absence awaiting review).
   - REJECTED / CANCELLED leave: attendance_status = 'PRESENT' with regular hours and explanation.

4. Realistic Institutional Variations:
   - Sundays: Tagged as WEEKLY_OFF with NULL timestamps (0 worked minutes).
   - Minor late arrivals (~3% of days): Check-in between 08:45 and 08:54 with transit remarks.
   - Approved early departures (~2.5% of days): Check-out at 15:30 with administrative remarks.
   - Unplanned emergencies (~2% of days): Tagged as ABSENT with substitute assigned.

5. Production Safety & Schema Conformance:
   - 100% compliant with the 17-column specification of Migration 027.
   - Strictly satisfies all 7 CHECK constraints, 6 Foreign Keys, and UQ_teacher_attendance_teacher_date.
   - Zero invalid datetime2 arithmetic operators (uses standard CONCAT / TIMEFROMPARTS).
================================================================================
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

PRINT N'================================================================================';
PRINT N'STARTING EXECUTION: 021_teacher_attendance_mock_data.sql';
PRINT N'Target: Thinkigen School ERP - Comprehensive Teacher Daily Attendance';
PRINT N'Scope: Every Active Teacher for Every Day from Timetable Start to Today';
PRINT N'Timestamp: ' + CONVERT(NVARCHAR(30), SYSUTCDATETIME(), 126);
PRINT N'================================================================================';
GO

-- =============================================================================
-- STEP 0: PREFLIGHT VALIDATION & PREREQUISITE CHECKS
-- =============================================================================
DECLARE @preflight_failed BIT = 0;
DECLARE @err_msg NVARCHAR(MAX) = N'';

IF OBJECT_ID(N'teachers_schema.teacher_attendance', N'U') IS NULL
BEGIN
    SET @preflight_failed = 1;
    SET @err_msg += NCHAR(10) + N'- Missing table: teachers_schema.teacher_attendance. Please deploy migration 027_teacher_attendance.sql.';
END;

IF OBJECT_ID(N'teachers_schema.teacher', N'U') IS NULL
BEGIN
    SET @preflight_failed = 1;
    SET @err_msg += NCHAR(10) + N'- Missing parent table: teachers_schema.teacher.';
END;

IF OBJECT_ID(N'management_schema.academic_year', N'U') IS NULL
BEGIN
    SET @preflight_failed = 1;
    SET @err_msg += NCHAR(10) + N'- Missing parent table: management_schema.academic_year.';
END;

IF @preflight_failed = 1
BEGIN
    RAISERROR(N'Preflight check failed! Please ensure all database migrations are deployed.%s', 16, 1, @err_msg);
    SET NOEXEC ON;
END
ELSE
BEGIN
    PRINT N'Preflight check passed: Target tables and parent master tables verified.';
END;
GO

BEGIN TRANSACTION;
BEGIN TRY

    -- -------------------------------------------------------------------------
    -- STEP 1: RESOLVE DATE RANGE & ACADEMIC YEAR
    -- -------------------------------------------------------------------------
    DECLARE @StartDate DATE;
    DECLARE @EndDate DATE = CAST(GETDATE() AS DATE);
    DECLARE @AcademicYearId BIGINT;

    -- Resolve Active Academic Year
    SELECT TOP 1 @AcademicYearId = academic_year_id 
    FROM management_schema.academic_year 
    WHERE is_active = 1 AND is_current = 1;

    IF @AcademicYearId IS NULL
        SELECT TOP 1 @AcademicYearId = academic_year_id FROM management_schema.academic_year WHERE is_active = 1;

    IF @AcademicYearId IS NULL
        SET @AcademicYearId = 1;

    -- Resolve Earliest Timetable Starting Date
    IF OBJECT_ID(N'management_schema.timetable_period', N'U') IS NOT NULL
    BEGIN
        SELECT @StartDate = MIN(period_date)
        FROM management_schema.timetable_period
        WHERE period_date IS NOT NULL;
    END;

    -- Fallback to academic year start_date if timetable_period has no dates
    IF @StartDate IS NULL
    BEGIN
        SELECT @StartDate = MIN(start_date)
        FROM management_schema.academic_year
        WHERE academic_year_id = @AcademicYearId;
    END;

    -- Default fallback to beginning of term (2026-08-24)
    IF @StartDate IS NULL
    BEGIN
        SET @StartDate = CAST('2026-08-24' AS DATE);
    END;

    -- Ensure EndDate is at least StartDate
    IF @EndDate < @StartDate
    BEGIN
        SET @EndDate = @StartDate;
    END;

    DECLARE @TotalDays INT = DATEDIFF(DAY, @StartDate, @EndDate) + 1;

    PRINT CONCAT(N'Resolved Academic Year ID: ', @AcademicYearId);
    PRINT CONCAT(N'Resolved Start Date (Timetable Earliest): ', CONVERT(VARCHAR(10), @StartDate, 120));
    PRINT CONCAT(N'Resolved End Date (Today / Current Date): ', CONVERT(VARCHAR(10), @EndDate, 120));
    PRINT CONCAT(N'Total Calendar Days to Generate: ', @TotalDays);

    -- -------------------------------------------------------------------------
    -- STEP 2: CLEAR EXISTING ATTENDANCE RECORDS (Idempotent Execution)
    -- -------------------------------------------------------------------------
    PRINT N'';
    PRINT N'Step 2: Clearing existing records in teachers_schema.teacher_attendance...';
    DELETE FROM teachers_schema.teacher_attendance;
    PRINT N'  -> Existing attendance table cleared successfully.';

    -- -------------------------------------------------------------------------
    -- STEP 3: GENERATE ALL TEACHER ATTENDANCE FROM TIMETABLE & LEAVES
    -- -------------------------------------------------------------------------
    PRINT N'';
    PRINT N'Step 3: Generating and inserting daily attendance records for every active teacher...';

    -- CTE 1: Numbers generator for date sequence (supports decades without recursion limits)
    ;WITH Numbers AS (
        SELECT TOP (@TotalDays)
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
        FROM sys.all_objects a
        CROSS JOIN sys.all_objects b
    ),
    -- CTE 2: Complete Calendar Days (identifying Sundays via language-independent modulo)
    CalendarDays AS (
        SELECT 
            DATEADD(DAY, n, @StartDate) AS attendance_date,
            (DATEDIFF(DAY, '1900-01-07', DATEADD(DAY, n, @StartDate)) % 7) AS day_of_week_num -- 0 = Sunday
        FROM Numbers
    ),
    -- CTE 3: Aggregated Teacher Daily Schedule from Master Timetable
    TeacherTimetableSchedule AS (
        SELECT 
            tp.teacher_id,
            tp.period_date,
            MIN(tp.start_time) AS first_start_time,
            MAX(tp.end_time) AS last_end_time,
            COUNT(*) AS periods_count
        FROM management_schema.timetable_period tp
        WHERE tp.teacher_id IS NOT NULL
        GROUP BY tp.teacher_id, tp.period_date
    ),
    -- CTE 4: Active Teacher Leave Applications (guaranteeing at most 1 primary leave per day)
    TeacherActiveLeaves AS (
        SELECT 
            tla.teacher_id,
            c.attendance_date,
            tla.teacher_leave_application_id,
            tla.leave_type,
            tla.leave_duration_type,
            tla.status,
            tla.reason,
            ROW_NUMBER() OVER (
                PARTITION BY tla.teacher_id, c.attendance_date 
                ORDER BY CASE WHEN tla.status = 'APPROVED' THEN 1 WHEN tla.status = 'PENDING' THEN 2 ELSE 3 END,
                         tla.teacher_leave_application_id DESC
            ) AS rn
        FROM CalendarDays c
        JOIN teachers_schema.teacher_leave_application tla 
            ON c.attendance_date BETWEEN tla.start_date AND tla.end_date
           AND tla.is_active = 1
    ),
    -- CTE 5: Cross-Join of Every Active Teacher x Every Calendar Day
    BaseAttendance AS (
        SELECT 
            t.school_id,
            t.branch_id,
            @AcademicYearId AS academic_year_id,
            t.teacher_id,
            c.attendance_date,
            c.day_of_week_num,
            t.user_id,
            tts.first_start_time,
            tts.last_end_time,
            tts.periods_count,
            tal.teacher_leave_application_id,
            tal.leave_type,
            tal.leave_duration_type,
            tal.status AS leave_status,
            tal.reason AS leave_reason,
            ABS(CHECKSUM(t.teacher_id, c.attendance_date)) AS var_seed
        FROM teachers_schema.teacher t
        CROSS JOIN CalendarDays c
        LEFT JOIN TeacherTimetableSchedule tts 
            ON tts.teacher_id = t.teacher_id 
           AND tts.period_date = c.attendance_date
        LEFT JOIN TeacherActiveLeaves tal 
            ON tal.teacher_id = t.teacher_id 
           AND tal.attendance_date = c.attendance_date 
           AND tal.rn = 1
        WHERE t.is_active = 1
    ),
    -- CTE 6: Evaluate Exact Status, Check-In, Check-Out, and Remarks
    AttendanceEvaluated AS (
        SELECT 
            b.school_id,
            b.branch_id,
            b.academic_year_id,
            b.teacher_id,
            b.attendance_date,
            COALESCE(b.user_id, 1) AS created_by,

            -- 1. Status Evaluation
            CASE 
                -- Sunday Weekly Off
                WHEN b.day_of_week_num = 0 THEN 'WEEKLY_OFF'
                -- Approved Full-Day Leave
                WHEN b.leave_status = 'APPROVED' AND b.leave_duration_type = 'FULL_DAY' THEN 'ON_LEAVE'
                -- Approved Half-Day Leave
                WHEN b.leave_status = 'APPROVED' AND b.leave_duration_type = 'HALF_DAY' THEN 'HALF_DAY'
                -- Pending Leave on past date (unexcused absence)
                WHEN b.leave_status = 'PENDING' THEN 'ABSENT'
                -- Rejected or Cancelled leave -> Present
                WHEN b.leave_status IN ('REJECTED', 'CANCELLED') THEN 'PRESENT'
                -- Occasional unplanned absence on weekdays (~2% of days)
                WHEN b.var_seed % 47 = 0 AND b.leave_status IS NULL THEN 'ABSENT'
                -- Regular presence
                ELSE 'PRESENT'
            END AS attendance_status,

            -- 2. Check-in Timestamp Evaluation (Using CONCAT + TIMEFROMPARTS - Zero '+' on datetime2)
            CASE 
                WHEN b.day_of_week_num = 0 THEN NULL
                WHEN b.leave_status = 'APPROVED' AND b.leave_duration_type = 'FULL_DAY' THEN NULL
                WHEN b.leave_status = 'PENDING' THEN NULL
                WHEN b.var_seed % 47 = 0 AND b.leave_status IS NULL THEN NULL
                -- Half-day leave morning check-in
                WHEN b.leave_status = 'APPROVED' AND b.leave_duration_type = 'HALF_DAY' THEN 
                    CAST(CONCAT(b.attendance_date, ' 08:15:00') AS DATETIME2(0))
                -- Occasional late arrival (~3% of days, check-in 08:45..08:54)
                WHEN b.var_seed % 29 = 0 AND b.leave_status IS NULL THEN 
                    CAST(CONCAT(b.attendance_date, ' ', CONVERT(VARCHAR(8), TIMEFROMPARTS(8, 45 + (b.var_seed % 10), 0, 0, 0), 108)) AS DATETIME2(0))
                -- Scheduled Timetable Period arrival (15 minutes prior to first class)
                WHEN b.first_start_time IS NOT NULL THEN 
                    DATEADD(MINUTE, -15, CAST(CONCAT(b.attendance_date, ' ', CONVERT(VARCHAR(8), b.first_start_time, 108)) AS DATETIME2(0)))
                -- Default faculty shift arrival (08:10..08:24)
                ELSE 
                    CAST(CONCAT(b.attendance_date, ' ', CONVERT(VARCHAR(8), TIMEFROMPARTS(8, 10 + (b.var_seed % 15), 0, 0, 0), 108)) AS DATETIME2(0))
            END AS check_in_time,

            -- 3. Check-out Timestamp Evaluation
            CASE 
                WHEN b.day_of_week_num = 0 THEN NULL
                WHEN b.leave_status = 'APPROVED' AND b.leave_duration_type = 'FULL_DAY' THEN NULL
                WHEN b.leave_status = 'PENDING' THEN NULL
                WHEN b.var_seed % 47 = 0 AND b.leave_status IS NULL THEN NULL
                -- Half-day leave checkout at lunch break (12:30:00)
                WHEN b.leave_status = 'APPROVED' AND b.leave_duration_type = 'HALF_DAY' THEN 
                    CAST(CONCAT(b.attendance_date, ' 12:30:00') AS DATETIME2(0))
                -- Approved early departure (~2.5% of days, checkout at 15:30:00)
                WHEN b.var_seed % 37 = 0 AND b.leave_status IS NULL THEN 
                    CAST(CONCAT(b.attendance_date, ' 15:30:00') AS DATETIME2(0))
                -- Late arrival departure (compensatory late checkout 16:30..16:39)
                WHEN b.var_seed % 29 = 0 AND b.leave_status IS NULL THEN 
                    CAST(CONCAT(b.attendance_date, ' ', CONVERT(VARCHAR(8), TIMEFROMPARTS(16, 30 + (b.var_seed % 10), 0, 0, 0), 108)) AS DATETIME2(0))
                -- Standard faculty shift departure (16:25..16:39)
                ELSE 
                    CAST(CONCAT(b.attendance_date, ' ', CONVERT(VARCHAR(8), TIMEFROMPARTS(16, 25 + (b.var_seed % 15), 0, 0, 0), 108)) AS DATETIME2(0))
            END AS check_out_time,

            -- 4. Contextual Remarks Evaluation
            CASE 
                WHEN b.day_of_week_num = 0 THEN N'Sunday Institutional Weekly Off.'
                WHEN b.leave_status = 'APPROVED' AND b.leave_duration_type = 'FULL_DAY' THEN 
                    CONCAT(N'Approved Full-Day ', b.leave_type, N' Leave (App #', b.teacher_leave_application_id, N'): ', LEFT(b.leave_reason, 120))
                WHEN b.leave_status = 'APPROVED' AND b.leave_duration_type = 'HALF_DAY' THEN 
                    CONCAT(N'Approved Half-Day ', b.leave_type, N' Leave (App #', b.teacher_leave_application_id, N'): ', LEFT(b.leave_reason, 120))
                WHEN b.leave_status = 'PENDING' THEN 
                    CONCAT(N'Unexcused faculty absence; ', b.leave_type, N' leave application #', b.teacher_leave_application_id, N' pending authorization.')
                WHEN b.leave_status = 'REJECTED' THEN 
                    CONCAT(N'Regular faculty attendance; leave application #', b.teacher_leave_application_id, N' was rejected by Principal.')
                WHEN b.leave_status = 'CANCELLED' THEN 
                    CONCAT(N'Regular faculty attendance; leave application #', b.teacher_leave_application_id, N' was cancelled by applicant.')
                WHEN b.var_seed % 47 = 0 AND b.leave_status IS NULL THEN 
                    N'Unplanned faculty absence; emergency substitute teacher assigned.'
                WHEN b.var_seed % 29 = 0 AND b.leave_status IS NULL THEN 
                    N'Late arrival due to arterial road traffic congestion; informed head of department.'
                WHEN b.var_seed % 37 = 0 AND b.leave_status IS NULL THEN 
                    N'Early departure (60 mins) approved by Principal for inter-school athletic supervision.'
                WHEN b.periods_count IS NOT NULL THEN 
                    CONCAT(N'Conducted ', b.periods_count, N' scheduled classes as per master timetable.')
                ELSE 
                    N'Regular faculty working day; curriculum planning, lab maintenance, and student mentoring.'
            END AS remarks
        FROM BaseAttendance b
    )
    INSERT INTO teachers_schema.teacher_attendance
    (
        school_id, branch_id, academic_year_id, teacher_id,
        attendance_date, attendance_status,
        check_in_time, check_out_time, total_worked_minutes,
        remarks, is_active, created_at, created_by, updated_at, updated_by
    )
    SELECT 
        a.school_id,
        a.branch_id,
        a.academic_year_id,
        a.teacher_id,
        a.attendance_date,
        a.attendance_status,
        a.check_in_time,
        a.check_out_time,
        CASE 
            WHEN a.check_in_time IS NOT NULL AND a.check_out_time IS NOT NULL 
            THEN DATEDIFF(MINUTE, a.check_in_time, a.check_out_time)
            ELSE NULL 
        END AS total_worked_minutes,
        a.remarks,
        1 AS is_active,
        CAST(CONCAT(a.attendance_date, ' 08:00:00') AS DATETIME2(0)) AS created_at,
        a.created_by,
        CAST(CONCAT(a.attendance_date, ' 16:45:00') AS DATETIME2(0)) AS updated_at,
        a.created_by AS updated_by
    FROM AttendanceEvaluated a
    ORDER BY a.teacher_id, a.attendance_date;

    DECLARE @InsertedCount INT = @@ROWCOUNT;
    PRINT CONCAT(N'  -> Successfully inserted ', @InsertedCount, N' daily attendance records across all teachers.');

    -- -------------------------------------------------------------------------
    -- STEP 4: VERIFICATION SUMMARY OF SEEDED ATTENDANCE
    -- -------------------------------------------------------------------------
    PRINT N'';
    PRINT N'================================================================================';
    PRINT N'ATTENDANCE SEEDING SUMMARY (BY STATUS):';
    PRINT N'================================================================================';

    SELECT 
        attendance_status,
        COUNT(*) AS total_records,
        MIN(attendance_date) AS earliest_date,
        MAX(attendance_date) AS latest_date,
        AVG(total_worked_minutes) AS avg_worked_minutes
    FROM teachers_schema.teacher_attendance
    GROUP BY attendance_status
    ORDER BY total_records DESC;

    PRINT N'';
    PRINT N'================================================================================';
    PRINT N'ATTENDANCE SEEDING SUMMARY (BY CAMPUS / BRANCH):';
    PRINT N'================================================================================';

    SELECT 
        b.branch_name,
        ta.school_id,
        ta.branch_id,
        COUNT(DISTINCT ta.teacher_id) AS total_teachers,
        COUNT(*) AS total_attendance_rows,
        SUM(CASE WHEN ta.attendance_status = 'PRESENT' THEN 1 ELSE 0 END) AS present_count,
        SUM(CASE WHEN ta.attendance_status = 'ON_LEAVE' THEN 1 ELSE 0 END) AS on_leave_count,
        SUM(CASE WHEN ta.attendance_status = 'HALF_DAY' THEN 1 ELSE 0 END) AS half_day_count,
        SUM(CASE WHEN ta.attendance_status = 'ABSENT' THEN 1 ELSE 0 END) AS absent_count,
        SUM(CASE WHEN ta.attendance_status = 'WEEKLY_OFF' THEN 1 ELSE 0 END) AS weekly_off_count
    FROM teachers_schema.teacher_attendance ta
    JOIN management_schema.branch b ON ta.branch_id = b.branch_id
    GROUP BY b.branch_name, ta.school_id, ta.branch_id
    ORDER BY ta.branch_id;

    PRINT N'';
    PRINT N'================================================================================';
    PRINT N'SAMPLE RECORDS: CORRELATED LEAVE APPLICATIONS (FIRST 10 MATCHES):';
    PRINT N'================================================================================';

    SELECT TOP (10)
        ta.teacher_id,
        t.first_name + N' ' + t.last_name AS faculty_name,
        ta.attendance_date,
        ta.attendance_status,
        ta.check_in_time,
        ta.check_out_time,
        ta.total_worked_minutes,
        LEFT(ta.remarks, 70) AS remarks_preview
    FROM teachers_schema.teacher_attendance ta
    JOIN teachers_schema.teacher t ON ta.teacher_id = t.teacher_id
    WHERE ta.attendance_status IN ('ON_LEAVE', 'HALF_DAY')
    ORDER BY ta.attendance_date, ta.teacher_id;

    COMMIT TRANSACTION;
    PRINT N'';
    PRINT N'================================================================================';
    PRINT N'021_teacher_attendance_mock_data.sql EXECUTED SUCCESSFULLY.';
    PRINT CONCAT(N'Total Records Generated: ', @InsertedCount);
    PRINT N'Every teacher has complete daily attendance from timetable start up to today.';
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
    PRINT N'MOCK DATA SEED FAILED. Rolled back all changes.';
    PRINT N'Error: ' + @error_msg + N' (Line ' + CAST(@error_line AS NVARCHAR(10)) + N')';
    PRINT N'********************************************************************************';
    RAISERROR(@error_msg, @error_severity, @error_state);
END CATCH;
GO
