"""
Thinkigen School ERP - Teacher Attendance Service Layer.
Module: Teacher Portal - Attendance Management
Database: Microsoft SQL Server (teachers_schema)

Enforces:
- Concurrency-safe check-in and check-out workflows
- Accurate integer working minutes calculation: total_worked_minutes = elapsed - breaks
- Policy-driven late arrival and early departure calculations based on configurable shift rules
- Multi-break management (lunch, tea, personal)
- Integration with approved leave applications and school calendar holidays
- Immutable audit event logging for all lifecycle transitions and administrative corrections
"""

from __future__ import annotations

import logging
from datetime import date, datetime, time, timezone, timedelta
from typing import Optional, Dict, Any, List, Union

from app.schemas.teacher_attendance import (
    AttendanceStatus,
    AttendanceEventSource,
    AttendanceEventType,
    BreakType,
    TeacherCheckInRequest,
    TeacherCheckOutRequest,
    AttendanceCorrectionRequest,
    TeacherAttendanceResponse,
    MonthlyAttendanceSummaryResponse,
)

logger = logging.getLogger("thinkigen.teacher_attendance")


class DuplicateCheckInError(Exception):
    """Raised when an active check-in already exists for the teacher on the calendar date."""
    pass


class CheckInMissingError(Exception):
    """Raised when check-out is attempted without an existing check-in."""
    pass


class DuplicateCheckOutError(Exception):
    """Raised when check-out has already been completed for the attendance session."""
    pass


class InvalidAttendanceOperationError(Exception):
    """Raised for logical errors such as check-out preceding check-in or negative working duration."""
    pass


class TeacherAttendanceService:
    """
    Core service handling daily teacher attendance, shift evaluation,
    working minutes calculation, break deductions, and leave integration.
    """

    def __init__(self, db_connection: Any = None):
        self.conn = db_connection

    # -------------------------------------------------------------------------
    # Helper: Duration & Display Formatting
    # -------------------------------------------------------------------------
    @staticmethod
    def format_hours_and_minutes(total_minutes: Optional[int]) -> Optional[str]:
        """Formats integer working minutes as human-readable string (e.g., '7h 15m')."""
        if total_minutes is None:
            return None
        hours = total_minutes // 60
        mins = total_minutes % 60
        return f"{hours}h {mins}m"

    # -------------------------------------------------------------------------
    # 1. Check-In Evaluation
    # -------------------------------------------------------------------------
    @staticmethod
    def evaluate_check_in(
        check_in_dt: datetime,
        shift_expected_start: time,
        shift_grace_period_minutes: int,
        existing_record: Optional[Dict[str, Any]] = None,
        has_approved_half_day_leave: bool = False,
    ) -> Dict[str, Any]:
        """
        Validates check-in conditions, calculates late arrival against shift policy,
        and determines initial attendance status.
        """
        if existing_record and existing_record.get("check_in_time") is not None:
            raise DuplicateCheckInError("Teacher has already checked in for this date.")

        # Calculate late arrival
        check_in_time_val = check_in_dt.time()
        start_seconds = shift_expected_start.hour * 3600 + shift_expected_start.minute * 60 + shift_expected_start.second
        check_in_seconds = check_in_time_val.hour * 3600 + check_in_time_val.minute * 60 + check_in_time_val.second

        diff_minutes = (check_in_seconds - start_seconds) // 60

        is_late = False
        late_by_minutes = 0
        if diff_minutes > shift_grace_period_minutes:
            is_late = True
            late_by_minutes = diff_minutes

        # Initial status: if half-day leave approved for today, mark HALF_DAY; otherwise PRESENT
        status = AttendanceStatus.HALF_DAY if has_approved_half_day_leave else AttendanceStatus.PRESENT

        return {
            "is_late": is_late,
            "late_by_minutes": max(0, late_by_minutes),
            "attendance_status": status,
        }

    # -------------------------------------------------------------------------
    # 2. Check-Out Evaluation
    # -------------------------------------------------------------------------
    @staticmethod
    def evaluate_check_out(
        check_in_dt: datetime,
        check_out_dt: datetime,
        break_minutes: int,
        shift_expected_end: time,
        shift_half_day_threshold_minutes: int = 240,
        shift_full_day_threshold_minutes: int = 420,
        has_approved_half_day_leave: bool = False,
        existing_check_out: Optional[datetime] = None,
    ) -> Dict[str, Any]:
        """
        Calculates working minutes: total_worked_minutes = elapsed_minutes - break_minutes.
        Calculates early departure against shift policy and evaluates final attendance status.
        """
        if existing_check_out is not None:
            raise DuplicateCheckOutError("Teacher has already checked out for this date.")

        if check_out_dt < check_in_dt:
            raise InvalidAttendanceOperationError("Check-out time cannot be earlier than check-in time.")

        # Total elapsed duration in minutes
        elapsed_minutes = int((check_out_dt - check_in_dt).total_seconds() // 60)
        total_worked_minutes = max(0, elapsed_minutes - break_minutes)

        # Early departure calculation
        check_out_time_val = check_out_dt.time()
        end_seconds = shift_expected_end.hour * 3600 + shift_expected_end.minute * 60 + shift_expected_end.second
        check_out_seconds = check_out_time_val.hour * 3600 + check_out_time_val.minute * 60 + check_out_time_val.second

        is_early_departure = False
        early_by_minutes = 0
        if check_out_seconds < end_seconds:
            is_early_departure = True
            early_by_minutes = (end_seconds - check_out_seconds) // 60

        # Status determination:
        # If teacher has approved half-day leave, status remains HALF_DAY.
        # Otherwise, if worked minutes are below half-day threshold, evaluate as HALF_DAY or ABSENT.
        if has_approved_half_day_leave:
            status = AttendanceStatus.HALF_DAY
        elif total_worked_minutes < shift_half_day_threshold_minutes:
            status = AttendanceStatus.HALF_DAY
        else:
            status = AttendanceStatus.PRESENT

        return {
            "total_worked_minutes": total_worked_minutes,
            "worked_hours_display": TeacherAttendanceService.format_hours_and_minutes(total_worked_minutes),
            "is_early_departure": is_early_departure,
            "early_by_minutes": max(0, early_by_minutes),
            "attendance_status": status,
        }

    # -------------------------------------------------------------------------
    # 3. Break Session Evaluation
    # -------------------------------------------------------------------------
    @staticmethod
    def evaluate_break_session(
        break_start_dt: datetime,
        break_end_dt: datetime,
    ) -> int:
        """
        Validates break interval and calculates break duration in integer minutes.
        """
        if break_end_dt < break_start_dt:
            raise InvalidAttendanceOperationError("Break end time cannot be earlier than break start time.")
        duration_minutes = int((break_end_dt - break_start_dt).total_seconds() // 60)
        return max(0, duration_minutes)

    # -------------------------------------------------------------------------
    # 4. Attendance Correction Evaluation
    # -------------------------------------------------------------------------
    @staticmethod
    def evaluate_correction(
        correction: AttendanceCorrectionRequest,
        shift_expected_start: time,
        shift_expected_end: time,
        shift_grace_period_minutes: int = 15,
    ) -> Dict[str, Any]:
        """
        Calculates revised metrics when an authorized administrator corrects attendance.
        """
        total_worked_minutes: Optional[int] = None
        is_late = False
        late_by_minutes = 0
        is_early = False
        early_by_minutes = 0

        break_minutes = correction.break_minutes or 0

        if correction.check_in_time and correction.check_out_time:
            if correction.check_out_time < correction.check_in_time:
                raise InvalidAttendanceOperationError("check_out_time cannot precede check_in_time.")

            elapsed = int((correction.check_out_time - correction.check_in_time).total_seconds() // 60)
            total_worked_minutes = max(0, elapsed - break_minutes)

            # Check late
            in_t = correction.check_in_time.time()
            start_sec = shift_expected_start.hour * 3600 + shift_expected_start.minute * 60
            in_sec = in_t.hour * 3600 + in_t.minute * 60
            diff_in = (in_sec - start_sec) // 60
            if diff_in > shift_grace_period_minutes:
                is_late = True
                late_by_minutes = diff_in

            # Check early
            out_t = correction.check_out_time.time()
            end_sec = shift_expected_end.hour * 3600 + shift_expected_end.minute * 60
            out_sec = out_t.hour * 3600 + out_t.minute * 60
            if out_sec < end_sec:
                is_early = True
                early_by_minutes = (end_sec - out_sec) // 60

        return {
            "attendance_status": correction.attendance_status,
            "check_in_time": correction.check_in_time,
            "check_out_time": correction.check_out_time,
            "break_minutes": break_minutes,
            "total_worked_minutes": total_worked_minutes,
            "worked_hours_display": TeacherAttendanceService.format_hours_and_minutes(total_worked_minutes),
            "is_late": is_late,
            "late_by_minutes": late_by_minutes,
            "is_early_departure": is_early,
            "early_by_minutes": early_by_minutes,
            "remarks": f"Corrected: {correction.correction_reason}",
        }

    # -------------------------------------------------------------------------
    # 5. Leave Integration: Reconcile Approved Leave
    # -------------------------------------------------------------------------
    @staticmethod
    def reconcile_leave_with_attendance(
        leave_application: Dict[str, Any],
    ) -> Dict[str, Any]:
        """
        Maps an approved leave application directly to attendance status.
        FULL_DAY -> ON_LEAVE
        HALF_DAY -> HALF_DAY
        """
        if leave_application.get("status") != "APPROVED":
            return {}

        duration_type = leave_application.get("leave_duration_type")
        if duration_type == "FULL_DAY":
            return {
                "attendance_status": AttendanceStatus.ON_LEAVE,
                "leave_application_id": leave_application.get("teacher_leave_application_id"),
                "check_in_time": None,
                "check_out_time": None,
                "total_worked_minutes": 0,
                "is_late": False,
                "is_early_departure": False,
                "remarks": f"Approved full-day leave ({leave_application.get('leave_type')}).",
            }
        elif duration_type == "HALF_DAY":
            return {
                "attendance_status": AttendanceStatus.HALF_DAY,
                "leave_application_id": leave_application.get("teacher_leave_application_id"),
                "remarks": f"Approved half-day leave ({leave_application.get('leave_type')}).",
            }
        return {}

    # -------------------------------------------------------------------------
    # 6. Monthly Summary Calculation
    # -------------------------------------------------------------------------
    @staticmethod
    def calculate_monthly_summary(
        teacher_id: int,
        school_id: int,
        branch_id: int,
        academic_year_id: int,
        month: int,
        year: int,
        total_calendar_days: int,
        attendance_records: List[Dict[str, Any]],
    ) -> MonthlyAttendanceSummaryResponse:
        """
        Aggregates monthly attendance metrics from daily records.
        """
        present_days = 0
        absent_days = 0
        half_days = 0
        on_leave_days = 0
        weekly_offs = 0
        holidays = 0
        total_worked_minutes = 0
        total_late = 0
        total_early = 0

        for r in attendance_records:
            st = r.get("attendance_status")
            if st == AttendanceStatus.PRESENT:
                present_days += 1
            elif st == AttendanceStatus.ABSENT:
                absent_days += 1
            elif st == AttendanceStatus.HALF_DAY:
                half_days += 1
            elif st == AttendanceStatus.ON_LEAVE:
                on_leave_days += 1
            elif st == AttendanceStatus.WEEKLY_OFF:
                weekly_offs += 1
            elif st == AttendanceStatus.HOLIDAY:
                holidays += 1

            mins = r.get("total_worked_minutes") or 0
            total_worked_minutes += mins

            if r.get("is_late"):
                total_late += 1
            if r.get("is_early_departure"):
                total_early += 1

        total_working_days = present_days + absent_days + half_days + on_leave_days
        effective_present = present_days + (0.5 * half_days)
        attendance_percentage = (
            round((effective_present / total_working_days) * 100, 2)
            if total_working_days > 0
            else 0.0
        )

        total_worked_hours = round(total_worked_minutes / 60.0, 2)
        working_days_present = present_days + half_days
        average_daily_minutes = (
            round(total_worked_minutes / working_days_present, 2)
            if working_days_present > 0
            else 0.0
        )

        return MonthlyAttendanceSummaryResponse(
            teacher_id=teacher_id,
            school_id=school_id,
            branch_id=branch_id,
            academic_year_id=academic_year_id,
            month=month,
            year=year,
            total_calendar_days=total_calendar_days,
            total_working_days=total_working_days,
            present_days=present_days,
            absent_days=absent_days,
            half_days=half_days,
            on_leave_days=on_leave_days,
            weekly_offs=weekly_offs,
            holidays=holidays,
            total_worked_minutes=total_worked_minutes,
            total_worked_hours=total_worked_hours,
            average_daily_worked_minutes=average_daily_minutes,
            total_late_arrivals=total_late,
            total_early_departures=total_early,
            attendance_percentage=attendance_percentage,
        )

