/*
    Migration Script: 037_add_overall_attentions_count.js
    Module:           Teacher Portal Management & Student Academic Health
    Target:           student_subject_attentions
    Purpose:          Production-grade migration to add `total_attentions_raised` (overall count of all alerts
                      raised for that student within the academic year across all subjects) at root and per-subject,
                      in-place upgrade existing documents, and apply refined strict JSON schema validation.
*/

(function () {
    var currentDbName = (typeof db !== "undefined" && db.getName && db.getName() !== "test") ? db.getName() : "thinkigen";
    var targetDb = typeof db !== "undefined" ? db.getSiblingDB(currentDbName) : null;
    if (!targetDb) {
        throw new Error("Unable to resolve target MongoDB database '" + currentDbName + "'.");
    }

    var COLLECTION_NAME = "student_subject_attentions";
    print("================================================================================");
    print("STARTING MIGRATION: 037_add_overall_attentions_count");
    print("Target Database: " + targetDb.getName());
    print("Timestamp:       " + new Date().toISOString());
    print("================================================================================");

    // 1. PRE-FLIGHT CHECKS
    var collections = targetDb.getCollectionNames();
    var collectionExists = collections.includes(COLLECTION_NAME);

    if (collectionExists) {
        print("[PRE-FLIGHT] Collection " + COLLECTION_NAME + " exists.");

        // 2. IN-PLACE MIGRATION OF EXISTING DOCUMENTS
        var existingDocsCount = targetDb[COLLECTION_NAME].countDocuments();
        if (existingDocsCount > 0) {
            print("[MIGRATION] Found " + existingDocsCount + " existing documents. Computing and backfilling total_attentions_raised...");
            var migratedCount = 0;
            var cursor = targetDb[COLLECTION_NAME].find({});
            while (cursor.hasNext()) {
                var doc = cursor.next();

                var docTotalRaised = 0;
                if (Array.isArray(doc.subjects)) {
                    doc.subjects.forEach(function (subj) {
                        var subjRaised = Array.isArray(subj.attentions) ? subj.attentions.length : 0;
                        subj.total_attentions_raised = NumberInt(subjRaised);
                        subj.active_attentions_count = NumberInt(subj.active_attentions_count != null ? subj.active_attentions_count : 0);
                        docTotalRaised += subjRaised;

                        if (Array.isArray(subj.attentions)) {
                            subj.attentions.forEach(function (att) {
                                delete att.severity;
                            });
                        }
                    });
                }

                doc.total_attentions_raised = NumberInt(docTotalRaised);
                doc.total_active_attentions = NumberInt(doc.total_active_attentions != null ? doc.total_active_attentions : 0);
                delete doc.critical_attentions_count;
                doc.updated_at = new Date();

                targetDb[COLLECTION_NAME].replaceOne({ _id: doc._id }, doc);
                migratedCount++;
            }
            print("[MIGRATION] Successfully backfilled total_attentions_raised across " + migratedCount + " documents.");
        }
    } else {
        print("[PRE-FLIGHT] Collection " + COLLECTION_NAME + " does not exist yet. It will be initialized.");
    }

    // 3. DEFINE UPDATED SCHEMA VALIDATOR
    var validator = {
        $jsonSchema: {
            bsonType: "object",
            required: [
                "student_id",
                "student_name",
                "school_id",
                "branch_id",
                "academic_year_id",
                "class_id",
                "class_name",
                "section_id",
                "section_name",
                "total_attentions_raised",
                "total_active_attentions",
                "subjects",
                "last_evaluated_at",
                "is_active",
                "created_at",
                "updated_at"
            ],
            additionalProperties: true,
            properties: {
                _id: { bsonType: ["objectId", "string"] },
                student_id: { bsonType: "int", minimum: 1 },
                student_name: { bsonType: "string", minLength: 1, maxLength: 150 },
                admission_number: { bsonType: ["string", "null"], maxLength: 50 },
                roll_number: { bsonType: ["string", "null"], maxLength: 50 },
                school_id: { bsonType: "int", minimum: 1 },
                branch_id: { bsonType: "int", minimum: 1 },
                academic_year_id: { bsonType: "int", minimum: 1 },
                class_id: { bsonType: "int", minimum: 1 },
                class_name: { bsonType: "string", minLength: 1, maxLength: 50 },
                section_id: { bsonType: "int", minimum: 1 },
                section_name: { bsonType: "string", minLength: 1, maxLength: 20 },
                total_attentions_raised: { bsonType: "int", minimum: 0 },
                total_active_attentions: { bsonType: "int", minimum: 0 },

                subjects: {
                    bsonType: "array",
                    items: {
                        bsonType: "object",
                        required: [
                            "subject_id",
                            "subject_name",
                            "subject_code",
                            "total_attentions_raised",
                            "active_attentions_count",
                            "attentions"
                        ],
                        additionalProperties: true,
                        properties: {
                            subject_id: { bsonType: "int", minimum: 1 },
                            subject_name: { bsonType: "string", minLength: 1, maxLength: 100 },
                            subject_code: { bsonType: "string", minLength: 1, maxLength: 30 },
                            assigned_teacher_id: { bsonType: ["int", "null"] },
                            assigned_teacher_name: { bsonType: ["string", "null"], maxLength: 150 },
                            total_attentions_raised: { bsonType: "int", minimum: 0 },
                            active_attentions_count: { bsonType: "int", minimum: 0 },

                            attentions: {
                                bsonType: "array",
                                items: {
                                    bsonType: "object",
                                    required: [
                                        "attention_id",
                                        "attention_type",
                                        "title",
                                        "description",
                                        "trigger_source",
                                        "source_id",
                                        "triggered_at",
                                        "status"
                                    ],
                                    additionalProperties: true,
                                    properties: {
                                        attention_id: { bsonType: "string", minLength: 1, maxLength: 64 },
                                        attention_type: {
                                            bsonType: "string",
                                            enum: [
                                                "LOW_ASSESSMENT_SCORE",
                                                "PENDING_HOMEWORK",
                                                "ABSENT_ATTENDANCE"
                                            ]
                                        },
                                        title: { bsonType: "string", minLength: 1, maxLength: 200 },
                                        description: { bsonType: "string", minLength: 1, maxLength: 500 },
                                        trigger_source: {
                                            bsonType: "string",
                                            enum: ["ASSESSMENT", "ASSIGNMENT_HOMEWORK", "ATTENDANCE"]
                                        },
                                        source_id: { bsonType: "int", minimum: 1 },
                                        triggered_at: { bsonType: "date" },
                                        status: {
                                            bsonType: "string",
                                            enum: ["ACTIVE", "ACKNOWLEDGED", "RESOLVED", "EXCUSED"]
                                        },
                                        acknowledged_at: { bsonType: ["date", "null"] },
                                        acknowledged_by_teacher_id: { bsonType: ["int", "null"] },
                                        resolved_at: { bsonType: ["date", "null"] },
                                        resolved_by_teacher_id: { bsonType: ["int", "null"] },
                                        resolution_remarks: { bsonType: ["string", "null"], maxLength: 500 },
                                        excused_reason: { bsonType: ["string", "null"], maxLength: 500 },

                                        assessment_details: {
                                            bsonType: ["object", "null"],
                                            additionalProperties: true,
                                            properties: {
                                                assessment_id: { bsonType: ["int", "null"] },
                                                assessment_name: { bsonType: ["string", "null"], maxLength: 150 },
                                                exam_type: { bsonType: ["string", "null"], maxLength: 50 },
                                                max_marks: { bsonType: ["int", "double", "decimal", "null"] },
                                                pass_marks: { bsonType: ["int", "double", "decimal", "null"] },
                                                obtained_marks: { bsonType: ["int", "double", "decimal", "null"] },
                                                percentage: { bsonType: ["int", "double", "decimal", "null"] }
                                            }
                                        },

                                        homework_details: {
                                            bsonType: ["object", "null"],
                                            additionalProperties: true,
                                            properties: {
                                                homework_id: { bsonType: ["int", "null"] },
                                                homework_title: { bsonType: ["string", "null"], maxLength: 200 },
                                                assigned_date: { bsonType: ["date", "null"] },
                                                due_date: { bsonType: ["date", "null"] },
                                                days_overdue: { bsonType: ["int", "null"] },
                                                submission_status: { bsonType: ["string", "null"] }
                                            }
                                        },

                                        attendance_details: {
                                            bsonType: ["object", "null"],
                                            additionalProperties: true,
                                            properties: {
                                                attendance_id: { bsonType: ["int", "null"] },
                                                attendance_date: { bsonType: ["date", "null"] },
                                                period_number: { bsonType: ["int", "null"] },
                                                period_time: { bsonType: ["string", "null"], maxLength: 30 },
                                                attendance_status: { bsonType: ["string", "null"] }
                                            }
                                        }
                                    }
                                }
                            },

                            subject_summary: {
                                bsonType: ["object", "null"],
                                additionalProperties: true,
                                properties: {
                                    assessments_passed: { bsonType: ["int", "null"] },
                                    assessments_failed: { bsonType: ["int", "null"] },
                                    homework_submitted: { bsonType: ["int", "null"] },
                                    homework_pending: { bsonType: ["int", "null"] },
                                    subject_attendance_percent: { bsonType: ["int", "double", "decimal", "null"] }
                                }
                            }
                        }
                    }
                },

                last_evaluated_at: { bsonType: "date" },
                is_active: { bsonType: ["int", "bool"] },
                created_at: { bsonType: "date" },
                updated_at: { bsonType: "date" }
            }
        }
    };

    // 4. APPLY SCHEMA VALIDATOR VIA collMod
    if (!collectionExists) {
        targetDb.createCollection(COLLECTION_NAME, {
            validator: validator,
            validationLevel: "strict",
            validationAction: "error"
        });
        print("[MIGRATION] Created collection " + COLLECTION_NAME + " with updated schema validator.");
    } else {
        var collModRes = targetDb.runCommand({
            collMod: COLLECTION_NAME,
            validator: validator,
            validationLevel: "strict",
            validationAction: "error"
        });
        if (collModRes.ok !== 1) {
            print("[ERROR] collMod failed: " + JSON.stringify(collModRes));
            throw new Error("collMod command failed.");
        }
        print("[MIGRATION] Successfully updated schema validation using collMod.");
    }

    // 5. ENSURE INDEXES WITHOUT SEVERITY
    var targetIdxName = "ix_student_attentions_status_type";
    var targetIdxKey = { academic_year_id: 1, "subjects.attentions.status": 1, "subjects.attentions.attention_type": 1 };
    var existingIndexes = targetDb[COLLECTION_NAME].getIndexes();
    var matchIdx = existingIndexes.find(function (e) { return e.name === targetIdxName; });

    if (matchIdx) {
        if (JSON.stringify(matchIdx.key) !== JSON.stringify(targetIdxKey)) {
            print("[INDEX] Rebuilding " + targetIdxName + " without severity field...");
            targetDb[COLLECTION_NAME].dropIndex(targetIdxName);
            targetDb[COLLECTION_NAME].createIndex(targetIdxKey, { name: targetIdxName });
            print("[INDEX] Successfully rebuilt index " + targetIdxName);
        } else {
            print("[INDEX] Index " + targetIdxName + " already up to date.");
        }
    } else {
        targetDb[COLLECTION_NAME].createIndex(targetIdxKey, { name: targetIdxName });
        print("[INDEX] Created index " + targetIdxName);
    }

    print("\n================================================================================");
    print("MIGRATION COMPLETED SUCCESSFULLY FOR " + COLLECTION_NAME);
    print("================================================================================");
})();
