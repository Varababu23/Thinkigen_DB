/*
    Collection: lesson_plan_documents
    Module:     Teacher Portal - Lesson Plan Management
    Database:   Thinkigen
    Role:       Document metadata management only. Physical files reside permanently in AWS S3.
                SQL Server is authoritative for schools, branches, academic years, teachers,
                classes, sections, subjects, and relational lesson-plan entities.
                FastAPI owns authorization, validation, upload orchestration, presigned URL
                generation, lifecycle transitions, and cleanup coordination.
*/

var COLLECTION_NAME = "lesson_plan_documents";

var validator = {
    $and: [
        {
            $jsonSchema: {
                bsonType: "object",
                required: [
                    "document_id",
                    "tenant",
                    "lesson_plan",
                    "academic_scope",
                    "owner",
                    "classification",
                    "file",
                    "storage",
                    "security",
                    "lifecycle",
                    "uploaded_by",
                    "created_at",
                    "updated_at"
                ],
                additionalProperties: false,
                properties: {
                    // ============================================================
                    // MONGODB FIELD: _id
                    // PURPOSE: Internal MongoDB primary key; never expose as public identifier.
                    // DATA TYPE: ObjectId | OWNER: MongoDB
                    // ============================================================
                    _id: { bsonType: "objectId" },

                    // ============================================================
                    // MONGODB FIELD: document_id
                    // PURPOSE: Immutable, globally unique application identifier.
                    // FORMAT: "DOC-LP-{YEAR}-{HEX/SEQ}" (e.g., "DOC-LP-2026-000001")
                    // ============================================================
                    document_id: {
                        bsonType: "string",
                        pattern: "^DOC-LP-[A-Z0-9]+(?:-[A-Z0-9]+)*$",
                        minLength: 10,
                        maxLength: 128
                    },

                    // ============================================================
                    // TENANT SCOPE: School, Branch, and Academic Year
                    // PURPOSE: Enforces strict multi-tenant isolation.
                    // OWNER: SQL Server authoritative primary keys.
                    // ============================================================
                    tenant: {
                        bsonType: "object",
                        required: ["school_id", "branch_id", "academic_year_id"],
                        additionalProperties: false,
                        properties: {
                            school_id: { bsonType: ["int", "long"], minimum: 1 },
                            branch_id: { bsonType: ["int", "long"], minimum: 1 },
                            academic_year_id: { bsonType: ["int", "long"], minimum: 1 }
                        }
                    },

                    // ============================================================
                    // LESSON PLAN REFERENCE
                    // PURPOSE: Relational binding to the authoritative SQL lesson plan
                    //          and the teacher authoring it.
                    // ============================================================
                    lesson_plan: {
                        bsonType: "object",
                        required: ["lesson_plan_id", "teacher_id"],
                        additionalProperties: false,
                        properties: {
                            lesson_plan_id: {
                                oneOf: [
                                    { bsonType: ["int", "long"], minimum: 1 },
                                    {
                                        bsonType: "string",
                                        minLength: 1,
                                        maxLength: 128,
                                        pattern: "^[A-Za-z0-9_-]+$"
                                    }
                                ]
                            },
                            teacher_id: { bsonType: ["int", "long"], minimum: 1 }
                        }
                    },

                    // ============================================================
                    // ACADEMIC SCOPE: Curriculum Hierarchy
                    // PURPOSE: Contextual classification within class, section, subject,
                    //          chapter, and syllabus topic.
                    // RULES:
                    //   - class_id is mandatory.
                    //   - section_id is nullable for class-wide lesson plans.
                    //   - subject_id is nullable for cross-subject resources.
                    //   - chapter_id is nullable for class-wide/subject-wide guides.
                    //   - topic_id is nullable for chapter-level resources.
                    // ============================================================
                    academic_scope: {
                        bsonType: "object",
                        required: ["class_id"],
                        additionalProperties: false,
                        properties: {
                            class_id: { bsonType: ["int", "long"], minimum: 1 },
                            section_id: { bsonType: ["int", "long", "null"], minimum: 1 },
                            subject_id: { bsonType: ["int", "long", "null"], minimum: 1 },
                            chapter_id: {
                                bsonType: ["string", "int", "long", "null"],
                                maxLength: 128
                            },
                            topic_id: {
                                bsonType: ["string", "int", "long", "null"],
                                maxLength: 128
                            }
                        }
                    },

                    // ============================================================
                    // OWNER
                    // PURPOSE: Enforces explicit entity ownership.
                    // RESTRICTION: entity_type must be "LESSON_PLAN", and entity_id
                    //              must match lesson_plan.lesson_plan_id.
                    // ============================================================
                    owner: {
                        bsonType: "object",
                        required: ["entity_type", "entity_id"],
                        additionalProperties: false,
                        properties: {
                            entity_type: {
                                bsonType: "string",
                                enum: ["LESSON_PLAN"]
                            },
                            entity_id: {
                                oneOf: [
                                    { bsonType: ["int", "long"], minimum: 1 },
                                    {
                                        bsonType: "string",
                                        minLength: 1,
                                        maxLength: 128,
                                        pattern: "^[A-Za-z0-9_-]+$"
                                    }
                                ]
                            }
                        }
                    },

                    // ============================================================
                    // CLASSIFICATION
                    // PURPOSE: Describes educational role and attachment category.
                    // ALLOWED ATTACHMENT TYPES: RESOURCE, ATTACHMENT, REFERENCE, MEDIA
                    // ============================================================
                    classification: {
                        bsonType: "object",
                        required: ["category", "attachment_type"],
                        additionalProperties: false,
                        properties: {
                            category: {
                                bsonType: "string",
                                enum: ["LESSON_PLAN"]
                            },
                            sub_category: {
                                bsonType: ["string", "null"],
                                maxLength: 100
                            },
                            attachment_type: {
                                bsonType: "string",
                                enum: ["RESOURCE", "ATTACHMENT", "REFERENCE", "MEDIA"]
                            }
                        }
                    },

                    // ============================================================
                    // FILE METADATA
                    // PURPOSE: Describes the binary payload stored in S3.
                    //          MongoDB never stores actual file binaries.
                    // ============================================================
                    file: {
                        bsonType: "object",
                        required: [
                            "original_name",
                            "extension",
                            "mime_type",
                            "size_bytes",
                            "checksum_sha256"
                        ],
                        additionalProperties: false,
                        properties: {
                            original_name: {
                                bsonType: "string",
                                minLength: 1,
                                maxLength: 255
                            },
                            extension: {
                                bsonType: "string",
                                pattern: "^\\.?[a-z0-9]{1,16}$"
                            },
                            mime_type: {
                                bsonType: "string",
                                pattern: "^[a-z0-9!#$&^_.+-]+/[a-z0-9!#$&^_.+-]+$",
                                minLength: 3,
                                maxLength: 200
                            },
                            size_bytes: {
                                bsonType: ["int", "long"],
                                minimum: 1
                            },
                            checksum_sha256: {
                                bsonType: "string",
                                pattern: "^[a-f0-9]{64}$"
                            }
                        }
                    },

                    // ============================================================
                    // STORAGE REFERENCE (AWS S3)
                    // PURPOSE: Direct pointer to private S3 object.
                    // KEY CONVENTION:
                    // lessons/{school_id}/{branch_id}/{academic_year_id}/{lesson_plan_id}/{document_id}/v{version}/{filename}
                    // ============================================================
                    storage: {
                        bsonType: "object",
                        required: ["provider", "bucket", "object_key"],
                        additionalProperties: false,
                        properties: {
                            provider: {
                                bsonType: "string",
                                enum: ["AWS_S3"]
                            },
                            bucket: {
                                bsonType: "string",
                                minLength: 3,
                                maxLength: 63
                            },
                            object_key: {
                                bsonType: "string",
                                minLength: 1,
                                maxLength: 1024
                            },
                            version_id: {
                                bsonType: ["string", "null"],
                                maxLength: 512
                            }
                        }
                    },

                    // ============================================================
                    // SECURITY
                    // PURPOSE: Visibility flag for metadata exposure.
                    // ============================================================
                    security: {
                        bsonType: "object",
                        required: ["visibility"],
                        additionalProperties: false,
                        properties: {
                            visibility: {
                                bsonType: "string",
                                enum: ["PRIVATE", "RESTRICTED", "PUBLIC"]
                            }
                        }
                    },

                    // ============================================================
                    // LIFECYCLE & DELETION AUDIT
                    // ALLOWED STATUSES: UPLOADING, ACTIVE, FAILED, DELETED, QUARANTINED
                    // INVARIANT: Non-DELETED must have deleted_at=null & deleted_by=null.
                    //            DELETED must have valid date and user ID.
                    // ============================================================
                    lifecycle: {
                        bsonType: "object",
                        required: ["status"],
                        additionalProperties: false,
                        properties: {
                            status: {
                                bsonType: "string",
                                enum: ["UPLOADING", "ACTIVE", "FAILED", "DELETED", "QUARANTINED"]
                            },
                            deleted_at: { bsonType: ["date", "null"] },
                            deleted_by: { bsonType: ["int", "long", "null"], minimum: 1 }
                        }
                    },

                    // SQL user ID who initiated upload
                    uploaded_by: { bsonType: ["int", "long"], minimum: 1 },

                    // SQL user ID who last updated metadata
                    updated_by: { bsonType: ["int", "long", "null"], minimum: 1 },

                    // ============================================================
                    // PREVIEW (OPTIONAL)
                    // Populated after preview thumbnail is generated and saved in S3
                    // ============================================================
                    preview: {
                        oneOf: [
                            { bsonType: "null" },
                            {
                                bsonType: "object",
                                required: ["available", "object_key", "mime_type"],
                                additionalProperties: false,
                                properties: {
                                    available: { bsonType: "bool" },
                                    object_key: { bsonType: "string", minLength: 1, maxLength: 1024 },
                                    mime_type: {
                                        bsonType: "string",
                                        pattern: "^[a-z0-9!#$&^_.+-]+/[a-z0-9!#$&^_.+-]+$",
                                        minLength: 3,
                                        maxLength: 200
                                    }
                                }
                            }
                        ]
                    },

                    // ============================================================
                    // PROCESSING (OPTIONAL)
                    // Background antivirus scan, OCR, or preview generation status
                    // ============================================================
                    processing: {
                        oneOf: [
                            { bsonType: "null" },
                            {
                                bsonType: "object",
                                required: ["status"],
                                additionalProperties: false,
                                properties: {
                                    status: {
                                        bsonType: "string",
                                        enum: ["NOT_REQUIRED", "PENDING", "PROCESSING", "COMPLETED", "FAILED"]
                                    },
                                    processed_at: { bsonType: ["date", "null"] },
                                    processor_version: { bsonType: ["string", "null"], maxLength: 100 },
                                    error_code: { bsonType: ["string", "null"], maxLength: 100 }
                                }
                            }
                        ]
                    },

                    // ============================================================
                    // STORAGE CLEANUP (OPTIONAL)
                    // Asynchronous S3 object purge tracking upon deletion or failed upload
                    // ============================================================
                    storage_cleanup: {
                        oneOf: [
                            { bsonType: "null" },
                            {
                                bsonType: "object",
                                required: ["status", "attempts"],
                                additionalProperties: false,
                                properties: {
                                    status: {
                                        bsonType: "string",
                                        enum: ["PENDING", "COMPLETED", "FAILED"]
                                    },
                                    attempts: { bsonType: ["int", "long"], minimum: 0 },
                                    last_attempt_at: { bsonType: ["date", "null"] },
                                    last_error: { bsonType: ["string", "null"], maxLength: 2000 }
                                }
                            }
                        ]
                    },

                    // Server-generated UTC timestamps
                    created_at: { bsonType: "date" },
                    updated_at: { bsonType: "date" }
                }
            }
        },

        // Cross-Field Rule 1: Owner entity_id must strictly match lesson_plan.lesson_plan_id
        {
            $expr: {
                $eq: ["$owner.entity_id", "$lesson_plan.lesson_plan_id"]
            }
        },

        // Cross-Field Rule 2: Storage provider must strictly be AWS_S3
        {
            "storage.provider": "AWS_S3"
        },

        // Cross-Field Rule 3: Owner entity type and classification category must both be LESSON_PLAN
        {
            "owner.entity_type": "LESSON_PLAN",
            "classification.category": "LESSON_PLAN"
        },

        // Cross-Field Rule 4: Syllabus Hierarchy Invariant
        // A topic cannot exist without an associated chapter.
        {
            $or: [
                { "academic_scope.topic_id": null },
                { "academic_scope.chapter_id": { $ne: null } }
            ]
        },

        // Cross-Field Rule 5: Deletion Audit Invariant
        {
            $or: [
                {
                    "lifecycle.status": { $ne: "DELETED" },
                    "lifecycle.deleted_at": null,
                    "lifecycle.deleted_by": null
                },
                {
                    "lifecycle.status": "DELETED",
                    "lifecycle.deleted_at": { $type: "date" },
                    "lifecycle.deleted_by": { $type: ["int", "long"] }
                }
            ]
        }
    ]
};

// -----------------------------------------------------------------------------
// Database Resolution & Collection Creation
// -----------------------------------------------------------------------------
var currentDbName = (typeof db !== "undefined" && db.getName && db.getName() !== "test") ? db.getName() : "Thinkigen";
var targetDb = typeof db !== "undefined" ? db.getSiblingDB(currentDbName) : null;
if (!targetDb) {
    throw new Error("Unable to resolve target MongoDB database '" + currentDbName + "'.");
}

if (!targetDb.getCollectionNames().includes(COLLECTION_NAME)) {
    targetDb.createCollection(COLLECTION_NAME, {
        validator: validator,
        validationLevel: "strict",
        validationAction: "error"
    });
    print("Created collection: " + COLLECTION_NAME + " with strict $jsonSchema validator.");
} else {
    targetDb.runCommand({
        collMod: COLLECTION_NAME,
        validator: validator,
        validationLevel: "strict",
        validationAction: "error"
    });
    print("Updated schema validation for collection: " + COLLECTION_NAME + ".");
}

// -----------------------------------------------------------------------------
// Production Index Definitions (Safe Reconciliation)
// -----------------------------------------------------------------------------
var indexes = [
    // 1. Global uniqueness on document_id
    {
        key: { document_id: 1 },
        options: { unique: true, name: "uq_lesson_plan_documents_document_id" }
    },
    // 2. Physical storage uniqueness on S3 bucket + object_key
    {
        key: { "storage.bucket": 1, "storage.object_key": 1 },
        options: { unique: true, name: "uq_lesson_plan_documents_bucket_object_key" }
    },
    // 3. Lesson plan lookup: All attachments for a specific lesson plan
    {
        key: { "lesson_plan.lesson_plan_id": 1, "lifecycle.status": 1, created_at: -1 },
        options: { name: "ix_lesson_plan_documents_plan_status_created" }
    },
    // 4. Tenant lookup: All documents within school, branch, and academic year
    {
        key: {
            "tenant.school_id": 1,
            "tenant.branch_id": 1,
            "tenant.academic_year_id": 1,
            "lifecycle.status": 1,
            created_at: -1
        },
        options: { name: "ix_lesson_plan_documents_tenant_status_created" }
    },
    // 5. Teacher lookup: All lesson plan documents authored by a teacher
    {
        key: { "lesson_plan.teacher_id": 1, "lifecycle.status": 1, created_at: -1 },
        options: { name: "ix_lesson_plan_documents_teacher_status_created" }
    },
    // 6. Class & Section lookup: Curriculum resources for a class and section
    {
        key: {
            "tenant.school_id": 1,
            "tenant.branch_id": 1,
            "tenant.academic_year_id": 1,
            "academic_scope.class_id": 1,
            "academic_scope.section_id": 1,
            "lifecycle.status": 1
        },
        options: { name: "ix_lesson_plan_documents_tenant_class_section_status" }
    },
    // 7. Subject lookup: All documents for a subject within a tenant scope
    {
        key: {
            "tenant.school_id": 1,
            "tenant.branch_id": 1,
            "tenant.academic_year_id": 1,
            "academic_scope.subject_id": 1,
            "lifecycle.status": 1
        },
        options: { name: "ix_lesson_plan_documents_tenant_subject_status" }
    },
    // 8. Chapter lookup: All documents targeting a specific chapter
    {
        key: {
            "tenant.school_id": 1,
            "tenant.branch_id": 1,
            "academic_scope.chapter_id": 1,
            "lifecycle.status": 1
        },
        options: { name: "ix_lesson_plan_documents_tenant_chapter_status" }
    },
    // 9. Topic lookup: All documents targeting a specific topic
    {
        key: {
            "tenant.school_id": 1,
            "tenant.branch_id": 1,
            "academic_scope.topic_id": 1,
            "lifecycle.status": 1
        },
        options: { name: "ix_lesson_plan_documents_tenant_topic_status" }
    },
    // 10. Checksum deduplication: Detect identical files within the same school tenant
    {
        key: { "tenant.school_id": 1, "file.checksum_sha256": 1 },
        options: { name: "ix_lesson_plan_documents_tenant_checksum" }
    },
    // 11. Partial Lifecycle Cleanup: Garbage collection of abandoned or failed uploads
    {
        key: { "lifecycle.status": 1, created_at: 1 },
        options: {
            name: "ix_lesson_plan_documents_lifecycle_cleanup",
            partialFilterExpression: {
                "lifecycle.status": { $in: ["UPLOADING", "FAILED", "QUARANTINED"] }
            }
        }
    },
    // 12. Partial Storage Cleanup: Asynchronous S3 deletion tracking
    {
        key: { "storage_cleanup.status": 1, "storage_cleanup.last_attempt_at": 1 },
        options: {
            name: "ix_lesson_plan_documents_storage_cleanup",
            partialFilterExpression: {
                "storage_cleanup.status": { $in: ["PENDING", "FAILED"] }
            }
        }
    }
];

indexes.forEach(function (idx) {
    var existingIndexes = targetDb[COLLECTION_NAME].getIndexes();
    var match = existingIndexes.find(function (e) {
        return e.name === idx.options.name;
    });

    if (!match) {
        targetDb[COLLECTION_NAME].createIndex(idx.key, idx.options);
        print("Created index: " + idx.options.name + " on " + COLLECTION_NAME);
    } else {
        var keysMatch = JSON.stringify(match.key) === JSON.stringify(idx.key);
        if (!keysMatch) {
            print("Index " + idx.options.name + " key pattern changed. Rebuilding index...");
            targetDb[COLLECTION_NAME].dropIndex(idx.options.name);
            targetDb[COLLECTION_NAME].createIndex(idx.key, idx.options);
            print("Rebuilt index: " + idx.options.name);
        } else {
            print("Index " + idx.options.name + " already exists with correct keys.");
        }
    }
});

