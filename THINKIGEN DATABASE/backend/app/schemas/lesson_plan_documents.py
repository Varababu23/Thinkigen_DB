"""
Thinkigen School ERP - Lesson Plan Documents Pydantic Schemas.
Module: Teacher Portal - Lesson Plan Management
Database: Thinkigen (MongoDB)

Enforces:
- Strict cross-field validations (curriculum topic-chapter hierarchy, deletion audit invariants)
- S3 storage key patterns and provider validation
- Strong typing for multi-tenant isolation and SQL Server foreign keys
- Safe BSON compatibility and zero raw binary payloads
"""

from __future__ import annotations

import re
from datetime import datetime
from enum import Enum
from typing import Optional, Union, List
from pydantic import BaseModel, Field, model_validator, field_validator, ConfigDict


# -----------------------------------------------------------------------------
# Enums
# -----------------------------------------------------------------------------

class DocumentClassificationCategory(str, Enum):
    LESSON_PLAN = "LESSON_PLAN"


class DocumentAttachmentType(str, Enum):
    RESOURCE = "RESOURCE"
    ATTACHMENT = "ATTACHMENT"
    REFERENCE = "REFERENCE"
    MEDIA = "MEDIA"


class DocumentVisibility(str, Enum):
    PRIVATE = "PRIVATE"
    RESTRICTED = "RESTRICTED"
    PUBLIC = "PUBLIC"


class DocumentLifecycleStatus(str, Enum):
    UPLOADING = "UPLOADING"
    ACTIVE = "ACTIVE"
    FAILED = "FAILED"
    DELETED = "DELETED"
    QUARANTINED = "QUARANTINED"


class ProcessingStatus(str, Enum):
    NOT_REQUIRED = "NOT_REQUIRED"
    PENDING = "PENDING"
    PROCESSING = "PROCESSING"
    COMPLETED = "COMPLETED"
    FAILED = "FAILED"


class StorageCleanupStatus(str, Enum):
    PENDING = "PENDING"
    COMPLETED = "COMPLETED"
    FAILED = "FAILED"


# -----------------------------------------------------------------------------
# Component Schemas
# -----------------------------------------------------------------------------

class TenantScope(BaseModel):
    model_config = ConfigDict(extra="forbid")

    school_id: int = Field(..., ge=1, description="SQL Server school_id")
    branch_id: int = Field(..., ge=1, description="SQL Server branch_id")
    academic_year_id: int = Field(..., ge=1, description="SQL Server academic_year_id")


class LessonPlanScope(BaseModel):
    model_config = ConfigDict(extra="forbid")

    lesson_plan_id: Union[int, str] = Field(..., description="SQL Server lesson_plan_id")
    teacher_id: int = Field(..., ge=1, description="SQL Server teacher_id / user_id")


class AcademicScope(BaseModel):
    model_config = ConfigDict(extra="forbid")

    class_id: int = Field(..., ge=1, description="SQL Server class_id (mandatory)")
    section_id: Optional[int] = Field(None, ge=1, description="SQL Server section_id (null for class-wide)")
    subject_id: Optional[int] = Field(None, ge=1, description="SQL Server subject_id (null for cross-subject)")
    chapter_id: Optional[Union[str, int]] = Field(None, max_length=128, description="Syllabus chapter identifier")
    topic_id: Optional[Union[str, int]] = Field(None, max_length=128, description="Syllabus topic identifier")

    @model_validator(mode="after")
    def validate_curriculum_hierarchy(self) -> AcademicScope:
        """Enforces that a topic cannot exist without an accompanying chapter."""
        if self.topic_id is not None and self.chapter_id is None:
            raise ValueError("Curriculum hierarchy error: academic_scope.topic_id requires a valid chapter_id.")
        return self


class DocumentOwner(BaseModel):
    model_config = ConfigDict(extra="forbid")

    entity_type: str = Field("LESSON_PLAN", pattern="^LESSON_PLAN$")
    entity_id: Union[int, str] = Field(..., description="Must match lesson_plan.lesson_plan_id")


class DocumentClassification(BaseModel):
    model_config = ConfigDict(extra="forbid")

    category: DocumentClassificationCategory = DocumentClassificationCategory.LESSON_PLAN
    sub_category: Optional[str] = Field(None, max_length=100)
    attachment_type: DocumentAttachmentType


class FileMetadata(BaseModel):
    model_config = ConfigDict(extra="forbid")

    original_name: str = Field(..., min_length=1, max_length=255)
    extension: str = Field(..., min_length=1, max_length=16)
    mime_type: str = Field(..., min_length=3, max_length=200)
    size_bytes: int = Field(..., ge=1)
    checksum_sha256: str = Field(..., min_length=64, max_length=64)

    @field_validator("extension")
    @classmethod
    def validate_extension(cls, v: str) -> str:
        clean = v.lstrip(".").lower()
        if not re.match(r"^[a-z0-9]{1,16}$", clean):
            raise ValueError(f"Invalid lowercase extension format: '{v}'")
        return clean

    @field_validator("checksum_sha256")
    @classmethod
    def validate_checksum(cls, v: str) -> str:
        clean = v.lower().strip()
        if not re.match(r"^[a-f0-9]{64}$", clean):
            raise ValueError("checksum_sha256 must be exactly 64 hexadecimal characters.")
        return clean

    @field_validator("mime_type")
    @classmethod
    def validate_mime_type(cls, v: str) -> str:
        if not re.match(r"^[a-z0-9!#$&^_.+-]+/[a-z0-9!#$&^_.+-]+$", v):
            raise ValueError(f"Invalid MIME type format: '{v}'")
        return v


class StorageMetadata(BaseModel):
    model_config = ConfigDict(extra="forbid")

    provider: str = Field("AWS_S3", pattern="^AWS_S3$")
    bucket: str = Field(..., min_length=3, max_length=63)
    object_key: str = Field(..., min_length=1, max_length=1024)
    version_id: Optional[str] = Field(None, max_length=512)


class SecurityMetadata(BaseModel):
    model_config = ConfigDict(extra="forbid")

    visibility: DocumentVisibility = DocumentVisibility.RESTRICTED


class LifecycleMetadata(BaseModel):
    model_config = ConfigDict(extra="forbid")

    status: DocumentLifecycleStatus
    deleted_at: Optional[datetime] = None
    deleted_by: Optional[int] = Field(None, ge=1)

    @model_validator(mode="after")
    def validate_deletion_invariants(self) -> LifecycleMetadata:
        """Enforces deletion audit invariants across all status transitions."""
        if self.status == DocumentLifecycleStatus.DELETED:
            if self.deleted_at is None or self.deleted_by is None:
                raise ValueError("DELETED status requires both deleted_at timestamp and deleted_by user ID.")
        else:
            if self.deleted_at is not None or self.deleted_by is not None:
                raise ValueError("Non-DELETED documents must have deleted_at=null and deleted_by=null.")
        return self


class PreviewMetadata(BaseModel):
    model_config = ConfigDict(extra="forbid")

    available: bool = True
    object_key: str = Field(..., min_length=1, max_length=1024)
    mime_type: str = Field(..., pattern=r"^[a-z0-9!#$&^_.+-]+/[a-z0-9!#$&^_.+-]+$")


class ProcessingMetadata(BaseModel):
    model_config = ConfigDict(extra="forbid")

    status: ProcessingStatus
    processed_at: Optional[datetime] = None
    processor_version: Optional[str] = Field(None, max_length=100)
    error_code: Optional[str] = Field(None, max_length=100)


class StorageCleanupMetadata(BaseModel):
    model_config = ConfigDict(extra="forbid")

    status: StorageCleanupStatus
    attempts: int = Field(0, ge=0)
    last_attempt_at: Optional[datetime] = None
    last_error: Optional[str] = Field(None, max_length=2000)


# -----------------------------------------------------------------------------
# Main Document Schema (MongoDB Document Representation)
# -----------------------------------------------------------------------------

class LessonPlanDocument(BaseModel):
    model_config = ConfigDict(extra="forbid")

    document_id: str = Field(..., pattern=r"^DOC-LP-[A-Z0-9]+(?:-[A-Z0-9]+)*$", min_length=10, max_length=128)
    tenant: TenantScope
    lesson_plan: LessonPlanScope
    academic_scope: AcademicScope
    owner: DocumentOwner
    classification: DocumentClassification
    file: FileMetadata
    storage: StorageMetadata
    security: SecurityMetadata
    lifecycle: LifecycleMetadata
    uploaded_by: int = Field(..., ge=1)
    updated_by: Optional[int] = Field(None, ge=1)
    preview: Optional[PreviewMetadata] = None
    processing: Optional[ProcessingMetadata] = None
    storage_cleanup: Optional[StorageCleanupMetadata] = None
    created_at: datetime
    updated_at: datetime

    @model_validator(mode="after")
    def validate_cross_field_invariants(self) -> LessonPlanDocument:
        """Enforces that owner.entity_id matches lesson_plan.lesson_plan_id."""
        if str(self.owner.entity_id) != str(self.lesson_plan.lesson_plan_id):
            raise ValueError(
                f"owner.entity_id ('{self.owner.entity_id}') must strictly match "
                f"lesson_plan.lesson_plan_id ('{self.lesson_plan.lesson_plan_id}')."
            )
        return self


# -----------------------------------------------------------------------------
# API Request & Response Models
# -----------------------------------------------------------------------------

class LessonPlanDocumentCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    tenant: TenantScope
    academic_scope: AcademicScope
    classification: DocumentClassification
    file: FileMetadata
    security: SecurityMetadata = Field(default_factory=SecurityMetadata)


class LessonPlanDocumentUploadCompleteRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    etag: Optional[str] = None
    actual_size_bytes: int = Field(..., ge=1)


class LessonPlanDocumentUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    visibility: Optional[DocumentVisibility] = None
    sub_category: Optional[str] = Field(None, max_length=100)
    original_name: Optional[str] = Field(None, min_length=1, max_length=255)


class LessonPlanDocumentResponse(BaseModel):
    model_config = ConfigDict(extra="ignore")

    document_id: str
    tenant: TenantScope
    lesson_plan: LessonPlanScope
    academic_scope: AcademicScope
    classification: DocumentClassification
    file: FileMetadata
    storage: StorageMetadata
    security: SecurityMetadata
    lifecycle: LifecycleMetadata
    uploaded_by: int
    updated_by: Optional[int] = None
    preview: Optional[PreviewMetadata] = None
    processing: Optional[ProcessingMetadata] = None
    created_at: datetime
    updated_at: datetime


class PresignedDownloadUrlResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    document_id: str
    file_name: str
    download_url: str
    expires_in_seconds: int = 900

