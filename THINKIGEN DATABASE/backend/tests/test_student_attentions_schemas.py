"""
Unit tests for student_attentions Pydantic models and service logic.
"""

from datetime import datetime, timezone, date
import pytest

from app.schemas.student_attentions import (
    AttentionType,
    TriggerSource,
    AttentionStatus,
    AttentionItemBase,
    AssessmentDetails,
    HomeworkDetails,
    AttendanceDetails,
    HomeworkSubmissionStatus,
    AttendancePeriodStatus,
    SubjectAttentionItem,
    StudentSubjectAttentionDocument,
)
from app.services.student_attentions_service import generate_deterministic_attention_id


def test_deterministic_attention_id():
    att_id_asm = generate_deterministic_attention_id(101, TriggerSource.ASSESSMENT, 501, 2026)
    assert att_id_asm == "ATT-101-ASM-501-2026"

    att_id_hw = generate_deterministic_attention_id(101, TriggerSource.ASSIGNMENT_HOMEWORK, 802, 2026)
    assert att_id_hw == "ATT-101-HW-802-2026"

    att_id_att = generate_deterministic_attention_id(101, TriggerSource.ATTENDANCE, 9003, 2026)
    assert att_id_att == "ATT-101-ATT-9003-2026"


def test_valid_assessment_attention():
    att = AttentionItemBase(
        attention_id="ATT-101-ASM-501-2026",
        attention_type=AttentionType.LOW_ASSESSMENT_SCORE,
        title="Failed Slip Test",
        description="Scored 12 out of 50",
        trigger_source=TriggerSource.ASSESSMENT,
        source_id=501,
        triggered_at=datetime.now(timezone.utc),
        status=AttentionStatus.ACTIVE,
        assessment_details=AssessmentDetails(
            assessment_id=501,
            assessment_name="Slip Test 1",
            exam_type="SLIP_TEST",
            max_marks=50,
            pass_marks=20,
            obtained_marks=12,
            percentage=24.0,
        ),
    )
    assert att.attention_type == AttentionType.LOW_ASSESSMENT_SCORE
    assert att.trigger_source == TriggerSource.ASSESSMENT
    assert att.assessment_details.obtained_marks == 12


def test_invalid_assessment_mismatched_trigger():
    with pytest.raises(ValueError, match="LOW_ASSESSMENT_SCORE must have trigger_source = ASSESSMENT"):
        AttentionItemBase(
            attention_id="ATT-101-ASM-501-2026",
            attention_type=AttentionType.LOW_ASSESSMENT_SCORE,
            title="Failed Slip Test",
            description="Scored 12 out of 50",
            trigger_source=TriggerSource.ATTENDANCE,  # INVALID TRIGGER
            source_id=501,
            triggered_at=datetime.now(timezone.utc),
            status=AttentionStatus.ACTIVE,
            assessment_details=AssessmentDetails(
                assessment_id=501,
                assessment_name="Slip Test 1",
                max_marks=50,
                pass_marks=20,
                obtained_marks=12,
                percentage=24.0,
            ),
        )


def test_invalid_assessment_with_homework_details():
    with pytest.raises(ValueError, match="homework_details and attendance_details must be null"):
        AttentionItemBase(
            attention_id="ATT-101-ASM-501-2026",
            attention_type=AttentionType.LOW_ASSESSMENT_SCORE,
            title="Failed Slip Test",
            description="Scored 12 out of 50",
            trigger_source=TriggerSource.ASSESSMENT,
            source_id=501,
            triggered_at=datetime.now(timezone.utc),
            status=AttentionStatus.ACTIVE,
            assessment_details=AssessmentDetails(
                assessment_id=501,
                assessment_name="Slip Test 1",
                max_marks=50,
                pass_marks=20,
                obtained_marks=12,
                percentage=24.0,
            ),
            homework_details=HomeworkDetails(  # ILLEGAL FOR ASSESSMENT
                homework_id=1,
                homework_title="HW",
                assigned_date=date(2026, 10, 1),
                due_date=date(2026, 10, 3),
                submission_status=HomeworkSubmissionStatus.NOT_SUBMITTED,
            ),
        )


def test_valid_homework_attention():
    att = AttentionItemBase(
        attention_id="ATT-101-HW-802-2026",
        attention_type=AttentionType.PENDING_HOMEWORK,
        title="Pending Homework Ex 4",
        description="Homework overdue",
        trigger_source=TriggerSource.ASSIGNMENT_HOMEWORK,
        source_id=802,
        triggered_at=datetime.now(timezone.utc),
        status=AttentionStatus.ACTIVE,
        homework_details=HomeworkDetails(
            homework_id=802,
            homework_title="Ex 4 Algebra",
            assigned_date=date(2026, 10, 10),
            due_date=date(2026, 10, 12),
            days_overdue=4,
            submission_status=HomeworkSubmissionStatus.NOT_SUBMITTED,
        ),
    )
    assert att.attention_type == AttentionType.PENDING_HOMEWORK
    assert att.homework_details.days_overdue == 4


def test_valid_attendance_attention():
    att = AttentionItemBase(
        attention_id="ATT-101-ATT-9003-2026",
        attention_type=AttentionType.ABSENT_ATTENDANCE,
        title="Absent in Period 2",
        description="Period absence",
        trigger_source=TriggerSource.ATTENDANCE,
        source_id=9003,
        triggered_at=datetime.now(timezone.utc),
        status=AttentionStatus.ACTIVE,
        attendance_details=AttendanceDetails(
            attendance_id=9003,
            attendance_date=date(2026, 10, 15),
            period_number=2,
            period_time="09:15 - 10:00",
            attendance_status=AttendancePeriodStatus.ABSENT,
        ),
    )
    assert att.attention_type == AttentionType.ABSENT_ATTENDANCE
    assert att.attendance_details.period_number == 2


def test_resolution_audit_requirements():
    # RESOLVED requires resolved_at
    with pytest.raises(ValueError, match="resolved_at must be populated"):
        AttentionItemBase(
            attention_id="ATT-101-ASM-501-2026",
            attention_type=AttentionType.LOW_ASSESSMENT_SCORE,
            title="Failed Slip Test",
            description="Scored 12 out of 50",
            trigger_source=TriggerSource.ASSESSMENT,
            source_id=501,
            triggered_at=datetime.now(timezone.utc),
            status=AttentionStatus.RESOLVED,
            resolved_at=None,  # Missing!
            assessment_details=AssessmentDetails(
                assessment_id=501,
                assessment_name="Slip Test 1",
                max_marks=50,
                pass_marks=20,
                obtained_marks=12,
                percentage=24.0,
            ),
        )

    # EXCUSED requires excused_reason
    with pytest.raises(ValueError, match="excused_reason must be populated"):
        AttentionItemBase(
            attention_id="ATT-101-ATT-9003-2026",
            attention_type=AttentionType.ABSENT_ATTENDANCE,
            title="Absent in Period 2",
            description="Period absence",
            trigger_source=TriggerSource.ATTENDANCE,
            source_id=9003,
            triggered_at=datetime.now(timezone.utc),
            status=AttentionStatus.EXCUSED,
            excused_reason=None,  # Missing!
            attendance_details=AttendanceDetails(
                attendance_id=9003,
                attendance_date=date(2026, 10, 15),
                period_number=2,
                attendance_status=AttendancePeriodStatus.ABSENT,
            ),
        )


def test_document_recalculate_counts():
    now = datetime.now(timezone.utc)
    att1 = AttentionItemBase(
        attention_id="ATT-101-ASM-501-2026",
        attention_type=AttentionType.LOW_ASSESSMENT_SCORE,
        title="Failed Slip Test",
        description="Scored 12 out of 50",
        trigger_source=TriggerSource.ASSESSMENT,
        source_id=501,
        triggered_at=now,
        status=AttentionStatus.ACTIVE,
        assessment_details=AssessmentDetails(
            assessment_id=501,
            assessment_name="Slip Test 1",
            max_marks=50,
            pass_marks=20,
            obtained_marks=12,
            percentage=24.0,
        ),
    )
    att2 = AttentionItemBase(
        attention_id="ATT-101-HW-802-2026",
        attention_type=AttentionType.PENDING_HOMEWORK,
        title="Pending Homework Ex 4",
        description="Homework overdue",
        trigger_source=TriggerSource.ASSIGNMENT_HOMEWORK,
        source_id=802,
        triggered_at=now,
        status=AttentionStatus.RESOLVED,
        resolved_at=now,
        homework_details=HomeworkDetails(
            homework_id=802,
            homework_title="Ex 4 Algebra",
            assigned_date=date(2026, 10, 10),
            due_date=date(2026, 10, 12),
            submission_status=HomeworkSubmissionStatus.NOT_SUBMITTED,
        ),
    )

    sub1 = SubjectAttentionItem(
        subject_id=1,
        subject_name="Mathematics",
        subject_code="MAT",
        attentions=[att1, att2],
    )

    doc = StudentSubjectAttentionDocument(
        student_id=101,
        student_name="Rahul Varma",
        school_id=1,
        branch_id=1,
        academic_year_id=2026,
        class_id=10,
        class_name="Class 10",
        section_id=1,
        section_name="A",
        subjects=[sub1],
        last_evaluated_at=now,
        created_at=now,
        updated_at=now,
    )

    # Trigger recalculation
    doc.recalculate_counts()

    # att1 is ACTIVE, att2 is RESOLVED
    assert doc.subjects[0].total_attentions_raised == 2
    assert doc.subjects[0].active_attentions_count == 1
    assert doc.total_attentions_raised == 2
    assert doc.total_active_attentions == 1


def test_all_attention_statuses_counted_in_overall_raised():
    """
    Verifies that all 4 lifecycle statuses (ACTIVE, ACKNOWLEDGED, RESOLVED, EXCUSED)
    are counted in total_attentions_raised, while only ACTIVE counts towards total_active_attentions.
    """
    now = datetime.now(timezone.utc)

    # 1. ACTIVE
    att_act = AttentionItemBase(
        attention_id="ATT-101-ASM-1-2026",
        attention_type=AttentionType.LOW_ASSESSMENT_SCORE,
        title="Failed Slip Test",
        description="Scored 10 out of 50",
        trigger_source=TriggerSource.ASSESSMENT,
        source_id=1,
        triggered_at=now,
        status=AttentionStatus.ACTIVE,
        assessment_details=AssessmentDetails(
            assessment_id=1,
            assessment_name="Slip Test 1",
            max_marks=50,
            pass_marks=20,
            obtained_marks=10,
            percentage=20.0,
        ),
    )

    # 2. ACTIVE
    att_act_high = AttentionItemBase(
        attention_id="ATT-101-HW-2-2026",
        attention_type=AttentionType.PENDING_HOMEWORK,
        title="Pending Homework",
        description="Homework overdue",
        trigger_source=TriggerSource.ASSIGNMENT_HOMEWORK,
        source_id=2,
        triggered_at=now,
        status=AttentionStatus.ACTIVE,
        homework_details=HomeworkDetails(
            homework_id=2,
            homework_title="HW 2",
            assigned_date=date(2026, 10, 1),
            due_date=date(2026, 10, 3),
            submission_status=HomeworkSubmissionStatus.NOT_SUBMITTED,
        ),
    )

    # 3. ACKNOWLEDGED
    att_ack = AttentionItemBase(
        attention_id="ATT-101-ATT-3-2026",
        attention_type=AttentionType.ABSENT_ATTENDANCE,
        title="Absent in Period 1",
        description="Absence",
        trigger_source=TriggerSource.ATTENDANCE,
        source_id=3,
        triggered_at=now,
        status=AttentionStatus.ACKNOWLEDGED,
        acknowledged_at=now,
        acknowledged_by_teacher_id=5,
        attendance_details=AttendanceDetails(
            attendance_id=3,
            attendance_date=date(2026, 10, 4),
            period_number=1,
            attendance_status=AttendancePeriodStatus.ABSENT,
        ),
    )

    # 4. RESOLVED
    att_res = AttentionItemBase(
        attention_id="ATT-101-HW-4-2026",
        attention_type=AttentionType.PENDING_HOMEWORK,
        title="Pending Homework 4",
        description="Homework resolved",
        trigger_source=TriggerSource.ASSIGNMENT_HOMEWORK,
        source_id=4,
        triggered_at=now,
        status=AttentionStatus.RESOLVED,
        resolved_at=now,
        resolved_by_teacher_id=5,
        resolution_remarks="Submitted late and checked",
        homework_details=HomeworkDetails(
            homework_id=4,
            homework_title="HW 4",
            assigned_date=date(2026, 10, 5),
            due_date=date(2026, 10, 7),
            submission_status=HomeworkSubmissionStatus.NOT_SUBMITTED,
        ),
    )

    # 5. EXCUSED
    att_exc = AttentionItemBase(
        attention_id="ATT-101-ATT-5-2026",
        attention_type=AttentionType.ABSENT_ATTENDANCE,
        title="Absent in Period 3",
        description="Medical absence",
        trigger_source=TriggerSource.ATTENDANCE,
        source_id=5,
        triggered_at=now,
        status=AttentionStatus.EXCUSED,
        resolved_at=now,
        resolved_by_teacher_id=5,
        excused_reason="Medical certificate provided",
        attendance_details=AttendanceDetails(
            attendance_id=5,
            attendance_date=date(2026, 10, 8),
            period_number=3,
            attendance_status=AttendancePeriodStatus.ABSENT,
        ),
    )

    sub_math = SubjectAttentionItem(
        subject_id=1,
        subject_name="Mathematics",
        subject_code="MAT",
        attentions=[att_act, att_act_high, att_ack],
    )

    sub_sci = SubjectAttentionItem(
        subject_id=2,
        subject_name="Science",
        subject_code="SCI",
        attentions=[att_res, att_exc],
    )

    doc = StudentSubjectAttentionDocument(
        student_id=101,
        student_name="Rahul Varma",
        school_id=1,
        branch_id=1,
        academic_year_id=2026,
        class_id=10,
        class_name="Class 10",
        section_id=1,
        section_name="A",
        subjects=[sub_math, sub_sci],
        last_evaluated_at=now,
        created_at=now,
        updated_at=now,
    )

    doc.recalculate_counts()

    # Math: 3 total raised, 2 active
    assert doc.subjects[0].total_attentions_raised == 3
    assert doc.subjects[0].active_attentions_count == 2

    # Science: 2 total raised (1 resolved, 1 excused), 0 active
    assert doc.subjects[1].total_attentions_raised == 2
    assert doc.subjects[1].active_attentions_count == 0

    # Overall Student Document:
    # Total raised: 3 + 2 = 5
    # Total active: 2
    assert doc.total_attentions_raised == 5
    assert doc.total_active_attentions == 2
