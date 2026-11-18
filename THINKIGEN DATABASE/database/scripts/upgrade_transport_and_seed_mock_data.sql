/*
    ================================================================================
    THINKIGEN SCHOOL ERP — COMPLETE TRANSPORT MODULE UPGRADE & MOCK DATA SEEDER
    ================================================================================
    File Path     : database/scripts/upgrade_transport_and_seed_mock_data.sql
    Target Engine : Microsoft SQL Server / Azure SQL Database (SSMS Ready)
    Schemas       : transport_schema, student_schema, security_schema, management_schema
    Purpose       :
      1. SCHEMA UPGRADE & DDL (100% Idempotent):
         - Creates missing tables:
             * transport_schema.trip_passenger_attendance
             * transport_schema.transport_incident
             * transport_schema.transport_incident_history
         - Enhances transport_schema.speed_measurement with GPS telemetry columns
           (latitude, longitude, heading_degrees, gps_fix_status, received_at).
         - Adds/verifies column attachment_url on incident tables.
         - Decouples incident history from restrictive FK deletion rule.
         - Applies multi-tenant foreign keys, domain CHECK constraints, and performance indexes.
      2. MOCK DATA SEEDING (100% Relational Accuracy across all 12 entities):
         - 4 Vehicles (2 per Branch under School 1)
         - 8 Staff (4 Drivers, 4 Attendants mapped to Users 7..14)
         - 8 Master Routes (4 Pickup, 4 Drop)
         - 24 Route Stops (3 stops per route)
         - 8 Trips (Adhering to vehicle, route, driver composite FKs)
         - 24 Operational Trip Stops (departed, arrived, pending)
         - 24 Speed Measurements (Full GPS telemetry coordinates & fix statuses)
         - Day-Scholar Student Transport Assignments
         - 4 Approved Transport Change Requests
         - 35 Active Incidents (transport_schema.transport_incident)
         - 15 Resolved Incidents (transport_schema.transport_incident_history)
         - 35 Trip Passenger Attendance records
      3. POST-DEPLOYMENT VERIFICATION:
         - Complete table row counts
         - Referential integrity check across all 12 tables
         - Sample data inspections
    ================================================================================
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

PRINT N'================================================================================';
PRINT N'PART 1: TRANSPORT SCHEMA DDL & UPGRADES';
PRINT N'================================================================================';
GO

/* =============================================================================
   1. TABLE DEFINITIONS
   ============================================================================= */

-- 1A. Table: transport_schema.trip_passenger_attendance
IF OBJECT_ID(N'[transport_schema].[trip_passenger_attendance]', N'U') IS NULL
BEGIN
    CREATE TABLE [transport_schema].[trip_passenger_attendance]
    (
        [trip_passenger_attendance_id] BIGINT IDENTITY(1,1) NOT NULL,
        [school_id]                    BIGINT NOT NULL,
        [branch_id]                    BIGINT NOT NULL,
        [trip_id]                      BIGINT NOT NULL,
        [user_id]                      BIGINT NOT NULL,
        [transport_assignment_id]      BIGINT NULL,
        [boarded_attendance_status]    NVARCHAR(20) NULL,
        [boarded_at]                   DATETIME2(0) NULL,
        [drop_attendance_status]       NVARCHAR(20) NULL,
        [drop_at]                      DATETIME2(0) NULL,
        [attendance_status]            NVARCHAR(20) NULL,
        [recorded_by]                  BIGINT NULL,
        [created_at]                   DATETIME2(0) NOT NULL CONSTRAINT [DF_trip_passenger_attendance_created_at] DEFAULT (SYSUTCDATETIME()),
        [created_by]                   BIGINT NULL,
        [updated_at]                   DATETIME2(0) NOT NULL CONSTRAINT [DF_trip_passenger_attendance_updated_at] DEFAULT (SYSUTCDATETIME()),
        [updated_by]                   BIGINT NULL,
        [row_version]                  ROWVERSION NOT NULL,

        CONSTRAINT [PK_trip_passenger_attendance]
            PRIMARY KEY CLUSTERED ([trip_passenger_attendance_id] ASC),

        CONSTRAINT [UQ_trip_passenger_attendance_trip_user]
            UNIQUE NONCLUSTERED ([trip_id] ASC, [user_id] ASC)
    );
    PRINT N'✔ Created table: transport_schema.trip_passenger_attendance';
END
ELSE
BEGIN
    PRINT N'ℹ Table transport_schema.trip_passenger_attendance already exists.';
END;
GO

-- 1B. Table: transport_schema.transport_incident
IF OBJECT_ID(N'[transport_schema].[transport_incident]', N'U') IS NULL
BEGIN
    CREATE TABLE [transport_schema].[transport_incident]
    (
        [transport_incident_id] BIGINT IDENTITY(1,1) NOT NULL,
        [school_id]             BIGINT NOT NULL,
        [branch_id]             BIGINT NOT NULL,
        [title]                 NVARCHAR(200) NOT NULL,
        [description]           NVARCHAR(2000) NULL,
        [record_type]           NVARCHAR(30) NOT NULL,
        [type]                  NVARCHAR(30) NOT NULL,
        [vehicle_id]            BIGINT NULL,
        [detected_at]           DATETIME2(0) NOT NULL,
        [status]                NVARCHAR(20) NOT NULL,
        [attachment_url]        NVARCHAR(1000) NULL,
        [is_active]             BIT NOT NULL CONSTRAINT [DF_transport_incident_is_active] DEFAULT ((1)),
        [created_at]            DATETIME2(0) NOT NULL CONSTRAINT [DF_transport_incident_created_at] DEFAULT (SYSUTCDATETIME()),
        [created_by]            BIGINT NOT NULL,
        [updated_at]            DATETIME2(0) NOT NULL CONSTRAINT [DF_transport_incident_updated_at] DEFAULT (SYSUTCDATETIME()),
        [updated_by]            BIGINT NULL,
        [row_version]           ROWVERSION NOT NULL,

        CONSTRAINT [PK_transport_incident]
            PRIMARY KEY CLUSTERED ([transport_incident_id] ASC)
    );
    PRINT N'✔ Created table: transport_schema.transport_incident';
END
ELSE
BEGIN
    PRINT N'ℹ Table transport_schema.transport_incident already exists.';
    IF COL_LENGTH(N'transport_schema.transport_incident', N'attachment_url') IS NULL
    BEGIN
        ALTER TABLE [transport_schema].[transport_incident] ADD [attachment_url] NVARCHAR(1000) NULL;
        PRINT N'✔ Added column attachment_url to transport_schema.transport_incident';
    END;
END;
GO

-- 1C. Table: transport_schema.transport_incident_history
IF OBJECT_ID(N'[transport_schema].[transport_incident_history]', N'U') IS NULL
BEGIN
    CREATE TABLE [transport_schema].[transport_incident_history]
    (
        [transport_incident_history_id] BIGINT IDENTITY(1,1) NOT NULL,
        [transport_incident_id]         BIGINT NOT NULL,
        [school_id]                     BIGINT NOT NULL,
        [branch_id]                     BIGINT NOT NULL,
        [title]                         NVARCHAR(200) NOT NULL,
        [description]                   NVARCHAR(2000) NULL,
        [record_type]                   NVARCHAR(30) NOT NULL,
        [type]                          NVARCHAR(30) NOT NULL,
        [vehicle_id]                    BIGINT NULL,
        [detected_at]                   DATETIME2(0) NOT NULL,
        [resolved_at]                   DATETIME2(0) NULL,
        [attachment_url]                NVARCHAR(1000) NULL,
        [updated_at]                    DATETIME2(0) NOT NULL CONSTRAINT [DF_transport_incident_history_updated_at] DEFAULT (SYSUTCDATETIME()),
        [updated_by]                    BIGINT NOT NULL,
        [row_version]                   ROWVERSION NOT NULL,

        CONSTRAINT [PK_transport_incident_history]
            PRIMARY KEY CLUSTERED ([transport_incident_history_id] ASC)
    );
    PRINT N'✔ Created table: transport_schema.transport_incident_history';
END
ELSE
BEGIN
    PRINT N'ℹ Table transport_schema.transport_incident_history already exists.';
    IF COL_LENGTH(N'transport_schema.transport_incident_history', N'attachment_url') IS NULL
    BEGIN
        ALTER TABLE [transport_schema].[transport_incident_history] ADD [attachment_url] NVARCHAR(1000) NULL;
        PRINT N'✔ Added column attachment_url to transport_schema.transport_incident_history';
    END;
END;
GO

-- 1D. Ensure GPS Telemetry columns exist on transport_schema.speed_measurement
IF OBJECT_ID(N'[transport_schema].[speed_measurement]', N'U') IS NOT NULL
BEGIN
    IF COL_LENGTH(N'transport_schema.speed_measurement', N'latitude') IS NULL
        ALTER TABLE [transport_schema].[speed_measurement] ADD [latitude] DECIMAL(9, 6) NULL;

    IF COL_LENGTH(N'transport_schema.speed_measurement', N'longitude') IS NULL
        ALTER TABLE [transport_schema].[speed_measurement] ADD [longitude] DECIMAL(9, 6) NULL;

    IF COL_LENGTH(N'transport_schema.speed_measurement', N'heading_degrees') IS NULL
        ALTER TABLE [transport_schema].[speed_measurement] ADD [heading_degrees] SMALLINT NULL;

    IF COL_LENGTH(N'transport_schema.speed_measurement', N'gps_fix_status') IS NULL
        ALTER TABLE [transport_schema].[speed_measurement] ADD [gps_fix_status] NVARCHAR(20) NOT NULL CONSTRAINT [DF_speed_measurement_gps_fix_status] DEFAULT (N'NO_FIX');

    IF COL_LENGTH(N'transport_schema.speed_measurement', N'received_at') IS NULL
        ALTER TABLE [transport_schema].[speed_measurement] ADD [received_at] DATETIME2(0) NOT NULL CONSTRAINT [DF_speed_measurement_received_at] DEFAULT (SYSUTCDATETIME());

    PRINT N'✔ Verified GPS columns on transport_schema.speed_measurement';
END;
GO

/* =============================================================================
   2. INCIDENT HISTORY TO INCIDENT FOREIGN KEY
   ============================================================================= */
IF NOT EXISTS (
    SELECT 1
    FROM sys.foreign_keys
    WHERE name = N'FK_transport_incident_history_incident'
      AND parent_object_id = OBJECT_ID(N'transport_schema.transport_incident_history')
)
BEGIN
    -- Purge any pre-existing orphaned history records before validating constraint
    DELETE h
    FROM [transport_schema].[transport_incident_history] h
    WHERE NOT EXISTS (
        SELECT 1
        FROM [transport_schema].[transport_incident] i
        WHERE i.transport_incident_id = h.transport_incident_id
    );

    ALTER TABLE [transport_schema].[transport_incident_history] WITH CHECK
    ADD CONSTRAINT [FK_transport_incident_history_incident] FOREIGN KEY ([transport_incident_id])
    REFERENCES [transport_schema].[transport_incident] ([transport_incident_id]);
    ALTER TABLE [transport_schema].[transport_incident_history] CHECK CONSTRAINT [FK_transport_incident_history_incident];
    PRINT N'✔ Enforced FK_transport_incident_history_incident referential integrity.';
END;
GO

/* =============================================================================
   3. FOREIGN KEY CONSTRAINTS
   ============================================================================= */

-- 3A. trip_passenger_attendance FKs
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_trip_passenger_attendance_school')
BEGIN
    ALTER TABLE [transport_schema].[trip_passenger_attendance] WITH CHECK
    ADD CONSTRAINT [FK_trip_passenger_attendance_school] FOREIGN KEY ([school_id])
    REFERENCES [management_schema].[school] ([school_id]);
    ALTER TABLE [transport_schema].[trip_passenger_attendance] CHECK CONSTRAINT [FK_trip_passenger_attendance_school];
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_trip_passenger_attendance_branch_scope')
BEGIN
    ALTER TABLE [transport_schema].[trip_passenger_attendance] WITH CHECK
    ADD CONSTRAINT [FK_trip_passenger_attendance_branch_scope] FOREIGN KEY ([school_id], [branch_id])
    REFERENCES [management_schema].[branch] ([school_id], [branch_id]);
    ALTER TABLE [transport_schema].[trip_passenger_attendance] CHECK CONSTRAINT [FK_trip_passenger_attendance_branch_scope];
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_trip_passenger_attendance_trip')
BEGIN
    ALTER TABLE [transport_schema].[trip_passenger_attendance] WITH CHECK
    ADD CONSTRAINT [FK_trip_passenger_attendance_trip] FOREIGN KEY ([trip_id])
    REFERENCES [transport_schema].[trip] ([trip_id]);
    ALTER TABLE [transport_schema].[trip_passenger_attendance] CHECK CONSTRAINT [FK_trip_passenger_attendance_trip];
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_trip_passenger_attendance_user')
BEGIN
    ALTER TABLE [transport_schema].[trip_passenger_attendance] WITH CHECK
    ADD CONSTRAINT [FK_trip_passenger_attendance_user] FOREIGN KEY ([user_id])
    REFERENCES [security_schema].[users] ([user_id]);
    ALTER TABLE [transport_schema].[trip_passenger_attendance] CHECK CONSTRAINT [FK_trip_passenger_attendance_user];
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_trip_passenger_attendance_assignment')
BEGIN
    ALTER TABLE [transport_schema].[trip_passenger_attendance] WITH CHECK
    ADD CONSTRAINT [FK_trip_passenger_attendance_assignment] FOREIGN KEY ([transport_assignment_id])
    REFERENCES [student_schema].[transport_assignment] ([transport_assignment_id]);
    ALTER TABLE [transport_schema].[trip_passenger_attendance] CHECK CONSTRAINT [FK_trip_passenger_attendance_assignment];
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_trip_passenger_attendance_recorded_by')
BEGIN
    ALTER TABLE [transport_schema].[trip_passenger_attendance] WITH CHECK
    ADD CONSTRAINT [FK_trip_passenger_attendance_recorded_by] FOREIGN KEY ([recorded_by])
    REFERENCES [security_schema].[users] ([user_id]);
    ALTER TABLE [transport_schema].[trip_passenger_attendance] CHECK CONSTRAINT [FK_trip_passenger_attendance_recorded_by];
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_trip_passenger_attendance_created_by')
BEGIN
    ALTER TABLE [transport_schema].[trip_passenger_attendance] WITH CHECK
    ADD CONSTRAINT [FK_trip_passenger_attendance_created_by] FOREIGN KEY ([created_by])
    REFERENCES [security_schema].[users] ([user_id]);
    ALTER TABLE [transport_schema].[trip_passenger_attendance] CHECK CONSTRAINT [FK_trip_passenger_attendance_created_by];
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_trip_passenger_attendance_updated_by')
BEGIN
    ALTER TABLE [transport_schema].[trip_passenger_attendance] WITH CHECK
    ADD CONSTRAINT [FK_trip_passenger_attendance_updated_by] FOREIGN KEY ([updated_by])
    REFERENCES [security_schema].[users] ([user_id]);
    ALTER TABLE [transport_schema].[trip_passenger_attendance] CHECK CONSTRAINT [FK_trip_passenger_attendance_updated_by];
END;
GO

-- 3B. transport_incident FKs
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_incident_school')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident] WITH CHECK
    ADD CONSTRAINT [FK_transport_incident_school] FOREIGN KEY ([school_id])
    REFERENCES [management_schema].[school] ([school_id]);
    ALTER TABLE [transport_schema].[transport_incident] CHECK CONSTRAINT [FK_transport_incident_school];
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_incident_branch_scope')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident] WITH CHECK
    ADD CONSTRAINT [FK_transport_incident_branch_scope] FOREIGN KEY ([school_id], [branch_id])
    REFERENCES [management_schema].[branch] ([school_id], [branch_id]);
    ALTER TABLE [transport_schema].[transport_incident] CHECK CONSTRAINT [FK_transport_incident_branch_scope];
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_incident_vehicle')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident] WITH CHECK
    ADD CONSTRAINT [FK_transport_incident_vehicle] FOREIGN KEY ([vehicle_id])
    REFERENCES [transport_schema].[vehicle] ([vehicle_id]);
    ALTER TABLE [transport_schema].[transport_incident] CHECK CONSTRAINT [FK_transport_incident_vehicle];
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_incident_created_by')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident] WITH CHECK
    ADD CONSTRAINT [FK_transport_incident_created_by] FOREIGN KEY ([created_by])
    REFERENCES [security_schema].[users] ([user_id]);
    ALTER TABLE [transport_schema].[transport_incident] CHECK CONSTRAINT [FK_transport_incident_created_by];
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_incident_updated_by')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident] WITH CHECK
    ADD CONSTRAINT [FK_transport_incident_updated_by] FOREIGN KEY ([updated_by])
    REFERENCES [security_schema].[users] ([user_id]);
    ALTER TABLE [transport_schema].[transport_incident] CHECK CONSTRAINT [FK_transport_incident_updated_by];
END;
GO

-- 3C. transport_incident_history FKs
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_incident_history_school')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident_history] WITH CHECK
    ADD CONSTRAINT [FK_transport_incident_history_school] FOREIGN KEY ([school_id])
    REFERENCES [management_schema].[school] ([school_id]);
    ALTER TABLE [transport_schema].[transport_incident_history] CHECK CONSTRAINT [FK_transport_incident_history_school];
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_incident_history_branch_scope')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident_history] WITH CHECK
    ADD CONSTRAINT [FK_transport_incident_history_branch_scope] FOREIGN KEY ([school_id], [branch_id])
    REFERENCES [management_schema].[branch] ([school_id], [branch_id]);
    ALTER TABLE [transport_schema].[transport_incident_history] CHECK CONSTRAINT [FK_transport_incident_history_branch_scope];
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_incident_history_vehicle')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident_history] WITH CHECK
    ADD CONSTRAINT [FK_transport_incident_history_vehicle] FOREIGN KEY ([vehicle_id])
    REFERENCES [transport_schema].[vehicle] ([vehicle_id]);
    ALTER TABLE [transport_schema].[transport_incident_history] CHECK CONSTRAINT [FK_transport_incident_history_vehicle];
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_transport_incident_history_updated_by')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident_history] WITH CHECK
    ADD CONSTRAINT [FK_transport_incident_history_updated_by] FOREIGN KEY ([updated_by])
    REFERENCES [security_schema].[users] ([user_id]);
    ALTER TABLE [transport_schema].[transport_incident_history] CHECK CONSTRAINT [FK_transport_incident_history_updated_by];
END;
GO

/* =============================================================================
   4. CHECK CONSTRAINTS
   ============================================================================= */

-- 4A. speed_measurement CHECK constraints
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_speed_measurement_latitude')
BEGIN
    ALTER TABLE [transport_schema].[speed_measurement] WITH CHECK
    ADD CONSTRAINT [CK_speed_measurement_latitude] CHECK ([latitude] IS NULL OR [latitude] BETWEEN -90.000000 AND 90.000000);
    ALTER TABLE [transport_schema].[speed_measurement] CHECK CONSTRAINT [CK_speed_measurement_latitude];
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_speed_measurement_longitude')
BEGIN
    ALTER TABLE [transport_schema].[speed_measurement] WITH CHECK
    ADD CONSTRAINT [CK_speed_measurement_longitude] CHECK ([longitude] IS NULL OR [longitude] BETWEEN -180.000000 AND 180.000000);
    ALTER TABLE [transport_schema].[speed_measurement] CHECK CONSTRAINT [CK_speed_measurement_longitude];
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_speed_measurement_coordinates')
BEGIN
    ALTER TABLE [transport_schema].[speed_measurement] WITH CHECK
    ADD CONSTRAINT [CK_speed_measurement_coordinates] CHECK (([latitude] IS NULL AND [longitude] IS NULL) OR ([latitude] IS NOT NULL AND [longitude] IS NOT NULL));
    ALTER TABLE [transport_schema].[speed_measurement] CHECK CONSTRAINT [CK_speed_measurement_coordinates];
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_speed_measurement_heading')
BEGIN
    ALTER TABLE [transport_schema].[speed_measurement] WITH CHECK
    ADD CONSTRAINT [CK_speed_measurement_heading] CHECK ([heading_degrees] IS NULL OR [heading_degrees] BETWEEN 0 AND 359);
    ALTER TABLE [transport_schema].[speed_measurement] CHECK CONSTRAINT [CK_speed_measurement_heading];
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_speed_measurement_gps_status')
BEGIN
    ALTER TABLE [transport_schema].[speed_measurement] WITH CHECK
    ADD CONSTRAINT [CK_speed_measurement_gps_status] CHECK ([gps_fix_status] IN (N'VALID', N'NO_FIX', N'INVALID'));
    ALTER TABLE [transport_schema].[speed_measurement] CHECK CONSTRAINT [CK_speed_measurement_gps_status];
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_speed_measurement_valid_coordinates')
BEGIN
    ALTER TABLE [transport_schema].[speed_measurement] WITH CHECK
    ADD CONSTRAINT [CK_speed_measurement_valid_coordinates] CHECK ([gps_fix_status] <> N'VALID' OR ([latitude] IS NOT NULL AND [longitude] IS NOT NULL));
    ALTER TABLE [transport_schema].[speed_measurement] CHECK CONSTRAINT [CK_speed_measurement_valid_coordinates];
END;
GO

-- 4B. trip_passenger_attendance CHECK constraints
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_trip_passenger_attendance_boarded_status')
BEGIN
    ALTER TABLE [transport_schema].[trip_passenger_attendance] WITH CHECK
    ADD CONSTRAINT [CK_trip_passenger_attendance_boarded_status] CHECK ([boarded_attendance_status] IS NULL OR [boarded_attendance_status] IN (N'BOARDED', N'NOT BOARDED', N'NOT TRAVELLING'));
    ALTER TABLE [transport_schema].[trip_passenger_attendance] CHECK CONSTRAINT [CK_trip_passenger_attendance_boarded_status];
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_trip_passenger_attendance_drop_status')
BEGIN
    ALTER TABLE [transport_schema].[trip_passenger_attendance] WITH CHECK
    ADD CONSTRAINT [CK_trip_passenger_attendance_drop_status] CHECK ([drop_attendance_status] IS NULL OR [drop_attendance_status] IN (N'DROPPED', N'NOT DROPPED', N'NOT TRAVELLING'));
    ALTER TABLE [transport_schema].[trip_passenger_attendance] CHECK CONSTRAINT [CK_trip_passenger_attendance_drop_status];
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_trip_passenger_attendance_status')
BEGIN
    ALTER TABLE [transport_schema].[trip_passenger_attendance] WITH CHECK
    ADD CONSTRAINT [CK_trip_passenger_attendance_status] CHECK ([attendance_status] IS NULL OR [attendance_status] IN (N'BOARDED', N'NOT BOARDED', N'NOT TRAVELLING', N'DROPPED', N'NOT DROPPED', N'ABSENT'));
    ALTER TABLE [transport_schema].[trip_passenger_attendance] CHECK CONSTRAINT [CK_trip_passenger_attendance_status];
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_trip_passenger_attendance_boarded_time')
BEGIN
    ALTER TABLE [transport_schema].[trip_passenger_attendance] WITH CHECK
    ADD CONSTRAINT [CK_trip_passenger_attendance_boarded_time] CHECK ([boarded_at] IS NULL OR [boarded_attendance_status] = N'BOARDED');
    ALTER TABLE [transport_schema].[trip_passenger_attendance] CHECK CONSTRAINT [CK_trip_passenger_attendance_boarded_time];
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_trip_passenger_attendance_drop_time')
BEGIN
    ALTER TABLE [transport_schema].[trip_passenger_attendance] WITH CHECK
    ADD CONSTRAINT [CK_trip_passenger_attendance_drop_time] CHECK ([drop_at] IS NULL OR [drop_attendance_status] = N'DROPPED');
    ALTER TABLE [transport_schema].[trip_passenger_attendance] CHECK CONSTRAINT [CK_trip_passenger_attendance_drop_time];
END;
GO

-- 4C. transport_incident CHECK constraints
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_transport_incident_record_type')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident] WITH CHECK
    ADD CONSTRAINT [CK_transport_incident_record_type] CHECK ([record_type] IN (N'INCIDENT', N'AUTOMATED_ALERT'));
    ALTER TABLE [transport_schema].[transport_incident] CHECK CONSTRAINT [CK_transport_incident_record_type];
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_transport_incident_status')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident] WITH CHECK
    ADD CONSTRAINT [CK_transport_incident_status] CHECK ([status] IN (N'NEW', N'IN_PROGRESS', N'RESOLVED', N'CLOSED', N'CANCELLED'));
    ALTER TABLE [transport_schema].[transport_incident] CHECK CONSTRAINT [CK_transport_incident_status];
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_transport_incident_title')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident] WITH CHECK
    ADD CONSTRAINT [CK_transport_incident_title] CHECK (LEN(LTRIM(RTRIM([title]))) > 0);
    ALTER TABLE [transport_schema].[transport_incident] CHECK CONSTRAINT [CK_transport_incident_title];
END;
GO

-- 4D. transport_incident_history CHECK constraints
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_transport_incident_history_record_type')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident_history] WITH CHECK
    ADD CONSTRAINT [CK_transport_incident_history_record_type] CHECK ([record_type] IN (N'INCIDENT', N'AUTOMATED_ALERT'));
    ALTER TABLE [transport_schema].[transport_incident_history] CHECK CONSTRAINT [CK_transport_incident_history_record_type];
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_transport_incident_history_title')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident_history] WITH CHECK
    ADD CONSTRAINT [CK_transport_incident_history_title] CHECK (LEN(LTRIM(RTRIM([title]))) > 0);
    ALTER TABLE [transport_schema].[transport_incident_history] CHECK CONSTRAINT [CK_transport_incident_history_title];
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_transport_incident_history_resolved_time')
BEGIN
    ALTER TABLE [transport_schema].[transport_incident_history] WITH CHECK
    ADD CONSTRAINT [CK_transport_incident_history_resolved_time] CHECK ([resolved_at] IS NULL OR [resolved_at] >= [detected_at]);
    ALTER TABLE [transport_schema].[transport_incident_history] CHECK CONSTRAINT [CK_transport_incident_history_resolved_time];
END;
GO

/* =============================================================================
   5. PERFORMANCE INDEXES
   ============================================================================= */

-- 5A. speed_measurement descending time indexes
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

-- 5B. trip_passenger_attendance indexes
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

-- 5C. transport_incident indexes
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

-- 5D. transport_incident_history indexes
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

PRINT N'✔ Finished Transport Schema DDL, Constraints & Indexes successfully.';
GO

/* =============================================================================
   6. COMPLETE MOCK DATA SEEDING (TRANSACTIONALLY SAFE & RE-RUNNABLE)
   ============================================================================= */

PRINT N'================================================================================';
PRINT N'PART 2: SEEDING ALL 12 TRANSPORT ENTITIES WITH 100% RELATIONAL ACCURACY';
PRINT N'================================================================================';
GO

BEGIN TRY
    BEGIN TRANSACTION;

    -- Preflight check: Ensure base parent data exists
    IF NOT EXISTS (SELECT 1 FROM management_schema.school WHERE school_id = 1)
       OR NOT EXISTS (SELECT 1 FROM management_schema.branch WHERE school_id = 1 AND branch_id IN (1, 2))
    BEGIN
        THROW 51000, 'Master school or branch records missing (School 1, Branches 1 & 2 required). Please run base management seed first.', 1;
    END;

    -- Ensure transport staff users exist in security_schema.users (Users 7..14)
    IF NOT EXISTS (SELECT 1 FROM security_schema.users WHERE user_id BETWEEN 7 AND 14)
    BEGIN
        PRINT N'ℹ Inserting missing transport users (IDs 6..14) into security_schema.users...';
        SET IDENTITY_INSERT security_schema.users ON;
        INSERT INTO security_schema.users
            (user_id, email_address, user_type, is_active, password_hash, password_plain_dev, password_set_at, failed_login_count, locked_until, last_login_at)
        VALUES
            (6,  N'mgt_1206@schoolname.edu', N'TRANSPORT', 1, NULL, N'Test@12345', '2026-04-01T08:00:00', 0, NULL, NULL),
            (7,  N'mgt_1207@schoolname.edu', N'TRANSPORT', 1, NULL, N'Test@12345', '2026-04-01T08:00:00', 0, NULL, NULL),
            (8,  N'mgt_1208@schoolname.edu', N'TRANSPORT', 1, NULL, N'Test@12345', '2026-04-01T08:00:00', 0, NULL, NULL),
            (9,  N'mgt_1209@schoolname.edu', N'TRANSPORT', 1, NULL, N'Test@12345', '2026-04-01T08:00:00', 0, NULL, NULL),
            (10, N'mgt_1210@schoolname.edu', N'TRANSPORT', 1, NULL, N'Test@12345', '2026-04-01T08:00:00', 0, NULL, NULL),
            (11, N'mgt_1211@schoolname.edu', N'TRANSPORT', 1, NULL, N'Test@12345', '2026-04-01T08:00:00', 0, NULL, NULL),
            (12, N'mgt_1212@schoolname.edu', N'TRANSPORT', 1, NULL, N'Test@12345', '2026-04-01T08:00:00', 0, NULL, NULL),
            (13, N'mgt_1213@schoolname.edu', N'TRANSPORT', 1, NULL, N'Test@12345', '2026-04-01T08:00:00', 0, NULL, NULL),
            (14, N'mgt_1214@schoolname.edu', N'TRANSPORT', 1, NULL, N'Test@12345', '2026-04-01T08:00:00', 0, NULL, NULL);
        SET IDENTITY_INSERT security_schema.users OFF;
    END;

    -- Clean up previous mock entries from all transport tables in strict child-to-parent order
    DELETE FROM student_schema.transport_change_request;
    DELETE FROM transport_schema.trip_passenger_attendance;
    DELETE FROM student_schema.transport_assignment;
    DELETE FROM transport_schema.transport_incident_history;
    DELETE FROM transport_schema.transport_incident;
    DELETE FROM transport_schema.speed_measurement;
    DELETE FROM transport_schema.trip_stop;
    DELETE FROM transport_schema.trip;
    DELETE FROM transport_schema.vehicle_route_stop;
    DELETE FROM transport_schema.vehicle_route;
    DELETE FROM transport_schema.staff;
    DELETE FROM transport_schema.vehicle;
    PRINT N'✔ Cleaned existing transport mock records.';

    /* --------------------------------------------------------------------------
       6.1 SEED: transport_schema.vehicle (4 Vehicles: 2 per Branch under School 1)
       -------------------------------------------------------------------------- */
    SET IDENTITY_INSERT transport_schema.vehicle ON;
    INSERT INTO transport_schema.vehicle
      (vehicle_id, school_id, branch_id, vehicle_number, vehicle_name, capacity, status, vehicle_health, is_active, created_by)
    VALUES
      (1, 1, 1, N'TG-01-AB-1001', N'Central Campus Bus A', 50, N'ACTIVE', N'EXCELLENT',     1, 1),
      (2, 1, 1, N'TG-01-AB-1002', N'Central Campus Bus B', 50, N'ACTIVE', N'GOOD',          1, 1),
      (3, 1, 2, N'TG-02-AB-2001', N'North Campus Bus A',   50, N'ACTIVE', N'GOOD',          1, 1),
      (4, 1, 2, N'TG-02-AB-2002', N'North Campus Bus B',   50, N'ACTIVE', N'NEEDS_SERVICE', 1, 1);
    SET IDENTITY_INSERT transport_schema.vehicle OFF;
    PRINT N'✔ Seeded transport_schema.vehicle (4 rows)';

    /* --------------------------------------------------------------------------
       6.2 SEED: transport_schema.staff (8 Staff: Users 7..14)
       -------------------------------------------------------------------------- */
    SET IDENTITY_INSERT transport_schema.staff ON;
    INSERT INTO transport_schema.staff
      (staff_id, school_id, branch_id, user_id, staff_name, staff_type, experience, mobile_number, license_number,
       license_expiry_date, status, is_active, created_by)
    VALUES
      -- Drivers (Users 7..10)
      (1, 1, 1, 7,  N'Ravi Kumar',   N'DRIVER',    12, N'919800000001', N'TS-DRV-1001', '2028-12-31', N'ACTIVE', 1, 1),
      (2, 1, 1, 8,  N'Suresh Naidu', N'DRIVER',     9, N'919800000002', N'TS-DRV-1002', '2028-12-31', N'ACTIVE', 1, 1),
      (3, 1, 2, 9,  N'Vijay Reddy',  N'DRIVER',    14, N'919800000003', N'TS-DRV-2001', '2028-12-31', N'ACTIVE', 1, 1),
      (4, 1, 2, 10, N'Prakash Rao',  N'DRIVER',     8, N'919800000004', N'TS-DRV-2002', '2028-12-31', N'ACTIVE', 1, 1),
      -- Attendants (Users 11..14)
      (5, 1, 1, 11, N'Mohan Rao',    N'ATTENDANT',  5, N'919800000005', NULL,            NULL,         N'ACTIVE', 1, 1),
      (6, 1, 1, 12, N'Karthik Rao',  N'ATTENDANT',  4, N'919800000006', NULL,            NULL,         N'ACTIVE', 1, 1),
      (7, 1, 2, 13, N'Imran Ali',    N'ATTENDANT',  6, N'919800000007', NULL,            NULL,         N'ACTIVE', 1, 1),
      (8, 1, 2, 14, N'Anil Kumar',   N'ATTENDANT',  3, N'919800000008', NULL,            NULL,         N'ACTIVE', 1, 1);
    SET IDENTITY_INSERT transport_schema.staff OFF;
    PRINT N'✔ Seeded transport_schema.staff (8 rows: 4 Drivers + 4 Attendants)';

    /* --------------------------------------------------------------------------
       6.3 SEED: transport_schema.vehicle_route (8 Master Routes: 4 PU + 4 DR)
       -------------------------------------------------------------------------- */
    SET IDENTITY_INSERT transport_schema.vehicle_route ON;
    INSERT INTO transport_schema.vehicle_route
      (vehicle_route_id, school_id, branch_id, vehicle_id, route_code, route_name, route_type,
       status, effective_from, effective_to, is_active, created_by)
    VALUES
      -- Branch 1 Routes (Vehicles 1 & 2)
      (1, 1, 1, 1, N'BR1-PU1', N'Central Route 1 Morning Pickup', N'PICKUP', N'ACTIVE', '2026-04-01', NULL, 1, 1),
      (2, 1, 1, 1, N'BR1-DR1', N'Central Route 1 Afternoon Drop',  N'DROP',   N'ACTIVE', '2026-04-01', NULL, 1, 1),
      (3, 1, 1, 2, N'BR1-PU2', N'Central Route 2 Morning Pickup', N'PICKUP', N'ACTIVE', '2026-04-01', NULL, 1, 1),
      (4, 1, 1, 2, N'BR1-DR2', N'Central Route 2 Afternoon Drop',  N'DROP',   N'ACTIVE', '2026-04-01', NULL, 1, 1),
      -- Branch 2 Routes (Vehicles 3 & 4)
      (5, 1, 2, 3, N'BR2-PU1', N'North Route 1 Morning Pickup',   N'PICKUP', N'ACTIVE', '2026-04-01', NULL, 1, 1),
      (6, 1, 2, 3, N'BR2-DR1', N'North Route 1 Afternoon Drop',   N'DROP',   N'ACTIVE', '2026-04-01', NULL, 1, 1),
      (7, 1, 2, 4, N'BR2-PU2', N'North Route 2 Morning Pickup',   N'PICKUP', N'ACTIVE', '2026-04-01', NULL, 1, 1),
      (8, 1, 2, 4, N'BR2-DR2', N'North Route 2 Afternoon Drop',   N'DROP',   N'ACTIVE', '2026-04-01', NULL, 1, 1);
    SET IDENTITY_INSERT transport_schema.vehicle_route OFF;
    PRINT N'✔ Seeded transport_schema.vehicle_route (8 master routes)';

    /* --------------------------------------------------------------------------
       6.4 SEED: transport_schema.vehicle_route_stop (24 Stops: 3 Stops per Route)
       -------------------------------------------------------------------------- */
    SET IDENTITY_INSERT transport_schema.vehicle_route_stop ON;
    INSERT INTO transport_schema.vehicle_route_stop
      (route_stop_id, vehicle_route_id, stop_sequence, stop_name, stop_address,
       planned_arrival_time, planned_departure_time, is_active, created_by)
    VALUES
      -- Route 1: Central Route 1 Morning Pickup
      (101, 1, 1, N'Jubilee Hills Check Post', N'Road No 36, Jubilee Hills', '07:10', '07:12', 1, 1),
      (102, 1, 2, N'Madhapur Metro Station',   N'Hitec City Main Road',      '07:25', '07:27', 1, 1),
      (103, 1, 3, N'Central Campus Gate',     N'Campus Main Entrance',       '08:05', '08:10', 1, 1),
      -- Route 2: Central Route 1 Afternoon Drop
      (104, 2, 1, N'Central Campus Gate',     N'Campus Main Entrance',       '15:10', '15:12', 1, 1),
      (105, 2, 2, N'Madhapur Metro Station',   N'Hitec City Main Road',      '15:35', '15:37', 1, 1),
      (106, 2, 3, N'Jubilee Hills Check Post', N'Road No 36, Jubilee Hills', '15:50', '15:52', 1, 1),
      -- Route 3: Central Route 2 Morning Pickup
      (107, 3, 1, N'Banjara Hills Care Hospital', N'Road No 1, Banjara Hills','07:10', '07:12', 1, 1),
      (108, 3, 2, N'Somajiguda Circle',        N'Raj Bhavan Road',           '07:25', '07:27', 1, 1),
      (109, 3, 3, N'Central Campus Gate',     N'Campus Main Entrance',       '08:05', '08:10', 1, 1),
      -- Route 4: Central Route 2 Afternoon Drop
      (110, 4, 1, N'Central Campus Gate',     N'Campus Main Entrance',       '15:10', '15:12', 1, 1),
      (111, 4, 2, N'Somajiguda Circle',        N'Raj Bhavan Road',           '15:35', '15:37', 1, 1),
      (112, 4, 3, N'Banjara Hills Care Hospital', N'Road No 1, Banjara Hills','15:50', '15:52', 1, 1),
      -- Route 5: North Route 1 Morning Pickup
      (201, 5, 1, N'Secunderabad Clock Tower', N'MG Road, Secunderabad',     '07:10', '07:12', 1, 1),
      (202, 5, 2, N'Paradise Circle',          N'Airport Road',              '07:25', '07:27', 1, 1),
      (203, 5, 3, N'North Campus Gate',        N'North Campus Entrance',     '08:05', '08:10', 1, 1),
      -- Route 6: North Route 1 Afternoon Drop
      (204, 6, 1, N'North Campus Gate',        N'North Campus Entrance',     '15:10', '15:12', 1, 1),
      (205, 6, 2, N'Paradise Circle',          N'Airport Road',              '15:35', '15:37', 1, 1),
      (206, 6, 3, N'Secunderabad Clock Tower', N'MG Road, Secunderabad',     '15:50', '15:52', 1, 1),
      -- Route 7: North Route 2 Morning Pickup
      (207, 7, 1, N'Trimulgherry Cross Road',  N'Military Area Junction',    '07:10', '07:12', 1, 1),
      (208, 7, 2, N'Karkhana Main Road',       N'APHB Colony Road',          '07:25', '07:27', 1, 1),
      (209, 7, 3, N'North Campus Gate',        N'North Campus Entrance',     '08:05', '08:10', 1, 1),
      -- Route 8: North Route 2 Afternoon Drop
      (210, 8, 1, N'North Campus Gate',        N'North Campus Entrance',     '15:10', '15:12', 1, 1),
      (211, 8, 2, N'Karkhana Main Road',       N'APHB Colony Road',          '15:35', '15:37', 1, 1),
      (212, 8, 3, N'Trimulgherry Cross Road',  N'Military Area Junction',    '15:50', '15:52', 1, 1);
    SET IDENTITY_INSERT transport_schema.vehicle_route_stop OFF;
    PRINT N'✔ Seeded transport_schema.vehicle_route_stop (24 route stops)';

    /* --------------------------------------------------------------------------
       6.5 SEED: transport_schema.trip (8 Trips: 4 Pickup + 4 Drop)
       -------------------------------------------------------------------------- */
    DECLARE @SeedTripDate DATE = '2026-09-01';

    SET IDENTITY_INSERT transport_schema.trip ON;
    INSERT INTO transport_schema.trip
      (trip_id, school_id, branch_id, vehicle_id, vehicle_route_id, driver_id, driver_type_enforcer,
       trip_date, trip_type, planned_start_time, planned_destination_time, actual_start_at,
       actual_destination_at, delay_minutes, status, is_active, created_by)
    VALUES
      -- Branch 1: Bus 1 (Driver 1: Ravi Kumar)
      (1, 1, 1, 1, 1, 1, N'DRIVER', @SeedTripDate, N'PICKUP', '07:00', '08:10', '2026-09-01 07:03:00', '2026-09-01 08:13:00', 3, N'COMPLETED', 1, 1),
      (2, 1, 1, 1, 2, 1, N'DRIVER', @SeedTripDate, N'DROP',   '15:00', '15:55', '2026-09-01 15:02:00', '2026-09-01 15:58:00', 3, N'COMPLETED', 1, 1),
      -- Branch 1: Bus 2 (Driver 2: Suresh Naidu)
      (3, 1, 1, 2, 3, 2, N'DRIVER', @SeedTripDate, N'PICKUP', '07:00', '08:10', '2026-09-01 07:01:00', '2026-09-01 08:12:00', 2, N'COMPLETED', 1, 1),
      (4, 1, 1, 2, 4, 2, N'DRIVER', @SeedTripDate, N'DROP',   '15:00', '15:55', '2026-09-01 15:04:00', '2026-09-01 15:59:00', 4, N'COMPLETED', 1, 1),
      -- Branch 2: Bus 3 (Driver 3: Vijay Reddy)
      (5, 1, 2, 3, 5, 3, N'DRIVER', @SeedTripDate, N'PICKUP', '07:00', '08:10', '2026-09-01 07:02:00', '2026-09-01 08:11:00', 1, N'COMPLETED', 1, 1),
      (6, 1, 2, 3, 6, 3, N'DRIVER', @SeedTripDate, N'DROP',   '15:00', '15:55', '2026-09-01 15:01:00', '2026-09-01 15:56:00', 1, N'COMPLETED', 1, 1),
      -- Branch 2: Bus 4 (Driver 4: Prakash Rao)
      (7, 1, 2, 4, 7, 4, N'DRIVER', @SeedTripDate, N'PICKUP', '07:00', '08:10', '2026-09-01 07:05:00', '2026-09-01 08:14:00', 4, N'COMPLETED', 1, 1),
      (8, 1, 2, 4, 8, 4, N'DRIVER', @SeedTripDate, N'DROP',   '15:00', '15:55', '2026-09-01 15:03:00', '2026-09-01 15:57:00', 2, N'COMPLETED', 1, 1);
    SET IDENTITY_INSERT transport_schema.trip OFF;
    PRINT N'✔ Seeded transport_schema.trip (8 trips: 4 Pickup + 4 Drop)';

    /* --------------------------------------------------------------------------
       6.6 SEED: transport_schema.trip_stop (24 Operational Trip Stops)
       -------------------------------------------------------------------------- */
    SET IDENTITY_INSERT transport_schema.trip_stop ON;
    INSERT INTO transport_schema.trip_stop
      (trip_stop_id, trip_id, vehicle_route_id, route_stop_id, stop_sequence,
       planned_arrival_at, actual_arrival_at, actual_departure_at, delay_minutes, status)
    SELECT
      ROW_NUMBER() OVER (ORDER BY t.trip_id, vrs.stop_sequence),
      t.trip_id,
      vrs.vehicle_route_id,
      vrs.route_stop_id,
      vrs.stop_sequence,
      DATEADD(SECOND, DATEDIFF(SECOND, CAST('00:00:00' AS TIME), vrs.planned_arrival_time), CAST(t.trip_date AS DATETIME2(0))),
      DATEADD(MINUTE, 2, DATEADD(SECOND, DATEDIFF(SECOND, CAST('00:00:00' AS TIME), vrs.planned_arrival_time), CAST(t.trip_date AS DATETIME2(0)))),
      DATEADD(MINUTE, 4, DATEADD(SECOND, DATEDIFF(SECOND, CAST('00:00:00' AS TIME), vrs.planned_arrival_time), CAST(t.trip_date AS DATETIME2(0)))),
      2,
      N'DEPARTED'
    FROM transport_schema.trip t
    INNER JOIN transport_schema.vehicle_route_stop vrs
      ON vrs.vehicle_route_id = t.vehicle_route_id;
    SET IDENTITY_INSERT transport_schema.trip_stop OFF;
    PRINT N'✔ Seeded transport_schema.trip_stop (24 trip stops)';

    /* --------------------------------------------------------------------------
       6.7 SEED: transport_schema.speed_measurement (24 Telemetry Records with GPS)
       -------------------------------------------------------------------------- */
    SET IDENTITY_INSERT transport_schema.speed_measurement ON;
    INSERT INTO transport_schema.speed_measurement
      (speed_measurement_id, trip_id, vehicle_id, recorded_at, speed_kmh,
       latitude, longitude, heading_degrees, gps_fix_status, received_at)
    SELECT
      ROW_NUMBER() OVER (ORDER BY t.trip_id, n.n),
      t.trip_id,
      t.vehicle_id,
      DATEADD(MINUTE, n.n * 10, CAST('2026-09-01T07:10:00' AS DATETIME2(0))),
      CAST(25.0 + (t.trip_id * 3 + n.n * 4) % 25 AS DECIMAL(6,2)),
      CASE WHEN (ROW_NUMBER() OVER (ORDER BY t.trip_id, n.n)) % 4 = 0 OR (ROW_NUMBER() OVER (ORDER BY t.trip_id, n.n)) % 7 = 0 THEN NULL
           ELSE CAST(17.385000 + ((ROW_NUMBER() OVER (ORDER BY t.trip_id, n.n)) * 0.001) AS DECIMAL(9,6)) END,
      CASE WHEN (ROW_NUMBER() OVER (ORDER BY t.trip_id, n.n)) % 4 = 0 OR (ROW_NUMBER() OVER (ORDER BY t.trip_id, n.n)) % 7 = 0 THEN NULL
           ELSE CAST(78.486000 + ((ROW_NUMBER() OVER (ORDER BY t.trip_id, n.n)) * 0.001) AS DECIMAL(9,6)) END,
      CASE WHEN (ROW_NUMBER() OVER (ORDER BY t.trip_id, n.n)) % 4 = 0 OR (ROW_NUMBER() OVER (ORDER BY t.trip_id, n.n)) % 7 = 0 THEN NULL
           ELSE CONVERT(SMALLINT, ((ROW_NUMBER() OVER (ORDER BY t.trip_id, n.n)) * 37) % 360) END,
      CASE WHEN (ROW_NUMBER() OVER (ORDER BY t.trip_id, n.n)) % 4 = 0 THEN N'NO_FIX'
           WHEN (ROW_NUMBER() OVER (ORDER BY t.trip_id, n.n)) % 7 = 0 THEN N'INVALID'
           ELSE N'VALID' END,
      SYSUTCDATETIME()
    FROM transport_schema.trip t
    CROSS JOIN (SELECT 1 AS n UNION ALL SELECT 2 UNION ALL SELECT 3) n;
    SET IDENTITY_INSERT transport_schema.speed_measurement OFF;
    PRINT N'✔ Seeded transport_schema.speed_measurement (24 speed measurements with GPS)';

    /* --------------------------------------------------------------------------
       6.8 SEED: student_schema.transport_assignment (Day-Scholar Assignments)
       -------------------------------------------------------------------------- */
    SET IDENTITY_INSERT student_schema.transport_assignment ON;
    INSERT INTO student_schema.transport_assignment
      (transport_assignment_id, school_id, branch_id, academic_year_id, class_id, section_id,
       student_id, vehicle_route_id, pickup_route_stop_id, drop_route_stop_id,
       estimated_pickup_time, estimated_drop_time, effective_from, effective_to,
       status, is_active, created_by)
    SELECT
      ROW_NUMBER() OVER (ORDER BY st.student_id) AS transport_assignment_id,
      1,
      st.branch_id,
      1,
      st.class_id,
      st.section_id,
      st.student_id,
      CASE WHEN st.branch_id = 1 THEN
        CASE WHEN st.student_id % 2 = 1 THEN 1 ELSE 3 END
      ELSE
        CASE WHEN st.student_id % 2 = 1 THEN 5 ELSE 7 END
      END AS vehicle_route_id,
      CASE WHEN st.branch_id = 1 THEN
        CASE WHEN st.student_id % 2 = 1 THEN 101 ELSE 107 END
      ELSE
        CASE WHEN st.student_id % 2 = 1 THEN 201 ELSE 207 END
      END AS pickup_route_stop_id,
      CASE WHEN st.branch_id = 1 THEN
        CASE WHEN st.student_id % 2 = 1 THEN 103 ELSE 109 END
      ELSE
        CASE WHEN st.student_id % 2 = 1 THEN 203 ELSE 209 END
      END AS drop_route_stop_id,
      '07:15',
      '08:05',
      '2026-04-01',
      NULL,
      N'ACTIVE',
      1,
      1
    FROM student_schema.student st
    WHERE st.residency_type = N'DAY_SCHOLAR' AND st.student_status = N'ACTIVE';
    SET IDENTITY_INSERT student_schema.transport_assignment OFF;
    PRINT CONCAT(N'✔ Seeded student_schema.transport_assignment (', @@ROWCOUNT, N' day-scholar assignments)');

    /* --------------------------------------------------------------------------
       6.9 SEED: student_schema.transport_change_request (4 Approved Requests)
       -------------------------------------------------------------------------- */
    SET IDENTITY_INSERT student_schema.transport_change_request ON;
    INSERT INTO student_schema.transport_change_request
      (transport_change_request_id, transport_assignment_id, school_id, branch_id, student_id, request_type,
       current_vehicle_route_id, requested_vehicle_route_id, current_pickup_stop_id, requested_pickup_stop_id,
       current_drop_stop_id, requested_drop_stop_id, effective_date, return_date, reason, status,
       reviewed_by, reviewed_at, is_active, created_by)
    SELECT
      ta.transport_assignment_id,
      ta.transport_assignment_id,
      ta.school_id,
      ta.branch_id,
      ta.student_id,
      N'PERMANENT',
      ta.vehicle_route_id,
      ta.vehicle_route_id,
      ta.pickup_route_stop_id,
      CASE WHEN ta.pickup_route_stop_id IN (101, 107) THEN ta.pickup_route_stop_id + 1 ELSE ta.pickup_route_stop_id END,
      ta.drop_route_stop_id,
      ta.drop_route_stop_id,
      '2026-09-01',
      NULL,
      N'Family shifted residential address.',
      N'APPROVED',
      1,
      '2026-08-30T10:00:00',
      1,
      st.user_id
    FROM student_schema.transport_assignment ta
    INNER JOIN student_schema.student st ON st.student_id = ta.student_id
    WHERE ta.transport_assignment_id <= 4;
    SET IDENTITY_INSERT student_schema.transport_change_request OFF;
    PRINT N'✔ Seeded student_schema.transport_change_request (4 approved requests)';

    /* --------------------------------------------------------------------------
       6.10 SEED: 50 Incidents (35 Active: 1..35, 15 Resolved: 36..50)
       -------------------------------------------------------------------------- */
    SET IDENTITY_INSERT transport_schema.transport_incident ON;
    ;WITH N AS
    (
        SELECT TOP (50)
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
        FROM sys.all_objects a
        CROSS JOIN sys.all_objects b
    )
    INSERT INTO transport_schema.transport_incident
    (
        transport_incident_id, school_id, branch_id, title, description,
        record_type, type, vehicle_id, detected_at,
        status, attachment_url, is_active,
        created_at, created_by, updated_at, updated_by
    )
    SELECT
        n,
        1,
        CASE WHEN n % 2 = 0 THEN 1 ELSE 2 END,
        CASE n % 8
            WHEN 0 THEN N'GPS Disconnected'
            WHEN 1 THEN N'Overspeed Alert'
            WHEN 2 THEN N'Unexpected Route Deviation'
            WHEN 3 THEN N'Vehicle Delay'
            WHEN 4 THEN N'Harsh Braking Detected'
            WHEN 5 THEN N'Unauthorized Stop'
            WHEN 6 THEN N'Vehicle Maintenance Alert'
            ELSE N'Passenger Attendance Mismatch'
        END,
        CONCAT(N'Mock transport incident generated for testing. Reference sequence ', n, N'.'),
        CASE WHEN n % 3 = 0 THEN N'INCIDENT' ELSE N'AUTOMATED_ALERT' END,
        CASE n % 8
            WHEN 0 THEN N'GPS_DISCONNECTED'
            WHEN 1 THEN N'OVERSPEED'
            WHEN 2 THEN N'ROUTE_DEVIATION'
            WHEN 3 THEN N'DELAY'
            WHEN 4 THEN N'HARSH_BRAKING'
            WHEN 5 THEN N'UNAUTHORIZED_STOP'
            WHEN 6 THEN N'MAINTENANCE'
            ELSE N'ATTENDANCE_MISMATCH'
        END,
        CASE WHEN n % 2 = 0 THEN 1 + ((n / 2) % 2) ELSE 3 + ((n / 2) % 2) END,
        DATEADD(MINUTE, -1 * n * 13, SYSUTCDATETIME()),
        CASE WHEN n <= 35 THEN N'NEW' ELSE N'RESOLVED' END,
        CASE WHEN n % 5 = 0
             THEN CONCAT(N'/attachments/incidents/incident_', n, N'.jpg')
             ELSE NULL
        END,
        CASE WHEN n <= 35 THEN 1 ELSE 0 END,
        SYSUTCDATETIME(),
        1,
        SYSUTCDATETIME(),
        1
    FROM N;
    SET IDENTITY_INSERT transport_schema.transport_incident OFF;
    PRINT N'✔ Seeded transport_schema.transport_incident (35 active [IDs 1..35] + 15 resolved [IDs 36..50])';

    /* --------------------------------------------------------------------------
       6.10B SEED: 15 Resolved Incident History Logs (IDs 1..15 -> Incidents 36..50)
       -------------------------------------------------------------------------- */
    SET IDENTITY_INSERT transport_schema.transport_incident_history ON;
    INSERT INTO transport_schema.transport_incident_history
    (
        transport_incident_history_id, transport_incident_id, school_id, branch_id,
        title, description, record_type, type, vehicle_id,
        detected_at, resolved_at, attachment_url, updated_at, updated_by
    )
    SELECT
        i.transport_incident_id - 35,
        i.transport_incident_id,
        i.school_id,
        i.branch_id,
        i.title,
        i.description,
        i.record_type,
        i.type,
        i.vehicle_id,
        i.detected_at,
        DATEADD(MINUTE, 45 + i.transport_incident_id, i.detected_at),
        i.attachment_url,
        SYSUTCDATETIME(),
        1
    FROM transport_schema.transport_incident i
    WHERE i.transport_incident_id BETWEEN 36 AND 50;
    SET IDENTITY_INSERT transport_schema.transport_incident_history OFF;
    PRINT N'✔ Seeded transport_schema.transport_incident_history (15 resolved audit logs [IDs 1..15 -> Incidents 36..50])';

    /* --------------------------------------------------------------------------
       6.11 SEED: transport_schema.trip_passenger_attendance (35 records: IDs 1..35)
       -------------------------------------------------------------------------- */
    SET IDENTITY_INSERT transport_schema.trip_passenger_attendance ON;

    ;WITH EligiblePassengers AS
    (
        SELECT
            ta.school_id,
            ta.branch_id,
            t.trip_id,
            st.user_id,
            ta.transport_assignment_id,
            ROW_NUMBER() OVER (ORDER BY ta.transport_assignment_id) AS rn
        FROM student_schema.transport_assignment ta
        INNER JOIN student_schema.student st
            ON st.student_id = ta.student_id
        INNER JOIN transport_schema.trip t
            ON t.school_id = ta.school_id
           AND t.branch_id = ta.branch_id
           AND t.vehicle_route_id = ta.vehicle_route_id
           AND t.trip_type = N'PICKUP'
        WHERE ta.status = N'ACTIVE'
          AND ta.is_active = 1
          AND st.user_id IS NOT NULL
    ),
    AttendanceMock AS
    (
        SELECT TOP (35)
            school_id,
            branch_id,
            trip_id,
            user_id,
            transport_assignment_id,
            rn,
            CASE
                WHEN rn % 10 BETWEEN 1 AND 7 THEN N'BOARDED'
                WHEN rn % 10 BETWEEN 8 AND 9 THEN N'NOT BOARDED'
                ELSE N'NOT TRAVELLING'
            END AS boarded_status,
            CASE
                WHEN rn % 10 BETWEEN 1 AND 5 THEN N'DROPPED'
                WHEN rn % 10 BETWEEN 6 AND 7 THEN N'NOT DROPPED'
                ELSE N'NOT TRAVELLING'
            END AS drop_status
        FROM EligiblePassengers
        ORDER BY rn
    )
    INSERT INTO transport_schema.trip_passenger_attendance
    (
        trip_passenger_attendance_id, school_id, branch_id, trip_id, user_id, transport_assignment_id,
        boarded_attendance_status, boarded_at,
        drop_attendance_status, drop_at,
        attendance_status, recorded_by,
        created_at, created_by, updated_at, updated_by
    )
    SELECT
        a.rn,
        a.school_id,
        a.branch_id,
        a.trip_id,
        a.user_id,
        a.transport_assignment_id,
        a.boarded_status,
        CASE WHEN a.boarded_status = N'BOARDED'
             THEN DATEADD(MINUTE, a.rn, CAST('2026-11-17T07:00:00' AS DATETIME2(0)))
             ELSE NULL END,
        a.drop_status,
        CASE WHEN a.drop_status = N'DROPPED'
             THEN DATEADD(MINUTE, a.rn, CAST('2026-11-17T08:00:00' AS DATETIME2(0)))
             ELSE NULL END,
        a.boarded_status,
        CASE a.trip_id
            WHEN 1 THEN 11 -- Mohan Rao (Attendant, Bus 1)
            WHEN 3 THEN 12 -- Karthik Rao (Attendant, Bus 2)
            WHEN 5 THEN 13 -- Imran Ali (Attendant, Bus 3)
            WHEN 7 THEN 14 -- Anil Kumar (Attendant, Bus 4)
            ELSE 11
        END,
        SYSUTCDATETIME(),
        1,
        SYSUTCDATETIME(),
        1
    FROM AttendanceMock a
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM transport_schema.trip_passenger_attendance existing
        WHERE existing.trip_id = a.trip_id
          AND existing.user_id = a.user_id
    );
    SET IDENTITY_INSERT transport_schema.trip_passenger_attendance OFF;
    PRINT CONCAT(N'✔ Seeded: ', @@ROWCOUNT, N' rows in transport_schema.trip_passenger_attendance (IDs 1..35)');

    COMMIT TRANSACTION;
    PRINT N'================================================================================';
    PRINT N'TRANSPORT MODULE UPGRADE & MOCK DATA SEEDING COMPLETE';
    PRINT N'================================================================================';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    PRINT N'❌ ERROR OCCURRED:';
    PRINT ERROR_MESSAGE();
    THROW;
END CATCH;
GO

/* =============================================================================
   7. POST-DEPLOYMENT VERIFICATION & SUMMARY REPORTS
   ============================================================================= */

PRINT N'--------------------------------------------------------------------------------';
PRINT N'VERIFICATION: ALL 12 TRANSPORT ENTITIES ROW COUNTS';
PRINT N'--------------------------------------------------------------------------------';

SELECT 'transport_schema.vehicle' AS [Table Name], COUNT_BIG(*) AS [Total Records] FROM transport_schema.vehicle
UNION ALL
SELECT 'transport_schema.staff', COUNT_BIG(*) FROM transport_schema.staff
UNION ALL
SELECT 'transport_schema.vehicle_route', COUNT_BIG(*) FROM transport_schema.vehicle_route
UNION ALL
SELECT 'transport_schema.vehicle_route_stop', COUNT_BIG(*) FROM transport_schema.vehicle_route_stop
UNION ALL
SELECT 'transport_schema.trip', COUNT_BIG(*) FROM transport_schema.trip
UNION ALL
SELECT 'transport_schema.trip_stop', COUNT_BIG(*) FROM transport_schema.trip_stop
UNION ALL
SELECT 'transport_schema.speed_measurement', COUNT_BIG(*) FROM transport_schema.speed_measurement
UNION ALL
SELECT 'student_schema.transport_assignment', COUNT_BIG(*) FROM student_schema.transport_assignment
UNION ALL
SELECT 'student_schema.transport_change_request', COUNT_BIG(*) FROM student_schema.transport_change_request
UNION ALL
SELECT 'transport_schema.transport_incident', COUNT_BIG(*) FROM transport_schema.transport_incident
UNION ALL
SELECT 'transport_schema.transport_incident_history', COUNT_BIG(*) FROM transport_schema.transport_incident_history
UNION ALL
SELECT 'transport_schema.trip_passenger_attendance', COUNT_BIG(*) FROM transport_schema.trip_passenger_attendance;
GO

PRINT N'--------------------------------------------------------------------------------';
PRINT N'VERIFICATION: ZERO ORPHANED ROWS OR MAPPED SCOPE MISMATCHES';
PRINT N'--------------------------------------------------------------------------------';

-- 1. Check vehicle - branch scope
SELECT 'Vehicle-Branch Mismatch' AS CheckName, COUNT(*) AS MismatchCount
FROM transport_schema.vehicle v
LEFT JOIN management_schema.branch b ON b.school_id = v.school_id AND b.branch_id = v.branch_id
WHERE b.branch_id IS NULL
UNION ALL
-- 2. Check staff - user mapping
SELECT 'Staff-User Mismatch', COUNT(*)
FROM transport_schema.staff s
LEFT JOIN security_schema.users u ON u.user_id = s.user_id
WHERE u.user_id IS NULL
UNION ALL
-- 3. Check trip - driver mapping
SELECT 'Trip-Driver Mismatch', COUNT(*)
FROM transport_schema.trip t
LEFT JOIN transport_schema.staff s ON s.staff_id = t.driver_id AND s.branch_id = t.branch_id AND s.staff_type = t.driver_type_enforcer
WHERE s.staff_id IS NULL
UNION ALL
-- 4. Check trip - vehicle mapping
SELECT 'Trip-Vehicle Mismatch', COUNT(*)
FROM transport_schema.trip t
LEFT JOIN transport_schema.vehicle v ON v.vehicle_id = t.vehicle_id AND v.branch_id = t.branch_id
WHERE v.vehicle_id IS NULL
UNION ALL
-- 5. Check attendance - trip mapping
SELECT 'Attendance-Trip Mismatch', COUNT(*)
FROM transport_schema.trip_passenger_attendance tpa
LEFT JOIN transport_schema.trip t ON t.trip_id = tpa.trip_id
WHERE t.trip_id IS NULL
UNION ALL
-- 6. Check attendance - student user mapping
SELECT 'Attendance-Student User Mismatch', COUNT(*)
FROM transport_schema.trip_passenger_attendance tpa
LEFT JOIN student_schema.student st ON st.user_id = tpa.user_id
WHERE st.student_id IS NULL
UNION ALL
-- 7. Check attendance - transport assignment mapping
SELECT 'Attendance-Assignment Mismatch', COUNT(*)
FROM transport_schema.trip_passenger_attendance tpa
LEFT JOIN student_schema.transport_assignment ta ON ta.transport_assignment_id = tpa.transport_assignment_id
WHERE ta.transport_assignment_id IS NULL
UNION ALL
-- 8. Check incident - vehicle mapping
SELECT 'Incident-Vehicle Mismatch', COUNT(*)
FROM transport_schema.transport_incident ti
LEFT JOIN transport_schema.vehicle v ON v.vehicle_id = ti.vehicle_id AND v.branch_id = ti.branch_id
WHERE v.vehicle_id IS NULL AND ti.vehicle_id IS NOT NULL
UNION ALL
-- 9. Check incident history - incident mapping (MUST BE 0!)
SELECT 'Incident History - Incident FK Mismatch', COUNT(*)
FROM transport_schema.transport_incident_history tih
LEFT JOIN transport_schema.transport_incident ti ON ti.transport_incident_id = tih.transport_incident_id
WHERE ti.transport_incident_id IS NULL
UNION ALL
-- 10. Check change request - assignment mapping
SELECT 'ChangeRequest-Assignment Mismatch', COUNT(*)
FROM student_schema.transport_change_request tcr
LEFT JOIN student_schema.transport_assignment ta ON ta.transport_assignment_id = tcr.transport_assignment_id
WHERE ta.transport_assignment_id IS NULL;
GO

PRINT N'--------------------------------------------------------------------------------';
PRINT N'SAMPLE ACTIVE INCIDENTS (TOP 5)';
PRINT N'--------------------------------------------------------------------------------';

SELECT TOP (5)
    transport_incident_id,
    school_id,
    branch_id,
    title,
    record_type,
    type,
    vehicle_id,
    status,
    detected_at,
    attachment_url
FROM transport_schema.transport_incident
ORDER BY transport_incident_id DESC;
GO

PRINT N'--------------------------------------------------------------------------------';
PRINT N'SAMPLE PASSENGER ATTENDANCE (TOP 5)';
PRINT N'--------------------------------------------------------------------------------';

SELECT TOP (5)
    trip_passenger_attendance_id,
    trip_id,
    user_id,
    transport_assignment_id,
    boarded_attendance_status,
    boarded_at,
    drop_attendance_status,
    drop_at,
    attendance_status
FROM transport_schema.trip_passenger_attendance
ORDER BY trip_passenger_attendance_id ASC;
GO

PRINT N'--------------------------------------------------------------------------------';
PRINT N'SAMPLE SPEED TELEMETRY WITH GPS COORDINATES (TOP 5)';
PRINT N'--------------------------------------------------------------------------------';

SELECT TOP (5)
    speed_measurement_id,
    trip_id,
    vehicle_id,
    speed_kmh,
    latitude,
    longitude,
    heading_degrees,
    gps_fix_status,
    recorded_at
FROM transport_schema.speed_measurement
ORDER BY speed_measurement_id ASC;
GO
