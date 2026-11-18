/*
================================================================================
SCRIPT:        032_create_and_verify_lesson_plan_documents_indexes.js
MODULE:        Teacher Portal - Lesson Plan Management
DATABASE:      Thinkigen (MongoDB Atlas / mongosh)
PURPOSE:
1. Idempotently creates and reconciles all 12 workload indexes for lesson_plan_documents.
2. Detects and resolves index-definition mismatches (avoids IndexKeySpecsConflict).
3. Verifies index existence, keys, uniqueness, and partialFilterExpressions.
4. Outputs a verification summary table for DBA/production verification.
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
    print("STARTING INDEX CREATION & VERIFICATION FOR: " + COLLECTION_NAME);
    print("Database:  " + targetDb.getName());
    print("Timestamp: " + new Date().toISOString());
    print("================================================================================");

    if (!targetDb.getCollectionNames().includes(COLLECTION_NAME)) {
        print("[WARN] Collection '" + COLLECTION_NAME + "' does not exist. Creating collection...");
        targetDb.createCollection(COLLECTION_NAME);
    }

    var requiredIndexes = [
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

    print("\n[PHASE 1] Reconciling production indexes...");
    requiredIndexes.forEach(function (idx) {
        var existingIndexes = targetDb[COLLECTION_NAME].getIndexes();
        var matchByName = existingIndexes.find(function (e) {
            return e.name === idx.options.name;
        });

        if (!matchByName) {
            // Check if same key exists under another auto-generated name
            var matchByKey = existingIndexes.find(function (e) {
                return JSON.stringify(e.key) === JSON.stringify(idx.key);
            });

            if (matchByKey && matchByKey.name !== "_id_") {
                print("  [INDEX REPLACED] Dropping index with conflicting name: " + matchByKey.name);
                targetDb[COLLECTION_NAME].dropIndex(matchByKey.name);
            }

            targetDb[COLLECTION_NAME].createIndex(idx.key, idx.options);
            print("  [INDEX CREATED]  " + idx.options.name);
        } else {
            // Verify keys match exactly
            var keysMatch = JSON.stringify(matchByName.key) === JSON.stringify(idx.key);
            var uniqueMatch = (!!matchByName.unique) === (!!idx.options.unique);
            var partialMatch = JSON.stringify(matchByName.partialFilterExpression || null) ===
                               JSON.stringify(idx.options.partialFilterExpression || null);

            if (!keysMatch || !uniqueMatch || !partialMatch) {
                print("  [INDEX SPEC MISMATCH] Rebuilding index: " + idx.options.name);
                targetDb[COLLECTION_NAME].dropIndex(idx.options.name);
                targetDb[COLLECTION_NAME].createIndex(idx.key, idx.options);
                print("  [INDEX REBUILT]  " + idx.options.name);
            } else {
                print("  [INDEX UP-TO-DATE] " + idx.options.name);
            }
        }
    });

    // -------------------------------------------------------------------------
    // Phase 2: Complete Verification & Report Table
    // -------------------------------------------------------------------------
    print("\n[PHASE 2] Verifying active indexes on collection '" + COLLECTION_NAME + "'...");
    var activeIndexes = targetDb[COLLECTION_NAME].getIndexes();
    var allPassed = true;

    print("--------------------------------------------------------------------------------");
    print(
        "STATUS".padEnd(8) +
        "INDEX NAME".padEnd(48) +
        "UNIQUE".padEnd(8) +
        "PARTIAL FILTER"
    );
    print("--------------------------------------------------------------------------------");

    requiredIndexes.forEach(function (expected) {
        var found = activeIndexes.find(function (act) {
            return act.name === expected.options.name;
        });

        if (!found) {
            print(
                "[FAIL]".padEnd(8) +
                expected.options.name.padEnd(48) +
                "MISSING"
            );
            allPassed = false;
        } else {
            var keysOk = JSON.stringify(found.key) === JSON.stringify(expected.key);
            var uniqueOk = (!!found.unique) === (!!expected.options.unique);
            var partialOk = JSON.stringify(found.partialFilterExpression || null) ===
                            JSON.stringify(expected.options.partialFilterExpression || null);

            var isOk = keysOk && uniqueOk && partialOk;
            var statusStr = isOk ? "[OK]" : "[FAIL]";
            if (!isOk) allPassed = false;

            var partialStr = found.partialFilterExpression
                ? JSON.stringify(found.partialFilterExpression)
                : "None";

            print(
                statusStr.padEnd(8) +
                found.name.padEnd(48) +
                (found.unique ? "YES" : "NO").padEnd(8) +
                partialStr
            );
        }
    });
    print("--------------------------------------------------------------------------------");

    if (allPassed) {
        print("\n[SUCCESS] All 12 indexes verified successfully on " + COLLECTION_NAME + ".");
    } else {
        throw new Error("[FAILURE] One or more indexes failed verification.");
    }
})();

