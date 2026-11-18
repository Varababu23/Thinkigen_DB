"""
FastAPI Router for Teacher Daily Attendance Management.
Module: Teacher Portal - Attendance Management
Database: Microsoft SQL Server (teachers_schema)

Provides REST endpoints for:
1. Teacher check-in
2. Teacher check-out
3. Teacher break start
4. Teacher break end
5. Get today's attendance
6. Get attendance by date
7. Get teacher attendance history
8. Get branch-wise daily attendance
9. Get monthly attendance summary
10. Get late arrival report
11. Get absent teacher report
12. Admin attendance correction
13. Attendance event history
"""

from __future__ import annotations

from datetime import date, datetime, timezone, timedelta
from typing import Optional, List
from fastapi import APIRouter, HTTPException, Query, Path, status

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
    TeacherAttendanceResponse,
    MonthlyAttendanceSummaryResponse,
    BranchDailyAttendanceReportItem,
    LateArrivalReportItem,
    AbsentTeacherReportItem,
    AttendanceEventResponse,
    AttendanceBreakResponse,
)
from app.services.teacher_attendance_service import (
    TeacherAttendanceService,
    DuplicateCheckInError,
    CheckInMissingError,
    DuplicateCheckOutError,
    InvalidAttendanceOperationError,
)

router = APIRouter(prefix="/teachers/attendance", tags=["Teacher Attendance"])


# -----------------------------------------------------------------------------
# 1. Teacher Check-In
# -----------------------------------------------------------------------------
@router.post(
    "/check-in",
    response_model=TeacherAttendanceResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Record Teacher Daily Check-In",
)
def check_in(
    payload: TeacherCheckInRequest,
    teacher_id: int = Query(1, description="Authenticated teacher ID"),
    school_id: int = Query(1, description="School ID"),
    branch_id: int = Query(1, description="Branch ID"),
    academic_year_id: int = Query(1, description="Academic Year ID"),
) -> TeacherAttendanceResponse:
    now = datetime.now(timezone.utc)
    today = now.date()
    shift_start = datetime.strptime("08:30:00", "%H:%M:%S").time()

    try:
        eval_res = TeacherAttendanceService.evaluate_check_in(
            check_in_dt=now,
            shift_expected_start=shift_start,
            shift_grace_period_minutes=15,
        )
    except DuplicateCheckInError as e:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(e))

    return TeacherAttendanceResponse(
        teacher_attendance_id=101,
        school_id=school_id,
        branch_id=branch_id,
        academic_year_id=academic_year_id,
        teacher_id=teacher_id,
        attendance_date=today,
        attendance_status=eval_res["attendance_status"],
        check_in_time=now,
        check_in_source=payload.source.value,
        check_out_time=None,
        check_out_source=None,
        break_minutes=0,
        total_worked_minutes=None,
        worked_hours_display=None,
        is_late=eval_res["is_late"],
        late_by_minutes=eval_res["late_by_minutes"],
        is_early_departure=False,
        early_by_minutes=0,
        leave_application_id=None,
        remarks=payload.remarks,
        breaks=[],
    )


# -----------------------------------------------------------------------------
# 2. Teacher Check-Out
# -----------------------------------------------------------------------------
@router.post(
    "/check-out",
    response_model=TeacherAttendanceResponse,
    summary="Record Teacher Daily Check-Out",
)
def check_out(
    payload: TeacherCheckOutRequest,
    teacher_id: int = Query(1, description="Authenticated teacher ID"),
) -> TeacherAttendanceResponse:
    now = datetime.now(timezone.utc)
    today = now.date()
    shift_end = datetime.strptime("16:30:00", "%H:%M:%S").time()
    mock_check_in = now.replace(hour=8, minute=20, second=0)

    try:
        eval_res = TeacherAttendanceService.evaluate_check_out(
            check_in_dt=mock_check_in,
            check_out_dt=now,
            break_minutes=45,
            shift_expected_end=shift_end,
        )
    except (DuplicateCheckOutError, InvalidAttendanceOperationError) as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))

    return TeacherAttendanceResponse(
        teacher_attendance_id=101,
        school_id=1,
        branch_id=1,
        academic_year_id=1,
        teacher_id=teacher_id,
        attendance_date=today,
        attendance_status=eval_res["attendance_status"],
        check_in_time=mock_check_in,
        check_in_source="BIOMETRIC",
        check_out_time=now,
        check_out_source=payload.source.value,
        break_minutes=45,
        total_worked_minutes=eval_res["total_worked_minutes"],
        worked_hours_display=eval_res["worked_hours_display"],
        is_late=False,
        late_by_minutes=0,
        is_early_departure=eval_res["is_early_departure"],
        early_by_minutes=eval_res["early_by_minutes"],
        leave_application_id=None,
        remarks=payload.remarks,
        breaks=[],
    )


# -----------------------------------------------------------------------------
# 3. Teacher Break Start
# -----------------------------------------------------------------------------
@router.post(
    "/break/start",
    response_model=AttendanceBreakResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Record Teacher Break Start",
)
def start_break(
    payload: TeacherBreakStartRequest,
    teacher_attendance_id: int = Query(..., description="Active Teacher Attendance ID"),
) -> AttendanceBreakResponse:
    now = datetime.now(timezone.utc)
    return AttendanceBreakResponse(
        attendance_break_id=1,
        teacher_attendance_id=teacher_attendance_id,
        break_start_time=now,
        break_end_time=None,
        break_duration_minutes=None,
        break_type=payload.break_type,
        is_approved=True,
    )


# -----------------------------------------------------------------------------
# 4. Teacher Break End
# -----------------------------------------------------------------------------
@router.post(
    "/break/end",
    response_model=AttendanceBreakResponse,
    summary="Record Teacher Break End",
)
def end_break(
    payload: TeacherBreakEndRequest,
) -> AttendanceBreakResponse:
    now = datetime.now(timezone.utc)
    mock_start = now - timedelta(minutes=45)
    duration = TeacherAttendanceService.evaluate_break_session(mock_start, now)
    return AttendanceBreakResponse(
        attendance_break_id=payload.attendance_break_id,
        teacher_attendance_id=101,
        break_start_time=mock_start,
        break_end_time=now,
        break_duration_minutes=duration,
        break_type=BreakType.LUNCH,
        is_approved=True,
    )


# -----------------------------------------------------------------------------
# 5. Get Today's Attendance
# -----------------------------------------------------------------------------
@router.get(
    "/today",
    response_model=Optional[TeacherAttendanceResponse],
    summary="Get Current Day Attendance for Authenticated Teacher",
)
def get_today_attendance(
    teacher_id: int = Query(1, description="Authenticated teacher ID"),
) -> Optional[TeacherAttendanceResponse]:
    today = date(2026, 10, 26)
    return TeacherAttendanceResponse(
        teacher_attendance_id=2,
        school_id=1,
        branch_id=1,
        academic_year_id=1,
        teacher_id=teacher_id,
        attendance_date=today,
        attendance_status=AttendanceStatus.PRESENT,
        check_in_time=datetime(2026, 10, 26, 8, 22, 0, tzinfo=timezone.utc),
        check_in_source="BIOMETRIC",
        check_out_time=datetime(2026, 10, 26, 16, 34, 0, tzinfo=timezone.utc),
        check_out_source="BIOMETRIC",
        break_minutes=45,
        total_worked_minutes=447,
        worked_hours_display="7h 27m",
        is_late=False,
        late_by_minutes=0,
        is_early_departure=False,
        early_by_minutes=0,
        remarks="Regular faculty attendance.",
        breaks=[],
    )


# -----------------------------------------------------------------------------
# 6. Get Attendance by Date
# -----------------------------------------------------------------------------
@router.get(
    "/date/{attendance_date}",
    response_model=Optional[TeacherAttendanceResponse],
    summary="Get Teacher Attendance for Specific Date",
)
def get_attendance_by_date(
    attendance_date: date = Path(..., description="Target attendance date"),
    teacher_id: int = Query(1, description="Teacher ID"),
) -> Optional[TeacherAttendanceResponse]:
    return TeacherAttendanceResponse(
        teacher_attendance_id=1,
        school_id=1,
        branch_id=1,
        academic_year_id=1,
        teacher_id=teacher_id,
        attendance_date=attendance_date,
        attendance_status=AttendanceStatus.PRESENT,
        check_in_time=datetime(2026, 10, 26, 8, 22, 0, tzinfo=timezone.utc),
        check_in_source="BIOMETRIC",
        check_out_time=datetime(2026, 10, 26, 16, 34, 0, tzinfo=timezone.utc),
        check_out_source="BIOMETRIC",
        break_minutes=45,
        total_worked_minutes=447,
        worked_hours_display="7h 27m",
        is_late=False,
        late_by_minutes=0,
        is_early_departure=False,
        early_by_minutes=0,
        remarks="Regular faculty attendance.",
        breaks=[],
    )


# -----------------------------------------------------------------------------
# 7. Get Teacher Attendance History
# -----------------------------------------------------------------------------
@router.get(
    "/teacher/{teacher_id}/history",
    response_model=List[TeacherAttendanceResponse],
    summary="Get Historical Attendance for Teacher",
)
def get_teacher_history(
    teacher_id: int = Path(..., description="Teacher ID"),
    limit: int = Query(30, ge=1, le=100),
) -> List[TeacherAttendanceResponse]:
    return [
        TeacherAttendanceResponse(
            teacher_attendance_id=2,
            school_id=1,
            branch_id=1,
            academic_year_id=1,
            teacher_id=teacher_id,
            attendance_date=date(2026, 10, 26),
            attendance_status=AttendanceStatus.PRESENT,
            check_in_time=datetime(2026, 10, 26, 8, 22, 0, tzinfo=timezone.utc),
            check_in_source="BIOMETRIC",
            check_out_time=datetime(2026, 10, 26, 16, 34, 0, tzinfo=timezone.utc),
            check_out_source="BIOMETRIC",
            break_minutes=45,
            total_worked_minutes=447,
            worked_hours_display="7h 27m",
            is_late=False,
            late_by_minutes=0,
            is_early_departure=False,
            early_by_minutes=0,
            remarks="Regular faculty attendance.",
            breaks=[],
        )
    ]


# -----------------------------------------------------------------------------
# 8. Branch-Wise Daily Attendance Report
# -----------------------------------------------------------------------------
@router.get(
    "/branch/{branch_id}/daily-report",
    response_model=List[BranchDailyAttendanceReportItem],
    summary="Get Branch-Wise Daily Attendance Report",
)
def get_branch_daily_report(
    branch_id: int = Path(..., description="Branch ID"),
    attendance_date: date = Query(..., description="Date for report"),
) -> List[BranchDailyAttendanceReportItem]:
    return [
        BranchDailyAttendanceReportItem(
            teacher_id=1,
            employee_code="TCH-001",
            teacher_name="Keshav Kulkarni",
            designation="English Teacher",
            attendance_status=AttendanceStatus.PRESENT,
            check_in_time=datetime(2026, 10, 26, 8, 22, 0, tzinfo=timezone.utc),
            check_out_time=datetime(2026, 10, 26, 16, 34, 0, tzinfo=timezone.utc),
            total_worked_minutes=447,
            is_late=False,
            late_by_minutes=0,
            is_early_departure=False,
            early_by_minutes=0,
            remarks="Regular faculty attendance.",
        ),
        BranchDailyAttendanceReportItem(
            teacher_id=2,
            employee_code="TCH-002",
            teacher_name="Radhika Pillai",
            designation="Mathematics Teacher",
            attendance_status=AttendanceStatus.PRESENT,
            check_in_time=datetime(2026, 10, 26, 8, 18, 0, tzinfo=timezone.utc),
            check_out_time=datetime(2026, 10, 26, 16, 30, 0, tzinfo=timezone.utc),
            total_worked_minutes=447,
            is_late=False,
            late_by_minutes=0,
            is_early_departure=False,
            early_by_minutes=0,
            remarks="Regular faculty attendance.",
        ),
    ]


# -----------------------------------------------------------------------------
# 9. Monthly Attendance Summary
# -----------------------------------------------------------------------------
@router.get(
    "/teacher/{teacher_id}/monthly-summary",
    response_model=MonthlyAttendanceSummaryResponse,
    summary="Get Monthly Attendance Aggregates for Teacher",
)
def get_monthly_summary(
    teacher_id: int = Path(..., description="Teacher ID"),
    month: int = Query(10, ge=1, le=12),
    year: int = Query(2026, ge=2020),
) -> MonthlyAttendanceSummaryResponse:
    records = [
        {"attendance_status": AttendanceStatus.PRESENT, "total_worked_minutes": 447, "is_late": False, "is_early_departure": False},
        {"attendance_status": AttendanceStatus.PRESENT, "total_worked_minutes": 447, "is_late": False, "is_early_departure": False},
        {"attendance_status": AttendanceStatus.PRESENT, "total_worked_minutes": 423, "is_late": True, "is_early_departure": False},
        {"attendance_status": AttendanceStatus.PRESENT, "total_worked_minutes": 450, "is_late": False, "is_early_departure": False},
        {"attendance_status": AttendanceStatus.PRESENT, "total_worked_minutes": 386, "is_late": False, "is_early_departure": True},
        {"attendance_status": AttendanceStatus.ON_LEAVE, "total_worked_minutes": 0, "is_late": False, "is_early_departure": False},
    ]

    return TeacherAttendanceService.calculate_monthly_summary(
        teacher_id=teacher_id,
        school_id=1,
        branch_id=1,
        academic_year_id=1,
        month=month,
        year=year,
        total_calendar_days=31,
        attendance_records=records,
    )


# -----------------------------------------------------------------------------
# 10. Late Arrival Report
# -----------------------------------------------------------------------------
@router.get(
    "/branch/{branch_id}/late-arrivals",
    response_model=List[LateArrivalReportItem],
    summary="Get Late Arrival Report for Branch",
)
def get_late_arrivals(
    branch_id: int = Path(..., description="Branch ID"),
    attendance_date: date = Query(..., description="Target date"),
) -> List[LateArrivalReportItem]:
    return [
        LateArrivalReportItem(
            teacher_id=1,
            employee_code="TCH-001",
            teacher_name="Keshav Kulkarni",
            attendance_date=attendance_date,
            check_in_time=datetime(2026, 10, 28, 8, 52, 0, tzinfo=timezone.utc),
            expected_start_time="08:30:00 (15 min grace)",
            late_by_minutes=22,
            remarks="Arrived late due to traffic diversion.",
        )
    ]


# -----------------------------------------------------------------------------
# 11. Absent Teacher Report
# -----------------------------------------------------------------------------
@router.get(
    "/branch/{branch_id}/absent-teachers",
    response_model=List[AbsentTeacherReportItem],
    summary="Get Absent Teacher Report for Branch",
)
def get_absent_teachers(
    branch_id: int = Path(..., description="Branch ID"),
    attendance_date: date = Query(..., description="Target date"),
) -> List[AbsentTeacherReportItem]:
    return [
        AbsentTeacherReportItem(
            teacher_id=1,
            employee_code="TCH-001",
            teacher_name="Keshav Kulkarni",
            attendance_date=attendance_date,
            has_approved_leave=True,
            leave_application_id=1,
            leave_type="CASUAL",
            remarks="Full-day casual leave approved.",
        )
    ]


# -----------------------------------------------------------------------------
# 12. Admin Attendance Correction
# -----------------------------------------------------------------------------
@router.post(
    "/correction",
    response_model=TeacherAttendanceResponse,
    summary="Authorized Admin Attendance Correction",
)
def correct_attendance(
    payload: AttendanceCorrectionRequest,
    teacher_id: int = Query(..., description="Teacher ID to correct"),
    admin_user_id: int = Query(3, description="Admin user performing correction"),
) -> TeacherAttendanceResponse:
    shift_start = datetime.strptime("08:30:00", "%H:%M:%S").time()
    shift_end = datetime.strptime("16:30:00", "%H:%M:%S").time()

    corrected = TeacherAttendanceService.evaluate_correction(
        correction=payload,
        shift_expected_start=shift_start,
        shift_expected_end=shift_end,
    )

    return TeacherAttendanceResponse(
        teacher_attendance_id=101,
        school_id=1,
        branch_id=1,
        academic_year_id=1,
        teacher_id=teacher_id,
        attendance_date=payload.attendance_date,
        attendance_status=corrected["attendance_status"],
        check_in_time=corrected["check_in_time"],
        check_in_source="ADMIN_MANUAL",
        check_out_time=corrected["check_out_time"],
        check_out_source="ADMIN_MANUAL" if corrected["check_out_time"] else None,
        break_minutes=corrected["break_minutes"],
        total_worked_minutes=corrected["total_worked_minutes"],
        worked_hours_display=corrected["worked_hours_display"],
        is_late=corrected["is_late"],
        late_by_minutes=corrected["late_by_minutes"],
        is_early_departure=corrected["is_early_departure"],
        early_by_minutes=corrected["early_by_minutes"],
        leave_application_id=None,
        remarks=corrected["remarks"],
        breaks=[],
    )


# -----------------------------------------------------------------------------
# 13. Attendance Event History
# -----------------------------------------------------------------------------
@router.get(
    "/{teacher_attendance_id}/events",
    response_model=List[AttendanceEventResponse],
    summary="Get Audit Event History for Attendance Record",
)
def get_attendance_events(
    teacher_attendance_id: int = Path(..., description="Attendance ID"),
) -> List[AttendanceEventResponse]:
    return [
        AttendanceEventResponse(
            attendance_event_id=1,
            teacher_attendance_id=teacher_attendance_id,
            teacher_id=1,
            event_type=AttendanceEventType.CHECK_IN,
            event_time=datetime(2026, 10, 26, 8, 22, 0, tzinfo=timezone.utc),
            event_source=AttendanceEventSource.BIOMETRIC,
            performed_by=101,
            remarks="Biometric terminal #1 check-in.",
        ),
        AttendanceEventResponse(
            attendance_event_id=2,
            teacher_attendance_id=teacher_attendance_id,
            teacher_id=1,
            event_type=AttendanceEventType.CHECK_OUT,
            event_time=datetime(2026, 10, 26, 16, 34, 0, tzinfo=timezone.utc),
            event_source=AttendanceEventSource.BIOMETRIC,
            performed_by=101,
            remarks="Biometric terminal #2 check-out.",
        ),
    ]
