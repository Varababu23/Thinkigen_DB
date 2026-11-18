/*
================================================================================
SCRIPT:        034_query_reference_lesson_plan_documents.js
MODULE:        Teacher Portal - Lesson Plan Management
DATABASE:      Thinkigen (MongoDB Atlas / mongosh)
PURPOSE:
Executable reference guide providing production-optimized query patterns for all
11 core workload scenarios. Every tenant-scoped query incorporates strict multi-tenant
isolation filters (school_id, branch_id, academic_year_id) and leverages dedicated
B-Tree indexes.
================================================================================
*/

(function () {
    var currentDbName = (typeof db !== "undefined" && db.getName && db.getName() !== "test") ? db.getName() : "Thinkigen";
    var targetDb = typeof db !== "undefined" ? db.getSiblingDB(currentDbName) : null;
    if (!targetDb) {
        throw new Error("Unable to resolve target MongoDB database '" + currentDbName + "'.");
    }

    var col = targetDb.lesson_plan_documents;
    var SCHOOL_ID = NumberInt(1);
    var BRANCH_ID = NumberInt(1);
    var YEAR_ID = NumberInt(1);

    print("================================================================================");
    print("PRODUCTION QUERY REFERENCE: lesson_plan_documents");
    print("Database:  " + targetDb.getName());
    print("Timestamp: " + new Date().toISOString());
    print("================================================================================");

    // -------------------------------------------------------------------------
    // QUERY 1: Fetch All Active Attachments For One Lesson Plan
    // INDEX:   ix_lesson_plan_documents_plan_status_created
    // -------------------------------------------------------------------------
    print("\n--- QUERY 1: Active attachments for Lesson Plan #101 ---");
    var q1 = col.find(
        {
            "tenant.school_id": SCHOOL_ID,
            "tenant.branch_id": BRANCH_ID,
            "tenant.academic_year_id": YEAR_ID,
            "lesson_plan.lesson_plan_id": NumberInt(101),
            "lifecycle.status": "ACTIVE"
        },
        {
            document_id: 1,
            "classification.attachment_type": 1,
            "classification.sub_category": 1,
            "file.original_name": 1,
            "file.mime_type": 1,
            "file.size_bytes": 1,
            "storage.object_key": 1,
            "preview.available": 1,
            "preview.object_key": 1,
            created_at: 1
        }
    ).sort({ created_at: -1 });

    q1.forEach(function (doc) {
        print("  [Q1] " + doc.document_id + " | " + doc.file.original_name + " (" + doc.classification.attachment_type + ")");
    });

    // -------------------------------------------------------------------------
    // QUERY 2: Fetch All Documents For A Teacher
    // INDEX:   ix_lesson_plan_documents_teacher_status_created
    // -------------------------------------------------------------------------
    print("\n--- QUERY 2: All documents authored by Teacher #1 ---");
    var q2 = col.find(
        {
            "tenant.school_id": SCHOOL_ID,
            "tenant.branch_id": BRANCH_ID,
            "tenant.academic_year_id": YEAR_ID,
            "lesson_plan.teacher_id": NumberInt(1),
            "lifecycle.status": "ACTIVE"
        },
        {
            document_id: 1,
            "lesson_plan.lesson_plan_id": 1,
            "file.original_name": 1,
            "academic_scope": 1,
            created_at: 1
        }
    ).sort({ created_at: -1 });

    q2.forEach(function (doc) {
        print("  [Q2] " + doc.document_id + " | LP #" + doc.lesson_plan.lesson_plan_id + " | " + doc.file.original_name);
    });

    // -------------------------------------------------------------------------
    // QUERY 3: Fetch All Resources For A Class And Section
    // INDEX:   ix_lesson_plan_documents_tenant_class_section_status
    // -------------------------------------------------------------------------
    print("\n--- QUERY 3: Curriculum resources for Class 9, Section 1 ---");
    var q3 = col.find(
        {
            "tenant.school_id": SCHOOL_ID,
            "tenant.branch_id": BRANCH_ID,
            "tenant.academic_year_id": YEAR_ID,
            "academic_scope.class_id": NumberInt(9),
            "academic_scope.section_id": NumberInt(1),
            "lifecycle.status": "ACTIVE"
        },
        {
            document_id: 1,
            "academic_scope.subject_id": 1,
            "academic_scope.chapter_id": 1,
            "file.original_name": 1
        }
    );

    q3.forEach(function (doc) {
        print("  [Q3] " + doc.document_id + " | Subj " + doc.academic_scope.subject_id + " | " + doc.file.original_name);
    });

    // -------------------------------------------------------------------------
    // QUERY 4: Fetch Documents For A Subject
    // INDEX:   ix_lesson_plan_documents_tenant_subject_status
    // -------------------------------------------------------------------------
    print("\n--- QUERY 4: Documents for Subject #3 (Science) ---");
    var q4 = col.find(
        {
            "tenant.school_id": SCHOOL_ID,
            "tenant.branch_id": BRANCH_ID,
            "tenant.academic_year_id": YEAR_ID,
            "academic_scope.subject_id": NumberInt(3),
            "lifecycle.status": "ACTIVE"
        },
        {
            document_id: 1,
            "academic_scope.class_id": 1,
            "academic_scope.chapter_id": 1,
            "file.original_name": 1
        }
    );

    q4.forEach(function (doc) {
        print("  [Q4] " + doc.document_id + " | Class " + doc.academic_scope.class_id + " | " + doc.file.original_name);
    });

    // -------------------------------------------------------------------------
    // QUERY 5: Fetch Chapter-Specific Documents
    // INDEX:   ix_lesson_plan_documents_tenant_chapter_status
    // -------------------------------------------------------------------------
    print("\n--- QUERY 5: Documents for Chapter 'CH-04' ---");
    var q5 = col.find(
        {
            "tenant.school_id": SCHOOL_ID,
            "tenant.branch_id": BRANCH_ID,
            "academic_scope.chapter_id": "CH-04",
            "lifecycle.status": "ACTIVE"
        },
        {
            document_id: 1,
            "academic_scope.class_id": 1,
            "academic_scope.subject_id": 1,
            "file.original_name": 1
        }
    );

    q5.forEach(function (doc) {
        print("  [Q5] " + doc.document_id + " | Chapter " + "CH-04" + " | " + doc.file.original_name);
    });

    // -------------------------------------------------------------------------
    // QUERY 6: Fetch Topic-Specific Documents
    // INDEX:   ix_lesson_plan_documents_tenant_topic_status
    // -------------------------------------------------------------------------
    print("\n--- QUERY 6: Documents for Topic 'TOP-01' ---");
    var q6 = col.find(
        {
            "tenant.school_id": SCHOOL_ID,
            "tenant.branch_id": BRANCH_ID,
            "academic_scope.topic_id": "TOP-01",
            "lifecycle.status": "ACTIVE"
        },
        {
            document_id: 1,
            "academic_scope.chapter_id": 1,
            "file.original_name": 1
        }
    );

    q6.forEach(function (doc) {
        print("  [Q6] " + doc.document_id + " | Topic " + "TOP-01" + " | " + doc.file.original_name);
    });

    // -------------------------------------------------------------------------
    // QUERY 7: Find Duplicate Checksums Within A School (Deduplication)
    // INDEX:   ix_lesson_plan_documents_tenant_checksum
    // -------------------------------------------------------------------------
    print("\n--- QUERY 7: Duplicate checksum audit within School #1 ---");
    var q7 = col.aggregate([
        {
            $match: {
                "tenant.school_id": SCHOOL_ID,
                "lifecycle.status": { $ne: "DELETED" }
            }
        },
        {
            $group: {
                _id: "$file.checksum_sha256",
                count: { $sum: 1 },
                documents: {
                    $push: {
                        document_id: "$document_id",
                        file_name: "$file.original_name",
                        size_bytes: "$file.size_bytes",
                        lesson_plan_id: "$lesson_plan.lesson_plan_id"
                    }
                }
            }
        },
        {
            $match: {
                count: { $gt: 1 }
            }
        }
    ]).toArray();

    if (q7.length === 0) {
        print("  [Q7] No duplicate checksums detected in School #" + SCHOOL_ID + ".");
    } else {
        q7.forEach(function (dup) {
            print("  [Q7 DUPLICATE] Checksum " + dup._id + " shared across " + dup.count + " documents.");
        });
    }

    // -------------------------------------------------------------------------
    // QUERY 8: Find Stale UPLOADING Documents (Abandoned Uploads > 2 Hours Old)
    // INDEX:   ix_lesson_plan_documents_lifecycle_cleanup (Partial)
    // -------------------------------------------------------------------------
    print("\n--- QUERY 8: Stale UPLOADING documents older than 2 hours ---");
    var twoHoursAgo = new Date(Date.now() - 2 * 60 * 60 * 1000);
    var q8 = col.find(
        {
            "lifecycle.status": "UPLOADING",
            created_at: { $lt: twoHoursAgo }
        },
        {
            document_id: 1,
            "storage.bucket": 1,
            "storage.object_key": 1,
            created_at: 1
        }
    );

    var staleCount = q8.count();
    print("  [Q8] Stale UPLOADING documents found: " + staleCount);

    // -------------------------------------------------------------------------
    // QUERY 9: Find FAILED or QUARANTINED Documents
    // INDEX:   ix_lesson_plan_documents_lifecycle_cleanup (Partial)
    // -------------------------------------------------------------------------
    print("\n--- QUERY 9: FAILED or QUARANTINED documents ---");
    var q9 = col.find(
        {
            "tenant.school_id": SCHOOL_ID,
            "lifecycle.status": { $in: ["FAILED", "QUARANTINED"] }
        },
        {
            document_id: 1,
            "lifecycle.status": 1,
            "processing.error_code": 1,
            updated_at: 1
        }
    ).sort({ created_at: -1 });

    var triageCount = q9.count();
    print("  [Q9] Triage documents found: " + triageCount);

    // -------------------------------------------------------------------------
    // QUERY 10: Find Pending S3 Cleanup Records
    // INDEX:    ix_lesson_plan_documents_storage_cleanup (Partial)
    // -------------------------------------------------------------------------
    print("\n--- QUERY 10: Pending S3 storage cleanups ---");
    var q10 = col.find(
        {
            "storage_cleanup.status": "PENDING"
        },
        {
            document_id: 1,
            "storage.bucket": 1,
            "storage.object_key": 1,
            "storage_cleanup.attempts": 1,
            "storage_cleanup.last_attempt_at": 1
        }
    ).sort({ "storage_cleanup.last_attempt_at": 1 });

    var cleanupCount = q10.count();
    print("  [Q10] Pending storage cleanups found: " + cleanupCount);

    // -------------------------------------------------------------------------
    // QUERY 11: Retrieve Document Metadata By document_id
    // INDEX:    uq_lesson_plan_documents_document_id
    // -------------------------------------------------------------------------
    print("\n--- QUERY 11: Exact lookup by document_id 'DOC-LP-2026-000001' ---");
    var q11 = col.findOne(
        { document_id: "DOC-LP-2026-000001" }
    );

    if (q11) {
        print("  [Q11] Found document: " + q11.document_id + " (" + q11.file.original_name + ")");
        print("        S3 Bucket:  " + q11.storage.bucket);
        print("        Object Key: " + q11.storage.object_key);
        print("        Status:     " + q11.lifecycle.status);
    } else {
        print("  [Q11] Document not found.");
    }

    print("\n[SUCCESS] Query reference execution completed without errors.");
})();

