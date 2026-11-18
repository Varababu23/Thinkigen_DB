# FastAPI Integration Contract: Lesson Plan Document Management

## 1. Architectural Scope & Service Responsibilities

FastAPI serves as the authoritative application layer between the Teacher Portal frontend, the SQL Server system of record, MongoDB metadata storage, and AWS S3 object storage.

```
+-----------------------------------------------------------------------------------+
|                                Fast API Backend                                   |
|                                                                                   |
|  [Auth & RBAC]        [SQL Validator]      [S3 Orchestrator]   [MongoDB DAL]      |
|  JWT Token            School, Branch,      Presigned URLs,     Metadata CRUD,     |
|  Role: TEACHER/ADMIN  Teacher, Lesson Plan Upload Complete,    Strict Schema,     |
|                       Subject, Syllabus    Virus Scan Hook     ESR Index Queries  |
+-----------------------------------------------------------------------------------+
       |                       |                    |                   |
       v                       v                    v                   v
[Client / Frontend]     [SQL Server]          [AWS S3]            [MongoDB]
```

### Core Security Principles
1. **Zero Raw Binary in MongoDB**: MongoDB stores metadata only. Binary payloads are streamed directly to/from AWS S3.
2. **Short-Lived Presigned URLs**: Presigned GET URLs expire after 900 seconds (15 minutes). Presigned PUT URLs expire after 1800 seconds (30 minutes).
3. **No S3 Credentials to Frontend**: Frontend clients never receive AWS Access Keys or Secret Keys.
4. **Authoritative SQL Authorization**: MongoDB metadata operations occur only after verifying teacher ownership and tenant scope in SQL Server.
5. **Only ACTIVE Documents Downloadable**: Requests for download URLs on non-`ACTIVE` documents are rejected with HTTP 403 / 409.

---

## 2. API Endpoints Specification

### 2.1 Initiate Upload Session
- **Endpoint**: `POST /api/v1/lesson-plans/{lesson_plan_id}/documents/upload-init`
- **Role**: `TEACHER`, `ACADEMIC_ADMIN`
- **Request Body**:
```json
{
  "tenant": { "school_id": 1, "branch_id": 1, "academic_year_id": 1 },
  "academic_scope": {
    "class_id": 9,
    "section_id": 1,
    "subject_id": 3,
    "chapter_id": "CH-04",
    "topic_id": null
  },
  "classification": {
    "sub_category": "LAB_EXPERIMENT_GUIDE",
    "attachment_type": "RESOURCE"
  },
  "file": {
    "original_name": "rutherford_alpha_scattering_lab_guide.pdf",
    "extension": "pdf",
    "mime_type": "application/pdf",
    "size_bytes": 2457600,
    "checksum_sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  },
  "security": { "visibility": "RESTRICTED" }
}
```
- **Execution Flow**:
  1. Authenticate user from JWT token (`user_id`, `school_id`, `branch_id`).
  2. Verify teacher is authorized to author `lesson_plan_id` in SQL Server.
  3. Validate file extension and MIME type against allowed whitelist.
  4. Generate globally unique `document_id`: `DOC-LP-{YEAR}-{HEX}`.
  5. Formulate S3 key: `lessons/{school_id}/{branch_id}/{academic_year_id}/{lesson_plan_id}/{document_id}/v1/{filename}`.
  6. Insert MongoDB document with `lifecycle.status = "UPLOADING"`.
  7. Generate presigned S3 PUT URL.
- **Response** (HTTP 201 Created):
```json
{
  "document_id": "DOC-LP-2026-000001",
  "upload_url": "https://thinkigen-school-documents-private.s3.amazonaws.com/lessons/1/1/1/101/DOC-LP-2026-000001/v1/rutherford_alpha_scattering_lab_guide.pdf?...",
  "expires_in_seconds": 1800,
  "status": "UPLOADING"
}
```

---

### 2.2 Complete & Verify Upload
- **Endpoint**: `POST /api/v1/lesson-plans/{lesson_plan_id}/documents/{document_id}/upload-complete`
- **Role**: `TEACHER`, `ACADEMIC_ADMIN`
- **Request Body**:
```json
{
  "etag": "\"e3b0c44298fc1c149afbf4c8996fb924\"",
  "actual_size_bytes": 2457600
}
```
- **Execution Flow**:
  1. Query S3 via `head_object` using stored `bucket` and `object_key`.
  2. Verify object exists, byte size matches `file.size_bytes`.
  3. Trigger background malware scan / preview worker (`processing.status = "PENDING"`).
  4. Conditionally update MongoDB: `lifecycle.status = "ACTIVE"`, `updated_at = UTC_NOW`.
- **Response** (HTTP 200 OK):
  Returns full `LessonPlanDocumentResponse`.

---

### 2.3 List Documents for a Lesson Plan
- **Endpoint**: `GET /api/v1/lesson-plans/{lesson_plan_id}/documents`
- **Role**: `TEACHER`, `STUDENT`, `ADMIN`
- **Query Parameters**:
  - `attachment_type` (optional): Filter by `RESOURCE`, `ATTACHMENT`, `REFERENCE`, `MEDIA`.
  - `chapter_id` (optional): Filter by specific syllabus chapter.
  - `topic_id` (optional): Filter by specific topic.
  - `status` (optional, default `"ACTIVE"`): Filter by lifecycle status.
- **Index Utilized**: `ix_lesson_plan_documents_plan_status_created`
- **Response** (HTTP 200 OK):
```json
{
  "lesson_plan_id": 101,
  "total": 1,
  "items": [
    {
      "document_id": "DOC-LP-2026-000001",
      "classification": {
        "category": "LESSON_PLAN",
        "sub_category": "LAB_EXPERIMENT_GUIDE",
        "attachment_type": "RESOURCE"
      },
      "file": {
        "original_name": "rutherford_alpha_scattering_lab_guide.pdf",
        "extension": "pdf",
        "mime_type": "application/pdf",
        "size_bytes": 2457600
      },
      "preview": {
        "available": true,
        "object_key": "lessons/1/1/1/101/DOC-LP-2026-000001/v1/previews/thumb_page_1.png"
      },
      "lifecycle": { "status": "ACTIVE" },
      "created_at": "2026-10-26T08:30:00Z"
    }
  ]
}
```

---

### 2.4 Generate Authorized Download URL
- **Endpoint**: `GET /api/v1/lesson-plan-documents/{document_id}/download`
- **Role**: Authenticated User with access to lesson plan
- **Execution Flow**:
  1. Fetch metadata by `document_id` via `uq_lesson_plan_documents_document_id`.
  2. Verify tenant scope matches current session.
  3. Verify `lifecycle.status == "ACTIVE"`. If not, return HTTP 403 Forbidden.
  4. Generate S3 presigned GET URL with `ResponseContentDisposition` set to download `file.original_name`.
  5. Log audit event in SQL Server / audit stream.
- **Response** (HTTP 200 OK):
```json
{
  "document_id": "DOC-LP-2026-000001",
  "file_name": "rutherford_alpha_scattering_lab_guide.pdf",
  "download_url": "https://thinkigen-school-documents-private.s3.amazonaws.com/lessons/...?...&response-content-disposition=attachment%3B%20filename%3D...",
  "expires_in_seconds": 900
}
```

---

### 2.5 Soft-Delete Document
- **Endpoint**: `DELETE /api/v1/lesson-plan-documents/{document_id}`
- **Role**: Owning Teacher or Admin
- **Execution Flow**:
  1. Fetch document and verify user is `uploaded_by` or school admin.
  2. Ensure document is not already `DELETED`.
  3. Atomically update MongoDB:
     ```javascript
     {
       $set: {
         "lifecycle.status": "DELETED",
         "lifecycle.deleted_at": new Date(),
         "lifecycle.deleted_by": current_user.user_id,
         "storage_cleanup": {
           "status": "PENDING",
           "attempts": 0,
           "last_attempt_at": null,
           "last_error": null
         },
         "updated_at": new Date()
       }
     }
     ```
  4. Enqueue background S3 deletion job.
- **Response** (HTTP 200 OK):
```json
{
  "document_id": "DOC-LP-2026-000001",
  "status": "DELETED",
  "deleted_at": "2026-11-03T12:00:00Z",
  "message": "Document soft-deleted and scheduled for storage purge."
}
```

---

### 2.6 Retry Failed Upload or Processing
- **Endpoint**: `POST /api/v1/lesson-plan-documents/{document_id}/retry`
- **Role**: Owning Teacher or Admin
- **Rules**:
  - Only valid if current status is `FAILED`.
  - Re-initializes status to `UPLOADING` and generates fresh presigned PUT URL.

---

## 3. Background Workers & Cleanup Tasks

### Stale Upload Garbage Collector
- Runs every 30 minutes.
- Scans `ix_lesson_plan_documents_lifecycle_cleanup` for `lifecycle.status == "UPLOADING"` and `created_at < (NOW - 2 HOURS)`.
- Updates status to `FAILED` with error code `UPLOAD_TIMED_OUT`.
- Enqueues S3 `DeleteObject` in case partial multi-part chunks exist.

### Asynchronous Storage Purge Worker
- Runs every 5 minutes.
- Scans `ix_lesson_plan_documents_storage_cleanup` for `storage_cleanup.status == "PENDING"`.
- Issues AWS S3 `DeleteObject` command.
- If S3 confirms deletion, sets `storage_cleanup.status = "COMPLETED"`.
- If S3 fails, increments `storage_cleanup.attempts`, sets `last_attempt_at = NOW`, `last_error = error_str`, and retries with exponential backoff (up to 5 attempts).

