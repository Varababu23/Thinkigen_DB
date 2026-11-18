"""
Thinkigen School ERP - Teacher Attendance Unit & Service Tests.
Module: Teacher Portal - Attendance Management
Database: Microsoft SQL Server (teachers_schema)

Validates:
- Strict Pydantic schema validation & constraint rules
- Check-in evaluation, shift grace period, and late arrival calculations
- Check-out evaluation, working duration (elapsed - break), and early departure calculations
- Multi-break duration validation and error handling
- Duplicate check-in & duplicate check-out prevention
- Administrative attendance correction logic & audit preservation
- Approved teacher leave integration (FULL_DAY -> ON_LEAVE, HALF_DAY -> HALF_DAY)
- Monthly attendance summary mathematical aggregation
- FastAPI router endpoint registration
"""

from datetime import date, datetime, time, timezone, timedelta
from decimal import Decimal
import sys
from pathlib import Path
import pytest
from pydantic import ValidationError

BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.schemas.teacher_attendance import (
    AttendanceStatus,
    AttendanceEventSource,
    AttendanceEventType,
    BreakType,
    TeacherCheckInRequest,
    TeacherCheckOutRequest,
    TeacherBreakStartRequest,
    TeacherBreakEndRequest,
    AttendanceCorrectionRequest,
    AttendanceBreakResponse,
    AttendanceEventResponse,
    TeacherAttendanceResponse,
    MonthlyAttendanceSummaryResponse,
)
from app.services.teacher_attendance_service import (
    TeacherAttendanceService,
    DuplicateCheckInError,
    CheckInMissingError,
    DuplicateCheckOutError,
    InvalidAttendanceOperationError,
)
from app.main import app


# =============================================================================
# 1. Schema Validation Tests
# =============================================================================

def test_teacher_check_in_request_defaults_and_extras():
    req = TeacherCheckInRequest()
    assert req.source == AttendanceEventSource.WEB_PORTAL
    assert req.remarks is None
    assert req.device_id is None

    # Extra fields forbidden
    with pytest.raises(ValidationError):
        TeacherCheckInRequest(extra_field="unsupported")


def test_teacher_check_out_request_valid():
    req = TeacherCheckOutRequest(
        source=AttendanceEventSource.BIOMETRIC,
        remarks="Biometric terminal gate 2 checkout",
        device_id="BIO-TERMINAL-02",
    )
    assert req.source == AttendanceEventSource.BIOMETRIC
    assert req.device_id == "BIO-TERMINAL-02"


def test_attendance_correction_request_time_ordering():
    # Valid ordering
    dt1 = datetime(2026, 11, 2, 8, 30, tzinfo=timezone.utc)
    dt2 = datetime(2026, 11, 2, 16, 30, tzinfo=timezone.utc)
    corr = AttendanceCorrectionRequest(
        attendance_date=date(2026, 11, 2),
        attendance_status=AttendanceStatus.PRESENT,
        check_in_time=dt1,
        check_out_time=dt2,
        break_minutes=45,
        correction_reason="Teacher forgot to tap biometric scanner at gate",
    )
    assert corr.break_minutes == 45
    assert corr.attendance_status == AttendanceStatus.PRESENT

    # Invalid ordering: checkout precedes checkin
    with pytest.raises(ValidationError, match="check_out_time cannot be earlier than check_in_time"):
        AttendanceCorrectionRequest(
            attendance_date=date(2026, 11, 2),
            attendance_status=AttendanceStatus.PRESENT,
            check_in_time=dt2,
            check_out_time=dt1,
            correction_reason="Invalid timing attempt",
        )


# =============================================================================
# 2. Check-In Evaluation Tests
# =============================================================================

def test_evaluate_check_in_on_time():
    # Shift start: 08:30:00, Grace: 15 mins (up to 08:45)
    # Check-in: 08:35:00 (within grace period)
    check_in_dt = datetime(2026, 11, 2, 8, 35, 0)
    shift_start = time(8, 30, 0)
    res = TeacherAttendanceService.evaluate_check_in(
        check_in_dt=check_in_dt,
        shift_expected_start=shift_start,
        shift_grace_period_minutes=15,
    )
    assert res["is_late"] is False
    assert res["late_by_minutes"] == 0
    assert res["attendance_status"] == AttendanceStatus.PRESENT


def test_evaluate_check_in_late_arrival():
    # Shift start: 08:30:00, Grace: 15 mins (08:45 threshold)
    # Check-in: 09:05:00 (35 mins after start -> late)
    check_in_dt = datetime(2026, 11, 2, 9, 5, 0)
    shift_start = time(8, 30, 0)
    res = TeacherAttendanceService.evaluate_check_in(
        check_in_dt=check_in_dt,
        shift_expected_start=shift_start,
        shift_grace_period_minutes=15,
    )
    assert res["is_late"] is True
    assert res["late_by_minutes"] == 35
    assert res["attendance_status"] == AttendanceStatus.PRESENT


def test_evaluate_check_in_duplicate_prevention():
    check_in_dt = datetime(2026, 11, 2, 8, 30, 0)
    existing = {"check_in_time": datetime(2026, 11, 2, 8, 25, 0)}
    with pytest.raises(DuplicateCheckInError, match="Teacher has already checked in"):
        TeacherAttendanceService.evaluate_check_in(
            check_in_dt=check_in_dt,
            shift_expected_start=time(8, 30, 0),
            shift_grace_period_minutes=15,
            existing_record=existing,
        )


def test_evaluate_check_in_with_approved_half_day():
    check_in_dt = datetime(2026, 11, 2, 12, 30, 0)
    shift_start = time(8, 30, 0)
    res = TeacherAttendanceService.evaluate_check_in(
        check_in_dt=check_in_dt,
        shift_expected_start=shift_start,
        shift_grace_period_minutes=15,
        has_approved_half_day_leave=True,
    )
    assert res["attendance_status"] == AttendanceStatus.HALF_DAY


# =============================================================================
# 3. Check-Out Evaluation & Duration Tests
# =============================================================================

def test_evaluate_check_out_full_day():
    # Check-in: 08:30:00, Check-out: 16:30:00 (8 hours = 480 mins)
    # Break: 45 mins -> worked: 480 - 45 = 435 mins (7h 15m)
    # Shift end: 16:00:00 -> not early
    check_in_dt = datetime(2026, 11, 2, 8, 30, 0)
    check_out_dt = datetime(2026, 11, 2, 16, 30, 0)
    res = TeacherAttendanceService.evaluate_check_out(
        check_in_dt=check_in_dt,
        check_out_dt=check_out_dt,
        break_minutes=45,
        shift_expected_end=time(16, 0, 0),
        shift_half_day_threshold_minutes=240,
        shift_full_day_threshold_minutes=420,
    )
    assert res["total_worked_minutes"] == 435
    assert res["worked_hours_display"] == "7h 15m"
    assert res["is_early_departure"] is False
    assert res["early_by_minutes"] == 0
    assert res["attendance_status"] == AttendanceStatus.PRESENT


def test_evaluate_check_out_early_departure():
    # Shift end: 16:00:00, Check-out: 14:45:00 (75 mins early)
    # Check-in: 08:30:00 -> elapsed = 375 mins. Break: 30 mins -> worked: 345 mins
    check_in_dt = datetime(2026, 11, 2, 8, 30, 0)
    check_out_dt = datetime(2026, 11, 2, 14, 45, 0)
    res = TeacherAttendanceService.evaluate_check_out(
        check_in_dt=check_in_dt,
        check_out_dt=check_out_dt,
        break_minutes=30,
        shift_expected_end=time(16, 0, 0),
        shift_half_day_threshold_minutes=240,
        shift_full_day_threshold_minutes=420,
    )
    assert res["is_early_departure"] is True
    assert res["early_by_minutes"] == 75
    assert res["total_worked_minutes"] == 345
    assert res["attendance_status"] == AttendanceStatus.PRESENT


def test_evaluate_check_out_below_half_day_threshold():
    # Worked 180 mins (< 240 mins threshold)
    check_in_dt = datetime(2026, 11, 2, 8, 30, 0)
    check_out_dt = datetime(2026, 11, 2, 11, 30, 0)
    res = TeacherAttendanceService.evaluate_check_out(
        check_in_dt=check_in_dt,
        check_out_dt=check_out_dt,
        break_minutes=0,
        shift_expected_end=time(16, 0, 0),
        shift_half_day_threshold_minutes=240,
    )
    assert res["total_worked_minutes"] == 180
    assert res["attendance_status"] == AttendanceStatus.HALF_DAY


def test_evaluate_check_out_duplicate_and_invalid_ordering():
    check_in_dt = datetime(2026, 11, 2, 8, 30, 0)
    check_out_dt = datetime(2026, 11, 2, 16, 30, 0)

    # Duplicate check-out
    with pytest.raises(DuplicateCheckOutError):
        TeacherAttendanceService.evaluate_check_out(
            check_in_dt=check_in_dt,
            check_out_dt=check_out_dt,
            break_minutes=0,
            shift_expected_end=time(16, 0, 0),
            existing_check_out=datetime(2026, 11, 2, 16, 0, 0),
        )

    # Invalid ordering: checkout < checkin
    with pytest.raises(InvalidAttendanceOperationError, match="Check-out time cannot be earlier than check-in time"):
        TeacherAttendanceService.evaluate_check_out(
            check_in_dt=check_out_dt,
            check_out_dt=check_in_dt,
            break_minutes=0,
            shift_expected_end=time(16, 0, 0),
        )


# =============================================================================
# 4. Break Session Evaluation Tests
# =============================================================================

def test_evaluate_break_session():
    b_start = datetime(2026, 11, 2, 12, 30, 0)
    b_end = datetime(2026, 11, 2, 13, 15, 0)
    duration = TeacherAttendanceService.evaluate_break_session(b_start, b_end)
    assert duration == 45

    # Negative break
    with pytest.raises(InvalidAttendanceOperationError, match="Break end time cannot be earlier"):
        TeacherAttendanceService.evaluate_break_session(b_end, b_start)


# =============================================================================
# 5. Administrative Correction Tests
# =============================================================================

def test_evaluate_correction():
    correction = AttendanceCorrectionRequest(
        attendance_date=date(2026, 11, 2),
        attendance_status=AttendanceStatus.PRESENT,
        check_in_time=datetime(2026, 11, 2, 8, 30, 0),
        check_out_time=datetime(2026, 11, 2, 16, 30, 0),
        break_minutes=30,
        correction_reason="Admin manual correction after gate register audit",
    )
    res = TeacherAttendanceService.evaluate_correction(
        correction=correction,
        shift_expected_start=time(8, 30, 0),
        shift_expected_end=time(16, 0, 0),
        shift_grace_period_minutes=15,
    )
    # 480 mins elapsed - 30 break = 450 worked
    assert res["total_worked_minutes"] == 450
    assert res["worked_hours_display"] == "7h 30m"
    assert res["is_late"] is False
    assert res["is_early_departure"] is False
    assert "Admin manual correction" in res["remarks"]


# =============================================================================
# 6. Leave Integration Tests
# =============================================================================

def test_reconcile_leave_full_day():
    full_day_leave = {
        "teacher_leave_application_id": 101,
        "status": "APPROVED",
        "leave_duration_type": "FULL_DAY",
        "leave_type": "CASUAL",
    }
    rec = TeacherAttendanceService.reconcile_leave_with_attendance(full_day_leave)
    assert rec["attendance_status"] == AttendanceStatus.ON_LEAVE
    assert rec["leave_application_id"] == 101
    assert rec["total_worked_minutes"] == 0
    assert rec["check_in_time"] is None


def test_reconcile_leave_half_day():
    half_day_leave = {
        "teacher_leave_application_id": 102,
        "status": "APPROVED",
        "leave_duration_type": "HALF_DAY",
        "leave_type": "SICK",
    }
    rec = TeacherAttendanceService.reconcile_leave_with_attendance(half_day_leave)
    assert rec["attendance_status"] == AttendanceStatus.HALF_DAY
    assert rec["leave_application_id"] == 102


def test_reconcile_leave_unapproved():
    pending_leave = {
        "teacher_leave_application_id": 103,
        "status": "PENDING",
        "leave_duration_type": "FULL_DAY",
    }
    rec = TeacherAttendanceService.reconcile_leave_with_attendance(pending_leave)
    assert rec == {}


# =============================================================================
# 7. Monthly Summary Calculation Tests
# =============================================================================

def test_calculate_monthly_summary():
    # 20 working days: 17 PRESENT (450 min each), 1 HALF_DAY (240 min), 1 ON_LEAVE (0 min), 1 ABSENT (0 min)
    # 4 WEEKLY_OFF, 2 HOLIDAYS. Total calendar days = 26.
    records = []
    for _ in range(17):
        records.append({
            "attendance_status": AttendanceStatus.PRESENT,
            "total_worked_minutes": 450,
            "is_late": False,
            "is_early_departure": False,
        })
    # 1 Late arrival present day
    records[0]["is_late"] = True

    # 1 Half day
    records.append({
        "attendance_status": AttendanceStatus.HALF_DAY,
        "total_worked_minutes": 240,
        "is_late": False,
        "is_early_departure": True,
    })

    # 1 On leave
    records.append({
        "attendance_status": AttendanceStatus.ON_LEAVE,
        "total_worked_minutes": 0,
        "is_late": False,
        "is_early_departure": False,
    })

    # 1 Absent
    records.append({
        "attendance_status": AttendanceStatus.ABSENT,
        "total_worked_minutes": 0,
        "is_late": False,
        "is_early_departure": False,
    })

    # 4 Weekly offs
    for _ in range(4):
        records.append({"attendance_status": AttendanceStatus.WEEKLY_OFF, "total_worked_minutes": 0})

    # 2 Holidays
    for _ in range(2):
        records.append({"attendance_status": AttendanceStatus.HOLIDAY, "total_worked_minutes": 0})

    summary = TeacherAttendanceService.calculate_monthly_summary(
        teacher_id=1,
        school_id=1,
        branch_id=1,
        academic_year_id=1,
        month=10,
        year=2026,
        total_calendar_days=26,
        attendance_records=records,
    )

    assert summary.teacher_id == 1
    assert summary.month == 10
    assert summary.year == 2026
    assert summary.total_calendar_days == 26
    assert summary.total_working_days == 20
    assert summary.present_days == 17
    assert summary.half_days == 1
    assert summary.on_leave_days == 1
    assert summary.absent_days == 1
    assert summary.weekly_offs == 4
    assert summary.holidays == 2

    # Worked minutes: (17 * 450) + 240 = 7650 + 240 = 7890
    assert summary.total_worked_minutes == 7890
    assert summary.total_worked_hours == round(7890 / 60.0, 2)  # 131.5

    # Attendance percentage: effective present = 17 + (0.5 * 1) = 17.5. Total working = 20.
    # (17.5 / 20) * 100 = 87.5%
    assert summary.attendance_percentage == 87.5

    assert summary.total_late_arrivals == 1
    assert summary.total_early_departures == 1


# =============================================================================
# 8. API Router Endpoint Registration Tests
# =============================================================================

def test_router_endpoints_registered_in_fastapi():
    openapi_schema = app.openapi()
    api_paths = openapi_schema.get("paths", {}).keys()
    expected_endpoints = [
        "/teachers/attendance/check-in",
        "/teachers/attendance/check-out",
        "/teachers/attendance/break/start",
        "/teachers/attendance/break/end",
        "/teachers/attendance/today",
        "/teachers/attendance/date/{attendance_date}",
        "/teachers/attendance/teacher/{teacher_id}/history",
        "/teachers/attendance/branch/{branch_id}/daily-report",
        "/teachers/attendance/teacher/{teacher_id}/monthly-summary",
        "/teachers/attendance/branch/{branch_id}/late-arrivals",
        "/teachers/attendance/branch/{branch_id}/absent-teachers",
        "/teachers/attendance/correction",
        "/teachers/attendance/{teacher_attendance_id}/events",
    ]
    for endpoint in expected_endpoints:
        assert endpoint in api_paths, f"Expected endpoint {endpoint} not found in FastAPI OpenAPI paths"
