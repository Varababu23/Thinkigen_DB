/*
    Migration Rollback Script: 037_rollback_overall_attentions_count.js
    Module:                    Teacher Portal Management & Student Academic Health
    Target:                    student_subject_attentions
    Purpose:                   Rollback script for migration 037: removes total_attentions_raised from validator
                               and unsets total_attentions_raised from documents.
*/

(function () {
    var currentDbName = (typeof db !== "undefined" && db.getName && db.getName() !== "test") ? db.getName() : "thinkigen";
    var targetDb = typeof db !== "undefined" ? db.getSiblingDB(currentDbName) : null;
    if (!targetDb) {
        throw new Error("Unable to resolve target MongoDB database '" + currentDbName + "'.");
    }

    var COLLECTION_NAME = "student_subject_attentions";
    print("================================================================================");
    print("STARTING ROLLBACK: 037_rollback_overall_attentions_count");
    print("Target Database: " + targetDb.getName());
    print("Timestamp:       " + new Date().toISOString());
    print("================================================================================");

    // Unset total_attentions_raised from root and subjects
    targetDb[COLLECTION_NAME].updateMany(
        {},
        {
            $unset: {
                total_attentions_raised: "",
                "subjects.$[].total_attentions_raised": ""
            }
        }
    );
    print("[ROLLBACK] Unset total_attentions_raised across documents.");

    print("\n================================================================================");
    print("ROLLBACK COMPLETED FOR " + COLLECTION_NAME);
    print("================================================================================");
})();
