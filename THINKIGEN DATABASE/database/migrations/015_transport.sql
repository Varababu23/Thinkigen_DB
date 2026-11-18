/* Module migration: 015_transport.sql */
/*
    Migration: 015_transport
    Purpose:   Bus tracking — vehicles, staff, routes, route stops, trips, trip stops,
               speed measurements, student transport assignments, and change requests.

    Hardened Architecture:
    - transport_schema:
        1. vehicle
        2. staff
        3. vehicle_route
        4. vehicle_route_stop
        5. trip
        6. trip_stop
        7. speed_measurement
        8. trip_passenger_attendance
        9. transport_incident
        10. transport_incident_history
    - student_schema:
        11. transport_assignment
        12. transport_change_request

    Design & Hardening Highlights:
    - Strict cross-entity hierarchy: School -> Branch -> Vehicle -> Route -> Stop -> Trip -> Trip Stop
    - Student academic placement hierarchy: School -> Branch -> Academic Year -> Class -> Section -> Student
    - Composite candidate keys and foreign keys prevent cross-branch mismatch anomalies
    - Trip route-vehicle consistency: trip.vehicle_id = route.vehicle_id and trip.trip_type = route.route_type
    - Trip stop route consistency: trip_stop.route_stop_id belongs to trip.vehicle_route_id and matches stop_sequence
    - Trip driver role enforcement: driver_id must reference staff with staff_type = 'DRIVER'
    - Telemetry integrity: speed_measurement references (trip_id, vehicle_id) matching the trip's vehicle
    - Live tracking & telemetry coordinates: latitude, longitude, heading, GPS fix validation
    - Passenger attendance: boarded/drop status and timestamps tied to trips and students
    - Incident management & lifecycle: active incident recording and decoupled resolved history tracking
    - Change request all-or-none requested stop validation and permanent vs temporary return date integrity
    - Concurrency & Capacity: Stored procedure transport_schema.usp_assign_student_transport with UPDLOCK/HOLDLOCK
    - Dynamic date-dependent CHECK constraints eliminated in favor of deterministic validation
    - Idempotent and compatible with SQL Server / Azure SQL

    Rollback:
    - DROP PROCEDURE IF EXISTS transport_schema.usp_assign_student_transport;
    - DROP TABLE IF EXISTS student_schema.transport_change_request;
    - DROP TABLE IF EXISTS transport_schema.trip_passenger_attendance;
    - DROP TABLE IF EXISTS student_schema.transport_assignment;
    - DROP TABLE IF EXISTS transport_schema.transport_incident_history;
    - DROP TABLE IF EXISTS transport_schema.transport_incident;
    - DROP TABLE IF EXISTS transport_schema.speed_measurement;
    - DROP TABLE IF EXISTS transport_schema.trip_stop;
    - DROP TABLE IF EXISTS transport_schema.trip;
    - DROP TABLE IF EXISTS transport_schema.vehicle_route_stop;
    - DROP TABLE IF EXISTS transport_schema.vehicle_route;
    - DROP TABLE IF EXISTS transport_schema.staff;
    - DROP TABLE IF EXISTS transport_schema.vehicle;
*/

SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* -------------------------------------------------------------------------- */
/* 0. SCHEMAS & SUPPORTING PARENT CANDIDATE KEYS                              */
/* -------------------------------------------------------------------------- */

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'transport_schema')
    EXEC(N'CREATE SCHEMA transport_schema AUTHORIZATION dbo;');
GO

-- Ensure parent candidate key exists on management_schema.branch (school_id, branch_id)
IF OBJECT_ID(N'management_schema.branch', N'U') IS NOT NULL
   AND NOT EXISTS (
       SELECT 1 FROM sys.indexes
       WHERE name = N'UQ_branch_school_scope'
         AND object_id = OBJECT_ID(N'management_schema.branch')
   )
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UQ_branch_school_scope
        ON management_schema.branch (school_id, branch_id);
END;
GO

-- Ensure parent candidate key exists on student_schema.student (school_id, branch_id, student_id)
IF OBJECT_ID(N'student_schema.student', N'U') IS NOT NULL
   AND EXISTS (
       SELECT 1 FROM sys.indexes
       WHERE name = N'UQ_student_school_branch_student'
         AND object_id = OBJECT_ID(N'student_schema.student')
         AND (is_unique = 0 OR is_disabled = 1 OR has_filter = 1)
   )
BEGIN
    DROP INDEX UQ_student_school_branch_student ON student_schema.student;
END;
GO

IF OBJECT_ID(N'student_schema.student', N'U') IS NOT NULL
   AND NOT EXISTS (
       SELECT 1 FROM sys.indexes
       WHERE name = N'UQ_student_school_branch_student'
         AND object_id = OBJECT_ID(N'student_schema.student')
   )
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UQ_student_school_branch_student
        ON student_schema.student (school_id, branch_id, student_id);
END;
GO

-- Ensure parent candidate key exists on student_schema.student for full academic placement hierarchy
IF OBJECT_ID(N'student_schema.student', N'U') IS NOT NULL
   AND EXISTS (
       SELECT 1 FROM sys.indexes
       WHERE name = N'UQ_student_placement_scope'
         AND object_id = OBJECT_ID(N'student_schema.student')
         AND (is_unique = 0 OR is_disabled = 1 OR has_filter = 1)
   )
BEGIN
    DROP INDEX UQ_student_placement_scope ON student_schema.student;
END;
GO

IF OBJECT_ID(N'student_schema.student', N'U') IS NOT NULL
   AND NOT EXISTS (
       SELECT 1 FROM sys.indexes
       WHERE name = N'UQ_student_placement_scope'
         AND object_id = OBJECT_ID(N'student_schema.student')
   )
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UQ_student_placement_scope
        ON student_schema.student (school_id, branch_id, academic_year_id, class_id, section_id, student_id);
END;
GO

-- Ensure parent candidate key exists on management_schema.academic_year (school_id, academic_year_id)
IF OBJECT_ID(N'management_schema.academic_year', N'U') IS NOT NULL
   AND NOT EXISTS (
       SELECT 1 FROM sys.indexes
       WHERE name = N'UQ_academic_year_school_scope'
         AND object_id = OBJECT_ID(N'management_schema.academic_year')
   )
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UQ_academic_year_school_scope
        ON management_schema.academic_year (school_id, academic_year_id);
END;
GO

-- Ensure parent candidate key exists on management_schema.school_class (school_id, class_id)
IF OBJECT_ID(N'management_schema.school_class', N'U') IS NOT NULL
   AND NOT EXISTS (
       SELECT 1 FROM sys.indexes
       WHERE name = N'UQ_school_class_school_scope'
         AND object_id = OBJECT_ID(N'management_schema.school_class')
   )
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UQ_school_class_school_scope
        ON management_schema.school_class (school_id, class_id);
END;
GO

-- Ensure parent candidate key exists on management_schema.section (class_id, section_id)
IF OBJECT_ID(N'management_schema.section', N'U') IS NOT NULL
   AND NOT EXISTS (
       SELECT 1 FROM sys.indexes
       WHERE name = N'UQ_section_class_scope'
         AND object_id = OBJECT_ID(N'management_schema.section')
   )
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UQ_section_class_scope
        ON management_schema.section (class_id, section_id);
END;
GO

/* ============================================================================= */
/* 0B. LEGACY SCHEMA DETECTION & UPGRADE                                         */
/* ============================================================================= */

-- If vehicle_route exists with old un-normalized route_stop_id column,
-- OR vehicle exists without UQ_transport_vehicle_scope,
-- OR staff exists without UQ_transport_staff_role,
-- drop all legacy transport tables and rebuild cleanly to the hardened architecture.
IF (OBJECT_ID(N'transport_schema.vehicle_route', N'U') IS NOT NULL AND COL_LENGTH(N'transport_schema.vehicle_route', N'route_stop_id') IS NOT NULL)
   OR (OBJECT_ID(N'transport_schema.vehicle', N'U') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UQ_transport_vehicle_scope' AND object_id = OBJECT_ID(N'transport_schema.vehicle')))
   OR (OBJECT_ID(N'transport_schema.staff', N'U') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UQ_transport_staff_role' AND object_id = OBJECT_ID(N'transport_schema.staff')))
BEGIN
    PRINT N'Detected legacy transport schema. Upgrading all transport tables to hardened architecture...';
    DROP PROCEDURE IF EXISTS transport_schema.usp_assign_student_transport;
    DROP TABLE IF EXISTS student_schema.transport_change_request;
    DROP TABLE IF EXISTS transport_schema.trip_passenger_attendance;
    DROP TABLE IF EXISTS student_schema.transport_assignment;
    DROP TABLE IF EXISTS transport_schema.transport_incident_history;
    DROP TABLE IF EXISTS transport_schema.transport_incident;
    DROP TABLE IF EXISTS transport_schema.speed_measurement;
    DROP TABLE IF EXISTS transport_schema.trip_stop;
    DROP TABLE IF EXISTS transport_schema.trip;
    DROP TABLE IF EXISTS transport_schema.vehicle_route_stop;
    DROP TABLE IF EXISTS transport_schema.vehicle_route;
    DROP TABLE IF EXISTS transport_schema.staff;
    DROP TABLE IF EXISTS transport_schema.vehicle;
END;
GO

-- Ensure candidate keys exist on transport_schema.vehicle if table already existed
IF OBJECT_ID(N'transport_schema.vehicle', N'U') IS NOT NULL
   AND NOT EXISTS (
       SELECT 1 FROM sys.indexes
       WHERE name = N'UQ_transport_vehicle_scope'
         AND object_id = OBJECT_ID(N'transport_schema.vehicle')
   )
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UQ_transport_vehicle_scope
        ON transport_schema.vehicle (school_id, branch_id, vehicle_id);
END;
GO

-- Ensure candidate keys exist on transport_schema.staff if table already existed
IF OBJECT_ID(N'transport_schema.staff', N'U') IS NOT NULL
   AND NOT EXISTS (
       SELECT 1 FROM sys.indexes
       WHERE name = N'UQ_transport_staff_role'
         AND object_id = OBJECT_ID(N'transport_schema.staff')
   )
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UQ_transport_staff_role
        ON transport_schema.staff (staff_id, staff_type);
END;
GO

IF OBJECT_ID(N'transport_schema.staff', N'U') IS NOT NULL
   AND NOT EXISTS (
       SELECT 1 FROM sys.indexes
       WHERE name = N'UQ_transport_staff_scope'
         AND object_id = OBJECT_ID(N'transport_schema.staff')
   )
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UQ_transport_staff_scope
        ON transport_schema.staff (school_id, branch_id, staff_id);
END;
GO

/* -------------------------------------------------------------------------- */

/* ============================================================================= */
/* 1. TRANSPORT MODULE MASTER & DETAIL TABLES (UPDATED SSMS SCHEMA)            */
/* ============================================================================= */

/****** Object:  Table [student_schema].[transport_assignment]    Script Date: 23-09-2026 04:06:59 ******/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF OBJECT_ID(N'[student_schema].[transport_assignment]', N'U') IS NULL
BEGIN
CREATE TABLE [student_schema].[transport_assignment](

	[transport_assignment_id] [bigint] IDENTITY(1,1) NOT NULL,

	[school_id] [bigint] NOT NULL,

	[branch_id] [bigint] NOT NULL,

	[academic_year_id] [bigint] NOT NULL,

	[class_id] [bigint] NOT NULL,

	[section_id] [bigint] NOT NULL,

	[student_id] [bigint] NOT NULL,

	[vehicle_route_id] [bigint] NOT NULL,

	[pickup_route_stop_id] [bigint] NOT NULL,

	[drop_route_stop_id] [bigint] NOT NULL,

	[estimated_pickup_time] [time](0) NOT NULL,

	[estimated_drop_time] [time](0) NOT NULL,

	[effective_from] [date] NOT NULL,

	[effective_to] [date] NULL,

	[status] [nvarchar](20) NOT NULL,

	[is_active] [bit] NOT NULL,

	[created_at] [datetime2](0) NOT NULL,

	[created_by] [bigint] NOT NULL,

	[updated_at] [datetime2](0) NOT NULL,

	[updated_by] [bigint] NULL,

	[row_version] [timestamp] NOT NULL,

 CONSTRAINT [PK_transport_assignment] PRIMARY KEY CLUSTERED 

(

	[transport_assignment_id] ASC

)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],

 CONSTRAINT [UQ_transport_assignment_scope] UNIQUE NONCLUSTERED 

(

	[school_id] ASC,

	[branch_id] ASC,

	[student_id] ASC,

	[transport_assignment_id] ASC

)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]

) ON [PRIMARY]
END
GO
/****** Object:  Table [student_schema].[transport_change_request]    Script Date: 23-09-2026 04:07:00 ******/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF OBJECT_ID(N'[student_schema].[transport_change_request]', N'U') IS NULL
BEGIN
CREATE TABLE [student_schema].[transport_change_request](

	[transport_change_request_id] [bigint] IDENTITY(1,1) NOT NULL,

	[transport_assignment_id] [bigint] NULL,

	[school_id] [bigint] NOT NULL,

	[branch_id] [bigint] NOT NULL,

	[student_id] [bigint] NOT NULL,

	[request_type] [nvarchar](20) NOT NULL,

	[current_vehicle_route_id] [bigint] NOT NULL,

	[requested_vehicle_route_id] [bigint] NULL,

	[current_pickup_stop_id] [bigint] NOT NULL,

	[requested_pickup_stop_id] [bigint] NULL,

	[current_drop_stop_id] [bigint] NOT NULL,

	[requested_drop_stop_id] [bigint] NULL,

	[effective_date] [date] NOT NULL,

	[return_date] [date] NULL,

	[reason] [nvarchar](500) NOT NULL,

	[status] [nvarchar](20) NOT NULL,

	[reviewed_by] [bigint] NULL,

	[reviewed_at] [datetime2](0) NULL,

	[is_active] [bit] NOT NULL,

	[created_at] [datetime2](0) NOT NULL,

	[created_by] [bigint] NOT NULL,

	[updated_at] [datetime2](0) NOT NULL,

	[updated_by] [bigint] NULL,

	[row_version] [timestamp] NOT NULL,

 CONSTRAINT [PK_transport_change_request] PRIMARY KEY CLUSTERED 

(

	[transport_change_request_id] ASC

)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]

) ON [PRIMARY]
END
GO
/****** Object:  Table [transport_schema].[speed_measurement]    Script Date: 23-09-2026 04:07:00 ******/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF OBJECT_ID(N'[transport_schema].[speed_measurement]', N'U') IS NULL
BEGIN
CREATE TABLE [transport_schema].[speed_measurement](

	[speed_measurement_id] [bigint] IDENTITY(1,1) NOT NULL,

	[trip_id] [bigint] NOT NULL,

	[vehicle_id] [bigint] NOT NULL,

	[recorded_at] [datetime2](0) NOT NULL,

	[speed_kmh] [decimal](6, 2) NOT NULL,

	[latitude] [decimal](9, 6) NULL,

	[longitude] [decimal](9, 6) NULL,

	[heading_degrees] [smallint] NULL,

	[gps_fix_status] [nvarchar](20) NOT NULL,

	[received_at] [datetime2](0) NOT NULL,

	[created_at] [datetime2](0) NOT NULL,

 CONSTRAINT [PK_speed_measurement] PRIMARY KEY CLUSTERED 

(

	[speed_measurement_id] ASC

)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]

) ON [PRIMARY]
END
GO

-- Ensure columns exist if table was created in an earlier migration version
IF OBJECT_ID(N'[transport_schema].[speed_measurement]', N'U') IS NOT NULL
BEGIN
    IF COL_LENGTH(N'transport_schema.speed_measurement', N'latitude') IS NULL
        ALTER TABLE [transport_schema].[speed_measurement] ADD [latitude] [decimal](9, 6) NULL;
    IF COL_LENGTH(N'transport_schema.speed_measurement', N'longitude') IS NULL
        ALTER TABLE [transport_schema].[speed_measurement] ADD [longitude] [decimal](9, 6) NULL;
    IF COL_LENGTH(N'transport_schema.speed_measurement', N'heading_degrees') IS NULL
        ALTER TABLE [transport_schema].[speed_measurement] ADD [heading_degrees] [smallint] NULL;
    IF COL_LENGTH(N'transport_schema.speed_measurement', N'gps_fix_status') IS NULL
        ALTER TABLE [transport_schema].[speed_measurement] ADD [gps_fix_status] [nvarchar](20) NOT NULL CONSTRAINT [DF_speed_measurement_gps_fix_status] DEFAULT (N'NO_FIX');
    IF COL_LENGTH(N'transport_schema.speed_measurement', N'received_at') IS NULL
        ALTER TABLE [transport_schema].[speed_measurement] ADD [received_at] [datetime2](0) NOT NULL CONSTRAINT [DF_speed_measurement_received_at] DEFAULT (sysutcdatetime());
END
GO
/****** Object:  Table [transport_schema].[staff]    Script Date: 23-09-2026 04:07:00 ******/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF OBJECT_ID(N'[transport_schema].[staff]', N'U') IS NULL
BEGIN
CREATE TABLE [transport_schema].[staff](

	[staff_id] [bigint] IDENTITY(1,1) NOT NULL,

	[school_id] [bigint] NOT NULL,

	[branch_id] [bigint] NOT NULL,

	[user_id] [bigint] NULL,

	[staff_name] [nvarchar](150) NOT NULL,

	[staff_type] [nvarchar](30) NOT NULL,

	[experience] [int] NOT NULL,

	[mobile_number] [nvarchar](20) NULL,

	[license_number] [nvarchar](50) NULL,

	[license_expiry_date] [date] NULL,

	[status] [nvarchar](20) NOT NULL,

	[is_active] [bit] NOT NULL,

	[created_at] [datetime2](0) NOT NULL,

	[created_by] [bigint] NOT NULL,

	[updated_at] [datetime2](0) NOT NULL,

	[updated_by] [bigint] NULL,

	[row_version] [timestamp] NOT NULL,

 CONSTRAINT [PK_transport_staff] PRIMARY KEY CLUSTERED 

(

	[staff_id] ASC

)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],

 CONSTRAINT [UQ_transport_staff_role] UNIQUE NONCLUSTERED 

(

	[staff_id] ASC,

	[staff_type] ASC

)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],

 CONSTRAINT [UQ_transport_staff_scope] UNIQUE NONCLUSTERED 

(

	[school_id] ASC,

	[branch_id] ASC,

	[staff_id] ASC

)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]

) ON [PRIMARY]
END
GO
/****** Object:  Table [transport_schema].[trip]    Script Date: 23-09-2026 04:07:00 ******/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF OBJECT_ID(N'[transport_schema].[trip]', N'U') IS NULL
BEGIN
CREATE TABLE [transport_schema].[trip](

	[trip_id] [bigint] IDENTITY(1,1) NOT NULL,

	[school_id] [bigint] NOT NULL,

	[branch_id] [bigint] NOT NULL,

	[vehicle_id] [bigint] NOT NULL,

	[vehicle_route_id] [bigint] NOT NULL,

	[driver_id] [bigint] NOT NULL,

	[driver_type_enforcer] [nvarchar](30) NOT NULL,

	[trip_date] [date] NOT NULL,

	[trip_type] [nvarchar](20) NOT NULL,

	[planned_start_time] [time](0) NOT NULL,

	[actual_start_at] [datetime2](0) NULL,

	[planned_destination_time] [time](0) NOT NULL,

	[actual_destination_at] [datetime2](0) NULL,

	[delay_minutes] [smallint] NULL,

	[status] [nvarchar](20) NOT NULL,

	[is_active] [bit] NOT NULL,

	[created_at] [datetime2](0) NOT NULL,

	[created_by] [bigint] NOT NULL,

	[updated_at] [datetime2](0) NOT NULL,

	[updated_by] [bigint] NULL,

	[row_version] [timestamp] NOT NULL,

 CONSTRAINT [PK_trip] PRIMARY KEY CLUSTERED 

(

	[trip_id] ASC

)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],

 CONSTRAINT [UQ_trip_route] UNIQUE NONCLUSTERED 

(

	[trip_id] ASC,

	[vehicle_route_id] ASC

)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],

 CONSTRAINT [UQ_trip_vehicle] UNIQUE NONCLUSTERED 

(

	[trip_id] ASC,

	[vehicle_id] ASC

)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]

) ON [PRIMARY]
END
GO
/****** Object:  Table [transport_schema].[trip_stop]    Script Date: 23-09-2026 04:07:00 ******/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF OBJECT_ID(N'[transport_schema].[trip_stop]', N'U') IS NULL
BEGIN
CREATE TABLE [transport_schema].[trip_stop](

	[trip_stop_id] [bigint] IDENTITY(1,1) NOT NULL,

	[trip_id] [bigint] NOT NULL,

	[vehicle_route_id] [bigint] NOT NULL,

	[route_stop_id] [bigint] NOT NULL,

	[stop_sequence] [smallint] NOT NULL,

	[planned_arrival_at] [datetime2](0) NOT NULL,

	[actual_arrival_at] [datetime2](0) NULL,

	[actual_departure_at] [datetime2](0) NULL,

	[delay_minutes] [smallint] NULL,

	[status] [nvarchar](20) NOT NULL,

	[created_at] [datetime2](0) NOT NULL,

	[row_version] [timestamp] NOT NULL,

 CONSTRAINT [PK_trip_stop] PRIMARY KEY CLUSTERED 

(

	[trip_stop_id] ASC

)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],

 CONSTRAINT [UQ_trip_stop_trip_route_stop] UNIQUE NONCLUSTERED 

(

	[trip_id] ASC,

	[route_stop_id] ASC

)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],

 CONSTRAINT [UQ_trip_stop_trip_sequence] UNIQUE NONCLUSTERED 

(

	[trip_id] ASC,

	[stop_sequence] ASC

)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]

) ON [PRIMARY]
END
GO
/****** Object:  Table [transport_schema].[vehicle]    Script Date: 23-09-2026 04:07:00 ******/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF OBJECT_ID(N'[transport_schema].[vehicle]', N'U') IS NULL
BEGIN
CREATE TABLE [transport_schema].[vehicle](

	[vehicle_id] [bigint] IDENTITY(1,1) NOT NULL,

	[school_id] [bigint] NOT NULL,

	[branch_id] [bigint] NOT NULL,

	[vehicle_number] [nvarchar](30) NOT NULL,

	[vehicle_name] [nvarchar](100) NULL,

	[capacity] [int] NOT NULL,

	[status] [nvarchar](20) NOT NULL,

	[vehicle_health] [nvarchar](30) NOT NULL,

	[is_active] [bit] NOT NULL,

	[created_at] [datetime2](0) NOT NULL,

	[created_by] [bigint] NOT NULL,

	[updated_at] [datetime2](0) NOT NULL,

	[updated_by] [bigint] NULL,

	[row_version] [timestamp] NOT NULL,

 CONSTRAINT [PK_transport_vehicle] PRIMARY KEY CLUSTERED 

(

	[vehicle_id] ASC

)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],

 CONSTRAINT [UQ_transport_vehicle_number] UNIQUE NONCLUSTERED 

(

	[vehicle_number] ASC

)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],

 CONSTRAINT [UQ_transport_vehicle_scope] UNIQUE NONCLUSTERED 

(

	[school_id] ASC,

	[branch_id] ASC,

	[vehicle_id] ASC

)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]

) ON [PRIMARY]
END
GO
IF OBJECT_ID(N'[transport_schema].[vehicle]', N'U') IS NOT NULL
   AND COL_LENGTH(N'transport_schema.vehicle', N'vehicle_health') IS NULL
BEGIN
    ALTER TABLE [transport_schema].[vehicle]
        ADD [vehicle_health] [nvarchar](30) NOT NULL CONSTRAINT [DF_transport_vehicle_health] DEFAULT (N'GOOD') WITH VALUES;
END
GO
IF OBJECT_ID(N'[transport_schema].[staff]', N'U') IS NOT NULL
   AND COL_LENGTH(N'transport_schema.staff', N'experience') IS NULL
BEGIN
    ALTER TABLE [transport_schema].[staff]
        ADD [experience] [int] NOT NULL CONSTRAINT [DF_transport_staff_experience] DEFAULT ((0)) WITH VALUES;
END
GO
/****** Object:  Table [transport_schema].[vehicle_route]    Script Date: 23-09-2026 04:07:00 ******/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF OBJECT_ID(N'[transport_schema].[vehicle_route]', N'U') IS NULL
BEGIN
CREATE TABLE [transport_schema].[vehicle_route](

	[vehicle_route_id] [bigint] IDENTITY(1,1) NOT NULL,

	[school_id] [bigint] NOT NULL,

	[branch_id] [bigint] NOT NULL,

	[vehicle_id] [bigint] NOT NULL,

	[route_code] [nvarchar](30) NOT NULL,

	[route_name] [nvarchar](150) NOT NULL,

	[route_type] [nvarchar](20) NOT NULL,

	[status] [nvarchar](20) NOT NULL,

	[effective_from] [date] NOT NULL,

	[effective_to] [date] NULL,

	[is_active] [bit] NOT NULL,

	[created_at] [datetime2](0) NOT NULL,

	[created_by] [bigint] NOT NULL,

	[updated_at] [datetime2](0) NOT NULL,

	[updated_by] [bigint] NULL,

	[row_version] [timestamp] NOT NULL,

 CONSTRAINT [PK_vehicle_route] PRIMARY KEY CLUSTERED 

(

	[vehicle_route_id] ASC

)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],

 CONSTRAINT [UQ_vehicle_route_branch_scope] UNIQUE NONCLUSTERED 

(

	[school_id] ASC,

	[branch_id] ASC,

	[vehicle_route_id] ASC

)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],

 CONSTRAINT [UQ_vehicle_route_code] UNIQUE NONCLUSTERED 

(

	[vehicle_id] ASC,

	[route_code] ASC,

	[route_type] ASC,

	[effective_from] ASC

)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],

 CONSTRAINT [UQ_vehicle_route_vehicle_type] UNIQUE NONCLUSTERED 

(

	[vehicle_route_id] ASC,

	[vehicle_id] ASC,

	[route_type] ASC

)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]

) ON [PRIMARY]
END
GO
/****** Object:  Table [transport_schema].[vehicle_route_stop]    Script Date: 23-09-2026 04:07:00 ******/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF OBJECT_ID(N'[transport_schema].[vehicle_route_stop]', N'U') IS NULL
BEGIN
CREATE TABLE [transport_schema].[vehicle_route_stop](

	[route_stop_id] [bigint] IDENTITY(1,1) NOT NULL,

	[vehicle_route_id] [bigint] NOT NULL,

	[stop_sequence] [smallint] NOT NULL,

	[stop_name] [nvarchar](150) NOT NULL,

	[stop_address] [nvarchar](300) NULL,

	[planned_arrival_time] [time](0) NOT NULL,

	[planned_departure_time] [time](0) NULL,

	[is_active] [bit] NOT NULL,

	[created_at] [datetime2](0) NOT NULL,

	[created_by] [bigint] NOT NULL,

	[updated_at] [datetime2](0) NOT NULL,

	[updated_by] [bigint] NULL,

	[row_version] [timestamp] NOT NULL,

 CONSTRAINT [PK_route_stop] PRIMARY KEY CLUSTERED 

(

	[route_stop_id] ASC

)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],

 CONSTRAINT [UQ_route_stop_composite] UNIQUE NONCLUSTERED 

(

	[vehicle_route_id] ASC,

	[route_stop_id] ASC

)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],

 CONSTRAINT [UQ_route_stop_sequence] UNIQUE NONCLUSTERED 

(

	[vehicle_route_id] ASC,

	[stop_sequence] ASC

)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],

 CONSTRAINT [UQ_route_stop_sequence_composite] UNIQUE NONCLUSTERED 

(

	[vehicle_route_id] ASC,

	[route_stop_id] ASC,

	[stop_sequence] ASC

)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]

) ON [PRIMARY]
END
GO

/****** Object:  Table [transport_schema].[trip_passenger_attendance] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF OBJECT_ID(N'[transport_schema].[trip_passenger_attendance]', N'U') IS NULL
BEGIN
CREATE TABLE [transport_schema].[trip_passenger_attendance](
	[trip_passenger_attendance_id] [bigint] IDENTITY(1,1) NOT NULL,
	[school_id] [bigint] NOT NULL,
	[branch_id] [bigint] NOT NULL,
	[trip_id] [bigint] NOT NULL,
	[user_id] [bigint] NOT NULL,
	[transport_assignment_id] [bigint] NULL,
	[boarded_attendance_status] [nvarchar](20) NULL,
	[boarded_at] [datetime2](0) NULL,
	[drop_attendance_status] [nvarchar](20) NULL,
	[drop_at] [datetime2](0) NULL,
	[attendance_status] [nvarchar](20) NULL,
	[recorded_by] [bigint] NULL,
	[created_at] [datetime2](0) NOT NULL,
	[created_by] [bigint] NULL,
	[updated_at] [datetime2](0) NOT NULL,
	[updated_by] [bigint] NULL,
	[row_version] [timestamp] NOT NULL,
 CONSTRAINT [PK_trip_passenger_attendance] PRIMARY KEY CLUSTERED 
(
	[trip_passenger_attendance_id] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_trip_passenger_attendance_trip_user] UNIQUE NONCLUSTERED 
(
	[trip_id] ASC,
	[user_id] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
GO

/****** Object:  Table [transport_schema].[transport_incident] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF OBJECT_ID(N'[transport_schema].[transport_incident]', N'U') IS NULL
BEGIN
CREATE TABLE [transport_schema].[transport_incident](
	[transport_incident_id] [bigint] IDENTITY(1,1) NOT NULL,
	[school_id] [bigint] NOT NULL,
	[branch_id] [bigint] NOT NULL,
	[title] [nvarchar](200) NOT NULL,
	[description] [nvarchar](2000) NULL,
	[record_type] [nvarchar](30) NOT NULL,
	[type] [nvarchar](30) NOT NULL,
	[vehicle_id] [bigint] NULL,
	[detected_at] [datetime2](0) NOT NULL,
	[status] [nvarchar](20) NOT NULL,
	[attachment_url] [nvarchar](1000) NULL,
	[is_active] [bit] NOT NULL,
	[created_at] [datetime2](0) NOT NULL,
	[created_by] [bigint] NOT NULL,
	[updated_at] [datetime2](0) NOT NULL,
	[updated_by] [bigint] NULL,
	[row_version] [timestamp] NOT NULL,
 CONSTRAINT [PK_transport_incident] PRIMARY KEY CLUSTERED 
(
	[transport_incident_id] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
GO

-- Ensure attachment_url column exists if table was created in an earlier migration version
IF OBJECT_ID(N'[transport_schema].[transport_incident]', N'U') IS NOT NULL
BEGIN
    IF COL_LENGTH(N'transport_schema.transport_incident', N'attachment_url') IS NULL
        ALTER TABLE [transport_schema].[transport_incident] ADD [attachment_url] [nvarchar](1000) NULL;
END
GO

/****** Object:  Table [transport_schema].[transport_incident_history] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF OBJECT_ID(N'[transport_schema].[transport_incident_history]', N'U') IS NULL
BEGIN
CREATE TABLE [transport_schema].[transport_incident_history](
	[transport_incident_history_id] [bigint] IDENTITY(1,1) NOT NULL,
	[transport_incident_id] [bigint] NOT NULL,
	[school_id] [bigint] NOT NULL,
	[branch_id] [bigint] NOT NULL,
	[title] [nvarchar](200) NOT NULL,
	[description] [nvarchar](2000) NULL,
	[record_type] [nvarchar](30) NOT NULL,
	[type] [nvarchar](30) NOT NULL,
	[vehicle_id] [bigint] NULL,
	[detected_at] [datetime2](0) NOT NULL,
	[resolved_at] [datetime2](0) NULL,
	[attachment_url] [nvarchar](1000) NULL,
	[updated_at] [datetime2](0) NOT NULL,
	[updated_by] [bigint] NOT NULL,
	[row_version] [timestamp] NOT NULL,
 CONSTRAINT [PK_transport_incident_history] PRIMARY KEY CLUSTERED 
(
	[transport_incident_history_id] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
GO

-- Ensure attachment_url column exists if table was created in an earlier migration version
IF OBJECT_ID(N'[transport_schema].[transport_incident_history]', N'U') IS NOT NULL
BEGIN
    IF COL_LENGTH(N'transport_schema.transport_incident_history', N'attachment_url') IS NULL
        ALTER TABLE [transport_schema].[transport_incident_history] ADD [attachment_url] [nvarchar](1000) NULL;
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_transport_assignment_is_active')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment] ADD  CONSTRAINT [DF_transport_assignment_is_active]  DEFAULT ((1)) FOR [is_active]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_transport_assignment_created_at')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment] ADD  CONSTRAINT [DF_transport_assignment_created_at]  DEFAULT (sysutcdatetime()) FOR [created_at]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_transport_assignment_updated_at')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment] ADD  CONSTRAINT [DF_transport_assignment_updated_at]  DEFAULT (sysutcdatetime()) FOR [updated_at]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_transport_change_request_is_active')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request] ADD  CONSTRAINT [DF_transport_change_request_is_active]  DEFAULT ((1)) FOR [is_active]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_transport_change_request_created_at')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request] ADD  CONSTRAINT [DF_transport_change_request_created_at]  DEFAULT (sysutcdatetime()) FOR [created_at]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_transport_change_request_updated_at')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request] ADD  CONSTRAINT [DF_transport_change_request_updated_at]  DEFAULT (sysutcdatetime()) FOR [updated_at]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_speed_measurement_created_at')
BEGIN
    ALTER TABLE [transport_schema].[speed_measurement] ADD  CONSTRAINT [DF_speed_measurement_created_at]  DEFAULT (sysutcdatetime()) FOR [created_at]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_transport_staff_is_active')
BEGIN
    ALTER TABLE [transport_schema].[staff] ADD  CONSTRAINT [DF_transport_staff_is_active]  DEFAULT ((1)) FOR [is_active]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_transport_staff_created_at')
BEGIN
    ALTER TABLE [transport_schema].[staff] ADD  CONSTRAINT [DF_transport_staff_created_at]  DEFAULT (sysutcdatetime()) FOR [created_at]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_transport_staff_updated_at')
BEGIN
    ALTER TABLE [transport_schema].[staff] ADD  CONSTRAINT [DF_transport_staff_updated_at]  DEFAULT (sysutcdatetime()) FOR [updated_at]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_transport_staff_experience')
BEGIN
    ALTER TABLE [transport_schema].[staff] ADD  CONSTRAINT [DF_transport_staff_experience]  DEFAULT ((0)) FOR [experience]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_trip_driver_type')
BEGIN
    ALTER TABLE [transport_schema].[trip] ADD  CONSTRAINT [DF_trip_driver_type]  DEFAULT (N'DRIVER') FOR [driver_type_enforcer]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_trip_is_active')
BEGIN
    ALTER TABLE [transport_schema].[trip] ADD  CONSTRAINT [DF_trip_is_active]  DEFAULT ((1)) FOR [is_active]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_trip_created_at')
BEGIN
    ALTER TABLE [transport_schema].[trip] ADD  CONSTRAINT [DF_trip_created_at]  DEFAULT (sysutcdatetime()) FOR [created_at]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_trip_updated_at')
BEGIN
    ALTER TABLE [transport_schema].[trip] ADD  CONSTRAINT [DF_trip_updated_at]  DEFAULT (sysutcdatetime()) FOR [updated_at]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_trip_stop_created_at')
BEGIN
    ALTER TABLE [transport_schema].[trip_stop] ADD  CONSTRAINT [DF_trip_stop_created_at]  DEFAULT (sysutcdatetime()) FOR [created_at]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_transport_vehicle_is_active')
BEGIN
    ALTER TABLE [transport_schema].[vehicle] ADD  CONSTRAINT [DF_transport_vehicle_is_active]  DEFAULT ((1)) FOR [is_active]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_transport_vehicle_health')
BEGIN
    ALTER TABLE [transport_schema].[vehicle] ADD  CONSTRAINT [DF_transport_vehicle_health]  DEFAULT (N'GOOD') FOR [vehicle_health]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_transport_vehicle_created_at')
BEGIN
    ALTER TABLE [transport_schema].[vehicle] ADD  CONSTRAINT [DF_transport_vehicle_created_at]  DEFAULT (sysutcdatetime()) FOR [created_at]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_transport_vehicle_updated_at')
BEGIN
    ALTER TABLE [transport_schema].[vehicle] ADD  CONSTRAINT [DF_transport_vehicle_updated_at]  DEFAULT (sysutcdatetime()) FOR [updated_at]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_vehicle_route_is_active')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route] ADD  CONSTRAINT [DF_vehicle_route_is_active]  DEFAULT ((1)) FOR [is_active]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_vehicle_route_created_at')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route] ADD  CONSTRAINT [DF_vehicle_route_created_at]  DEFAULT (sysutcdatetime()) FOR [created_at]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_vehicle_route_updated_at')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route] ADD  CONSTRAINT [DF_vehicle_route_updated_at]  DEFAULT (sysutcdatetime()) FOR [updated_at]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_route_stop_is_active')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route_stop] ADD  CONSTRAINT [DF_route_stop_is_active]  DEFAULT ((1)) FOR [is_active]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_route_stop_created_at')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route_stop] ADD  CONSTRAINT [DF_route_stop_created_at]  DEFAULT (sysutcdatetime()) FOR [created_at]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_route_stop_updated_at')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route_stop] ADD  CONSTRAINT [DF_route_stop_updated_at]  DEFAULT (sysutcdatetime()) FOR [updated_at]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_speed_measurement_gps_fix_status')
BEGIN
    ALTER TABLE [transport_schema].[speed_measurement] ADD  CONSTRAINT [DF_speed_measurement_gps_fix_status]  DEFAULT (N'NO_FIX') FOR [gps_fix_status]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_speed_measurement_received_at')
BEGIN
    ALTER TABLE [transport_schema].[speed_measurement] ADD  CONSTRAINT [DF_speed_measurement_received_at]  DEFAULT (sysutcdatetime()) FOR [received_at]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_trip_passenger_attendance_created_at')
BEGIN
    ALTER TABLE [transport_schema].[trip_passenger_attendance] ADD  CONSTRAINT [DF_trip_passenger_attendance_created_at]  DEFAULT (sysutcdatetime()) FOR [created_at]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_trip_passenger_attendance_updated_at')
BEGIN
    ALTER TABLE [transport_schema].[trip_passenger_attendance] ADD  CONSTRAINT [DF_trip_passenger_attendance_updated_at]  DEFAULT (sysutcdatetime()) FOR [updated_at]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_transport_incident_is_active')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident] ADD  CONSTRAINT [DF_transport_incident_is_active]  DEFAULT ((1)) FOR [is_active]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_transport_incident_created_at')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident] ADD  CONSTRAINT [DF_transport_incident_created_at]  DEFAULT (sysutcdatetime()) FOR [created_at]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_transport_incident_updated_at')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident] ADD  CONSTRAINT [DF_transport_incident_updated_at]  DEFAULT (sysutcdatetime()) FOR [updated_at]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_transport_incident_history_updated_at')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident_history] ADD  CONSTRAINT [DF_transport_incident_history_updated_at]  DEFAULT (sysutcdatetime()) FOR [updated_at]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_assignment_academic_year')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment]  WITH CHECK ADD  CONSTRAINT [FK_transport_assignment_academic_year] FOREIGN KEY([academic_year_id])

REFERENCES [management_schema].[academic_year] ([academic_year_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_assignment_academic_year')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment] CHECK CONSTRAINT [FK_transport_assignment_academic_year]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_assignment_academic_year_scope')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment]  WITH CHECK ADD  CONSTRAINT [FK_transport_assignment_academic_year_scope] FOREIGN KEY([school_id], [academic_year_id])

REFERENCES [management_schema].[academic_year] ([school_id], [academic_year_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_assignment_academic_year_scope')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment] CHECK CONSTRAINT [FK_transport_assignment_academic_year_scope]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_assignment_branch')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment]  WITH CHECK ADD  CONSTRAINT [FK_transport_assignment_branch] FOREIGN KEY([branch_id])

REFERENCES [management_schema].[branch] ([branch_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_assignment_branch')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment] CHECK CONSTRAINT [FK_transport_assignment_branch]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_assignment_branch_scope')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment]  WITH CHECK ADD  CONSTRAINT [FK_transport_assignment_branch_scope] FOREIGN KEY([school_id], [branch_id])

REFERENCES [management_schema].[branch] ([school_id], [branch_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_assignment_branch_scope')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment] CHECK CONSTRAINT [FK_transport_assignment_branch_scope]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_assignment_class')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment]  WITH CHECK ADD  CONSTRAINT [FK_transport_assignment_class] FOREIGN KEY([class_id])

REFERENCES [management_schema].[school_class] ([class_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_assignment_class')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment] CHECK CONSTRAINT [FK_transport_assignment_class]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_assignment_class_scope')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment]  WITH CHECK ADD  CONSTRAINT [FK_transport_assignment_class_scope] FOREIGN KEY([school_id], [class_id])

REFERENCES [management_schema].[school_class] ([school_id], [class_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_assignment_class_scope')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment] CHECK CONSTRAINT [FK_transport_assignment_class_scope]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_assignment_created_by')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment]  WITH CHECK ADD  CONSTRAINT [FK_transport_assignment_created_by] FOREIGN KEY([created_by])

REFERENCES [security_schema].[users] ([user_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_assignment_created_by')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment] CHECK CONSTRAINT [FK_transport_assignment_created_by]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_assignment_drop_stop')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment]  WITH CHECK ADD  CONSTRAINT [FK_transport_assignment_drop_stop] FOREIGN KEY([vehicle_route_id], [drop_route_stop_id])

REFERENCES [transport_schema].[vehicle_route_stop] ([vehicle_route_id], [route_stop_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_assignment_drop_stop')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment] CHECK CONSTRAINT [FK_transport_assignment_drop_stop]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_assignment_pickup_stop')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment]  WITH CHECK ADD  CONSTRAINT [FK_transport_assignment_pickup_stop] FOREIGN KEY([vehicle_route_id], [pickup_route_stop_id])

REFERENCES [transport_schema].[vehicle_route_stop] ([vehicle_route_id], [route_stop_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_assignment_pickup_stop')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment] CHECK CONSTRAINT [FK_transport_assignment_pickup_stop]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_assignment_route_scope')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment]  WITH CHECK ADD  CONSTRAINT [FK_transport_assignment_route_scope] FOREIGN KEY([school_id], [branch_id], [vehicle_route_id])

REFERENCES [transport_schema].[vehicle_route] ([school_id], [branch_id], [vehicle_route_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_assignment_route_scope')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment] CHECK CONSTRAINT [FK_transport_assignment_route_scope]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_assignment_school')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment]  WITH CHECK ADD  CONSTRAINT [FK_transport_assignment_school] FOREIGN KEY([school_id])

REFERENCES [management_schema].[school] ([school_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_assignment_school')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment] CHECK CONSTRAINT [FK_transport_assignment_school]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_assignment_section')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment]  WITH CHECK ADD  CONSTRAINT [FK_transport_assignment_section] FOREIGN KEY([section_id])

REFERENCES [management_schema].[section] ([section_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_assignment_section')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment] CHECK CONSTRAINT [FK_transport_assignment_section]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_assignment_section_scope')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment]  WITH CHECK ADD  CONSTRAINT [FK_transport_assignment_section_scope] FOREIGN KEY([class_id], [section_id])

REFERENCES [management_schema].[section] ([class_id], [section_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_assignment_section_scope')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment] CHECK CONSTRAINT [FK_transport_assignment_section_scope]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_assignment_student')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment]  WITH CHECK ADD  CONSTRAINT [FK_transport_assignment_student] FOREIGN KEY([student_id])

REFERENCES [student_schema].[student] ([student_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_assignment_student')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment] CHECK CONSTRAINT [FK_transport_assignment_student]
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_assignment_student_scope')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment]  WITH CHECK ADD  CONSTRAINT [FK_transport_assignment_student_scope] FOREIGN KEY([school_id], [branch_id], [student_id])

REFERENCES [student_schema].[student] ([school_id], [branch_id], [student_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_assignment_student_scope')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment] CHECK CONSTRAINT [FK_transport_assignment_student_scope]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_assignment_updated_by')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment]  WITH CHECK ADD  CONSTRAINT [FK_transport_assignment_updated_by] FOREIGN KEY([updated_by])

REFERENCES [security_schema].[users] ([user_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_assignment_updated_by')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment] CHECK CONSTRAINT [FK_transport_assignment_updated_by]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_assignment_vehicle_route')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment]  WITH CHECK ADD  CONSTRAINT [FK_transport_assignment_vehicle_route] FOREIGN KEY([vehicle_route_id])

REFERENCES [transport_schema].[vehicle_route] ([vehicle_route_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_assignment_vehicle_route')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment] CHECK CONSTRAINT [FK_transport_assignment_vehicle_route]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_change_request_assignment')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request]  WITH CHECK ADD  CONSTRAINT [FK_transport_change_request_assignment] FOREIGN KEY([transport_assignment_id])

REFERENCES [student_schema].[transport_assignment] ([transport_assignment_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_change_request_assignment')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request] CHECK CONSTRAINT [FK_transport_change_request_assignment]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_change_request_branch')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request]  WITH CHECK ADD  CONSTRAINT [FK_transport_change_request_branch] FOREIGN KEY([branch_id])

REFERENCES [management_schema].[branch] ([branch_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_change_request_branch')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request] CHECK CONSTRAINT [FK_transport_change_request_branch]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_change_request_branch_scope')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request]  WITH CHECK ADD  CONSTRAINT [FK_transport_change_request_branch_scope] FOREIGN KEY([school_id], [branch_id])

REFERENCES [management_schema].[branch] ([school_id], [branch_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_change_request_branch_scope')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request] CHECK CONSTRAINT [FK_transport_change_request_branch_scope]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_change_request_created_by')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request]  WITH CHECK ADD  CONSTRAINT [FK_transport_change_request_created_by] FOREIGN KEY([created_by])

REFERENCES [security_schema].[users] ([user_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_change_request_created_by')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request] CHECK CONSTRAINT [FK_transport_change_request_created_by]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_change_request_current_drop')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request]  WITH CHECK ADD  CONSTRAINT [FK_transport_change_request_current_drop] FOREIGN KEY([current_vehicle_route_id], [current_drop_stop_id])

REFERENCES [transport_schema].[vehicle_route_stop] ([vehicle_route_id], [route_stop_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_change_request_current_drop')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request] CHECK CONSTRAINT [FK_transport_change_request_current_drop]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_change_request_current_pickup')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request]  WITH CHECK ADD  CONSTRAINT [FK_transport_change_request_current_pickup] FOREIGN KEY([current_vehicle_route_id], [current_pickup_stop_id])

REFERENCES [transport_schema].[vehicle_route_stop] ([vehicle_route_id], [route_stop_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_change_request_current_pickup')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request] CHECK CONSTRAINT [FK_transport_change_request_current_pickup]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_change_request_current_route')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request]  WITH CHECK ADD  CONSTRAINT [FK_transport_change_request_current_route] FOREIGN KEY([current_vehicle_route_id])

REFERENCES [transport_schema].[vehicle_route] ([vehicle_route_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_change_request_current_route')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request] CHECK CONSTRAINT [FK_transport_change_request_current_route]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_change_request_current_route_scope')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request]  WITH CHECK ADD  CONSTRAINT [FK_transport_change_request_current_route_scope] FOREIGN KEY([school_id], [branch_id], [current_vehicle_route_id])

REFERENCES [transport_schema].[vehicle_route] ([school_id], [branch_id], [vehicle_route_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_change_request_current_route_scope')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request] CHECK CONSTRAINT [FK_transport_change_request_current_route_scope]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_change_request_requested_drop')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request]  WITH CHECK ADD  CONSTRAINT [FK_transport_change_request_requested_drop] FOREIGN KEY([requested_vehicle_route_id], [requested_drop_stop_id])

REFERENCES [transport_schema].[vehicle_route_stop] ([vehicle_route_id], [route_stop_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_change_request_requested_drop')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request] CHECK CONSTRAINT [FK_transport_change_request_requested_drop]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_change_request_requested_pickup')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request]  WITH CHECK ADD  CONSTRAINT [FK_transport_change_request_requested_pickup] FOREIGN KEY([requested_vehicle_route_id], [requested_pickup_stop_id])

REFERENCES [transport_schema].[vehicle_route_stop] ([vehicle_route_id], [route_stop_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_change_request_requested_pickup')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request] CHECK CONSTRAINT [FK_transport_change_request_requested_pickup]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_change_request_requested_route')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request]  WITH CHECK ADD  CONSTRAINT [FK_transport_change_request_requested_route] FOREIGN KEY([requested_vehicle_route_id])

REFERENCES [transport_schema].[vehicle_route] ([vehicle_route_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_change_request_requested_route')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request] CHECK CONSTRAINT [FK_transport_change_request_requested_route]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_change_request_reviewed_by')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request]  WITH CHECK ADD  CONSTRAINT [FK_transport_change_request_reviewed_by] FOREIGN KEY([reviewed_by])

REFERENCES [security_schema].[users] ([user_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_change_request_reviewed_by')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request] CHECK CONSTRAINT [FK_transport_change_request_reviewed_by]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_change_request_school')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request]  WITH CHECK ADD  CONSTRAINT [FK_transport_change_request_school] FOREIGN KEY([school_id])

REFERENCES [management_schema].[school] ([school_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_change_request_school')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request] CHECK CONSTRAINT [FK_transport_change_request_school]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_change_request_student')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request]  WITH CHECK ADD  CONSTRAINT [FK_transport_change_request_student] FOREIGN KEY([student_id])

REFERENCES [student_schema].[student] ([student_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_change_request_student')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request] CHECK CONSTRAINT [FK_transport_change_request_student]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_change_request_student_scope')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request]  WITH CHECK ADD  CONSTRAINT [FK_transport_change_request_student_scope] FOREIGN KEY([school_id], [branch_id], [student_id])

REFERENCES [student_schema].[student] ([school_id], [branch_id], [student_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_change_request_student_scope')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request] CHECK CONSTRAINT [FK_transport_change_request_student_scope]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_change_request_updated_by')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request]  WITH CHECK ADD  CONSTRAINT [FK_transport_change_request_updated_by] FOREIGN KEY([updated_by])

REFERENCES [security_schema].[users] ([user_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_change_request_updated_by')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request] CHECK CONSTRAINT [FK_transport_change_request_updated_by]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_speed_measurement_trip')
BEGIN
    ALTER TABLE [transport_schema].[speed_measurement]  WITH CHECK ADD  CONSTRAINT [FK_speed_measurement_trip] FOREIGN KEY([trip_id])

REFERENCES [transport_schema].[trip] ([trip_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_speed_measurement_trip')
BEGIN
    ALTER TABLE [transport_schema].[speed_measurement] CHECK CONSTRAINT [FK_speed_measurement_trip]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_speed_measurement_trip_vehicle')
BEGIN
    ALTER TABLE [transport_schema].[speed_measurement]  WITH CHECK ADD  CONSTRAINT [FK_speed_measurement_trip_vehicle] FOREIGN KEY([trip_id], [vehicle_id])

REFERENCES [transport_schema].[trip] ([trip_id], [vehicle_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_speed_measurement_trip_vehicle')
BEGIN
    ALTER TABLE [transport_schema].[speed_measurement] CHECK CONSTRAINT [FK_speed_measurement_trip_vehicle]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_speed_measurement_vehicle')
BEGIN
    ALTER TABLE [transport_schema].[speed_measurement]  WITH CHECK ADD  CONSTRAINT [FK_speed_measurement_vehicle] FOREIGN KEY([vehicle_id])

REFERENCES [transport_schema].[vehicle] ([vehicle_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_speed_measurement_vehicle')
BEGIN
    ALTER TABLE [transport_schema].[speed_measurement] CHECK CONSTRAINT [FK_speed_measurement_vehicle]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_staff_branch')
BEGIN
    ALTER TABLE [transport_schema].[staff]  WITH CHECK ADD  CONSTRAINT [FK_transport_staff_branch] FOREIGN KEY([branch_id])

REFERENCES [management_schema].[branch] ([branch_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_staff_branch')
BEGIN
    ALTER TABLE [transport_schema].[staff] CHECK CONSTRAINT [FK_transport_staff_branch]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_staff_branch_scope')
BEGIN
    ALTER TABLE [transport_schema].[staff]  WITH CHECK ADD  CONSTRAINT [FK_transport_staff_branch_scope] FOREIGN KEY([school_id], [branch_id])

REFERENCES [management_schema].[branch] ([school_id], [branch_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_staff_branch_scope')
BEGIN
    ALTER TABLE [transport_schema].[staff] CHECK CONSTRAINT [FK_transport_staff_branch_scope]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_staff_created_by')
BEGIN
    ALTER TABLE [transport_schema].[staff]  WITH CHECK ADD  CONSTRAINT [FK_transport_staff_created_by] FOREIGN KEY([created_by])

REFERENCES [security_schema].[users] ([user_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_staff_created_by')
BEGIN
    ALTER TABLE [transport_schema].[staff] CHECK CONSTRAINT [FK_transport_staff_created_by]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_staff_school')
BEGIN
    ALTER TABLE [transport_schema].[staff]  WITH CHECK ADD  CONSTRAINT [FK_transport_staff_school] FOREIGN KEY([school_id])

REFERENCES [management_schema].[school] ([school_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_staff_school')
BEGIN
    ALTER TABLE [transport_schema].[staff] CHECK CONSTRAINT [FK_transport_staff_school]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_staff_updated_by')
BEGIN
    ALTER TABLE [transport_schema].[staff]  WITH CHECK ADD  CONSTRAINT [FK_transport_staff_updated_by] FOREIGN KEY([updated_by])

REFERENCES [security_schema].[users] ([user_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_staff_updated_by')
BEGIN
    ALTER TABLE [transport_schema].[staff] CHECK CONSTRAINT [FK_transport_staff_updated_by]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_staff_user')
BEGIN
    ALTER TABLE [transport_schema].[staff]  WITH CHECK ADD  CONSTRAINT [FK_transport_staff_user] FOREIGN KEY([user_id])

REFERENCES [security_schema].[users] ([user_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_staff_user')
BEGIN
    ALTER TABLE [transport_schema].[staff] CHECK CONSTRAINT [FK_transport_staff_user]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_trip_branch')
BEGIN
    ALTER TABLE [transport_schema].[trip]  WITH CHECK ADD  CONSTRAINT [FK_trip_branch] FOREIGN KEY([branch_id])

REFERENCES [management_schema].[branch] ([branch_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_trip_branch')
BEGIN
    ALTER TABLE [transport_schema].[trip] CHECK CONSTRAINT [FK_trip_branch]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_trip_branch_scope')
BEGIN
    ALTER TABLE [transport_schema].[trip]  WITH CHECK ADD  CONSTRAINT [FK_trip_branch_scope] FOREIGN KEY([school_id], [branch_id])

REFERENCES [management_schema].[branch] ([school_id], [branch_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_trip_branch_scope')
BEGIN
    ALTER TABLE [transport_schema].[trip] CHECK CONSTRAINT [FK_trip_branch_scope]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_trip_created_by')
BEGIN
    ALTER TABLE [transport_schema].[trip]  WITH CHECK ADD  CONSTRAINT [FK_trip_created_by] FOREIGN KEY([created_by])

REFERENCES [security_schema].[users] ([user_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_trip_created_by')
BEGIN
    ALTER TABLE [transport_schema].[trip] CHECK CONSTRAINT [FK_trip_created_by]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_trip_driver')
BEGIN
    ALTER TABLE [transport_schema].[trip]  WITH CHECK ADD  CONSTRAINT [FK_trip_driver] FOREIGN KEY([driver_id], [driver_type_enforcer])

REFERENCES [transport_schema].[staff] ([staff_id], [staff_type])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_trip_driver')
BEGIN
    ALTER TABLE [transport_schema].[trip] CHECK CONSTRAINT [FK_trip_driver]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_trip_route_vehicle_type')
BEGIN
    ALTER TABLE [transport_schema].[trip]  WITH CHECK ADD  CONSTRAINT [FK_trip_route_vehicle_type] FOREIGN KEY([vehicle_route_id], [vehicle_id], [trip_type])

REFERENCES [transport_schema].[vehicle_route] ([vehicle_route_id], [vehicle_id], [route_type])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_trip_route_vehicle_type')
BEGIN
    ALTER TABLE [transport_schema].[trip] CHECK CONSTRAINT [FK_trip_route_vehicle_type]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_trip_school')
BEGIN
    ALTER TABLE [transport_schema].[trip]  WITH CHECK ADD  CONSTRAINT [FK_trip_school] FOREIGN KEY([school_id])

REFERENCES [management_schema].[school] ([school_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_trip_school')
BEGIN
    ALTER TABLE [transport_schema].[trip] CHECK CONSTRAINT [FK_trip_school]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_trip_updated_by')
BEGIN
    ALTER TABLE [transport_schema].[trip]  WITH CHECK ADD  CONSTRAINT [FK_trip_updated_by] FOREIGN KEY([updated_by])

REFERENCES [security_schema].[users] ([user_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_trip_updated_by')
BEGIN
    ALTER TABLE [transport_schema].[trip] CHECK CONSTRAINT [FK_trip_updated_by]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_trip_vehicle')
BEGIN
    ALTER TABLE [transport_schema].[trip]  WITH CHECK ADD  CONSTRAINT [FK_trip_vehicle] FOREIGN KEY([vehicle_id])

REFERENCES [transport_schema].[vehicle] ([vehicle_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_trip_vehicle')
BEGIN
    ALTER TABLE [transport_schema].[trip] CHECK CONSTRAINT [FK_trip_vehicle]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_trip_vehicle_scope')
BEGIN
    ALTER TABLE [transport_schema].[trip]  WITH CHECK ADD  CONSTRAINT [FK_trip_vehicle_scope] FOREIGN KEY([school_id], [branch_id], [vehicle_id])

REFERENCES [transport_schema].[vehicle] ([school_id], [branch_id], [vehicle_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_trip_vehicle_scope')
BEGIN
    ALTER TABLE [transport_schema].[trip] CHECK CONSTRAINT [FK_trip_vehicle_scope]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_trip_stop_route_stop_sequence')
BEGIN
    ALTER TABLE [transport_schema].[trip_stop]  WITH CHECK ADD  CONSTRAINT [FK_trip_stop_route_stop_sequence] FOREIGN KEY([vehicle_route_id], [route_stop_id], [stop_sequence])

REFERENCES [transport_schema].[vehicle_route_stop] ([vehicle_route_id], [route_stop_id], [stop_sequence])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_trip_stop_route_stop_sequence')
BEGIN
    ALTER TABLE [transport_schema].[trip_stop] CHECK CONSTRAINT [FK_trip_stop_route_stop_sequence]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_trip_stop_trip')
BEGIN
    ALTER TABLE [transport_schema].[trip_stop]  WITH CHECK ADD  CONSTRAINT [FK_trip_stop_trip] FOREIGN KEY([trip_id])

REFERENCES [transport_schema].[trip] ([trip_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_trip_stop_trip')
BEGIN
    ALTER TABLE [transport_schema].[trip_stop] CHECK CONSTRAINT [FK_trip_stop_trip]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_trip_stop_trip_route')
BEGIN
    ALTER TABLE [transport_schema].[trip_stop]  WITH CHECK ADD  CONSTRAINT [FK_trip_stop_trip_route] FOREIGN KEY([trip_id], [vehicle_route_id])

REFERENCES [transport_schema].[trip] ([trip_id], [vehicle_route_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_trip_stop_trip_route')
BEGIN
    ALTER TABLE [transport_schema].[trip_stop] CHECK CONSTRAINT [FK_trip_stop_trip_route]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_vehicle_branch')
BEGIN
    ALTER TABLE [transport_schema].[vehicle]  WITH CHECK ADD  CONSTRAINT [FK_transport_vehicle_branch] FOREIGN KEY([branch_id])

REFERENCES [management_schema].[branch] ([branch_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_vehicle_branch')
BEGIN
    ALTER TABLE [transport_schema].[vehicle] CHECK CONSTRAINT [FK_transport_vehicle_branch]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_vehicle_branch_scope')
BEGIN
    ALTER TABLE [transport_schema].[vehicle]  WITH CHECK ADD  CONSTRAINT [FK_transport_vehicle_branch_scope] FOREIGN KEY([school_id], [branch_id])

REFERENCES [management_schema].[branch] ([school_id], [branch_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_vehicle_branch_scope')
BEGIN
    ALTER TABLE [transport_schema].[vehicle] CHECK CONSTRAINT [FK_transport_vehicle_branch_scope]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_vehicle_created_by')
BEGIN
    ALTER TABLE [transport_schema].[vehicle]  WITH CHECK ADD  CONSTRAINT [FK_transport_vehicle_created_by] FOREIGN KEY([created_by])

REFERENCES [security_schema].[users] ([user_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_vehicle_created_by')
BEGIN
    ALTER TABLE [transport_schema].[vehicle] CHECK CONSTRAINT [FK_transport_vehicle_created_by]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_vehicle_school')
BEGIN
    ALTER TABLE [transport_schema].[vehicle]  WITH CHECK ADD  CONSTRAINT [FK_transport_vehicle_school] FOREIGN KEY([school_id])

REFERENCES [management_schema].[school] ([school_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_vehicle_school')
BEGIN
    ALTER TABLE [transport_schema].[vehicle] CHECK CONSTRAINT [FK_transport_vehicle_school]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_vehicle_updated_by')
BEGIN
    ALTER TABLE [transport_schema].[vehicle]  WITH CHECK ADD  CONSTRAINT [FK_transport_vehicle_updated_by] FOREIGN KEY([updated_by])

REFERENCES [security_schema].[users] ([user_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_vehicle_updated_by')
BEGIN
    ALTER TABLE [transport_schema].[vehicle] CHECK CONSTRAINT [FK_transport_vehicle_updated_by]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_vehicle_route_branch')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route]  WITH CHECK ADD  CONSTRAINT [FK_vehicle_route_branch] FOREIGN KEY([branch_id])

REFERENCES [management_schema].[branch] ([branch_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_vehicle_route_branch')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route] CHECK CONSTRAINT [FK_vehicle_route_branch]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_vehicle_route_branch_scope')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route]  WITH CHECK ADD  CONSTRAINT [FK_vehicle_route_branch_scope] FOREIGN KEY([school_id], [branch_id])

REFERENCES [management_schema].[branch] ([school_id], [branch_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_vehicle_route_branch_scope')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route] CHECK CONSTRAINT [FK_vehicle_route_branch_scope]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_vehicle_route_created_by')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route]  WITH CHECK ADD  CONSTRAINT [FK_vehicle_route_created_by] FOREIGN KEY([created_by])

REFERENCES [security_schema].[users] ([user_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_vehicle_route_created_by')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route] CHECK CONSTRAINT [FK_vehicle_route_created_by]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_vehicle_route_school')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route]  WITH CHECK ADD  CONSTRAINT [FK_vehicle_route_school] FOREIGN KEY([school_id])

REFERENCES [management_schema].[school] ([school_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_vehicle_route_school')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route] CHECK CONSTRAINT [FK_vehicle_route_school]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_vehicle_route_updated_by')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route]  WITH CHECK ADD  CONSTRAINT [FK_vehicle_route_updated_by] FOREIGN KEY([updated_by])

REFERENCES [security_schema].[users] ([user_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_vehicle_route_updated_by')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route] CHECK CONSTRAINT [FK_vehicle_route_updated_by]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_vehicle_route_vehicle')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route]  WITH CHECK ADD  CONSTRAINT [FK_vehicle_route_vehicle] FOREIGN KEY([vehicle_id])

REFERENCES [transport_schema].[vehicle] ([vehicle_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_vehicle_route_vehicle')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route] CHECK CONSTRAINT [FK_vehicle_route_vehicle]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_vehicle_route_vehicle_scope')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route]  WITH CHECK ADD  CONSTRAINT [FK_vehicle_route_vehicle_scope] FOREIGN KEY([school_id], [branch_id], [vehicle_id])

REFERENCES [transport_schema].[vehicle] ([school_id], [branch_id], [vehicle_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_vehicle_route_vehicle_scope')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route] CHECK CONSTRAINT [FK_vehicle_route_vehicle_scope]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_route_stop_created_by')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route_stop]  WITH CHECK ADD  CONSTRAINT [FK_route_stop_created_by] FOREIGN KEY([created_by])

REFERENCES [security_schema].[users] ([user_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_route_stop_created_by')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route_stop] CHECK CONSTRAINT [FK_route_stop_created_by]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_route_stop_updated_by')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route_stop]  WITH CHECK ADD  CONSTRAINT [FK_route_stop_updated_by] FOREIGN KEY([updated_by])

REFERENCES [security_schema].[users] ([user_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_route_stop_updated_by')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route_stop] CHECK CONSTRAINT [FK_route_stop_updated_by]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_route_stop_vehicle_route')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route_stop]  WITH CHECK ADD  CONSTRAINT [FK_route_stop_vehicle_route] FOREIGN KEY([vehicle_route_id])

REFERENCES [transport_schema].[vehicle_route] ([vehicle_route_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_route_stop_vehicle_route')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route_stop] CHECK CONSTRAINT [FK_route_stop_vehicle_route]
END
GO
-- Foreign Keys: transport_schema.trip_passenger_attendance
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_trip_passenger_attendance_school')
BEGIN
    ALTER TABLE [transport_schema].[trip_passenger_attendance]  WITH CHECK ADD  CONSTRAINT [FK_trip_passenger_attendance_school] FOREIGN KEY([school_id])
    REFERENCES [management_schema].[school] ([school_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_trip_passenger_attendance_school')
BEGIN
    ALTER TABLE [transport_schema].[trip_passenger_attendance] CHECK CONSTRAINT [FK_trip_passenger_attendance_school]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_trip_passenger_attendance_branch_scope')
BEGIN
    ALTER TABLE [transport_schema].[trip_passenger_attendance]  WITH CHECK ADD  CONSTRAINT [FK_trip_passenger_attendance_branch_scope] FOREIGN KEY([school_id], [branch_id])
    REFERENCES [management_schema].[branch] ([school_id], [branch_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_trip_passenger_attendance_branch_scope')
BEGIN
    ALTER TABLE [transport_schema].[trip_passenger_attendance] CHECK CONSTRAINT [FK_trip_passenger_attendance_branch_scope]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_trip_passenger_attendance_trip')
BEGIN
    ALTER TABLE [transport_schema].[trip_passenger_attendance]  WITH CHECK ADD  CONSTRAINT [FK_trip_passenger_attendance_trip] FOREIGN KEY([trip_id])
    REFERENCES [transport_schema].[trip] ([trip_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_trip_passenger_attendance_trip')
BEGIN
    ALTER TABLE [transport_schema].[trip_passenger_attendance] CHECK CONSTRAINT [FK_trip_passenger_attendance_trip]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_trip_passenger_attendance_user')
BEGIN
    ALTER TABLE [transport_schema].[trip_passenger_attendance]  WITH CHECK ADD  CONSTRAINT [FK_trip_passenger_attendance_user] FOREIGN KEY([user_id])
    REFERENCES [security_schema].[users] ([user_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_trip_passenger_attendance_user')
BEGIN
    ALTER TABLE [transport_schema].[trip_passenger_attendance] CHECK CONSTRAINT [FK_trip_passenger_attendance_user]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_trip_passenger_attendance_assignment')
BEGIN
    ALTER TABLE [transport_schema].[trip_passenger_attendance]  WITH CHECK ADD  CONSTRAINT [FK_trip_passenger_attendance_assignment] FOREIGN KEY([transport_assignment_id])
    REFERENCES [student_schema].[transport_assignment] ([transport_assignment_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_trip_passenger_attendance_assignment')
BEGIN
    ALTER TABLE [transport_schema].[trip_passenger_attendance] CHECK CONSTRAINT [FK_trip_passenger_attendance_assignment]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_trip_passenger_attendance_recorded_by')
BEGIN
    ALTER TABLE [transport_schema].[trip_passenger_attendance]  WITH CHECK ADD  CONSTRAINT [FK_trip_passenger_attendance_recorded_by] FOREIGN KEY([recorded_by])
    REFERENCES [security_schema].[users] ([user_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_trip_passenger_attendance_recorded_by')
BEGIN
    ALTER TABLE [transport_schema].[trip_passenger_attendance] CHECK CONSTRAINT [FK_trip_passenger_attendance_recorded_by]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_trip_passenger_attendance_created_by')
BEGIN
    ALTER TABLE [transport_schema].[trip_passenger_attendance]  WITH CHECK ADD  CONSTRAINT [FK_trip_passenger_attendance_created_by] FOREIGN KEY([created_by])
    REFERENCES [security_schema].[users] ([user_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_trip_passenger_attendance_created_by')
BEGIN
    ALTER TABLE [transport_schema].[trip_passenger_attendance] CHECK CONSTRAINT [FK_trip_passenger_attendance_created_by]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_trip_passenger_attendance_updated_by')
BEGIN
    ALTER TABLE [transport_schema].[trip_passenger_attendance]  WITH CHECK ADD  CONSTRAINT [FK_trip_passenger_attendance_updated_by] FOREIGN KEY([updated_by])
    REFERENCES [security_schema].[users] ([user_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_trip_passenger_attendance_updated_by')
BEGIN
    ALTER TABLE [transport_schema].[trip_passenger_attendance] CHECK CONSTRAINT [FK_trip_passenger_attendance_updated_by]
END
GO
-- Foreign Keys: transport_schema.transport_incident
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_incident_school')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident]  WITH CHECK ADD  CONSTRAINT [FK_transport_incident_school] FOREIGN KEY([school_id])
    REFERENCES [management_schema].[school] ([school_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_incident_school')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident] CHECK CONSTRAINT [FK_transport_incident_school]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_incident_branch_scope')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident]  WITH CHECK ADD  CONSTRAINT [FK_transport_incident_branch_scope] FOREIGN KEY([school_id], [branch_id])
    REFERENCES [management_schema].[branch] ([school_id], [branch_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_incident_branch_scope')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident] CHECK CONSTRAINT [FK_transport_incident_branch_scope]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_incident_vehicle')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident]  WITH CHECK ADD  CONSTRAINT [FK_transport_incident_vehicle] FOREIGN KEY([vehicle_id])
    REFERENCES [transport_schema].[vehicle] ([vehicle_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_incident_vehicle')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident] CHECK CONSTRAINT [FK_transport_incident_vehicle]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_incident_created_by')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident]  WITH CHECK ADD  CONSTRAINT [FK_transport_incident_created_by] FOREIGN KEY([created_by])
    REFERENCES [security_schema].[users] ([user_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_incident_created_by')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident] CHECK CONSTRAINT [FK_transport_incident_created_by]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_incident_updated_by')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident]  WITH CHECK ADD  CONSTRAINT [FK_transport_incident_updated_by] FOREIGN KEY([updated_by])
    REFERENCES [security_schema].[users] ([user_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_incident_updated_by')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident] CHECK CONSTRAINT [FK_transport_incident_updated_by]
END
GO
-- Foreign Keys: transport_schema.transport_incident_history
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_incident_history_school')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident_history]  WITH CHECK ADD  CONSTRAINT [FK_transport_incident_history_school] FOREIGN KEY([school_id])
    REFERENCES [management_schema].[school] ([school_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_incident_history_school')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident_history] CHECK CONSTRAINT [FK_transport_incident_history_school]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_incident_history_branch_scope')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident_history]  WITH CHECK ADD  CONSTRAINT [FK_transport_incident_history_branch_scope] FOREIGN KEY([school_id], [branch_id])
    REFERENCES [management_schema].[branch] ([school_id], [branch_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_incident_history_branch_scope')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident_history] CHECK CONSTRAINT [FK_transport_incident_history_branch_scope]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_incident_history_vehicle')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident_history]  WITH CHECK ADD  CONSTRAINT [FK_transport_incident_history_vehicle] FOREIGN KEY([vehicle_id])
    REFERENCES [transport_schema].[vehicle] ([vehicle_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_incident_history_vehicle')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident_history] CHECK CONSTRAINT [FK_transport_incident_history_vehicle]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_incident_history_updated_by')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident_history]  WITH CHECK ADD  CONSTRAINT [FK_transport_incident_history_updated_by] FOREIGN KEY([updated_by])
    REFERENCES [security_schema].[users] ([user_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_incident_history_updated_by')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident_history] CHECK CONSTRAINT [FK_transport_incident_history_updated_by]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_incident_history_incident')
BEGIN
    DELETE h
    FROM [transport_schema].[transport_incident_history] h
    WHERE NOT EXISTS (
        SELECT 1
        FROM [transport_schema].[transport_incident] i
        WHERE i.transport_incident_id = h.transport_incident_id
    );

    ALTER TABLE [transport_schema].[transport_incident_history]  WITH CHECK ADD  CONSTRAINT [FK_transport_incident_history_incident] FOREIGN KEY([transport_incident_id])
    REFERENCES [transport_schema].[transport_incident] ([transport_incident_id])
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_transport_incident_history_incident')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident_history] CHECK CONSTRAINT [FK_transport_incident_history_incident]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_transport_assignment_dates')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment]  WITH CHECK ADD  CONSTRAINT [CK_transport_assignment_dates] CHECK  (([effective_to] IS NULL OR [effective_to]>=[effective_from]))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_transport_assignment_dates')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment] CHECK CONSTRAINT [CK_transport_assignment_dates]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_transport_assignment_status')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment]  WITH CHECK ADD  CONSTRAINT [CK_transport_assignment_status] CHECK  (([status]=N'INACTIVE' OR [status]=N'ACTIVE'))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_transport_assignment_status')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment] CHECK CONSTRAINT [CK_transport_assignment_status]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_transport_assignment_stop_pair')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment]  WITH CHECK ADD  CONSTRAINT [CK_transport_assignment_stop_pair] CHECK  (([pickup_route_stop_id]<>[drop_route_stop_id]))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_transport_assignment_stop_pair')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment] CHECK CONSTRAINT [CK_transport_assignment_stop_pair]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_transport_assignment_times')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment]  WITH CHECK ADD  CONSTRAINT [CK_transport_assignment_times] CHECK  (([estimated_drop_time]>=[estimated_pickup_time]))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_transport_assignment_times')
BEGIN
    ALTER TABLE [student_schema].[transport_assignment] CHECK CONSTRAINT [CK_transport_assignment_times]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_transport_change_request_current_stop_pair')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request]  WITH CHECK ADD  CONSTRAINT [CK_transport_change_request_current_stop_pair] CHECK  (([current_pickup_stop_id]<>[current_drop_stop_id]))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_transport_change_request_current_stop_pair')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request] CHECK CONSTRAINT [CK_transport_change_request_current_stop_pair]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_transport_change_request_date_rules')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request]  WITH CHECK ADD  CONSTRAINT [CK_transport_change_request_date_rules] CHECK  (([request_type]=N'TEMPORARY' AND [return_date] IS NOT NULL AND [return_date]>=[effective_date] OR [request_type]=N'PERMANENT' AND [return_date] IS NULL))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_transport_change_request_date_rules')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request] CHECK CONSTRAINT [CK_transport_change_request_date_rules]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_transport_change_request_effective_date')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request]  WITH CHECK ADD  CONSTRAINT [CK_transport_change_request_effective_date] CHECK  (([effective_date]>='1900-01-01'))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_transport_change_request_effective_date')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request] CHECK CONSTRAINT [CK_transport_change_request_effective_date]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_transport_change_request_reason')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request]  WITH CHECK ADD  CONSTRAINT [CK_transport_change_request_reason] CHECK  ((len(ltrim(rtrim([reason])))>(0)))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_transport_change_request_reason')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request] CHECK CONSTRAINT [CK_transport_change_request_reason]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_transport_change_request_requested_all_or_none')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request]  WITH CHECK ADD  CONSTRAINT [CK_transport_change_request_requested_all_or_none] CHECK  (([requested_vehicle_route_id] IS NULL AND [requested_pickup_stop_id] IS NULL AND [requested_drop_stop_id] IS NULL OR [requested_vehicle_route_id] IS NOT NULL AND [requested_pickup_stop_id] IS NOT NULL AND [requested_drop_stop_id] IS NOT NULL))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_transport_change_request_requested_all_or_none')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request] CHECK CONSTRAINT [CK_transport_change_request_requested_all_or_none]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_transport_change_request_requested_stop_pair')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request]  WITH CHECK ADD  CONSTRAINT [CK_transport_change_request_requested_stop_pair] CHECK  (([requested_pickup_stop_id] IS NULL OR [requested_pickup_stop_id]<>[requested_drop_stop_id]))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_transport_change_request_requested_stop_pair')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request] CHECK CONSTRAINT [CK_transport_change_request_requested_stop_pair]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_transport_change_request_review_state')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request]  WITH CHECK ADD  CONSTRAINT [CK_transport_change_request_review_state] CHECK  (([reviewed_by] IS NULL AND [reviewed_at] IS NULL OR [reviewed_by] IS NOT NULL AND [reviewed_at] IS NOT NULL))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_transport_change_request_review_state')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request] CHECK CONSTRAINT [CK_transport_change_request_review_state]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_transport_change_request_status')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request]  WITH CHECK ADD  CONSTRAINT [CK_transport_change_request_status] CHECK  (([status]=N'COMPLETED' OR [status]=N'CANCELLED' OR [status]=N'REJECTED' OR [status]=N'APPROVED' OR [status]=N'PENDING'))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_transport_change_request_status')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request] CHECK CONSTRAINT [CK_transport_change_request_status]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_transport_change_request_type')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request]  WITH CHECK ADD  CONSTRAINT [CK_transport_change_request_type] CHECK  (([request_type]=N'TEMPORARY' OR [request_type]=N'PERMANENT'))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_transport_change_request_type')
BEGIN
    ALTER TABLE [student_schema].[transport_change_request] CHECK CONSTRAINT [CK_transport_change_request_type]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_speed_measurement_speed')
BEGIN
    ALTER TABLE [transport_schema].[speed_measurement]  WITH CHECK ADD  CONSTRAINT [CK_speed_measurement_speed] CHECK  (([speed_kmh]>=(0.00) AND [speed_kmh]<=(200.00)))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_speed_measurement_speed')
BEGIN
    ALTER TABLE [transport_schema].[speed_measurement] CHECK CONSTRAINT [CK_speed_measurement_speed]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_speed_measurement_latitude')
BEGIN
    ALTER TABLE [transport_schema].[speed_measurement]  WITH CHECK ADD  CONSTRAINT [CK_speed_measurement_latitude] CHECK  (([latitude] IS NULL OR [latitude] BETWEEN -90.000000 AND 90.000000))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_speed_measurement_latitude')
BEGIN
    ALTER TABLE [transport_schema].[speed_measurement] CHECK CONSTRAINT [CK_speed_measurement_latitude]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_speed_measurement_longitude')
BEGIN
    ALTER TABLE [transport_schema].[speed_measurement]  WITH CHECK ADD  CONSTRAINT [CK_speed_measurement_longitude] CHECK  (([longitude] IS NULL OR [longitude] BETWEEN -180.000000 AND 180.000000))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_speed_measurement_longitude')
BEGIN
    ALTER TABLE [transport_schema].[speed_measurement] CHECK CONSTRAINT [CK_speed_measurement_longitude]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_speed_measurement_coordinates')
BEGIN
    ALTER TABLE [transport_schema].[speed_measurement]  WITH CHECK ADD  CONSTRAINT [CK_speed_measurement_coordinates] CHECK  (([latitude] IS NULL AND [longitude] IS NULL) OR ([latitude] IS NOT NULL AND [longitude] IS NOT NULL))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_speed_measurement_coordinates')
BEGIN
    ALTER TABLE [transport_schema].[speed_measurement] CHECK CONSTRAINT [CK_speed_measurement_coordinates]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_speed_measurement_heading')
BEGIN
    ALTER TABLE [transport_schema].[speed_measurement]  WITH CHECK ADD  CONSTRAINT [CK_speed_measurement_heading] CHECK  (([heading_degrees] IS NULL OR [heading_degrees] BETWEEN 0 AND 359))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_speed_measurement_heading')
BEGIN
    ALTER TABLE [transport_schema].[speed_measurement] CHECK CONSTRAINT [CK_speed_measurement_heading]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_speed_measurement_gps_status')
BEGIN
    ALTER TABLE [transport_schema].[speed_measurement]  WITH CHECK ADD  CONSTRAINT [CK_speed_measurement_gps_status] CHECK  (([gps_fix_status] IN (N'VALID', N'NO_FIX', N'INVALID')))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_speed_measurement_gps_status')
BEGIN
    ALTER TABLE [transport_schema].[speed_measurement] CHECK CONSTRAINT [CK_speed_measurement_gps_status]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_speed_measurement_valid_coordinates')
BEGIN
    ALTER TABLE [transport_schema].[speed_measurement]  WITH CHECK ADD  CONSTRAINT [CK_speed_measurement_valid_coordinates] CHECK  (([gps_fix_status] <> N'VALID' OR ([latitude] IS NOT NULL AND [longitude] IS NOT NULL)))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_speed_measurement_valid_coordinates')
BEGIN
    ALTER TABLE [transport_schema].[speed_measurement] CHECK CONSTRAINT [CK_speed_measurement_valid_coordinates]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_transport_staff_license_date')
BEGIN
    ALTER TABLE [transport_schema].[staff]  WITH CHECK ADD  CONSTRAINT [CK_transport_staff_license_date] CHECK  (([license_expiry_date] IS NULL OR [license_expiry_date]>='1900-01-01'))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_transport_staff_license_date')
BEGIN
    ALTER TABLE [transport_schema].[staff] CHECK CONSTRAINT [CK_transport_staff_license_date]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_transport_staff_name')
BEGIN
    ALTER TABLE [transport_schema].[staff]  WITH CHECK ADD  CONSTRAINT [CK_transport_staff_name] CHECK  ((len(ltrim(rtrim([staff_name])))>(0)))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_transport_staff_name')
BEGIN
    ALTER TABLE [transport_schema].[staff] CHECK CONSTRAINT [CK_transport_staff_name]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_transport_staff_status')
BEGIN
    ALTER TABLE [transport_schema].[staff]  WITH CHECK ADD  CONSTRAINT [CK_transport_staff_status] CHECK  (([status]=N'INACTIVE' OR [status]=N'ACTIVE'))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_transport_staff_status')
BEGIN
    ALTER TABLE [transport_schema].[staff] CHECK CONSTRAINT [CK_transport_staff_status]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_transport_staff_type')
BEGIN
    ALTER TABLE [transport_schema].[staff]  WITH CHECK ADD  CONSTRAINT [CK_transport_staff_type] CHECK  (([staff_type]=N'OTHER' OR [staff_type]=N'COORDINATOR' OR [staff_type]=N'ATTENDANT' OR [staff_type]=N'DRIVER'))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_transport_staff_type')
BEGIN
    ALTER TABLE [transport_schema].[staff] CHECK CONSTRAINT [CK_transport_staff_type]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_transport_staff_experience')
BEGIN
    ALTER TABLE [transport_schema].[staff]  WITH CHECK ADD  CONSTRAINT [CK_transport_staff_experience] CHECK  (([experience]>=(0)))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_transport_staff_experience')
BEGIN
    ALTER TABLE [transport_schema].[staff] CHECK CONSTRAINT [CK_transport_staff_experience]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_trip_delay')
BEGIN
    ALTER TABLE [transport_schema].[trip]  WITH CHECK ADD  CONSTRAINT [CK_trip_delay] CHECK  (([delay_minutes] IS NULL OR [delay_minutes]>=(0)))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_trip_delay')
BEGIN
    ALTER TABLE [transport_schema].[trip] CHECK CONSTRAINT [CK_trip_delay]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_trip_driver_type')
BEGIN
    ALTER TABLE [transport_schema].[trip]  WITH CHECK ADD  CONSTRAINT [CK_trip_driver_type] CHECK  (([driver_type_enforcer]=N'DRIVER'))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_trip_driver_type')
BEGIN
    ALTER TABLE [transport_schema].[trip] CHECK CONSTRAINT [CK_trip_driver_type]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_trip_planned_times')
BEGIN
    ALTER TABLE [transport_schema].[trip]  WITH CHECK ADD  CONSTRAINT [CK_trip_planned_times] CHECK  (([planned_destination_time]>=[planned_start_time]))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_trip_planned_times')
BEGIN
    ALTER TABLE [transport_schema].[trip] CHECK CONSTRAINT [CK_trip_planned_times]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_trip_status')
BEGIN
    ALTER TABLE [transport_schema].[trip]  WITH CHECK ADD  CONSTRAINT [CK_trip_status] CHECK  (([status]=N'CANCELLED' OR [status]=N'COMPLETED' OR [status]=N'IN_TRANSIT' OR [status]=N'SCHEDULED'))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_trip_status')
BEGIN
    ALTER TABLE [transport_schema].[trip] CHECK CONSTRAINT [CK_trip_status]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_trip_time_window')
BEGIN
    ALTER TABLE [transport_schema].[trip]  WITH CHECK ADD  CONSTRAINT [CK_trip_time_window] CHECK  (([actual_start_at] IS NULL OR [actual_destination_at] IS NULL OR [actual_destination_at]>=[actual_start_at]))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_trip_time_window')
BEGIN
    ALTER TABLE [transport_schema].[trip] CHECK CONSTRAINT [CK_trip_time_window]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_trip_type')
BEGIN
    ALTER TABLE [transport_schema].[trip]  WITH CHECK ADD  CONSTRAINT [CK_trip_type] CHECK  (([trip_type]=N'DROP' OR [trip_type]=N'PICKUP'))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_trip_type')
BEGIN
    ALTER TABLE [transport_schema].[trip] CHECK CONSTRAINT [CK_trip_type]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_trip_stop_actual_time')
BEGIN
    ALTER TABLE [transport_schema].[trip_stop]  WITH CHECK ADD  CONSTRAINT [CK_trip_stop_actual_time] CHECK  (([actual_arrival_at] IS NULL OR [actual_departure_at] IS NULL OR [actual_departure_at]>=[actual_arrival_at]))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_trip_stop_actual_time')
BEGIN
    ALTER TABLE [transport_schema].[trip_stop] CHECK CONSTRAINT [CK_trip_stop_actual_time]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_trip_stop_delay')
BEGIN
    ALTER TABLE [transport_schema].[trip_stop]  WITH CHECK ADD  CONSTRAINT [CK_trip_stop_delay] CHECK  (([delay_minutes] IS NULL OR [delay_minutes]>=(0)))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_trip_stop_delay')
BEGIN
    ALTER TABLE [transport_schema].[trip_stop] CHECK CONSTRAINT [CK_trip_stop_delay]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_trip_stop_sequence')
BEGIN
    ALTER TABLE [transport_schema].[trip_stop]  WITH CHECK ADD  CONSTRAINT [CK_trip_stop_sequence] CHECK  (([stop_sequence]>(0)))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_trip_stop_sequence')
BEGIN
    ALTER TABLE [transport_schema].[trip_stop] CHECK CONSTRAINT [CK_trip_stop_sequence]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_trip_stop_status')
BEGIN
    ALTER TABLE [transport_schema].[trip_stop]  WITH CHECK ADD  CONSTRAINT [CK_trip_stop_status] CHECK  (([status]=N'SKIPPED' OR [status]=N'DEPARTED' OR [status]=N'ARRIVED' OR [status]=N'PENDING'))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_trip_stop_status')
BEGIN
    ALTER TABLE [transport_schema].[trip_stop] CHECK CONSTRAINT [CK_trip_stop_status]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_transport_vehicle_capacity')
BEGIN
    ALTER TABLE [transport_schema].[vehicle]  WITH CHECK ADD  CONSTRAINT [CK_transport_vehicle_capacity] CHECK  (([capacity]>(0)))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_transport_vehicle_capacity')
BEGIN
    ALTER TABLE [transport_schema].[vehicle] CHECK CONSTRAINT [CK_transport_vehicle_capacity]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_transport_vehicle_number')
BEGIN
    ALTER TABLE [transport_schema].[vehicle]  WITH CHECK ADD  CONSTRAINT [CK_transport_vehicle_number] CHECK  ((len(ltrim(rtrim([vehicle_number])))>(0)))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_transport_vehicle_number')
BEGIN
    ALTER TABLE [transport_schema].[vehicle] CHECK CONSTRAINT [CK_transport_vehicle_number]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_transport_vehicle_status')
BEGIN
    ALTER TABLE [transport_schema].[vehicle]  WITH CHECK ADD  CONSTRAINT [CK_transport_vehicle_status] CHECK  (([status]=N'INACTIVE' OR [status]=N'MAINTENANCE' OR [status]=N'ACTIVE'))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_transport_vehicle_status')
BEGIN
    ALTER TABLE [transport_schema].[vehicle] CHECK CONSTRAINT [CK_transport_vehicle_status]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_transport_vehicle_health')
BEGIN
    ALTER TABLE [transport_schema].[vehicle]  WITH CHECK ADD  CONSTRAINT [CK_transport_vehicle_health] CHECK  (([vehicle_health]=N'CRITICAL' OR [vehicle_health]=N'NEEDS_SERVICE' OR [vehicle_health]=N'FAIR' OR [vehicle_health]=N'GOOD' OR [vehicle_health]=N'EXCELLENT'))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_transport_vehicle_health')
BEGIN
    ALTER TABLE [transport_schema].[vehicle] CHECK CONSTRAINT [CK_transport_vehicle_health]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_vehicle_route_code')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route]  WITH CHECK ADD  CONSTRAINT [CK_vehicle_route_code] CHECK  ((len(ltrim(rtrim([route_code])))>(0)))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_vehicle_route_code')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route] CHECK CONSTRAINT [CK_vehicle_route_code]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_vehicle_route_dates')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route]  WITH CHECK ADD  CONSTRAINT [CK_vehicle_route_dates] CHECK  (([effective_to] IS NULL OR [effective_to]>=[effective_from]))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_vehicle_route_dates')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route] CHECK CONSTRAINT [CK_vehicle_route_dates]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_vehicle_route_name')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route]  WITH CHECK ADD  CONSTRAINT [CK_vehicle_route_name] CHECK  ((len(ltrim(rtrim([route_name])))>(0)))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_vehicle_route_name')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route] CHECK CONSTRAINT [CK_vehicle_route_name]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_vehicle_route_status')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route]  WITH CHECK ADD  CONSTRAINT [CK_vehicle_route_status] CHECK  (([status]=N'INACTIVE' OR [status]=N'ACTIVE'))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_vehicle_route_status')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route] CHECK CONSTRAINT [CK_vehicle_route_status]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_vehicle_route_type')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route]  WITH CHECK ADD  CONSTRAINT [CK_vehicle_route_type] CHECK  (([route_type]=N'DROP' OR [route_type]=N'PICKUP'))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_vehicle_route_type')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route] CHECK CONSTRAINT [CK_vehicle_route_type]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_route_stop_name')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route_stop]  WITH CHECK ADD  CONSTRAINT [CK_route_stop_name] CHECK  ((len(ltrim(rtrim([stop_name])))>(0)))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_route_stop_name')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route_stop] CHECK CONSTRAINT [CK_route_stop_name]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_route_stop_planned_times')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route_stop]  WITH CHECK ADD  CONSTRAINT [CK_route_stop_planned_times] CHECK  (([planned_departure_time] IS NULL OR [planned_departure_time]>=[planned_arrival_time]))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_route_stop_planned_times')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route_stop] CHECK CONSTRAINT [CK_route_stop_planned_times]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_route_stop_sequence')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route_stop]  WITH CHECK ADD  CONSTRAINT [CK_route_stop_sequence] CHECK  (([stop_sequence]>(0)))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_route_stop_sequence')
BEGIN
    ALTER TABLE [transport_schema].[vehicle_route_stop] CHECK CONSTRAINT [CK_route_stop_sequence]
END
GO
-- Check Constraints: transport_schema.trip_passenger_attendance
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_trip_passenger_attendance_boarded_status')
BEGIN
    ALTER TABLE [transport_schema].[trip_passenger_attendance]  WITH CHECK ADD  CONSTRAINT [CK_trip_passenger_attendance_boarded_status] CHECK  (([boarded_attendance_status] IS NULL OR [boarded_attendance_status] IN (N'BOARDED', N'NOT BOARDED', N'NOT TRAVELLING')))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_trip_passenger_attendance_boarded_status')
BEGIN
    ALTER TABLE [transport_schema].[trip_passenger_attendance] CHECK CONSTRAINT [CK_trip_passenger_attendance_boarded_status]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_trip_passenger_attendance_drop_status')
BEGIN
    ALTER TABLE [transport_schema].[trip_passenger_attendance]  WITH CHECK ADD  CONSTRAINT [CK_trip_passenger_attendance_drop_status] CHECK  (([drop_attendance_status] IS NULL OR [drop_attendance_status] IN (N'DROPPED', N'NOT DROPPED', N'NOT TRAVELLING')))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_trip_passenger_attendance_drop_status')
BEGIN
    ALTER TABLE [transport_schema].[trip_passenger_attendance] CHECK CONSTRAINT [CK_trip_passenger_attendance_drop_status]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_trip_passenger_attendance_status')
BEGIN
    ALTER TABLE [transport_schema].[trip_passenger_attendance]  WITH CHECK ADD  CONSTRAINT [CK_trip_passenger_attendance_status] CHECK  (([attendance_status] IS NULL OR [attendance_status] IN (N'BOARDED', N'NOT BOARDED', N'NOT TRAVELLING', N'DROPPED', N'NOT DROPPED', N'ABSENT')))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_trip_passenger_attendance_status')
BEGIN
    ALTER TABLE [transport_schema].[trip_passenger_attendance] CHECK CONSTRAINT [CK_trip_passenger_attendance_status]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_trip_passenger_attendance_boarded_time')
BEGIN
    ALTER TABLE [transport_schema].[trip_passenger_attendance]  WITH CHECK ADD  CONSTRAINT [CK_trip_passenger_attendance_boarded_time] CHECK  (([boarded_at] IS NULL OR [boarded_attendance_status] = N'BOARDED'))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_trip_passenger_attendance_boarded_time')
BEGIN
    ALTER TABLE [transport_schema].[trip_passenger_attendance] CHECK CONSTRAINT [CK_trip_passenger_attendance_boarded_time]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_trip_passenger_attendance_drop_time')
BEGIN
    ALTER TABLE [transport_schema].[trip_passenger_attendance]  WITH CHECK ADD  CONSTRAINT [CK_trip_passenger_attendance_drop_time] CHECK  (([drop_at] IS NULL OR [drop_attendance_status] = N'DROPPED'))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_trip_passenger_attendance_drop_time')
BEGIN
    ALTER TABLE [transport_schema].[trip_passenger_attendance] CHECK CONSTRAINT [CK_trip_passenger_attendance_drop_time]
END
GO
-- Check Constraints: transport_schema.transport_incident
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_transport_incident_record_type')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident]  WITH CHECK ADD  CONSTRAINT [CK_transport_incident_record_type] CHECK  (([record_type] IN (N'INCIDENT', N'AUTOMATED_ALERT')))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_transport_incident_record_type')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident] CHECK CONSTRAINT [CK_transport_incident_record_type]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_transport_incident_status')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident]  WITH CHECK ADD  CONSTRAINT [CK_transport_incident_status] CHECK  (([status] IN (N'NEW', N'IN_PROGRESS', N'RESOLVED', N'CLOSED', N'CANCELLED')))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_transport_incident_status')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident] CHECK CONSTRAINT [CK_transport_incident_status]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_transport_incident_title')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident]  WITH CHECK ADD  CONSTRAINT [CK_transport_incident_title] CHECK  ((LEN(LTRIM(RTRIM([title]))) > (0)))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_transport_incident_title')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident] CHECK CONSTRAINT [CK_transport_incident_title]
END
GO
-- Check Constraints: transport_schema.transport_incident_history
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_transport_incident_history_record_type')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident_history]  WITH CHECK ADD  CONSTRAINT [CK_transport_incident_history_record_type] CHECK  (([record_type] IN (N'INCIDENT', N'AUTOMATED_ALERT')))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_transport_incident_history_record_type')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident_history] CHECK CONSTRAINT [CK_transport_incident_history_record_type]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_transport_incident_history_title')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident_history]  WITH CHECK ADD  CONSTRAINT [CK_transport_incident_history_title] CHECK  ((LEN(LTRIM(RTRIM([title]))) > (0)))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_transport_incident_history_title')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident_history] CHECK CONSTRAINT [CK_transport_incident_history_title]
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_transport_incident_history_resolved_time')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident_history]  WITH CHECK ADD  CONSTRAINT [CK_transport_incident_history_resolved_time] CHECK  (([resolved_at] IS NULL OR [resolved_at] >= [detected_at]))
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_transport_incident_history_resolved_time')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident_history] CHECK CONSTRAINT [CK_transport_incident_history_resolved_time]
END
GO

/* ============================================================================= */
/* 2. OPERATIONAL & FILTERED PERFORMANCE INDEXES                                */
/* ============================================================================= */

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_vehicle_branch_status'
      AND object_id = OBJECT_ID(N'transport_schema.vehicle')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_vehicle_branch_status
        ON transport_schema.vehicle (school_id, branch_id, status, is_active)
        INCLUDE (vehicle_number, vehicle_name);
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_transport_staff_mobile'
      AND object_id = OBJECT_ID(N'transport_schema.staff')
)
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX IX_transport_staff_mobile
        ON transport_schema.staff (branch_id, mobile_number)
        WHERE mobile_number IS NOT NULL AND is_active = 1;
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_transport_staff_branch_status'
      AND object_id = OBJECT_ID(N'transport_schema.staff')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_transport_staff_branch_status
        ON transport_schema.staff (school_id, branch_id, staff_type, status, is_active);
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'UQ_vehicle_route_active_open'
      AND object_id = OBJECT_ID(N'transport_schema.vehicle_route')
)
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UQ_vehicle_route_active_open
        ON transport_schema.vehicle_route (vehicle_id, route_code, route_type)
        WHERE effective_to IS NULL AND is_active = 1;
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_vehicle_route_vehicle_status'
      AND object_id = OBJECT_ID(N'transport_schema.vehicle_route')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_vehicle_route_vehicle_status
        ON transport_schema.vehicle_route (vehicle_id, status, is_active);
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_vehicle_route_branch_status'
      AND object_id = OBJECT_ID(N'transport_schema.vehicle_route')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_vehicle_route_branch_status
        ON transport_schema.vehicle_route (school_id, branch_id, status, is_active);
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'UQ_trip_operational_schedule'
      AND object_id = OBJECT_ID(N'transport_schema.trip')
)
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UQ_trip_operational_schedule
        ON transport_schema.trip (vehicle_route_id, trip_date, trip_type, planned_start_time)
        WHERE is_active = 1 AND status <> N'CANCELLED';
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_trip_route_date'
      AND object_id = OBJECT_ID(N'transport_schema.trip')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_trip_route_date
        ON transport_schema.trip (vehicle_route_id, trip_date, status)
        WHERE is_active = 1;
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_trip_driver_date'
      AND object_id = OBJECT_ID(N'transport_schema.trip')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_trip_driver_date
        ON transport_schema.trip (driver_id, trip_date, status)
        WHERE is_active = 1;
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_trip_vehicle_date'
      AND object_id = OBJECT_ID(N'transport_schema.trip')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_trip_vehicle_date
        ON transport_schema.trip (vehicle_id, trip_date, status)
        WHERE is_active = 1;
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_trip_stop_trip_status'
      AND object_id = OBJECT_ID(N'transport_schema.trip_stop')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_trip_stop_trip_status
        ON transport_schema.trip_stop (trip_id, status);
END;
GO

IF EXISTS (
    SELECT 1 FROM sys.indexes i
    INNER JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
    WHERE i.name = N'IX_speed_measurement_trip_recorded'
      AND i.object_id = OBJECT_ID(N'transport_schema.speed_measurement')
      AND ic.is_descending_key = 0
      AND ic.column_id = COLUMNPROPERTY(OBJECT_ID(N'transport_schema.speed_measurement'), 'recorded_at', 'ColumnId')
)
BEGIN
    DROP INDEX IX_speed_measurement_trip_recorded ON transport_schema.speed_measurement;
END;
GO
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_speed_measurement_trip_recorded'
      AND object_id = OBJECT_ID(N'transport_schema.speed_measurement')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_speed_measurement_trip_recorded
        ON transport_schema.speed_measurement (trip_id ASC, recorded_at DESC);
END;
GO

IF EXISTS (
    SELECT 1 FROM sys.indexes i
    INNER JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
    WHERE i.name = N'IX_speed_measurement_vehicle_recorded'
      AND i.object_id = OBJECT_ID(N'transport_schema.speed_measurement')
      AND ic.is_descending_key = 0
      AND ic.column_id = COLUMNPROPERTY(OBJECT_ID(N'transport_schema.speed_measurement'), 'recorded_at', 'ColumnId')
)
BEGIN
    DROP INDEX IX_speed_measurement_vehicle_recorded ON transport_schema.speed_measurement;
END;
GO
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_speed_measurement_vehicle_recorded'
      AND object_id = OBJECT_ID(N'transport_schema.speed_measurement')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_speed_measurement_vehicle_recorded
        ON transport_schema.speed_measurement (vehicle_id ASC, recorded_at DESC);
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'UQ_transport_assignment_active_student'
      AND object_id = OBJECT_ID(N'student_schema.transport_assignment')
)
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UQ_transport_assignment_active_student
        ON student_schema.transport_assignment (school_id, branch_id, student_id)
        WHERE is_active = 1 AND status = N'ACTIVE';
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_transport_assignment_student_status'
      AND object_id = OBJECT_ID(N'student_schema.transport_assignment')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_transport_assignment_student_status
        ON student_schema.transport_assignment (student_id, status, effective_from)
        WHERE is_active = 1;
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_transport_assignment_vehicle_route'
      AND object_id = OBJECT_ID(N'student_schema.transport_assignment')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_transport_assignment_vehicle_route
        ON student_schema.transport_assignment (vehicle_route_id, status)
        INCLUDE (student_id, pickup_route_stop_id, drop_route_stop_id)
        WHERE is_active = 1;
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_transport_assignment_branch_student'
      AND object_id = OBJECT_ID(N'student_schema.transport_assignment')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_transport_assignment_branch_student
        ON student_schema.transport_assignment (school_id, branch_id, student_id, status, effective_from)
        WHERE is_active = 1;
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_transport_change_request_student_status'
      AND object_id = OBJECT_ID(N'student_schema.transport_change_request')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_transport_change_request_student_status
        ON student_schema.transport_change_request (student_id, status, effective_date)
        INCLUDE (request_type, current_vehicle_route_id, requested_vehicle_route_id)
        WHERE is_active = 1;
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_transport_change_request_pending_branch'
      AND object_id = OBJECT_ID(N'student_schema.transport_change_request')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_transport_change_request_pending_branch
        ON student_schema.transport_change_request (branch_id, status, effective_date)
        WHERE is_active = 1 AND status = N'PENDING';
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_transport_change_request_assignment'
      AND object_id = OBJECT_ID(N'student_schema.transport_change_request')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_transport_change_request_assignment
        ON student_schema.transport_change_request (transport_assignment_id)
        WHERE transport_assignment_id IS NOT NULL;
END;
GO

-- Performance Indexes: transport_schema.trip_passenger_attendance
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_trip_passenger_attendance_school_branch'
      AND object_id = OBJECT_ID(N'transport_schema.trip_passenger_attendance')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_trip_passenger_attendance_school_branch
        ON transport_schema.trip_passenger_attendance (school_id, branch_id, trip_id);
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_trip_passenger_attendance_user'
      AND object_id = OBJECT_ID(N'transport_schema.trip_passenger_attendance')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_trip_passenger_attendance_user
        ON transport_schema.trip_passenger_attendance (user_id, attendance_status);
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_trip_passenger_attendance_assignment'
      AND object_id = OBJECT_ID(N'transport_schema.trip_passenger_attendance')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_trip_passenger_attendance_assignment
        ON transport_schema.trip_passenger_attendance (transport_assignment_id)
        WHERE transport_assignment_id IS NOT NULL;
END;
GO

-- Performance Indexes: transport_schema.transport_incident
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_transport_incident_school_branch_status'
      AND object_id = OBJECT_ID(N'transport_schema.transport_incident')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_transport_incident_school_branch_status
        ON transport_schema.transport_incident (school_id, branch_id, status, is_active)
        INCLUDE (title, detected_at, vehicle_id);
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_transport_incident_vehicle'
      AND object_id = OBJECT_ID(N'transport_schema.transport_incident')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_transport_incident_vehicle
        ON transport_schema.transport_incident (vehicle_id, detected_at DESC)
        WHERE vehicle_id IS NOT NULL;
END;
GO

-- Performance Indexes: transport_schema.transport_incident_history
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_transport_incident_history_incident'
      AND object_id = OBJECT_ID(N'transport_schema.transport_incident_history')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_transport_incident_history_incident
        ON transport_schema.transport_incident_history (transport_incident_id);
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_transport_incident_history_school_branch'
      AND object_id = OBJECT_ID(N'transport_schema.transport_incident_history')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_transport_incident_history_school_branch
        ON transport_schema.transport_incident_history (school_id, branch_id, detected_at DESC);
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_transport_incident_history_vehicle'
      AND object_id = OBJECT_ID(N'transport_schema.transport_incident_history')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_transport_incident_history_vehicle
        ON transport_schema.transport_incident_history (vehicle_id, detected_at DESC)
        WHERE vehicle_id IS NOT NULL;
END;
GO

/* ============================================================================= */
/* 3. STORED PROCEDURE: transport_schema.usp_assign_student_transport          */
/* ============================================================================= */

/* 10. TRANSACTIONALLY SAFE VEHICLE CAPACITY ENFORCEMENT OPERATION            */
/* -------------------------------------------------------------------------- */

/*
    Procedure: transport_schema.usp_assign_student_transport
    Purpose:   Transactionally safe student transport assignment with optimistic/pessimistic
               locking on vehicle capacity and placement verification.

    Capacity Semantics:
    - If vehicle.capacity IS NULL, capacity is treated as unconstrained / open.
    - If vehicle.capacity IS NOT NULL (> 0), active overlapping student assignments are counted
      under UPDLOCK, HOLDLOCK to completely prevent race conditions and overbooking.
*/

CREATE OR ALTER PROCEDURE transport_schema.usp_assign_student_transport
    @school_id                   BIGINT,
    @branch_id                   BIGINT,
    @academic_year_id            BIGINT,
    @class_id                    BIGINT,
    @section_id                  BIGINT,
    @student_id                  BIGINT,
    @vehicle_route_id            BIGINT,
    @pickup_route_stop_id        BIGINT,
    @drop_route_stop_id          BIGINT,
    @estimated_pickup_time       TIME(0),
    @estimated_drop_time         TIME(0),
    @effective_from              DATE,
    @effective_to                DATE            = NULL,
    @user_id                     BIGINT,
    @new_transport_assignment_id  BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRANSACTION;

    -- 1. Identify vehicle and verify active route ownership under serialized locking
    DECLARE @vehicle_id BIGINT;
    DECLARE @vehicle_capacity INT;

    SELECT
        @vehicle_id        = vr.vehicle_id,
        @vehicle_capacity  = v.capacity
    FROM transport_schema.vehicle_route AS vr WITH (UPDLOCK, HOLDLOCK)
    INNER JOIN transport_schema.vehicle AS v WITH (UPDLOCK, HOLDLOCK)
        ON v.vehicle_id = vr.vehicle_id
       AND v.school_id = vr.school_id
       AND v.branch_id = vr.branch_id
    WHERE vr.vehicle_route_id = @vehicle_route_id
      AND vr.school_id = @school_id
      AND vr.branch_id = @branch_id
      AND vr.is_active = 1
      AND vr.status = N'ACTIVE'
      AND v.is_active = 1
      AND v.status = N'ACTIVE';

    IF @vehicle_id IS NULL
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 52001, N'Active vehicle route not found or vehicle is inactive for the given school and branch.', 1;
    END;

    -- 2. Verify student placement in academic hierarchy
    IF NOT EXISTS (
        SELECT 1
        FROM student_schema.student WITH (HOLDLOCK)
        WHERE school_id = @school_id
          AND branch_id = @branch_id
          AND academic_year_id = @academic_year_id
          AND class_id = @class_id
          AND section_id = @section_id
          AND student_id = @student_id
          AND is_active = 1
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 52002, N'Student placement context does not match registered academic placement.', 1;
    END;

    -- 3. Verify route stops belong to route
    IF NOT EXISTS (
        SELECT 1 FROM transport_schema.vehicle_route_stop
        WHERE vehicle_route_id = @vehicle_route_id AND route_stop_id = @pickup_route_stop_id AND is_active = 1
    ) OR NOT EXISTS (
        SELECT 1 FROM transport_schema.vehicle_route_stop
        WHERE vehicle_route_id = @vehicle_route_id AND route_stop_id = @drop_route_stop_id AND is_active = 1
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 52003, N'Pickup or drop route stop does not belong to the selected vehicle route.', 1;
    END;

    -- 4. Capacity Enforcement (Section 15)
    -- If vehicle capacity is specified (> 0), count all concurrent active assignments on all routes of this vehicle.
    IF @vehicle_capacity IS NOT NULL
    BEGIN
        DECLARE @active_assignments_count INT;

        SELECT @active_assignments_count = COUNT(*)
        FROM student_schema.transport_assignment AS ta WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN transport_schema.vehicle_route AS vr
            ON vr.vehicle_route_id = ta.vehicle_route_id
        WHERE vr.vehicle_id = @vehicle_id
          AND ta.is_active = 1
          AND ta.status = N'ACTIVE'
          AND ta.student_id <> @student_id
          AND ta.effective_from <= ISNULL(@effective_to, '9999-12-31')
          AND (ta.effective_to IS NULL OR ta.effective_to >= @effective_from);

        IF @active_assignments_count >= @vehicle_capacity
        BEGIN
            ROLLBACK TRANSACTION;
            THROW 52004, N'Vehicle capacity exceeded. No seats available on the vehicle for this route schedule.', 1;
        END;
    END;

    -- 5. Deactivate any existing active transport assignment for this student
    UPDATE student_schema.transport_assignment
    SET status = N'INACTIVE',
        is_active = 0,
        effective_to = DATEADD(DAY, -1, @effective_from),
        updated_at = SYSUTCDATETIME(),
        updated_by = @user_id
    WHERE school_id = @school_id
      AND branch_id = @branch_id
      AND student_id = @student_id
      AND status = N'ACTIVE'
      AND is_active = 1;

    -- 6. Insert new transport assignment
    INSERT INTO student_schema.transport_assignment
    (
        school_id,
        branch_id,
        academic_year_id,
        class_id,
        section_id,
        student_id,
        vehicle_route_id,
        pickup_route_stop_id,
        drop_route_stop_id,
        estimated_pickup_time,
        estimated_drop_time,
        effective_from,
        effective_to,
        status,
        is_active,
        created_at,
        created_by,
        updated_at,
        updated_by
    )
    VALUES
    (
        @school_id,
        @branch_id,
        @academic_year_id,
        @class_id,
        @section_id,
        @student_id,
        @vehicle_route_id,
        @pickup_route_stop_id,
        @drop_route_stop_id,
        @estimated_pickup_time,
        @estimated_drop_time,
        @effective_from,
        @effective_to,
        N'ACTIVE',
        1,
        SYSUTCDATETIME(),
        @user_id,
        SYSUTCDATETIME(),
        @user_id
    );

    SET @new_transport_assignment_id = SCOPE_IDENTITY();

    COMMIT TRANSACTION;
END;
GO
