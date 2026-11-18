/*
    ================================================================================
    THINKIGEN SCHOOL ERP — Transport Module Mock Data Seeder
    ================================================================================
    File Path     : database/seeds/015_transport_mock_data.sql
    Target Engine : Microsoft SQL Server / Azure SQL Database
    Schemas       : transport_schema, student_schema, security_schema, management_schema
    Purpose       :
      Populates 100% relationally accurate mock data across all 12 transport entities:
        1. transport_schema.vehicle (4 Buses, 2 per Branch under School 1)
        2. transport_schema.staff (8 Staff: 4 Drivers, 4 Attendants mapped to Users 7..14)
        3. transport_schema.vehicle_route (8 Master Routes: 4 Pickup, 4 Drop)
        4. transport_schema.vehicle_route_stop (24 Route Stops: 3 stops per route)
        5. transport_schema.trip (8 Trips adhering to driver, vehicle & branch composite FKs)
        6. transport_schema.trip_stop (24 Operational Trip Stops)
        7. transport_schema.speed_measurement (24 Telemetry Records with valid GPS)
        8. student_schema.transport_assignment (Day-Scholar student assignments)
        9. student_schema.transport_change_request (4 Approved Change Requests)
        10. transport_schema.transport_incident (35 Active Incidents & Alerts)
        11. transport_schema.transport_incident_history (15 Resolved Archived Incidents)
        12. transport_schema.trip_passenger_attendance (35 Passenger Attendance rows)

    Prerequisites:
      - Tables created by running: database/migrations/015_transport.sql
      - Base seed data: school (1), branches (1, 2), academic_year (1), classes,
        sections, students, and users (1..14, 201..600) from 002 master seed.
    ================================================================================
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

PRINT N'================================================================================';
PRINT N'STARTING TRANSPORT SCHEMA MOCK DATA SEEDING';
PRINT N'================================================================================';
GO

-- Preflight check: Ensure all 12 tables exist
IF OBJECT_ID(N'transport_schema.vehicle', N'U') IS NULL
   OR OBJECT_ID(N'transport_schema.staff', N'U') IS NULL
   OR OBJECT_ID(N'transport_schema.vehicle_route', N'U') IS NULL
   OR OBJECT_ID(N'transport_schema.vehicle_route_stop', N'U') IS NULL
   OR OBJECT_ID(N'transport_schema.trip', N'U') IS NULL
   OR OBJECT_ID(N'transport_schema.trip_stop', N'U') IS NULL
   OR OBJECT_ID(N'transport_schema.speed_measurement', N'U') IS NULL
   OR OBJECT_ID(N'student_schema.transport_assignment', N'U') IS NULL
   OR OBJECT_ID(N'student_schema.transport_change_request', N'U') IS NULL
   OR OBJECT_ID(N'transport_schema.transport_incident', N'U') IS NULL
   OR OBJECT_ID(N'transport_schema.transport_incident_history', N'U') IS NULL
   OR OBJECT_ID(N'transport_schema.trip_passenger_attendance', N'U') IS NULL
BEGIN
    RAISERROR(N'Transport module tables are missing. Please execute database/migrations/015_transport.sql first.', 16, 1);
    RETURN;
END;
GO

-- Preflight check: Ensure base parent data exists
IF NOT EXISTS (SELECT 1 FROM management_schema.school WHERE school_id = 1)
   OR NOT EXISTS (SELECT 1 FROM management_schema.branch WHERE school_id = 1 AND branch_id IN (1, 2))
   OR NOT EXISTS (SELECT 1 FROM security_schema.users WHERE user_id BETWEEN 7 AND 14)
BEGIN
    RAISERROR(N'Base master seed data (School 1, Branches 1 & 2, Transport Users 7..14) missing. Please run 002_THINKIGEN_REALISTIC_MOCK_DATA_V22.sql first.', 16, 1);
    RETURN;
END;
GO

BEGIN TRANSACTION;
BEGIN TRY

    /* -------------------------------------------------------------------------- */
    /* 0. CLEANUP EXISTING TRANSPORT DATA (Child-to-Parent Order)                 */
    /* -------------------------------------------------------------------------- */
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
    PRINT N'✔ Cleaned up existing transport mock records.';

    /* -------------------------------------------------------------------------- */
    /* 1. SEED: transport_schema.vehicle (4 Vehicles: 2 per Branch under School 1) */
    /* -------------------------------------------------------------------------- */
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

    /* -------------------------------------------------------------------------- */
    /* 2. SEED: transport_schema.staff (8 Staff: Users 7..14)                      */
    /* -------------------------------------------------------------------------- */
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

    /* -------------------------------------------------------------------------- */
    /* 3. SEED: transport_schema.vehicle_route (8 Master Routes: 4 PU + 4 DR)     */
    /* -------------------------------------------------------------------------- */
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

    /* -------------------------------------------------------------------------- */
    /* 4. SEED: transport_schema.vehicle_route_stop (24 Stops: 3 Stops per Route) */
    /* -------------------------------------------------------------------------- */
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

    /* -------------------------------------------------------------------------- */
    /* 5. SEED: transport_schema.trip (8 Trips: 4 Pickup + 4 Drop)                */
    /* -------------------------------------------------------------------------- */
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

    /* -------------------------------------------------------------------------- */
    /* 6. SEED: transport_schema.trip_stop (24 Operational Trip Stops)            */
    /* -------------------------------------------------------------------------- */
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

    /* -------------------------------------------------------------------------- */
    /* 7. SEED: transport_schema.speed_measurement (24 Telemetry Records with GPS)*/
    /* -------------------------------------------------------------------------- */
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

    /* -------------------------------------------------------------------------- */
    /* 8. SEED: student_schema.transport_assignment (Day-Scholar Assignments)     */
    /* -------------------------------------------------------------------------- */
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

    /* -------------------------------------------------------------------------- */
    /* 9. SEED: student_schema.transport_change_request (4 Approved Requests)     */
    /* -------------------------------------------------------------------------- */
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

    /* -------------------------------------------------------------------------- */
    /* 10. SEED: 50 Incidents (35 Active: 1..35, 15 Resolved: 36..50)            */
    /* -------------------------------------------------------------------------- */
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

    /* -------------------------------------------------------------------------- */
    /* 10B. SEED: transport_schema.transport_incident_history (15 Resolved Logs)  */
    /* -------------------------------------------------------------------------- */
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

    /* -------------------------------------------------------------------------- */
    /* 11. SEED: transport_schema.trip_passenger_attendance (35 records)          */
    /* -------------------------------------------------------------------------- */
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
    PRINT CONCAT(N'✔ Seeded transport_schema.trip_passenger_attendance (', @@ROWCOUNT, N' rows)');

    COMMIT TRANSACTION;
    PRINT N'================================================================================';
    PRINT N'TRANSPORT MOCK DATA SEEDING COMPLETED SUCCESSFULLY!';
    PRINT N'================================================================================';

    -- Display seeded row counts
    SELECT 'transport_schema.vehicle' AS entity_name, COUNT(*) AS row_count FROM transport_schema.vehicle
    UNION ALL
    SELECT 'transport_schema.staff', COUNT(*) FROM transport_schema.staff
    UNION ALL
    SELECT 'transport_schema.vehicle_route', COUNT(*) FROM transport_schema.vehicle_route
    UNION ALL
    SELECT 'transport_schema.vehicle_route_stop', COUNT(*) FROM transport_schema.vehicle_route_stop
    UNION ALL
    SELECT 'transport_schema.trip', COUNT(*) FROM transport_schema.trip
    UNION ALL
    SELECT 'transport_schema.trip_stop', COUNT(*) FROM transport_schema.trip_stop
    UNION ALL
    SELECT 'transport_schema.speed_measurement', COUNT(*) FROM transport_schema.speed_measurement
    UNION ALL
    SELECT 'student_schema.transport_assignment', COUNT(*) FROM student_schema.transport_assignment
    UNION ALL
    SELECT 'student_schema.transport_change_request', COUNT(*) FROM student_schema.transport_change_request
    UNION ALL
    SELECT 'transport_schema.transport_incident', COUNT(*) FROM transport_schema.transport_incident
    UNION ALL
    SELECT 'transport_schema.transport_incident_history', COUNT(*) FROM transport_schema.transport_incident_history
    UNION ALL
    SELECT 'transport_schema.trip_passenger_attendance', COUNT(*) FROM transport_schema.trip_passenger_attendance;

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    PRINT N'❌ Error occurred during Transport Mock Data Seeding:';
    PRINT ERROR_MESSAGE();
    THROW;
END CATCH;
GO
