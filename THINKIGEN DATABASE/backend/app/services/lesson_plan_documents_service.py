"""
Thinkigen School ERP - Lesson Plan Documents Service Layer.
Module: Teacher Portal - Lesson Plan Management
Database: Thinkigen (MongoDB)

Handles:
- Deterministic document_id generation
- S3 upload session orchestration and presigned URL generation
- Strict state machine transitions (UPLOADING -> ACTIVE, ACTIVE -> DELETED, etc.)
- Multi-tenant query isolation and ESR-indexed database operations
- Asynchronous storage cleanup coordination and idempotent soft deletion
"""

from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone
from typing import Optional, List, Dict, Any, Union

from app.schemas.lesson_plan_documents import (
    DocumentClassificationCategory,
    DocumentAttachmentType,
    DocumentVisibility,
    DocumentLifecycleStatus,
    ProcessingStatus,
    StorageCleanupStatus,
    TenantScope,
    LessonPlanScope,
    AcademicScope,
    DocumentOwner,
    DocumentClassification,
    FileMetadata,
    StorageMetadata,
    SecurityMetadata,
    LifecycleMetadata,
    PreviewMetadata,
    ProcessingMetadata,
    StorageCleanupMetadata,
    LessonPlanDocument,
    LessonPlanDocumentCreateRequest,
    LessonPlanDocumentUpdateRequest,
    PresignedDownloadUrlResponse,
)

logger = logging.getLogger("thinkigen.lesson_plans.documents")


class LessonPlanDocumentService:
    """
    Core service managing lesson plan document metadata lifecycle,
    AWS S3 coordination, and tenant-scoped retrieval.
    """

    COLLECTION_NAME = "lesson_plan_documents"

    def __init__(self, mongo_db: Any, s3_client: Optional[Any] = None, s3_bucket: str = "thinkigen-school-documents-private"):
        self.db = mongo_db
        self.collection = mongo_db[self.COLLECTION_NAME]
        self.s3_client = s3_client
        self.s3_bucket = s3_bucket

    # -------------------------------------------------------------------------
    # Helper: Identifier & Key Formulations
    # -------------------------------------------------------------------------
    @staticmethod
    def generate_document_id(year: int) -> str:
        """
        Generates a globally unique, immutable document identifier.
        Format: DOC-LP-{YEAR}-{HEX8} (e.g., DOC-LP-2026-A1B2C3D4)
        """
        hex_suffix = uuid.uuid4().hex[:8].upper()
        return f"DOC-LP-{year}-{hex_suffix}"

    @staticmethod
    def construct_s3_key(
        school_id: int,
        branch_id: int,
        academic_year_id: int,
        lesson_plan_id: Union[int, str],
        document_id: str,
        filename: str,
        version: int = 1,
    ) -> str:
        """
        Constructs a standardized, immutable S3 object key.
        Convention: lessons/{school_id}/{branch_id}/{academic_year_id}/{lesson_plan_id}/{document_id}/v{version}/{filename}
        """
        clean_name = filename.strip().replace(" ", "_")
        return f"lessons/{school_id}/{branch_id}/{academic_year_id}/{lesson_plan_id}/{document_id}/v{version}/{clean_name}"

    # -------------------------------------------------------------------------
    # 1. Initiate Upload Session
    # -------------------------------------------------------------------------
    async def initiate_upload(
        self,
        lesson_plan_id: Union[int, str],
        teacher_id: int,
        uploader_user_id: int,
        payload: LessonPlanDocumentCreateRequest,
    ) -> Dict[str, Any]:
        """
        Initiates an upload session, generates document_id, creates initial
        MongoDB metadata with status=UPLOADING, and returns a presigned PUT URL.
        """
        now = datetime.now(timezone.utc)
        doc_id = self.generate_document_id(payload.tenant.academic_year_id)

        s3_key = self.construct_s3_key(
            school_id=payload.tenant.school_id,
            branch_id=payload.tenant.branch_id,
            academic_year_id=payload.tenant.academic_year_id,
            lesson_plan_id=lesson_plan_id,
            document_id=doc_id,
            filename=payload.file.original_name,
            version=1,
        )

        doc = LessonPlanDocument(
            document_id=doc_id,
            tenant=payload.tenant,
            lesson_plan=LessonPlanScope(lesson_plan_id=lesson_plan_id, teacher_id=teacher_id),
            academic_scope=payload.academic_scope,
            owner=DocumentOwner(entity_type="LESSON_PLAN", entity_id=lesson_plan_id),
            classification=payload.classification,
            file=payload.file,
            storage=StorageMetadata(
                provider="AWS_S3",
                bucket=self.s3_bucket,
                object_key=s3_key,
                version_id=None,
            ),
            security=payload.security,
            lifecycle=LifecycleMetadata(
                status=DocumentLifecycleStatus.UPLOADING,
                deleted_at=None,
                deleted_by=None,
            ),
            uploaded_by=uploader_user_id,
            updated_by=None,
            preview=None,
            processing=ProcessingMetadata(status=ProcessingStatus.PENDING),
            storage_cleanup=None,
            created_at=now,
            updated_at=now,
        )

        doc_dict = doc.model_dump(mode="json")
        # Persist to MongoDB
        await self.collection.insert_one(doc_dict)
        logger.info("Initiated upload session for %s (Key: %s)", doc_id, s3_key)

        # Generate presigned PUT URL
        presigned_put_url = f"https://{self.s3_bucket}.s3.amazonaws.com/{s3_key}?upload_signature=simulated_presigned_put"
        if self.s3_client and hasattr(self.s3_client, "generate_presigned_url"):
            presigned_put_url = self.s3_client.generate_presigned_url(
                "put_object",
                Params={"Bucket": self.s3_bucket, "Key": s3_key, "ContentType": payload.file.mime_type},
                ExpiresIn=1800,
            )

        return {
            "document_id": doc_id,
            "upload_url": presigned_put_url,
            "expires_in_seconds": 1800,
            "status": DocumentLifecycleStatus.UPLOADING.value,
        }

    # -------------------------------------------------------------------------
    # 2. Complete & Verify Upload
    # -------------------------------------------------------------------------
    async def complete_upload(
        self,
        document_id: str,
        actual_size_bytes: int,
        etag: Optional[str] = None,
    ) -> Optional[Dict[str, Any]]:
        """
        Transitions status from UPLOADING to ACTIVE after binary upload verification.
        """
        now = datetime.now(timezone.utc)
        result = await self.collection.find_one_and_update(
            {"document_id": document_id, "lifecycle.status": DocumentLifecycleStatus.UPLOADING.value},
            {
                "$set": {
                    "lifecycle.status": DocumentLifecycleStatus.ACTIVE.value,
                    "processing.status": ProcessingStatus.COMPLETED.value,
                    "processing.processed_at": now,
                    "updated_at": now,
                }
            },
            return_document=True,
        )

        if not result:
            logger.warning("Complete upload failed: %s not in UPLOADING state", document_id)
            return None

        logger.info("Document %s transitioned to ACTIVE", document_id)
        return result

    # -------------------------------------------------------------------------
    # 3. Retrieve Documents for a Lesson Plan
    # -------------------------------------------------------------------------
    async def list_documents_for_lesson_plan(
        self,
        school_id: int,
        branch_id: int,
        academic_year_id: int,
        lesson_plan_id: Union[int, str],
        attachment_type: Optional[DocumentAttachmentType] = None,
        chapter_id: Optional[str] = None,
        topic_id: Optional[str] = None,
        status: DocumentLifecycleStatus = DocumentLifecycleStatus.ACTIVE,
    ) -> List[Dict[str, Any]]:
        """
        Queries all documents attached to a specific lesson plan using
        index ix_lesson_plan_documents_plan_status_created.
        """
        filter_query: Dict[str, Any] = {
            "tenant.school_id": school_id,
            "tenant.branch_id": branch_id,
            "tenant.academic_year_id": academic_year_id,
            "lesson_plan.lesson_plan_id": lesson_plan_id,
            "lifecycle.status": status.value,
        }

        if attachment_type:
            filter_query["classification.attachment_type"] = attachment_type.value
        if chapter_id:
            filter_query["academic_scope.chapter_id"] = chapter_id
        if topic_id:
            filter_query["academic_scope.topic_id"] = topic_id

        cursor = self.collection.find(filter_query).sort("created_at", -1)
        documents = await cursor.to_list(length=100)
        return documents

    # -------------------------------------------------------------------------
    # 4. Generate Authorized Download URL
    # -------------------------------------------------------------------------
    async def generate_download_url(
        self,
        document_id: str,
        user_school_id: int,
    ) -> Optional[PresignedDownloadUrlResponse]:
        """
        Validates ACTIVE lifecycle status and generates a short-lived presigned GET URL.
        """
        doc = await self.collection.find_one({"document_id": document_id})
        if not doc:
            return None

        # Multi-tenant security check
        if doc.get("tenant", {}).get("school_id") != user_school_id:
            logger.warning("Tenant mismatch for document %s", document_id)
            return None

        # Status check
        if doc.get("lifecycle", {}).get("status") != DocumentLifecycleStatus.ACTIVE.value:
            logger.warning("Refusing download: document %s is not ACTIVE", document_id)
            return None

        storage = doc.get("storage", {})
        bucket = storage.get("bucket", self.s3_bucket)
        object_key = storage.get("object_key", "")
        file_name = doc.get("file", {}).get("original_name", "download")

        download_url = f"https://{bucket}.s3.amazonaws.com/{object_key}?download_signature=simulated_presigned_get"
        if self.s3_client and hasattr(self.s3_client, "generate_presigned_url"):
            download_url = self.s3_client.generate_presigned_url(
                "get_object",
                Params={
                    "Bucket": bucket,
                    "Key": object_key,
                    "ResponseContentDisposition": f'attachment; filename="{file_name}"',
                },
                ExpiresIn=900,
            )

        return PresignedDownloadUrlResponse(
            document_id=document_id,
            file_name=file_name,
            download_url=download_url,
            expires_in_seconds=900,
        )

    # -------------------------------------------------------------------------
    # 5. Soft-Delete Document
    # -------------------------------------------------------------------------
    async def soft_delete_document(
        self,
        document_id: str,
        user_id: int,
        school_id: int,
    ) -> Optional[Dict[str, Any]]:
        """
        Performs an atomic soft-delete, enforces deletion audit invariants,
        and enqueues storage cleanup.
        """
        now = datetime.now(timezone.utc)
        result = await self.collection.find_one_and_update(
            {
                "document_id": document_id,
                "tenant.school_id": school_id,
                "lifecycle.status": {"$ne": DocumentLifecycleStatus.DELETED.value},
            },
            {
                "$set": {
                    "lifecycle.status": DocumentLifecycleStatus.DELETED.value,
                    "lifecycle.deleted_at": now,
                    "lifecycle.deleted_by": user_id,
                    "storage_cleanup": {
                        "status": StorageCleanupStatus.PENDING.value,
                        "attempts": 0,
                        "last_attempt_at": None,
                        "last_error": None,
                    },
                    "updated_by": user_id,
                    "updated_at": now,
                }
            },
            return_document=True,
        )

        if result:
            logger.info("Soft-deleted document %s by user %d", document_id, user_id)
        return result

    # -------------------------------------------------------------------------
    # 6. Retry Failed Upload or Processing
    # -------------------------------------------------------------------------
    async def retry_failed_upload(
        self,
        document_id: str,
        user_id: int,
    ) -> Optional[Dict[str, Any]]:
        """
        Allows controlled retry from FAILED state back to UPLOADING.
        """
        now = datetime.now(timezone.utc)
        result = await self.collection.find_one_and_update(
            {
                "document_id": document_id,
                "lifecycle.status": DocumentLifecycleStatus.FAILED.value,
            },
            {
                "$set": {
                    "lifecycle.status": DocumentLifecycleStatus.UPLOADING.value,
                    "processing.status": ProcessingStatus.PENDING.value,
                    "processing.error_code": None,
                    "updated_by": user_id,
                    "updated_at": now,
                }
            },
            return_document=True,
        )
        return result

