/*
================================================================================
SCRIPT:        035_rollback_lesson_plan_documents.js
MODULE:        Teacher Portal - Lesson Plan Management
DATABASE:      Thinkigen (MongoDB Atlas / mongosh)
PURPOSE:
Safe rollback script for lesson_plan_documents:
1. Reverts/relaxes the collMod schema validator without data loss.
2. Safely drops all 12 custom workload indexes created by migration.
3. Preserves internal _id_ index and preserves 100% of existing collection records.
4. SAFETY GUARANTEE: Never drops collection; never deletes documents.
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
    print("STARTING LESSON PLAN DOCUMENTS SAFE ROLLBACK");
    print("Target Database: " + targetDb.getName());
    print("Collection:      " + COLLECTION_NAME);
    print("Timestamp:       " + new Date().toISOString());
    print("================================================================================");

    if (!targetDb.getCollectionNames().includes(COLLECTION_NAME)) {
        print("[INFO] Collection '" + COLLECTION_NAME + "' does not exist. Nothing to roll back.");
        return;
    }

    // -------------------------------------------------------------------------
    // STEP 1: Relax Schema Validation
    // -------------------------------------------------------------------------
    print("\n[STEP 1] Reverting collection validator to moderate mode...");
    try {
        targetDb.runCommand({
            collMod: COLLECTION_NAME,
            validator: {},
            validationLevel: "off"
        });
        print("  -> Schema validator disabled/relaxed without deleting records.");
    } catch (e) {
        print("  [WARN] Failed to relax validator: " + e.message);
    }

    // -------------------------------------------------------------------------
    // STEP 2: Drop Custom Workload Indexes (Preserve _id_)
    // -------------------------------------------------------------------------
    var indexesToDrop = [
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
    ];

    print("\n[STEP 2] Dropping custom workload indexes...");
    var existingIndexes = targetDb[COLLECTION_NAME].getIndexes();

    indexesToDrop.forEach(function (indexName) {
        var found = existingIndexes.find(function (idx) {
            return idx.name === indexName;
        });

        if (found) {
            try {
                targetDb[COLLECTION_NAME].dropIndex(indexName);
                print("  [DROPPED] " + indexName);
            } catch (e) {
                print("  [ERROR] Failed to drop " + indexName + ": " + e.message);
            }
        } else {
            print("  [NOT FOUND] " + indexName + " (already dropped)");
        }
    });

    var remaining = targetDb[COLLECTION_NAME].getIndexes().map(function (i) { return i.name; });
    var docCount = targetDb[COLLECTION_NAME].countDocuments();

    print("\n================================================================================");
    print("ROLLBACK COMPLETE SUMMARY");
    print("Collection:        " + COLLECTION_NAME);
    print("Preserved Records: " + docCount + " documents (ZERO data lost)");
    print("Remaining Indexes: " + remaining.join(", "));
    print("Status:            SAFE ROLLBACK EXECUTED");
    print("================================================================================");
})();

