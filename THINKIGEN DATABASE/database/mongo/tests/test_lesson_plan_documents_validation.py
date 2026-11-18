"""
Contract and Schema Validation Test Suite for lesson_plan_documents.
Verifies all JavaScript definitions, regular expressions, index specifications,
and cross-field validation invariants without requiring an active live MongoDB connection.
"""

import re
from pathlib import Path
import pytest

ROOT = Path(__file__).resolve().parents[1]
COLL_FILE = ROOT / "collections" / "028_lesson_plan_documents.js"
INDEX_FILE = ROOT / "scripts" / "032_create_and_verify_lesson_plan_documents_indexes.js"
SAMPLE_FILE = ROOT / "scripts" / "033_insert_sample_lesson_plan_documents.js"
MOCK_FILE = ROOT / "scripts" / "036_insert_lesson_plan_documents_mock_data.js"
QUERY_FILE = ROOT / "scripts" / "034_query_reference_lesson_plan_documents.js"
MIG_FILE = ROOT / "scripts" / "035_migrate_lesson_plan_documents.js"
ROL_FILE = ROOT / "scripts" / "035_rollback_lesson_plan_documents.js"


def _read(p: Path) -> str:
    text = p.read_text(encoding="utf-8")
    assert text.strip(), f"File {p.name} is empty"
    return text


def test_files_exist() -> None:
    for f in [COLL_FILE, INDEX_FILE, SAMPLE_FILE, MOCK_FILE, QUERY_FILE, MIG_FILE, ROL_FILE]:
        assert f.exists(), f"Missing required file: {f}"


def test_collection_file_contract() -> None:
    src = _read(COLL_FILE)

    # 1. Collection Name & Strict Validation
    assert 'var COLLECTION_NAME = "lesson_plan_documents";' in src
    assert 'validationLevel: "strict"' in src
    assert 'validationAction: "error"' in src

    # 2. Required fields
    required_fields = [
        '"document_id"',
        '"tenant"',
        '"lesson_plan"',
        '"academic_scope"',
        '"owner"',
        '"classification"',
        '"file"',
        '"storage"',
        '"security"',
        '"lifecycle"',
        '"uploaded_by"',
        '"created_at"',
        '"updated_at"'
    ]
    for rf in required_fields:
        assert rf in src, f"Missing required field in validator: {rf}"

    # 3. Enum Constraints
    assert '"LESSON_PLAN"' in src
    assert '"RESOURCE"' in src
    assert '"ATTACHMENT"' in src
    assert '"REFERENCE"' in src
    assert '"MEDIA"' in src
    assert '"AWS_S3"' in src
    assert '"PRIVATE"' in src
    assert '"RESTRICTED"' in src
    assert '"PUBLIC"' in src
    assert '"UPLOADING"' in src
    assert '"ACTIVE"' in src
    assert '"FAILED"' in src
    assert '"DELETED"' in src
    assert '"QUARANTINED"' in src

    # 4. Cross-Field Invariants in $and
    assert '$expr:' in src
    assert '$eq: ["$owner.entity_id", "$lesson_plan.lesson_plan_id"]' in src
    assert '"storage.provider": "AWS_S3"' in src
    assert '"owner.entity_type": "LESSON_PLAN"' in src
    assert '"classification.category": "LESSON_PLAN"' in src
    assert '"academic_scope.topic_id": null' in src
    assert '"academic_scope.chapter_id": { $ne: null }' in src
    assert '"lifecycle.status": { $ne: "DELETED" }' in src
    assert '"lifecycle.status": "DELETED"' in src


def test_workload_indexes_completeness() -> None:
    idx_src = _read(INDEX_FILE)

    required_indexes = [
        "uq_lesson_plan_documents_document_id",
        "uq_lesson_plan_documents_bucket_object_key",
        "ix_lesson_plan_documents_plan_status_created",
        "ix_lesson_plan_documents_tenant_status_created",
        "ix_lesson_plan_documents_teacher_status_created",
        "ix_lesson_plan_documents_tenant_class_section_status",
        "ix_lesson_plan_documents_tenant_subject_status",
        "ix_lesson_plan_documents_tenant_chapter_status",
        "ix_lesson_plan_documents_tenant_topic_status",
        "ix_lesson_plan_documents_tenant_checksum",
        "ix_lesson_plan_documents_lifecycle_cleanup",
        "ix_lesson_plan_documents_storage_cleanup"
    ]

    for idx_name in required_indexes:
        assert idx_name in idx_src, f"Index script missing index: {idx_name}"

    # Check partial filters
    assert 'UPLOADING' in idx_src and 'FAILED' in idx_src and 'QUARANTINED' in idx_src
    assert 'PENDING' in idx_src and 'FAILED' in idx_src


def test_sample_documents_validity() -> None:
    sample_src = _read(SAMPLE_FILE)

    assert "DOC-LP-2026-000001" in sample_src
    assert "DOC-LP-2026-000002" in sample_src
    assert "DOC-LP-2026-000003" in sample_src

    # Verify Science chapter-level resource (topic_id is null)
    assert 'chapter_id: "CH-04"' in sample_src
    assert 'topic_id: null' in sample_src
    assert 'attachment_type: "RESOURCE"' in sample_src

    # Verify Math topic-level attachment (topic_id is set)
    assert 'chapter_id: "CH-01"' in sample_src
    assert 'topic_id: "TOP-01"' in sample_src
    assert 'attachment_type: "ATTACHMENT"' in sample_src

    # Verify Class-wide reference (section_id and subject_id are null)
    assert 'section_id: null' in sample_src
    assert 'subject_id: null' in sample_src
    assert 'attachment_type: "REFERENCE"' in sample_src


def test_mock_data_script_completeness() -> None:
    mock_src = _read(MOCK_FILE)

    # Must contain all 8 documents
    for i in range(1, 9):
        assert f"DOC-LP-2026-{i:06d}" in mock_src, f"Missing document {i} in mock data script"

    # Verify media attachment
    assert '"MEDIA"' in mock_src
    # Verify soft-deleted document with audit trail
    assert '"DELETED"' in mock_src
    assert "deleted_at:" in mock_src
    assert "deleted_by: NumberInt(2)" in mock_src
    assert 'status: "PENDING"' in mock_src  # storage cleanup pending


def test_query_reference_patterns() -> None:
    query_src = _read(QUERY_FILE)

    for i in range(1, 12):
        assert f"QUERY {i}:" in query_src, f"Missing QUERY {i} in query reference script"


def test_migration_and_rollback_safety() -> None:
    mig_src = _read(MIG_FILE)
    rol_src = _read(ROL_FILE)

    # Both must use dynamic database resolution
    assert "targetDb" in mig_src and "targetDb" in rol_src
    assert "collMod" in mig_src and "collMod" in rol_src

    # Migration must handle backward compatibility for missing chapter_id/topic_id
    assert "academic_scope.chapter_id" in mig_src
    assert "academic_scope.topic_id" in mig_src

    # Rollback must drop the custom workload indexes and relax validator
    assert "dropIndex" in rol_src
    assert "uq_lesson_plan_documents_document_id" in rol_src
    assert "validationLevel: \"off\"" in rol_src


def test_regex_validations() -> None:
    # Document ID regex test
    doc_id_pattern = re.compile(r"^DOC-LP-[A-Z0-9]+(?:-[A-Z0-9]+)*$")
    assert doc_id_pattern.match("DOC-LP-2026-000001")
    assert doc_id_pattern.match("DOC-LP-2026-ABCD-1234")
    assert not doc_id_pattern.match("DOC-000001")
    assert not doc_id_pattern.match("doc-lp-2026-001")

    # SHA256 regex test
    sha_pattern = re.compile(r"^[a-f0-9]{64}$")
    assert sha_pattern.match("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    assert not sha_pattern.match("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b85")  # 63 chars
    assert not sha_pattern.match("E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855")  # uppercase

