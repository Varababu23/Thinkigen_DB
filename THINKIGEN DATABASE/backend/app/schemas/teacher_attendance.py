"""
Thinkigen School ERP - Teacher Attendance Pydantic Schemas.
Module: Teacher Portal - Attendance Management
Database: Microsoft SQL Server (teachers_schema)

Enforces:
- Strict attendance status and event type enumerations
- Integer working duration and break calculations (zero floating-point authoritative durations)
- Late arrival and early departure metrics
- Concurrency-safe check-in, check-out, break tracking, and administrative correction contracts
- Timezone-aware date and timestamp representations
"""

from __future__ import annotations

from datetime import date, datetime, time
from decimal import Decimal
from enum import Enum
from typing import Optional, List, Union
from pydantic import BaseModel, Field, model_validator, field_validator, ConfigDict


# -----------------------------------------------------------------------------
# Enums
# -----------------------------------------------------------------------------

class AttendanceStatus(str, Enum):
    PRESENT = "PRESENT"
    ABSENT = "ABSENT"
    HALF_DAY = "HALF_DAY"
    ON_LEAVE = "ON_LEAVE"
    WEEKLY_OFF = "WEEKLY_OFF"
    HOLIDAY = "HOLIDAY"


class AttendanceEventSource(str, Enum):
    WEB_PORTAL = "WEB_PORTAL"
    MOBILE_APP = "MOBILE_APP"
    BIOMETRIC = "BIOMETRIC"
    SYSTEM = "SYSTEM"
    ADMIN_MANUAL = "ADMIN_MANUAL"


class AttendanceEventType(str, Enum):
    CHECK_IN = "CHECK_IN"
    CHECK_OUT = "CHECK_OUT"
    BREAK_START = "BREAK_START"
    BREAK_END = "BREAK_END"
    ATTENDANCE_CORRECTION = "ATTENDANCE_CORRECTION"
    ADMIN_OVERRIDE = "ADMIN_OVERRIDE"
    BIOMETRIC_SYNC = "BIOMETRIC_SYNC"
    AUTO_ABSENT_MARKED = "AUTO_ABSENT_MARKED"


class BreakType(str, Enum):
    LUNCH = "LUNCH"
    TEA = "TEA"
    PERSONAL = "PERSONAL"
    OFFICIAL = "OFFICIAL"
    OTHER = "OTHER"


# -----------------------------------------------------------------------------
# Request Schemas
# -----------------------------------------------------------------------------

class TeacherCheckInRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    source: AttendanceEventSource = AttendanceEventSource.WEB_PORTAL
    remarks: Optional[str] = Field(None, max_length=500)
    device_id: Optional[str] = Field(None, max_length=100)


class TeacherCheckOutRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    source: AttendanceEventSource = AttendanceEventSource.WEB_PORTAL
    remarks: Optional[str] = Field(None, max_length=500)
    device_id: Optional[str] = Field(None, max_length=100)


class TeacherBreakStartRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    break_type: BreakType = BreakType.LUNCH
    remarks: Optional[str] = Field(None, max_length=500)


class TeacherBreakEndRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    attendance_break_id: int = Field(..., ge=1)
    remarks: Optional[str] = Field(None, max_length=500)


class AttendanceCorrectionRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    attendance_date: date
    attendance_status: AttendanceStatus
    check_in_time: Optional[datetime] = None
    check_out_time: Optional[datetime] = None
    break_minutes: Optional[int] = Field(None, ge=0)
    correction_reason: str = Field(..., min_length=5, max_length=500)

    @model_validator(mode="after")
    def validate_times(self) -> AttendanceCorrectionRequest:
        if self.check_in_time and self.check_out_time:
            if self.check_out_time < self.check_in_time:
                raise ValueError("check_out_time cannot be earlier than check_in_time")
        return self


# -----------------------------------------------------------------------------
# Response Schemas
# -----------------------------------------------------------------------------

class AttendanceBreakResponse(BaseModel):
    model_config = ConfigDict(extra="ignore")

    attendance_break_id: int
    teacher_attendance_id: int
    break_start_time: datetime
    break_end_time: Optional[datetime] = None
    break_duration_minutes: Optional[int] = None
    break_type: BreakType
    is_approved: bool


class AttendanceEventResponse(BaseModel):
    model_config = ConfigDict(extra="ignore")

    attendance_event_id: int
    teacher_attendance_id: int
    teacher_id: int
    event_type: AttendanceEventType
    event_time: datetime
    event_source: AttendanceEventSource
    performed_by: Optional[int] = None
    remarks: Optional[str] = None
    correction_reason: Optional[str] = None
    original_status: Optional[str] = None
    revised_status: Optional[str] = None
    original_check_in_time: Optional[datetime] = None
    revised_check_in_time: Optional[datetime] = None
    original_check_out_time: Optional[datetime] = None
    revised_check_out_time: Optional[datetime] = None
    original_total_worked_minutes: Optional[int] = None
    revised_total_worked_minutes: Optional[int] = None
    original_break_minutes: Optional[int] = None
    revised_break_minutes: Optional[int] = None


class TeacherAttendanceResponse(BaseModel):
    model_config = ConfigDict(extra="ignore")

    teacher_attendance_id: int
    school_id: int
    branch_id: int
    academic_year_id: int
    teacher_id: int
    attendance_date: date
    attendance_status: AttendanceStatus
    check_in_time: Optional[datetime] = None
    check_out_time: Optional[datetime] = None
    total_worked_minutes: Optional[int] = None
    remarks: Optional[str] = None
    is_active: bool = True
    created_at: Optional[datetime] = None
    created_by: Optional[int] = None
    updated_at: Optional[datetime] = None
    updated_by: Optional[int] = None

    # Auxiliary / legacy display fields (optional with defaults)
    break_minutes: int = 0
    worked_hours_display: Optional[str] = None
    is_late: bool = False
    late_by_minutes: int = 0
    is_early_departure: bool = False
    early_by_minutes: int = 0
    leave_application_id: Optional[int] = None
    check_in_source: Optional[str] = None
    check_out_source: Optional[str] = None
    marked_by: Optional[int] = None
    is_corrected: bool = False
    correction_reason: Optional[str] = None
    corrected_by: Optional[int] = None
    corrected_at: Optional[datetime] = None
    breaks: List[AttendanceBreakResponse] = []


class MonthlyAttendanceSummaryResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    teacher_id: int
    school_id: int
    branch_id: int
    academic_year_id: int
    month: int
    year: int
    total_calendar_days: int
    total_working_days: int
    present_days: int
    absent_days: int
    half_days: int
    on_leave_days: int
    weekly_offs: int
    holidays: int
    total_worked_minutes: int
    total_worked_hours: float
    average_daily_worked_minutes: float
    total_late_arrivals: int
    total_early_departures: int
    attendance_percentage: float


class BranchDailyAttendanceReportItem(BaseModel):
    model_config = ConfigDict(extra="ignore")

    teacher_id: int
    employee_code: str
    teacher_name: str
    designation: str
    attendance_status: AttendanceStatus
    check_in_time: Optional[datetime] = None
    check_out_time: Optional[datetime] = None
    total_worked_minutes: Optional[int] = None
    is_late: bool
    late_by_minutes: int
    is_early_departure: bool
    early_by_minutes: int
    remarks: Optional[str] = None


class LateArrivalReportItem(BaseModel):
    model_config = ConfigDict(extra="ignore")

    teacher_id: int
    employee_code: str
    teacher_name: str
    attendance_date: date
    check_in_time: datetime
    expected_start_time: str
    late_by_minutes: int
    remarks: Optional[str] = None


class AbsentTeacherReportItem(BaseModel):
    model_config = ConfigDict(extra="ignore")

    teacher_id: int
    employee_code: str
    teacher_name: str
    attendance_date: date
    has_approved_leave: bool
    leave_application_id: Optional[int] = None
    leave_type: Optional[str] = None
    remarks: Optional[str] = None

