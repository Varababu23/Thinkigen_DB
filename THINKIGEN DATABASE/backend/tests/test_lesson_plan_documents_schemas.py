"""
Unit & Schema Validation Tests for Lesson Plan Documents.
Tests Pydantic v2 schemas, cross-field invariants, and service helper methods.
"""

from datetime import datetime, timezone
import pytest
from pydantic import ValidationError

from app.schemas.lesson_plan_documents import (
    TenantScope,
    LessonPlanScope,
    AcademicScope,
    DocumentOwner,
    DocumentClassification,
    DocumentClassificationCategory,
    DocumentAttachmentType,
    DocumentVisibility,
    DocumentLifecycleStatus,
    FileMetadata,
    StorageMetadata,
    SecurityMetadata,
    LifecycleMetadata,
    PreviewMetadata,
    ProcessingMetadata,
    ProcessingStatus,
    LessonPlanDocument,
    LessonPlanDocumentCreateRequest,
)
from app.services.lesson_plan_documents_service import LessonPlanDocumentService


# -----------------------------------------------------------------------------
# Fixtures
# -----------------------------------------------------------------------------

@pytest.fixture
def valid_tenant():
    return TenantScope(school_id=1, branch_id=1, academic_year_id=1)


@pytest.fixture
def valid_file():
    return FileMetadata(
        original_name="physics_notes.pdf",
        extension="pdf",
        mime_type="application/pdf",
        size_bytes=204800,
        checksum_sha256="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    )


# -----------------------------------------------------------------------------
# Test Cases: Sample Documents
# -----------------------------------------------------------------------------

def test_sample1_science_chapter_level(valid_tenant, valid_file):
    """Sample 1: Science chapter-level resource (topic_id=None)."""
    now = datetime.now(timezone.utc)
    doc = LessonPlanDocument(
        document_id="DOC-LP-2026-000001",
        tenant=valid_tenant,
        lesson_plan=LessonPlanScope(lesson_plan_id=101, teacher_id=1),
        academic_scope=AcademicScope(
            class_id=9,
            section_id=1,
            subject_id=3,
            chapter_id="CH-04",
            topic_id=None,
        ),
        owner=DocumentOwner(entity_type="LESSON_PLAN", entity_id=101),
        classification=DocumentClassification(
            category=DocumentClassificationCategory.LESSON_PLAN,
            sub_category="LAB_EXPERIMENT_GUIDE",
            attachment_type=DocumentAttachmentType.RESOURCE,
        ),
        file=valid_file,
        storage=StorageMetadata(
            provider="AWS_S3",
            bucket="thinkigen-school-documents-private",
            object_key="lessons/1/1/1/101/DOC-LP-2026-000001/v1/physics_notes.pdf",
            version_id="s3.ver.001",
        ),
        security=SecurityMetadata(visibility=DocumentVisibility.RESTRICTED),
        lifecycle=LifecycleMetadata(status=DocumentLifecycleStatus.ACTIVE, deleted_at=None, deleted_by=None),
        uploaded_by=1,
        updated_by=None,
        preview=PreviewMetadata(
            available=True,
            object_key="lessons/1/1/1/101/DOC-LP-2026-000001/v1/previews/thumb.png",
            mime_type="image/png",
        ),
        processing=ProcessingMetadata(status=ProcessingStatus.COMPLETED, processed_at=now),
        storage_cleanup=None,
        created_at=now,
        updated_at=now,
    )
    assert doc.document_id == "DOC-LP-2026-000001"
    assert doc.academic_scope.chapter_id == "CH-04"
    assert doc.academic_scope.topic_id is None


def test_sample2_math_topic_level(valid_tenant):
    """Sample 2: Mathematics topic-level attachment (topic_id present)."""
    now = datetime.now(timezone.utc)
    doc = LessonPlanDocument(
        document_id="DOC-LP-2026-000002",
        tenant=valid_tenant,
        lesson_plan=LessonPlanScope(lesson_plan_id=102, teacher_id=2),
        academic_scope=AcademicScope(
            class_id=10,
            section_id=2,
            subject_id=1,
            chapter_id="CH-01",
            topic_id="TOP-01",
        ),
        owner=DocumentOwner(entity_type="LESSON_PLAN", entity_id=102),
        classification=DocumentClassification(
            category=DocumentClassificationCategory.LESSON_PLAN,
            sub_category="PRACTICE_WORKSHEET",
            attachment_type=DocumentAttachmentType.ATTACHMENT,
        ),
        file=FileMetadata(
            original_name="problem_set.docx",
            extension="docx",
            mime_type="application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            size_bytes=102400,
            checksum_sha256="875704a29a00824b0d0023a416a927a44f248eec13e9a7e0996c4d8e87e148e6",
        ),
        storage=StorageMetadata(
            provider="AWS_S3",
            bucket="thinkigen-school-documents-private",
            object_key="lessons/1/1/1/102/DOC-LP-2026-000002/v1/problem_set.docx",
        ),
        security=SecurityMetadata(visibility=DocumentVisibility.RESTRICTED),
        lifecycle=LifecycleMetadata(status=DocumentLifecycleStatus.ACTIVE, deleted_at=None, deleted_by=None),
        uploaded_by=2,
        updated_by=2,
        preview=None,
        processing=None,
        storage_cleanup=None,
        created_at=now,
        updated_at=now,
    )
    assert doc.academic_scope.topic_id == "TOP-01"


def test_sample3_class_wide_reference(valid_tenant, valid_file):
    """Sample 3: Class-wide reference (section_id=None, subject_id=None, chapter_id=None)."""
    now = datetime.now(timezone.utc)
    doc = LessonPlanDocument(
        document_id="DOC-LP-2026-000003",
        tenant=valid_tenant,
        lesson_plan=LessonPlanScope(lesson_plan_id=103, teacher_id=3),
        academic_scope=AcademicScope(
            class_id=8,
            section_id=None,
            subject_id=None,
            chapter_id=None,
            topic_id=None,
        ),
        owner=DocumentOwner(entity_type="LESSON_PLAN", entity_id=103),
        classification=DocumentClassification(
            category=DocumentClassificationCategory.LESSON_PLAN,
            sub_category="ORIENTATION",
            attachment_type=DocumentAttachmentType.REFERENCE,
        ),
        file=valid_file,
        storage=StorageMetadata(
            provider="AWS_S3",
            bucket="thinkigen-school-documents-private",
            object_key="lessons/1/1/1/103/DOC-LP-2026-000003/v1/physics_notes.pdf",
        ),
        security=SecurityMetadata(visibility=DocumentVisibility.PUBLIC),
        lifecycle=LifecycleMetadata(status=DocumentLifecycleStatus.ACTIVE, deleted_at=None, deleted_by=None),
        uploaded_by=3,
        updated_by=None,
        preview=None,
        processing=None,
        storage_cleanup=None,
        created_at=now,
        updated_at=now,
    )
    assert doc.academic_scope.section_id is None
    assert doc.security.visibility == DocumentVisibility.PUBLIC


# -----------------------------------------------------------------------------
# Test Cases: Curriculum Hierarchy Invariant
# -----------------------------------------------------------------------------

def test_topic_without_chapter_raises_error():
    """academic_scope.topic_id cannot be set when chapter_id is None."""
    with pytest.raises(ValidationError) as exc:
        AcademicScope(
            class_id=10,
            section_id=1,
            subject_id=1,
            chapter_id=None,
            topic_id="TOP-01",
        )
    assert "academic_scope.topic_id requires a valid chapter_id" in str(exc.value)


# -----------------------------------------------------------------------------
# Test Cases: Deletion Audit Invariant
# -----------------------------------------------------------------------------

def test_active_status_with_deletion_fields_raises_error():
    """Non-DELETED documents must have deleted_at=null and deleted_by=null."""
    with pytest.raises(ValidationError) as exc:
        LifecycleMetadata(
            status=DocumentLifecycleStatus.ACTIVE,
            deleted_at=datetime.now(timezone.utc),
            deleted_by=1,
        )
    assert "Non-DELETED documents must have deleted_at=null and deleted_by=null" in str(exc.value)


def test_deleted_status_missing_audit_raises_error():
    """DELETED status requires deleted_at and deleted_by."""
    with pytest.raises(ValidationError) as exc:
        LifecycleMetadata(
            status=DocumentLifecycleStatus.DELETED,
            deleted_at=None,
            deleted_by=None,
        )
    assert "DELETED status requires both deleted_at timestamp and deleted_by user ID" in str(exc.value)


def test_deleted_status_valid_audit_succeeds():
    """Valid DELETED record passes validation."""
    now = datetime.now(timezone.utc)
    lifecycle = LifecycleMetadata(
        status=DocumentLifecycleStatus.DELETED,
        deleted_at=now,
        deleted_by=10,
    )
    assert lifecycle.status == DocumentLifecycleStatus.DELETED
    assert lifecycle.deleted_by == 10


# -----------------------------------------------------------------------------
# Test Cases: Cross-Field Invariant (Owner Entity ID == Lesson Plan ID)
# -----------------------------------------------------------------------------

def test_owner_mismatch_raises_error(valid_tenant, valid_file):
    """owner.entity_id must strictly match lesson_plan.lesson_plan_id."""
    now = datetime.now(timezone.utc)
    with pytest.raises(ValidationError) as exc:
        LessonPlanDocument(
            document_id="DOC-LP-2026-000001",
            tenant=valid_tenant,
            lesson_plan=LessonPlanScope(lesson_plan_id=101, teacher_id=1),
            academic_scope=AcademicScope(class_id=9),
            owner=DocumentOwner(entity_type="LESSON_PLAN", entity_id=999),  # Mismatch!
            classification=DocumentClassification(
                category=DocumentClassificationCategory.LESSON_PLAN,
                attachment_type=DocumentAttachmentType.RESOURCE,
            ),
            file=valid_file,
            storage=StorageMetadata(
                provider="AWS_S3",
                bucket="thinkigen-school-documents-private",
                object_key="lessons/1/1/1/101/doc/v1/f.pdf",
            ),
            security=SecurityMetadata(visibility=DocumentVisibility.RESTRICTED),
            lifecycle=LifecycleMetadata(status=DocumentLifecycleStatus.ACTIVE),
            uploaded_by=1,
            created_at=now,
            updated_at=now,
        )
    assert "owner.entity_id ('999') must strictly match lesson_plan.lesson_plan_id ('101')" in str(exc.value)


# -----------------------------------------------------------------------------
# Test Cases: Service Helpers
# -----------------------------------------------------------------------------

def test_service_id_and_key_formulation():
    doc_id = LessonPlanDocumentService.generate_document_id(2026)
    assert doc_id.startswith("DOC-LP-2026-")
    assert len(doc_id) >= 15

    key = LessonPlanDocumentService.construct_s3_key(
        school_id=1,
        branch_id=2,
        academic_year_id=2026,
        lesson_plan_id=101,
        document_id=doc_id,
        filename="Physics Lab Guide.pdf",
        version=1,
    )
    assert key == f"lessons/1/2/2026/101/{doc_id}/v1/Physics_Lab_Guide.pdf"

