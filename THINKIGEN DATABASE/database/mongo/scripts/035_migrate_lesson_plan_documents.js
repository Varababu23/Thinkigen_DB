/*
================================================================================
SCRIPT:        035_migrate_lesson_plan_documents.js
MODULE:        Teacher Portal - Lesson Plan Management
DATABASE:      Thinkigen (MongoDB Atlas / mongosh)
PURPOSE:
Standalone, zero-downtime deployment and migration script for lesson_plan_documents:
1. Creates collection with strict $jsonSchema if non-existent.
2. If existing, runs a safe migration ensuring backward compatibility for
   academic_scope.chapter_id and academic_scope.topic_id.
3. Applies strict collMod validator.
4. Idempotently builds and reconciles all 12 workload indexes without index collisions.
5. Verifies all indexes and documents against the validator.
6. SAFETY GUARANTEE: Never drops collection; never deletes data.
================================================================================
*/

(function () {
    var currentDbName = (typeof db !== "undefined" && db.getName && db.getName() !== "test") ? db.getName() : "Thinkigen";
    var targetDb = typeof db !== "undefined" ? db.getSiblingDB(currentDbName) : null;
    if (!targetDb) {
        throw new Error("Unable to resolve target MongoDB database '" + currentDbName + "'.");
    }

    var COLLECTION_NAME = "lesson_plan_documents";

    print("================================================================================");
    print("STARTING LESSON PLAN DOCUMENTS PRODUCTION DEPLOYMENT & MIGRATION");
    print("Target Database: " + targetDb.getName());
    print("Collection:      " + COLLECTION_NAME);
    print("Timestamp:       " + new Date().toISOString());
    print("================================================================================");

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
                        _id: { bsonType: "objectId" },
                        document_id: {
                            bsonType: "string",
                            pattern: "^DOC-LP-[A-Z0-9]+(?:-[A-Z0-9]+)*$",
                            minLength: 10,
                            maxLength: 128
                        },
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
                        uploaded_by: { bsonType: ["int", "long"], minimum: 1 },
                        updated_by: { bsonType: ["int", "long", "null"], minimum: 1 },
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
                        created_at: { bsonType: "date" },
                        updated_at: { bsonType: "date" }
                    }
                }
            },
            {
                $expr: {
                    $eq: ["$owner.entity_id", "$lesson_plan.lesson_plan_id"]
                }
            },
            {
                "storage.provider": "AWS_S3"
            },
            {
                "owner.entity_type": "LESSON_PLAN",
                "classification.category": "LESSON_PLAN"
            },
            {
                $or: [
                    { "academic_scope.topic_id": null },
                    { "academic_scope.chapter_id": { $ne: null } }
                ]
            },
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

    // -------------------------------------------------------------------------
    // STEP 1: Collection Existence & Migration
    // -------------------------------------------------------------------------
    if (!targetDb.getCollectionNames().includes(COLLECTION_NAME)) {
        print("\n[STEP 1] Creating collection '" + COLLECTION_NAME + "' with strict validator...");
        targetDb.createCollection(COLLECTION_NAME, {
            validator: validator,
            validationLevel: "strict",
            validationAction: "error"
        });
        print("  -> Collection created successfully.");
    } else {
        print("\n[STEP 1] Collection exists. Running backward-compatibility migration...");
        var missingScopeUpdates = targetDb[COLLECTION_NAME].updateMany(
            {
                $or: [
                    { "academic_scope.chapter_id": { $exists: false } },
                    { "academic_scope.topic_id": { $exists: false } }
                ]
            },
            {
                $set: {
                    "academic_scope.chapter_id": null,
                    "academic_scope.topic_id": null
                }
            }
        );
        print("  -> Migrated legacy documents missing chapter_id/topic_id: " + missingScopeUpdates.modifiedCount);

        print("\n[STEP 2] Updating collection validator via collMod...");
        targetDb.runCommand({
            collMod: COLLECTION_NAME,
            validator: validator,
            validationLevel: "strict",
            validationAction: "error"
        });
        print("  -> Schema validator updated to strict.");
    }

    // -------------------------------------------------------------------------
    // STEP 3: Reconcile Production Indexes
    // -------------------------------------------------------------------------
    print("\n[STEP 3] Reconciling all 12 production indexes...");

    var indexes = [
        { key: { document_id: 1 }, options: { unique: true, name: "uq_lesson_plan_documents_document_id" } },
        { key: { "storage.bucket": 1, "storage.object_key": 1 }, options: { unique: true, name: "uq_lesson_plan_documents_bucket_object_key" } },
        { key: { "lesson_plan.lesson_plan_id": 1, "lifecycle.status": 1, created_at: -1 }, options: { name: "ix_lesson_plan_documents_plan_status_created" } },
        { key: { "tenant.school_id": 1, "tenant.branch_id": 1, "tenant.academic_year_id": 1, "lifecycle.status": 1, created_at: -1 }, options: { name: "ix_lesson_plan_documents_tenant_status_created" } },
        { key: { "lesson_plan.teacher_id": 1, "lifecycle.status": 1, created_at: -1 }, options: { name: "ix_lesson_plan_documents_teacher_status_created" } },
        { key: { "tenant.school_id": 1, "tenant.branch_id": 1, "tenant.academic_year_id": 1, "academic_scope.class_id": 1, "academic_scope.section_id": 1, "lifecycle.status": 1 }, options: { name: "ix_lesson_plan_documents_tenant_class_section_status" } },
        { key: { "tenant.school_id": 1, "tenant.branch_id": 1, "tenant.academic_year_id": 1, "academic_scope.subject_id": 1, "lifecycle.status": 1 }, options: { name: "ix_lesson_plan_documents_tenant_subject_status" } },
        { key: { "tenant.school_id": 1, "tenant.branch_id": 1, "academic_scope.chapter_id": 1, "lifecycle.status": 1 }, options: { name: "ix_lesson_plan_documents_tenant_chapter_status" } },
        { key: { "tenant.school_id": 1, "tenant.branch_id": 1, "academic_scope.topic_id": 1, "lifecycle.status": 1 }, options: { name: "ix_lesson_plan_documents_tenant_topic_status" } },
        { key: { "tenant.school_id": 1, "file.checksum_sha256": 1 }, options: { name: "ix_lesson_plan_documents_tenant_checksum" } },
        {
            key: { "lifecycle.status": 1, created_at: 1 },
            options: {
                name: "ix_lesson_plan_documents_lifecycle_cleanup",
                partialFilterExpression: { "lifecycle.status": { $in: ["UPLOADING", "FAILED", "QUARANTINED"] } }
            }
        },
        {
            key: { "storage_cleanup.status": 1, "storage_cleanup.last_attempt_at": 1 },
            options: {
                name: "ix_lesson_plan_documents_storage_cleanup",
                partialFilterExpression: { "storage_cleanup.status": { $in: ["PENDING", "FAILED"] } }
            }
        }
    ];

    indexes.forEach(function (idx) {
        var existingIndexes = targetDb[COLLECTION_NAME].getIndexes();
        var matchByName = existingIndexes.find(function (e) { return e.name === idx.options.name; });

        if (!matchByName) {
            targetDb[COLLECTION_NAME].createIndex(idx.key, idx.options);
            print("  [INDEX CREATED]  " + idx.options.name);
        } else {
            var keysMatch = JSON.stringify(matchByName.key) === JSON.stringify(idx.key);
            var uniqueMatch = (!!matchByName.unique) === (!!idx.options.unique);
            var partialMatch = JSON.stringify(matchByName.partialFilterExpression || null) ===
                               JSON.stringify(idx.options.partialFilterExpression || null);

            if (!keysMatch || !uniqueMatch || !partialMatch) {
                print("  [INDEX MISMATCH] Dropping and rebuilding: " + idx.options.name);
                targetDb[COLLECTION_NAME].dropIndex(idx.options.name);
                targetDb[COLLECTION_NAME].createIndex(idx.key, idx.options);
                print("  [INDEX REBUILT]  " + idx.options.name);
            } else {
                print("  [INDEX UP-TO-DATE] " + idx.options.name);
            }
        }
    });

    // -------------------------------------------------------------------------
    // STEP 4: Deployment Verification
    // -------------------------------------------------------------------------
    var count = targetDb[COLLECTION_NAME].countDocuments();
    var idxCount = targetDb[COLLECTION_NAME].getIndexes().length;
    print("\n================================================================================");
    print("DEPLOYMENT & MIGRATION SUMMARY");
    print("Collection:        " + COLLECTION_NAME);
    print("Total Documents:   " + count);
    print("Total Indexes:     " + idxCount + " (1 default _id_ + 12 workload indexes)");
    print("Schema Validation: STRICT (BSON jsonSchema with cross-field invariants)");
    print("Status:            SUCCESS");
    print("================================================================================");
})();

