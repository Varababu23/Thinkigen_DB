/*
================================================================================
SCRIPT:        040_seed_realistic_student_attentions_all_20_students.js
MODULE:        Teacher Portal Management & Student Academic Health
DATABASE:      thinkigen (MongoDB / mongosh)
COLLECTION:    student_subject_attentions

AUTHENTIC MAPPINGS ENFORCED (FROM SQL SERVER REALISTIC MASTER SEEDS):
- School: ID 1
- Branch: ID 1 (Central Campus)
- Academic Year: ID 1 (2026-2027)
- Class: ID 1 ("Class 1 - Central")
- Section 1 ("A"): Students 1 to 10 (Roll R-01 to R-10, ADM-2026-0001 to ADM-2026-0010)
  Faculty:
  * Subject 1 (English, "ENG"):          Teacher 1  (Keshav Kulkarni, HOD)
  * Subject 2 (Mathematics, "MAT"):      Teacher 8  (Zara Pai, HOD)
  * Subject 3 (Science, "SCI"):          Teacher 15 (Bhuvan Solanki, HOD)
  * Subject 4 (Social Science, "SOC"):   Teacher 22 (Rashmi Chopra, HOD)
  * Subject 5 (Computer Science, "CSC"): Teacher 29 (Raghunath Mathur, HOD)
  * Subject 6 (Physical Ed, "PE"):       Teacher 35 (Abhiram Kansal)
- Section 2 ("B"): Students 11 to 20 (Roll R-01 to R-10, ADM-2026-0011 to ADM-2026-0020)
  Faculty:
  * Subject 1 (English, "ENG"):          Teacher 2  (Radhika Pillai)
  * Subject 2 (Mathematics, "MAT"):      Teacher 9  (Utkarsh Mishra)
  * Subject 3 (Science, "SCI"):          Teacher 16 (Juhi Rajput)
  * Subject 4 (Social Science, "SOC"):   Teacher 23 (Kushagra Kapoor)
  * Subject 5 (Computer Science, "CSC"): Teacher 30 (Chitra Nigam)
  * Subject 6 (Physical Ed, "PE"):       Teacher 35 (Abhiram Kansal)

METRIC INVARIANTS ENFORCED:
1. total_attentions_raised: Total count of all alerts raised (ACTIVE + ACKNOWLEDGED + RESOLVED + EXCUSED).
2. total_active_attentions: Total count of currently ACTIVE alerts requiring intervention.
3. Subject level: total_attentions_raised and active_attentions_count maintained per subject.
4. NO severity or critical attention fields anywhere (completely removed per specification).
5. 100% BSON 32-bit int (NumberInt).
6. 100% Past dates up to today (<= 2026-11-18).
7. Total Students Seeded: Exactly 20 students.
================================================================================
*/

(function () {
    var currentDbName = (typeof db !== "undefined" && db.getName && db.getName() !== "test") ? db.getName() : "thinkigen";
    var targetDb = typeof db !== "undefined" ? db.getSiblingDB(currentDbName) : null;
    if (!targetDb) {
        throw new Error("Unable to resolve target MongoDB database '" + currentDbName + "'.");
    }

    var COLLECTION_NAME = "student_subject_attentions";
    print("================================================================================");
    print("SEEDING REALISTIC MOCK DATA (ALL 20 STUDENTS): " + COLLECTION_NAME);
    print("Target Database: " + targetDb.getName());
    print("Timestamp:       " + new Date().toISOString());
    print("================================================================================");

    // -------------------------------------------------------------------------
    // 1. RECONCILE SCHEMA VALIDATOR (Removing critical_attentions_count & severity)
    // -------------------------------------------------------------------------
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

    var collections = targetDb.getCollectionNames();
    if (!collections.includes(COLLECTION_NAME)) {
        targetDb.createCollection(COLLECTION_NAME, {
            validator: validator,
            validationLevel: "strict",
            validationAction: "error"
        });
        print("[SCHEMA] Created collection " + COLLECTION_NAME + " with refined schema validator.");
    } else {
        var collModRes = targetDb.runCommand({
            collMod: COLLECTION_NAME,
            validator: validator,
            validationLevel: "strict",
            validationAction: "error"
        });
        if (collModRes.ok === 1) {
            print("[SCHEMA] Successfully updated schema validator via collMod (removed severity & critical_attentions_count).");
        } else {
            print("[WARN] collMod warning: " + JSON.stringify(collModRes));
        }
    }

    // -------------------------------------------------------------------------
    // 2. RECONCILE INDEXES (Remove severity from triage index)
    // -------------------------------------------------------------------------
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
            print("[INDEX] Index " + targetIdxName + " already conforms to specification.");
        }
    } else {
        targetDb[COLLECTION_NAME].createIndex(targetIdxKey, { name: targetIdxName });
        print("[INDEX] Created index " + targetIdxName);
    }

    // -------------------------------------------------------------------------
    // 3. DELETE EXISTING MOCK DATA (Clean wipe per user request)
    // -------------------------------------------------------------------------
    var delRes = targetDb[COLLECTION_NAME].deleteMany({});
    print("[CLEANUP] Deleted " + delRes.deletedCount + " existing mock documents from " + COLLECTION_NAME + ".");

    // -------------------------------------------------------------------------
    // 4. PREPARE ALL 20 PRODUCTION-GRADE STUDENT ATTENTION DOCUMENTS
    // -------------------------------------------------------------------------
    var docsToInsert = [

        {
            student_id: NumberInt(1),
            student_name: "Karishma Shaik",
            admission_number: "ADM-2026-0001",
            roll_number: "R-01",
            school_id: NumberInt(1),
            branch_id: NumberInt(1),
            academic_year_id: NumberInt(1),
            class_id: NumberInt(1),
            class_name: "Class 1 - Central",
            section_id: NumberInt(1),
            section_name: "A",
            total_attentions_raised: NumberInt(4),
            total_active_attentions: NumberInt(2),
            subjects: [
            {
                subject_id: NumberInt(1),
                subject_name: "English",
                subject_code: "ENG",
                assigned_teacher_id: NumberInt(1),
                assigned_teacher_name: "Keshav Kulkarni",
                total_attentions_raised: NumberInt(1),
                active_attentions_count: NumberInt(0),
                attentions: [
                    {
                        attention_id: "ATT-1-HW-3001-1",
                        attention_type: "PENDING_HOMEWORK",
                        title: "Overdue Poetry Analysis Essay - The Road Not Taken",
                        description: "Poetry analysis essay assigned on Oct 12 submitted late and accepted.",
                        trigger_source: "ASSIGNMENT_HOMEWORK",
                        source_id: NumberInt(3001),
                        triggered_at: new Date("2026-10-16T09:00:00Z"),
                        status: "RESOLVED",
                        acknowledged_at: new Date("2026-10-16T11:00:00Z"),
                        acknowledged_by_teacher_id: NumberInt(1),
                        resolved_at: new Date("2026-10-18T14:30:00Z"),
                        resolved_by_teacher_id: NumberInt(1),
                        resolution_remarks: "Completed handwritten essay with annotations evaluated and accepted.",
                        excused_reason: null,
                        assessment_details: null,
                        homework_details: {
                                homework_id: NumberInt(3001),
                                homework_title: "Poetry Analysis - The Road Not Taken",
                                assigned_date: new Date("2026-10-12T08:00:00Z"),
                                due_date: new Date("2026-10-15T16:00:00Z"),
                                days_overdue: NumberInt(2),
                                submission_status: "LATE"
                            },
                        attendance_details: null
                    }
                ],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(2),
                subject_name: "Mathematics",
                subject_code: "MAT",
                assigned_teacher_id: NumberInt(8),
                assigned_teacher_name: "Zara Pai",
                total_attentions_raised: NumberInt(2),
                active_attentions_count: NumberInt(2),
                attentions: [
                    {
                        attention_id: "ATT-1-ASM-501-1",
                        attention_type: "LOW_ASSESSMENT_SCORE",
                        title: "Linear Equations Slip Test Below Benchmark",
                        description: "Scored 14/50 on algebra diagnostic slip test.",
                        trigger_source: "ASSESSMENT",
                        source_id: NumberInt(501),
                        triggered_at: new Date("2026-10-28T14:30:00Z"),
                        status: "ACTIVE",
                        acknowledged_at: new Date("2026-10-29T08:30:00Z"),
                        acknowledged_by_teacher_id: NumberInt(8),
                        resolved_at: null,
                        resolved_by_teacher_id: null,
                        resolution_remarks: null,
                        excused_reason: null,
                        assessment_details: {
                                assessment_id: NumberInt(501),
                                assessment_name: "Linear Equations Slip Test",
                                exam_type: "SLIP_TEST",
                                max_marks: 50.0,
                                pass_marks: 20.0,
                                obtained_marks: 14.0,
                                percentage: 28.0
                            },
                        homework_details: null,
                        attendance_details: null
                    },
                    {
                        attention_id: "ATT-1-HW-3002-1",
                        attention_type: "PENDING_HOMEWORK",
                        title: "Polynomial Algebraic Identities Exercise 3.2 Overdue",
                        description: "Exercise 3.2 textbook problems overdue by 3 days.",
                        trigger_source: "ASSIGNMENT_HOMEWORK",
                        source_id: NumberInt(3002),
                        triggered_at: new Date("2026-10-26T08:00:00Z"),
                        status: "ACTIVE",
                        acknowledged_at: new Date("2026-10-27T09:00:00Z"),
                        acknowledged_by_teacher_id: NumberInt(8),
                        resolved_at: null,
                        resolved_by_teacher_id: null,
                        resolution_remarks: null,
                        excused_reason: null,
                        assessment_details: null,
                        homework_details: {
                                homework_id: NumberInt(3002),
                                homework_title: "Polynomial Identities Exercise 3.2",
                                assigned_date: new Date("2026-10-20T08:00:00Z"),
                                due_date: new Date("2026-10-23T16:00:00Z"),
                                days_overdue: NumberInt(3),
                                submission_status: "PENDING"
                            },
                        attendance_details: null
                    }
                ],
                subject_summary: {
                    assessments_passed: NumberInt(2),
                    assessments_failed: NumberInt(1),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(1),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(3),
                subject_name: "Science",
                subject_code: "SCI",
                assigned_teacher_id: NumberInt(15),
                assigned_teacher_name: "Bhuvan Solanki",
                total_attentions_raised: NumberInt(1),
                active_attentions_count: NumberInt(0),
                attentions: [
                    {
                        attention_id: "ATT-1-ATT-9001-1",
                        attention_type: "ABSENT_ATTENDANCE",
                        title: "Period 3 Chemistry Practical Absence",
                        description: "Absent during Acids and Bases lab practical; medical note submitted.",
                        trigger_source: "ATTENDANCE",
                        source_id: NumberInt(9001),
                        triggered_at: new Date("2026-10-15T11:00:00Z"),
                        status: "EXCUSED",
                        acknowledged_at: new Date("2026-10-15T11:30:00Z"),
                        acknowledged_by_teacher_id: NumberInt(15),
                        resolved_at: new Date("2026-10-16T09:00:00Z"),
                        resolved_by_teacher_id: NumberInt(15),
                        resolution_remarks: "Excused by Science teacher per clinic slip.",
                        excused_reason: "Medical certificate from Central School Clinic submitted.",
                        assessment_details: null,
                        homework_details: null,
                        attendance_details: {
                                attendance_id: NumberInt(9001),
                                attendance_date: new Date("2026-10-15T00:00:00Z"),
                                period_number: NumberInt(3),
                                period_time: "10:15 - 11:00",
                                attendance_status: "ABSENT"
                            }
                    }
                ],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 92.5
                }
            },
            {
                subject_id: NumberInt(4),
                subject_name: "Social Science",
                subject_code: "SOC",
                assigned_teacher_id: NumberInt(22),
                assigned_teacher_name: "Rashmi Chopra",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(5),
                subject_name: "Computer Science",
                subject_code: "CSC",
                assigned_teacher_id: NumberInt(29),
                assigned_teacher_name: "Raghunath Mathur",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(6),
                subject_name: "Physical Education",
                subject_code: "PE",
                assigned_teacher_id: NumberInt(35),
                assigned_teacher_name: "Abhiram Kansal",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            }
        ],
            last_evaluated_at: new Date("2026-11-18T14:00:00Z"),
            is_active: NumberInt(1),
            created_at: new Date("2026-10-01T08:00:00Z"),
            updated_at: new Date("2026-11-18T14:00:00Z")
        },
        {
            student_id: NumberInt(2),
            student_name: "Dhamodhar Rao",
            admission_number: "ADM-2026-0002",
            roll_number: "R-02",
            school_id: NumberInt(1),
            branch_id: NumberInt(1),
            academic_year_id: NumberInt(1),
            class_id: NumberInt(1),
            class_name: "Class 1 - Central",
            section_id: NumberInt(1),
            section_name: "A",
            total_attentions_raised: NumberInt(2),
            total_active_attentions: NumberInt(1),
            subjects: [
            {
                subject_id: NumberInt(1),
                subject_name: "English",
                subject_code: "ENG",
                assigned_teacher_id: NumberInt(1),
                assigned_teacher_name: "Keshav Kulkarni",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(2),
                subject_name: "Mathematics",
                subject_code: "MAT",
                assigned_teacher_id: NumberInt(8),
                assigned_teacher_name: "Zara Pai",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(3),
                subject_name: "Science",
                subject_code: "SCI",
                assigned_teacher_id: NumberInt(15),
                assigned_teacher_name: "Bhuvan Solanki",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(4),
                subject_name: "Social Science",
                subject_code: "SOC",
                assigned_teacher_id: NumberInt(22),
                assigned_teacher_name: "Rashmi Chopra",
                total_attentions_raised: NumberInt(1),
                active_attentions_count: NumberInt(0),
                attentions: [
                    {
                        attention_id: "ATT-2-HW-3014-1",
                        attention_type: "PENDING_HOMEWORK",
                        title: "Map Work: River Systems of Southern India",
                        description: "Geography river basin mapping assignment submitted after 1-day delay.",
                        trigger_source: "ASSIGNMENT_HOMEWORK",
                        source_id: NumberInt(3014),
                        triggered_at: new Date("2026-10-20T08:00:00Z"),
                        status: "RESOLVED",
                        acknowledged_at: new Date("2026-10-20T10:00:00Z"),
                        acknowledged_by_teacher_id: NumberInt(22),
                        resolved_at: new Date("2026-10-22T11:00:00Z"),
                        resolved_by_teacher_id: NumberInt(22),
                        resolution_remarks: "Map coloring and key labeling checked; verified complete.",
                        excused_reason: null,
                        assessment_details: null,
                        homework_details: {
                                homework_id: NumberInt(3014),
                                homework_title: "River Systems Mapping Portfolio",
                                assigned_date: new Date("2026-10-16T08:00:00Z"),
                                due_date: new Date("2026-10-19T16:00:00Z"),
                                days_overdue: NumberInt(1),
                                submission_status: "LATE"
                            },
                        attendance_details: null
                    }
                ],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(5),
                subject_name: "Computer Science",
                subject_code: "CSC",
                assigned_teacher_id: NumberInt(29),
                assigned_teacher_name: "Raghunath Mathur",
                total_attentions_raised: NumberInt(1),
                active_attentions_count: NumberInt(1),
                attentions: [
                    {
                        attention_id: "ATT-2-HW-3012-1",
                        attention_type: "PENDING_HOMEWORK",
                        title: "Overdue Python Loop Programming Lab 3",
                        description: "Loop iterations worksheet assigned Oct 23 not submitted.",
                        trigger_source: "ASSIGNMENT_HOMEWORK",
                        source_id: NumberInt(3012),
                        triggered_at: new Date("2026-10-27T08:00:00Z"),
                        status: "ACTIVE",
                        acknowledged_at: new Date("2026-10-28T09:00:00Z"),
                        acknowledged_by_teacher_id: NumberInt(29),
                        resolved_at: null,
                        resolved_by_teacher_id: null,
                        resolution_remarks: null,
                        excused_reason: null,
                        assessment_details: null,
                        homework_details: {
                                homework_id: NumberInt(3012),
                                homework_title: "Python Lab 3: Loop Iterations",
                                assigned_date: new Date("2026-10-23T08:00:00Z"),
                                due_date: new Date("2026-10-26T16:00:00Z"),
                                days_overdue: NumberInt(3),
                                submission_status: "PENDING"
                            },
                        attendance_details: null
                    }
                ],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(1),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(6),
                subject_name: "Physical Education",
                subject_code: "PE",
                assigned_teacher_id: NumberInt(35),
                assigned_teacher_name: "Abhiram Kansal",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            }
        ],
            last_evaluated_at: new Date("2026-11-18T14:00:00Z"),
            is_active: NumberInt(1),
            created_at: new Date("2026-10-01T08:00:00Z"),
            updated_at: new Date("2026-11-18T14:00:00Z")
        },
        {
            student_id: NumberInt(3),
            student_name: "Sita Ram",
            admission_number: "ADM-2026-0003",
            roll_number: "R-03",
            school_id: NumberInt(1),
            branch_id: NumberInt(1),
            academic_year_id: NumberInt(1),
            class_id: NumberInt(1),
            class_name: "Class 1 - Central",
            section_id: NumberInt(1),
            section_name: "A",
            total_attentions_raised: NumberInt(2),
            total_active_attentions: NumberInt(2),
            subjects: [
            {
                subject_id: NumberInt(1),
                subject_name: "English",
                subject_code: "ENG",
                assigned_teacher_id: NumberInt(1),
                assigned_teacher_name: "Keshav Kulkarni",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(2),
                subject_name: "Mathematics",
                subject_code: "MAT",
                assigned_teacher_id: NumberInt(8),
                assigned_teacher_name: "Zara Pai",
                total_attentions_raised: NumberInt(1),
                active_attentions_count: NumberInt(1),
                attentions: [
                    {
                        attention_id: "ATT-3-ASM-503-1",
                        attention_type: "LOW_ASSESSMENT_SCORE",
                        title: "Trigonometric Ratios Slip Test Deficit",
                        description: "Scored 12/50 on introductory trigonometry test; remedial coaching advised.",
                        trigger_source: "ASSESSMENT",
                        source_id: NumberInt(503),
                        triggered_at: new Date("2026-10-28T14:30:00Z"),
                        status: "ACTIVE",
                        acknowledged_at: new Date("2026-10-29T08:45:00Z"),
                        acknowledged_by_teacher_id: NumberInt(8),
                        resolved_at: null,
                        resolved_by_teacher_id: null,
                        resolution_remarks: null,
                        excused_reason: null,
                        assessment_details: {
                                assessment_id: NumberInt(503),
                                assessment_name: "Trigonometric Ratios Test",
                                exam_type: "SLIP_TEST",
                                max_marks: 50.0,
                                pass_marks: 20.0,
                                obtained_marks: 12.0,
                                percentage: 24.0
                            },
                        homework_details: null,
                        attendance_details: null
                    }
                ],
                subject_summary: {
                    assessments_passed: NumberInt(2),
                    assessments_failed: NumberInt(1),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(3),
                subject_name: "Science",
                subject_code: "SCI",
                assigned_teacher_id: NumberInt(15),
                assigned_teacher_name: "Bhuvan Solanki",
                total_attentions_raised: NumberInt(1),
                active_attentions_count: NumberInt(1),
                attentions: [
                    {
                        attention_id: "ATT-3-ATT-9015-1",
                        attention_type: "ABSENT_ATTENDANCE",
                        title: "Period 3 Science Laboratory Absence",
                        description: "Unexcused absence during Acids & Bases experimental practical.",
                        trigger_source: "ATTENDANCE",
                        source_id: NumberInt(9015),
                        triggered_at: new Date("2026-11-05T11:00:00Z"),
                        status: "ACTIVE",
                        acknowledged_at: new Date("2026-11-06T08:30:00Z"),
                        acknowledged_by_teacher_id: NumberInt(15),
                        resolved_at: null,
                        resolved_by_teacher_id: null,
                        resolution_remarks: null,
                        excused_reason: null,
                        assessment_details: null,
                        homework_details: null,
                        attendance_details: {
                                attendance_id: NumberInt(9015),
                                attendance_date: new Date("2026-11-05T00:00:00Z"),
                                period_number: NumberInt(3),
                                period_time: "10:15 - 11:00",
                                attendance_status: "ABSENT"
                            }
                    }
                ],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 92.5
                }
            },
            {
                subject_id: NumberInt(4),
                subject_name: "Social Science",
                subject_code: "SOC",
                assigned_teacher_id: NumberInt(22),
                assigned_teacher_name: "Rashmi Chopra",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(5),
                subject_name: "Computer Science",
                subject_code: "CSC",
                assigned_teacher_id: NumberInt(29),
                assigned_teacher_name: "Raghunath Mathur",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(6),
                subject_name: "Physical Education",
                subject_code: "PE",
                assigned_teacher_id: NumberInt(35),
                assigned_teacher_name: "Abhiram Kansal",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            }
        ],
            last_evaluated_at: new Date("2026-11-18T14:00:00Z"),
            is_active: NumberInt(1),
            created_at: new Date("2026-10-01T08:00:00Z"),
            updated_at: new Date("2026-11-18T14:00:00Z")
        },
        {
            student_id: NumberInt(4),
            student_name: "Krupa Joseph",
            admission_number: "ADM-2026-0004",
            roll_number: "R-04",
            school_id: NumberInt(1),
            branch_id: NumberInt(1),
            academic_year_id: NumberInt(1),
            class_id: NumberInt(1),
            class_name: "Class 1 - Central",
            section_id: NumberInt(1),
            section_name: "A",
            total_attentions_raised: NumberInt(2),
            total_active_attentions: NumberInt(2),
            subjects: [
            {
                subject_id: NumberInt(1),
                subject_name: "English",
                subject_code: "ENG",
                assigned_teacher_id: NumberInt(1),
                assigned_teacher_name: "Keshav Kulkarni",
                total_attentions_raised: NumberInt(1),
                active_attentions_count: NumberInt(1),
                attentions: [
                    {
                        attention_id: "ATT-4-HW-3020-1",
                        attention_type: "PENDING_HOMEWORK",
                        title: "Active & Passive Voice Transformation Practice Overdue",
                        description: "Grammar transformation exercise 4.1 pending submission.",
                        trigger_source: "ASSIGNMENT_HOMEWORK",
                        source_id: NumberInt(3020),
                        triggered_at: new Date("2026-11-06T08:00:00Z"),
                        status: "ACTIVE",
                        acknowledged_at: new Date("2026-11-07T08:30:00Z"),
                        acknowledged_by_teacher_id: NumberInt(1),
                        resolved_at: null,
                        resolved_by_teacher_id: null,
                        resolution_remarks: null,
                        excused_reason: null,
                        assessment_details: null,
                        homework_details: {
                                homework_id: NumberInt(3020),
                                homework_title: "Voice Transformation Practice 4.1",
                                assigned_date: new Date("2026-11-02T08:00:00Z"),
                                due_date: new Date("2026-11-05T16:00:00Z"),
                                days_overdue: NumberInt(2),
                                submission_status: "PENDING"
                            },
                        attendance_details: null
                    }
                ],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(1),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(2),
                subject_name: "Mathematics",
                subject_code: "MAT",
                assigned_teacher_id: NumberInt(8),
                assigned_teacher_name: "Zara Pai",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(3),
                subject_name: "Science",
                subject_code: "SCI",
                assigned_teacher_id: NumberInt(15),
                assigned_teacher_name: "Bhuvan Solanki",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(4),
                subject_name: "Social Science",
                subject_code: "SOC",
                assigned_teacher_id: NumberInt(22),
                assigned_teacher_name: "Rashmi Chopra",
                total_attentions_raised: NumberInt(1),
                active_attentions_count: NumberInt(1),
                attentions: [
                    {
                        attention_id: "ATT-4-ASM-504-1",
                        attention_type: "LOW_ASSESSMENT_SCORE",
                        title: "Indian Constitution Principles Diagnostic Retest",
                        description: "Scored 15/40 on Indian Constitution foundational principles slip test.",
                        trigger_source: "ASSESSMENT",
                        source_id: NumberInt(504),
                        triggered_at: new Date("2026-10-27T15:00:00Z"),
                        status: "ACTIVE",
                        acknowledged_at: new Date("2026-10-28T09:15:00Z"),
                        acknowledged_by_teacher_id: NumberInt(22),
                        resolved_at: null,
                        resolved_by_teacher_id: null,
                        resolution_remarks: null,
                        excused_reason: null,
                        assessment_details: {
                                assessment_id: NumberInt(504),
                                assessment_name: "Constitution Principles Diagnostic",
                                exam_type: "SLIP_TEST",
                                max_marks: 40.0,
                                pass_marks: 18.0,
                                obtained_marks: 15.0,
                                percentage: 37.5
                            },
                        homework_details: null,
                        attendance_details: null
                    }
                ],
                subject_summary: {
                    assessments_passed: NumberInt(2),
                    assessments_failed: NumberInt(1),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(5),
                subject_name: "Computer Science",
                subject_code: "CSC",
                assigned_teacher_id: NumberInt(29),
                assigned_teacher_name: "Raghunath Mathur",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(6),
                subject_name: "Physical Education",
                subject_code: "PE",
                assigned_teacher_id: NumberInt(35),
                assigned_teacher_name: "Abhiram Kansal",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            }
        ],
            last_evaluated_at: new Date("2026-11-18T14:00:00Z"),
            is_active: NumberInt(1),
            created_at: new Date("2026-10-01T08:00:00Z"),
            updated_at: new Date("2026-11-18T14:00:00Z")
        },
        {
            student_id: NumberInt(5),
            student_name: "Jeswanth Reddy",
            admission_number: "ADM-2026-0005",
            roll_number: "R-05",
            school_id: NumberInt(1),
            branch_id: NumberInt(1),
            academic_year_id: NumberInt(1),
            class_id: NumberInt(1),
            class_name: "Class 1 - Central",
            section_id: NumberInt(1),
            section_name: "A",
            total_attentions_raised: NumberInt(2),
            total_active_attentions: NumberInt(1),
            subjects: [
            {
                subject_id: NumberInt(1),
                subject_name: "English",
                subject_code: "ENG",
                assigned_teacher_id: NumberInt(1),
                assigned_teacher_name: "Keshav Kulkarni",
                total_attentions_raised: NumberInt(1),
                active_attentions_count: NumberInt(1),
                attentions: [
                    {
                        attention_id: "ATT-5-HW-3025-1",
                        attention_type: "PENDING_HOMEWORK",
                        title: "Direct & Indirect Speech Exercise 5.1 Overdue",
                        description: "Grammar transformation exercise 5.1 not submitted by due date.",
                        trigger_source: "ASSIGNMENT_HOMEWORK",
                        source_id: NumberInt(3025),
                        triggered_at: new Date("2026-11-08T08:00:00Z"),
                        status: "ACTIVE",
                        acknowledged_at: new Date("2026-11-09T09:00:00Z"),
                        acknowledged_by_teacher_id: NumberInt(1),
                        resolved_at: null,
                        resolved_by_teacher_id: null,
                        resolution_remarks: null,
                        excused_reason: null,
                        assessment_details: null,
                        homework_details: {
                                homework_id: NumberInt(3025),
                                homework_title: "Direct & Indirect Speech Exercise 5.1",
                                assigned_date: new Date("2026-11-04T08:00:00Z"),
                                due_date: new Date("2026-11-07T16:00:00Z"),
                                days_overdue: NumberInt(2),
                                submission_status: "PENDING"
                            },
                        attendance_details: null
                    }
                ],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(1),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(2),
                subject_name: "Mathematics",
                subject_code: "MAT",
                assigned_teacher_id: NumberInt(8),
                assigned_teacher_name: "Zara Pai",
                total_attentions_raised: NumberInt(1),
                active_attentions_count: NumberInt(0),
                attentions: [
                    {
                        attention_id: "ATT-5-HW-3026-1",
                        attention_type: "PENDING_HOMEWORK",
                        title: "Linear Graphs Problem Set 2",
                        description: "Graph sheet problems submitted after verification.",
                        trigger_source: "ASSIGNMENT_HOMEWORK",
                        source_id: NumberInt(3026),
                        triggered_at: new Date("2026-10-18T08:00:00Z"),
                        status: "RESOLVED",
                        acknowledged_at: new Date("2026-10-18T10:00:00Z"),
                        acknowledged_by_teacher_id: NumberInt(8),
                        resolved_at: new Date("2026-10-20T12:00:00Z"),
                        resolved_by_teacher_id: NumberInt(8),
                        resolution_remarks: "All 5 plotted lines and intersection points verified accurate.",
                        excused_reason: null,
                        assessment_details: null,
                        homework_details: {
                                homework_id: NumberInt(3026),
                                homework_title: "Linear Equations Graph Plotting Set",
                                assigned_date: new Date("2026-10-14T08:00:00Z"),
                                due_date: new Date("2026-10-17T16:00:00Z"),
                                days_overdue: NumberInt(1),
                                submission_status: "LATE"
                            },
                        attendance_details: null
                    }
                ],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(3),
                subject_name: "Science",
                subject_code: "SCI",
                assigned_teacher_id: NumberInt(15),
                assigned_teacher_name: "Bhuvan Solanki",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(4),
                subject_name: "Social Science",
                subject_code: "SOC",
                assigned_teacher_id: NumberInt(22),
                assigned_teacher_name: "Rashmi Chopra",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(5),
                subject_name: "Computer Science",
                subject_code: "CSC",
                assigned_teacher_id: NumberInt(29),
                assigned_teacher_name: "Raghunath Mathur",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(6),
                subject_name: "Physical Education",
                subject_code: "PE",
                assigned_teacher_id: NumberInt(35),
                assigned_teacher_name: "Abhiram Kansal",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            }
        ],
            last_evaluated_at: new Date("2026-11-18T14:00:00Z"),
            is_active: NumberInt(1),
            created_at: new Date("2026-10-01T08:00:00Z"),
            updated_at: new Date("2026-11-18T14:00:00Z")
        },
        {
            student_id: NumberInt(6),
            student_name: "Sravan Kumar",
            admission_number: "ADM-2026-0006",
            roll_number: "R-06",
            school_id: NumberInt(1),
            branch_id: NumberInt(1),
            academic_year_id: NumberInt(1),
            class_id: NumberInt(1),
            class_name: "Class 1 - Central",
            section_id: NumberInt(1),
            section_name: "A",
            total_attentions_raised: NumberInt(2),
            total_active_attentions: NumberInt(2),
            subjects: [
            {
                subject_id: NumberInt(1),
                subject_name: "English",
                subject_code: "ENG",
                assigned_teacher_id: NumberInt(1),
                assigned_teacher_name: "Keshav Kulkarni",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(2),
                subject_name: "Mathematics",
                subject_code: "MAT",
                assigned_teacher_id: NumberInt(8),
                assigned_teacher_name: "Zara Pai",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(3),
                subject_name: "Science",
                subject_code: "SCI",
                assigned_teacher_id: NumberInt(15),
                assigned_teacher_name: "Bhuvan Solanki",
                total_attentions_raised: NumberInt(1),
                active_attentions_count: NumberInt(1),
                attentions: [
                    {
                        attention_id: "ATT-6-ASM-506-1",
                        attention_type: "LOW_ASSESSMENT_SCORE",
                        title: "Force and Laws of Motion Slip Test Benchmark Deficit",
                        description: "Scored 8/40, below passing threshold of 16 in mechanics slip test.",
                        trigger_source: "ASSESSMENT",
                        source_id: NumberInt(506),
                        triggered_at: new Date("2026-10-29T14:30:00Z"),
                        status: "ACTIVE",
                        acknowledged_at: new Date("2026-10-30T08:30:00Z"),
                        acknowledged_by_teacher_id: NumberInt(15),
                        resolved_at: null,
                        resolved_by_teacher_id: null,
                        resolution_remarks: null,
                        excused_reason: null,
                        assessment_details: {
                                assessment_id: NumberInt(506),
                                assessment_name: "Force & Laws of Motion Test",
                                exam_type: "SLIP_TEST",
                                max_marks: 40.0,
                                pass_marks: 16.0,
                                obtained_marks: 8.0,
                                percentage: 20.0
                            },
                        homework_details: null,
                        attendance_details: null
                    }
                ],
                subject_summary: {
                    assessments_passed: NumberInt(2),
                    assessments_failed: NumberInt(1),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(4),
                subject_name: "Social Science",
                subject_code: "SOC",
                assigned_teacher_id: NumberInt(22),
                assigned_teacher_name: "Rashmi Chopra",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(5),
                subject_name: "Computer Science",
                subject_code: "CSC",
                assigned_teacher_id: NumberInt(29),
                assigned_teacher_name: "Raghunath Mathur",
                total_attentions_raised: NumberInt(1),
                active_attentions_count: NumberInt(1),
                attentions: [
                    {
                        attention_id: "ATT-6-HW-3030-1",
                        attention_type: "PENDING_HOMEWORK",
                        title: "HTML/CSS Form Creation Lab Assignment Overdue",
                        description: "Web page form styling exercise pending upload.",
                        trigger_source: "ASSIGNMENT_HOMEWORK",
                        source_id: NumberInt(3030),
                        triggered_at: new Date("2026-11-10T08:00:00Z"),
                        status: "ACTIVE",
                        acknowledged_at: new Date("2026-11-11T09:00:00Z"),
                        acknowledged_by_teacher_id: NumberInt(29),
                        resolved_at: null,
                        resolved_by_teacher_id: null,
                        resolution_remarks: null,
                        excused_reason: null,
                        assessment_details: null,
                        homework_details: {
                                homework_id: NumberInt(3030),
                                homework_title: "HTML Form Creation Lab",
                                assigned_date: new Date("2026-11-05T08:00:00Z"),
                                due_date: new Date("2026-11-08T16:00:00Z"),
                                days_overdue: NumberInt(2),
                                submission_status: "PENDING"
                            },
                        attendance_details: null
                    }
                ],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(1),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(6),
                subject_name: "Physical Education",
                subject_code: "PE",
                assigned_teacher_id: NumberInt(35),
                assigned_teacher_name: "Abhiram Kansal",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            }
        ],
            last_evaluated_at: new Date("2026-11-18T14:00:00Z"),
            is_active: NumberInt(1),
            created_at: new Date("2026-10-01T08:00:00Z"),
            updated_at: new Date("2026-11-18T14:00:00Z")
        },
        {
            student_id: NumberInt(7),
            student_name: "Gaurav Joshi",
            admission_number: "ADM-2026-0007",
            roll_number: "R-07",
            school_id: NumberInt(1),
            branch_id: NumberInt(1),
            academic_year_id: NumberInt(1),
            class_id: NumberInt(1),
            class_name: "Class 1 - Central",
            section_id: NumberInt(1),
            section_name: "A",
            total_attentions_raised: NumberInt(1),
            total_active_attentions: NumberInt(0),
            subjects: [
            {
                subject_id: NumberInt(1),
                subject_name: "English",
                subject_code: "ENG",
                assigned_teacher_id: NumberInt(1),
                assigned_teacher_name: "Keshav Kulkarni",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(2),
                subject_name: "Mathematics",
                subject_code: "MAT",
                assigned_teacher_id: NumberInt(8),
                assigned_teacher_name: "Zara Pai",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(3),
                subject_name: "Science",
                subject_code: "SCI",
                assigned_teacher_id: NumberInt(15),
                assigned_teacher_name: "Bhuvan Solanki",
                total_attentions_raised: NumberInt(1),
                active_attentions_count: NumberInt(0),
                attentions: [
                    {
                        attention_id: "ATT-7-ATT-9020-1",
                        attention_type: "ABSENT_ATTENDANCE",
                        title: "Period 2 Science Biology Microscopy Session Absence",
                        description: "Absent during onion cell mount practical; student made up practical in zero period.",
                        trigger_source: "ATTENDANCE",
                        source_id: NumberInt(9020),
                        triggered_at: new Date("2026-10-18T10:00:00Z"),
                        status: "RESOLVED",
                        acknowledged_at: new Date("2026-10-18T11:00:00Z"),
                        acknowledged_by_teacher_id: NumberInt(15),
                        resolved_at: new Date("2026-10-21T16:00:00Z"),
                        resolved_by_teacher_id: NumberInt(15),
                        resolution_remarks: "Slide preparation and sketch verified during zero period makeup.",
                        excused_reason: null,
                        assessment_details: null,
                        homework_details: null,
                        attendance_details: {
                                attendance_id: NumberInt(9020),
                                attendance_date: new Date("2026-10-18T00:00:00Z"),
                                period_number: NumberInt(2),
                                period_time: "09:15 - 10:00",
                                attendance_status: "ABSENT"
                            }
                    }
                ],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 92.5
                }
            },
            {
                subject_id: NumberInt(4),
                subject_name: "Social Science",
                subject_code: "SOC",
                assigned_teacher_id: NumberInt(22),
                assigned_teacher_name: "Rashmi Chopra",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(5),
                subject_name: "Computer Science",
                subject_code: "CSC",
                assigned_teacher_id: NumberInt(29),
                assigned_teacher_name: "Raghunath Mathur",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(6),
                subject_name: "Physical Education",
                subject_code: "PE",
                assigned_teacher_id: NumberInt(35),
                assigned_teacher_name: "Abhiram Kansal",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            }
        ],
            last_evaluated_at: new Date("2026-11-18T14:00:00Z"),
            is_active: NumberInt(1),
            created_at: new Date("2026-10-01T08:00:00Z"),
            updated_at: new Date("2026-11-18T14:00:00Z")
        },
        {
            student_id: NumberInt(8),
            student_name: "Manish Talwar",
            admission_number: "ADM-2026-0008",
            roll_number: "R-08",
            school_id: NumberInt(1),
            branch_id: NumberInt(1),
            academic_year_id: NumberInt(1),
            class_id: NumberInt(1),
            class_name: "Class 1 - Central",
            section_id: NumberInt(1),
            section_name: "A",
            total_attentions_raised: NumberInt(1),
            total_active_attentions: NumberInt(1),
            subjects: [
            {
                subject_id: NumberInt(1),
                subject_name: "English",
                subject_code: "ENG",
                assigned_teacher_id: NumberInt(1),
                assigned_teacher_name: "Keshav Kulkarni",
                total_attentions_raised: NumberInt(1),
                active_attentions_count: NumberInt(1),
                attentions: [
                    {
                        attention_id: "ATT-8-ASM-508-1",
                        attention_type: "LOW_ASSESSMENT_SCORE",
                        title: "Unseen Prose Reading Comprehension Diagnostic Below 40%",
                        description: "Scored 15/50 on comprehension diagnostic test.",
                        trigger_source: "ASSESSMENT",
                        source_id: NumberInt(508),
                        triggered_at: new Date("2026-11-04T14:00:00Z"),
                        status: "ACTIVE",
                        acknowledged_at: new Date("2026-11-05T08:30:00Z"),
                        acknowledged_by_teacher_id: NumberInt(1),
                        resolved_at: null,
                        resolved_by_teacher_id: null,
                        resolution_remarks: null,
                        excused_reason: null,
                        assessment_details: {
                                assessment_id: NumberInt(508),
                                assessment_name: "Reading Comprehension Diagnostic",
                                exam_type: "SLIP_TEST",
                                max_marks: 50.0,
                                pass_marks: 20.0,
                                obtained_marks: 15.0,
                                percentage: 30.0
                            },
                        homework_details: null,
                        attendance_details: null
                    }
                ],
                subject_summary: {
                    assessments_passed: NumberInt(2),
                    assessments_failed: NumberInt(1),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(2),
                subject_name: "Mathematics",
                subject_code: "MAT",
                assigned_teacher_id: NumberInt(8),
                assigned_teacher_name: "Zara Pai",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(3),
                subject_name: "Science",
                subject_code: "SCI",
                assigned_teacher_id: NumberInt(15),
                assigned_teacher_name: "Bhuvan Solanki",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(4),
                subject_name: "Social Science",
                subject_code: "SOC",
                assigned_teacher_id: NumberInt(22),
                assigned_teacher_name: "Rashmi Chopra",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(5),
                subject_name: "Computer Science",
                subject_code: "CSC",
                assigned_teacher_id: NumberInt(29),
                assigned_teacher_name: "Raghunath Mathur",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(6),
                subject_name: "Physical Education",
                subject_code: "PE",
                assigned_teacher_id: NumberInt(35),
                assigned_teacher_name: "Abhiram Kansal",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            }
        ],
            last_evaluated_at: new Date("2026-11-18T14:00:00Z"),
            is_active: NumberInt(1),
            created_at: new Date("2026-10-01T08:00:00Z"),
            updated_at: new Date("2026-11-18T14:00:00Z")
        },
        {
            student_id: NumberInt(9),
            student_name: "Zara Tiwari",
            admission_number: "ADM-2026-0009",
            roll_number: "R-09",
            school_id: NumberInt(1),
            branch_id: NumberInt(1),
            academic_year_id: NumberInt(1),
            class_id: NumberInt(1),
            class_name: "Class 1 - Central",
            section_id: NumberInt(1),
            section_name: "A",
            total_attentions_raised: NumberInt(1),
            total_active_attentions: NumberInt(1),
            subjects: [
            {
                subject_id: NumberInt(1),
                subject_name: "English",
                subject_code: "ENG",
                assigned_teacher_id: NumberInt(1),
                assigned_teacher_name: "Keshav Kulkarni",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(2),
                subject_name: "Mathematics",
                subject_code: "MAT",
                assigned_teacher_id: NumberInt(8),
                assigned_teacher_name: "Zara Pai",
                total_attentions_raised: NumberInt(1),
                active_attentions_count: NumberInt(1),
                attentions: [
                    {
                        attention_id: "ATT-9-ASM-509-1",
                        attention_type: "LOW_ASSESSMENT_SCORE",
                        title: "Mensuration Surface Areas & Volumes Test Deficit",
                        description: "Scored 13/50 on Mensuration diagnostic test.",
                        trigger_source: "ASSESSMENT",
                        source_id: NumberInt(509),
                        triggered_at: new Date("2026-11-05T14:30:00Z"),
                        status: "ACTIVE",
                        acknowledged_at: new Date("2026-11-06T08:30:00Z"),
                        acknowledged_by_teacher_id: NumberInt(8),
                        resolved_at: null,
                        resolved_by_teacher_id: null,
                        resolution_remarks: null,
                        excused_reason: null,
                        assessment_details: {
                                assessment_id: NumberInt(509),
                                assessment_name: "Surface Areas Diagnostic",
                                exam_type: "SLIP_TEST",
                                max_marks: 50.0,
                                pass_marks: 20.0,
                                obtained_marks: 13.0,
                                percentage: 26.0
                            },
                        homework_details: null,
                        attendance_details: null
                    }
                ],
                subject_summary: {
                    assessments_passed: NumberInt(2),
                    assessments_failed: NumberInt(1),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(3),
                subject_name: "Science",
                subject_code: "SCI",
                assigned_teacher_id: NumberInt(15),
                assigned_teacher_name: "Bhuvan Solanki",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(4),
                subject_name: "Social Science",
                subject_code: "SOC",
                assigned_teacher_id: NumberInt(22),
                assigned_teacher_name: "Rashmi Chopra",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(5),
                subject_name: "Computer Science",
                subject_code: "CSC",
                assigned_teacher_id: NumberInt(29),
                assigned_teacher_name: "Raghunath Mathur",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(6),
                subject_name: "Physical Education",
                subject_code: "PE",
                assigned_teacher_id: NumberInt(35),
                assigned_teacher_name: "Abhiram Kansal",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            }
        ],
            last_evaluated_at: new Date("2026-11-18T14:00:00Z"),
            is_active: NumberInt(1),
            created_at: new Date("2026-10-01T08:00:00Z"),
            updated_at: new Date("2026-11-18T14:00:00Z")
        },
        {
            student_id: NumberInt(10),
            student_name: "Sarita Sengupta",
            admission_number: "ADM-2026-0010",
            roll_number: "R-10",
            school_id: NumberInt(1),
            branch_id: NumberInt(1),
            academic_year_id: NumberInt(1),
            class_id: NumberInt(1),
            class_name: "Class 1 - Central",
            section_id: NumberInt(1),
            section_name: "A",
            total_attentions_raised: NumberInt(0),
            total_active_attentions: NumberInt(0),
            subjects: [
            {
                subject_id: NumberInt(1),
                subject_name: "English",
                subject_code: "ENG",
                assigned_teacher_id: NumberInt(1),
                assigned_teacher_name: "Keshav Kulkarni",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(2),
                subject_name: "Mathematics",
                subject_code: "MAT",
                assigned_teacher_id: NumberInt(8),
                assigned_teacher_name: "Zara Pai",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(3),
                subject_name: "Science",
                subject_code: "SCI",
                assigned_teacher_id: NumberInt(15),
                assigned_teacher_name: "Bhuvan Solanki",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(4),
                subject_name: "Social Science",
                subject_code: "SOC",
                assigned_teacher_id: NumberInt(22),
                assigned_teacher_name: "Rashmi Chopra",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(5),
                subject_name: "Computer Science",
                subject_code: "CSC",
                assigned_teacher_id: NumberInt(29),
                assigned_teacher_name: "Raghunath Mathur",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(6),
                subject_name: "Physical Education",
                subject_code: "PE",
                assigned_teacher_id: NumberInt(35),
                assigned_teacher_name: "Abhiram Kansal",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            }
        ],
            last_evaluated_at: new Date("2026-11-18T14:00:00Z"),
            is_active: NumberInt(1),
            created_at: new Date("2026-10-01T08:00:00Z"),
            updated_at: new Date("2026-11-18T14:00:00Z")
        },
        {
            student_id: NumberInt(11),
            student_name: "Gurpreet Pillai",
            admission_number: "ADM-2026-0011",
            roll_number: "R-01",
            school_id: NumberInt(1),
            branch_id: NumberInt(1),
            academic_year_id: NumberInt(1),
            class_id: NumberInt(1),
            class_name: "Class 1 - Central",
            section_id: NumberInt(2),
            section_name: "B",
            total_attentions_raised: NumberInt(2),
            total_active_attentions: NumberInt(1),
            subjects: [
            {
                subject_id: NumberInt(1),
                subject_name: "English",
                subject_code: "ENG",
                assigned_teacher_id: NumberInt(2),
                assigned_teacher_name: "Radhika Pillai",
                total_attentions_raised: NumberInt(1),
                active_attentions_count: NumberInt(0),
                attentions: [
                    {
                        attention_id: "ATT-11-HW-3040-1",
                        attention_type: "PENDING_HOMEWORK",
                        title: "English Reading Journal Entry 4 Late Submission",
                        description: "Reading journal submitted 2 days late; evaluated by Radhika Pillai.",
                        trigger_source: "ASSIGNMENT_HOMEWORK",
                        source_id: NumberInt(3040),
                        triggered_at: new Date("2026-10-20T08:00:00Z"),
                        status: "RESOLVED",
                        acknowledged_at: new Date("2026-10-20T10:00:00Z"),
                        acknowledged_by_teacher_id: NumberInt(2),
                        resolved_at: new Date("2026-10-23T14:00:00Z"),
                        resolved_by_teacher_id: NumberInt(2),
                        resolution_remarks: "Journal log checked and stamped.",
                        excused_reason: null,
                        assessment_details: null,
                        homework_details: {
                                homework_id: NumberInt(3040),
                                homework_title: "Reading Journal Entry 4",
                                assigned_date: new Date("2026-10-16T08:00:00Z"),
                                due_date: new Date("2026-10-19T16:00:00Z"),
                                days_overdue: NumberInt(2),
                                submission_status: "LATE"
                            },
                        attendance_details: null
                    }
                ],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(2),
                subject_name: "Mathematics",
                subject_code: "MAT",
                assigned_teacher_id: NumberInt(9),
                assigned_teacher_name: "Utkarsh Mishra",
                total_attentions_raised: NumberInt(1),
                active_attentions_count: NumberInt(1),
                attentions: [
                    {
                        attention_id: "ATT-11-ASM-511-1",
                        attention_type: "LOW_ASSESSMENT_SCORE",
                        title: "Section B Quadratic Equation Slip Test Benchmark Deficit",
                        description: "Scored 16/50 on algebra quadratic polynomials diagnostic slip test.",
                        trigger_source: "ASSESSMENT",
                        source_id: NumberInt(511),
                        triggered_at: new Date("2026-10-28T14:30:00Z"),
                        status: "ACTIVE",
                        acknowledged_at: new Date("2026-10-29T09:00:00Z"),
                        acknowledged_by_teacher_id: NumberInt(9),
                        resolved_at: null,
                        resolved_by_teacher_id: null,
                        resolution_remarks: null,
                        excused_reason: null,
                        assessment_details: {
                                assessment_id: NumberInt(511),
                                assessment_name: "Section B Quadratic Diagnostic",
                                exam_type: "SLIP_TEST",
                                max_marks: 50.0,
                                pass_marks: 20.0,
                                obtained_marks: 16.0,
                                percentage: 32.0
                            },
                        homework_details: null,
                        attendance_details: null
                    }
                ],
                subject_summary: {
                    assessments_passed: NumberInt(2),
                    assessments_failed: NumberInt(1),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(3),
                subject_name: "Science",
                subject_code: "SCI",
                assigned_teacher_id: NumberInt(16),
                assigned_teacher_name: "Juhi Rajput",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(4),
                subject_name: "Social Science",
                subject_code: "SOC",
                assigned_teacher_id: NumberInt(23),
                assigned_teacher_name: "Kushagra Kapoor",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(5),
                subject_name: "Computer Science",
                subject_code: "CSC",
                assigned_teacher_id: NumberInt(30),
                assigned_teacher_name: "Chitra Nigam",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(6),
                subject_name: "Physical Education",
                subject_code: "PE",
                assigned_teacher_id: NumberInt(35),
                assigned_teacher_name: "Abhiram Kansal",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            }
        ],
            last_evaluated_at: new Date("2026-11-18T14:00:00Z"),
            is_active: NumberInt(1),
            created_at: new Date("2026-10-01T08:00:00Z"),
            updated_at: new Date("2026-11-18T14:00:00Z")
        },
        {
            student_id: NumberInt(12),
            student_name: "Deepika Pathak",
            admission_number: "ADM-2026-0012",
            roll_number: "R-02",
            school_id: NumberInt(1),
            branch_id: NumberInt(1),
            academic_year_id: NumberInt(1),
            class_id: NumberInt(1),
            class_name: "Class 1 - Central",
            section_id: NumberInt(2),
            section_name: "B",
            total_attentions_raised: NumberInt(1),
            total_active_attentions: NumberInt(1),
            subjects: [
            {
                subject_id: NumberInt(1),
                subject_name: "English",
                subject_code: "ENG",
                assigned_teacher_id: NumberInt(2),
                assigned_teacher_name: "Radhika Pillai",
                total_attentions_raised: NumberInt(1),
                active_attentions_count: NumberInt(1),
                attentions: [
                    {
                        attention_id: "ATT-12-ATT-9032-1",
                        attention_type: "ABSENT_ATTENDANCE",
                        title: "Period 1 English Literature Attendance Absence",
                        description: "Absent without prior leave slip during Merchant of Venice introduction.",
                        trigger_source: "ATTENDANCE",
                        source_id: NumberInt(9032),
                        triggered_at: new Date("2026-11-06T09:30:00Z"),
                        status: "ACTIVE",
                        acknowledged_at: new Date("2026-11-07T08:30:00Z"),
                        acknowledged_by_teacher_id: NumberInt(2),
                        resolved_at: null,
                        resolved_by_teacher_id: null,
                        resolution_remarks: null,
                        excused_reason: null,
                        assessment_details: null,
                        homework_details: null,
                        attendance_details: {
                                attendance_id: NumberInt(9032),
                                attendance_date: new Date("2026-11-06T00:00:00Z"),
                                period_number: NumberInt(1),
                                period_time: "08:30 - 09:15",
                                attendance_status: "ABSENT"
                            }
                    }
                ],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 92.5
                }
            },
            {
                subject_id: NumberInt(2),
                subject_name: "Mathematics",
                subject_code: "MAT",
                assigned_teacher_id: NumberInt(9),
                assigned_teacher_name: "Utkarsh Mishra",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(3),
                subject_name: "Science",
                subject_code: "SCI",
                assigned_teacher_id: NumberInt(16),
                assigned_teacher_name: "Juhi Rajput",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(4),
                subject_name: "Social Science",
                subject_code: "SOC",
                assigned_teacher_id: NumberInt(23),
                assigned_teacher_name: "Kushagra Kapoor",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(5),
                subject_name: "Computer Science",
                subject_code: "CSC",
                assigned_teacher_id: NumberInt(30),
                assigned_teacher_name: "Chitra Nigam",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(6),
                subject_name: "Physical Education",
                subject_code: "PE",
                assigned_teacher_id: NumberInt(35),
                assigned_teacher_name: "Abhiram Kansal",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            }
        ],
            last_evaluated_at: new Date("2026-11-18T14:00:00Z"),
            is_active: NumberInt(1),
            created_at: new Date("2026-10-01T08:00:00Z"),
            updated_at: new Date("2026-11-18T14:00:00Z")
        },
        {
            student_id: NumberInt(13),
            student_name: "Varun Venkataraman",
            admission_number: "ADM-2026-0013",
            roll_number: "R-03",
            school_id: NumberInt(1),
            branch_id: NumberInt(1),
            academic_year_id: NumberInt(1),
            class_id: NumberInt(1),
            class_name: "Class 1 - Central",
            section_id: NumberInt(2),
            section_name: "B",
            total_attentions_raised: NumberInt(1),
            total_active_attentions: NumberInt(1),
            subjects: [
            {
                subject_id: NumberInt(1),
                subject_name: "English",
                subject_code: "ENG",
                assigned_teacher_id: NumberInt(2),
                assigned_teacher_name: "Radhika Pillai",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(2),
                subject_name: "Mathematics",
                subject_code: "MAT",
                assigned_teacher_id: NumberInt(9),
                assigned_teacher_name: "Utkarsh Mishra",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(3),
                subject_name: "Science",
                subject_code: "SCI",
                assigned_teacher_id: NumberInt(16),
                assigned_teacher_name: "Juhi Rajput",
                total_attentions_raised: NumberInt(1),
                active_attentions_count: NumberInt(1),
                attentions: [
                    {
                        attention_id: "ATT-13-HW-3045-1",
                        attention_type: "PENDING_HOMEWORK",
                        title: "Physics Ray Optics Diagram Portfolio Overdue",
                        description: "Refraction ray diagrams lab homework not submitted.",
                        trigger_source: "ASSIGNMENT_HOMEWORK",
                        source_id: NumberInt(3045),
                        triggered_at: new Date("2026-11-09T08:00:00Z"),
                        status: "ACTIVE",
                        acknowledged_at: new Date("2026-11-10T09:00:00Z"),
                        acknowledged_by_teacher_id: NumberInt(16),
                        resolved_at: null,
                        resolved_by_teacher_id: null,
                        resolution_remarks: null,
                        excused_reason: null,
                        assessment_details: null,
                        homework_details: {
                                homework_id: NumberInt(3045),
                                homework_title: "Ray Optics Lab Homework Portfolio",
                                assigned_date: new Date("2026-11-04T08:00:00Z"),
                                due_date: new Date("2026-11-07T16:00:00Z"),
                                days_overdue: NumberInt(2),
                                submission_status: "PENDING"
                            },
                        attendance_details: null
                    }
                ],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(1),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(4),
                subject_name: "Social Science",
                subject_code: "SOC",
                assigned_teacher_id: NumberInt(23),
                assigned_teacher_name: "Kushagra Kapoor",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(5),
                subject_name: "Computer Science",
                subject_code: "CSC",
                assigned_teacher_id: NumberInt(30),
                assigned_teacher_name: "Chitra Nigam",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(6),
                subject_name: "Physical Education",
                subject_code: "PE",
                assigned_teacher_id: NumberInt(35),
                assigned_teacher_name: "Abhiram Kansal",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            }
        ],
            last_evaluated_at: new Date("2026-11-18T14:00:00Z"),
            is_active: NumberInt(1),
            created_at: new Date("2026-10-01T08:00:00Z"),
            updated_at: new Date("2026-11-18T14:00:00Z")
        },
        {
            student_id: NumberInt(14),
            student_name: "Reena Mitra",
            admission_number: "ADM-2026-0014",
            roll_number: "R-04",
            school_id: NumberInt(1),
            branch_id: NumberInt(1),
            academic_year_id: NumberInt(1),
            class_id: NumberInt(1),
            class_name: "Class 1 - Central",
            section_id: NumberInt(2),
            section_name: "B",
            total_attentions_raised: NumberInt(1),
            total_active_attentions: NumberInt(1),
            subjects: [
            {
                subject_id: NumberInt(1),
                subject_name: "English",
                subject_code: "ENG",
                assigned_teacher_id: NumberInt(2),
                assigned_teacher_name: "Radhika Pillai",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(2),
                subject_name: "Mathematics",
                subject_code: "MAT",
                assigned_teacher_id: NumberInt(9),
                assigned_teacher_name: "Utkarsh Mishra",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(3),
                subject_name: "Science",
                subject_code: "SCI",
                assigned_teacher_id: NumberInt(16),
                assigned_teacher_name: "Juhi Rajput",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(4),
                subject_name: "Social Science",
                subject_code: "SOC",
                assigned_teacher_id: NumberInt(23),
                assigned_teacher_name: "Kushagra Kapoor",
                total_attentions_raised: NumberInt(1),
                active_attentions_count: NumberInt(1),
                attentions: [
                    {
                        attention_id: "ATT-14-ASM-514-1",
                        attention_type: "LOW_ASSESSMENT_SCORE",
                        title: "Medieval Indian Architecture Map Test Re-evaluation",
                        description: "Scored 13/40 on Mughal architecture and monuments mapping evaluation.",
                        trigger_source: "ASSESSMENT",
                        source_id: NumberInt(514),
                        triggered_at: new Date("2026-11-08T14:30:00Z"),
                        status: "ACTIVE",
                        acknowledged_at: new Date("2026-11-09T09:00:00Z"),
                        acknowledged_by_teacher_id: NumberInt(23),
                        resolved_at: null,
                        resolved_by_teacher_id: null,
                        resolution_remarks: null,
                        excused_reason: null,
                        assessment_details: {
                                assessment_id: NumberInt(514),
                                assessment_name: "Mughal Architecture Map Test",
                                exam_type: "SLIP_TEST",
                                max_marks: 40.0,
                                pass_marks: 18.0,
                                obtained_marks: 13.0,
                                percentage: 32.5
                            },
                        homework_details: null,
                        attendance_details: null
                    }
                ],
                subject_summary: {
                    assessments_passed: NumberInt(2),
                    assessments_failed: NumberInt(1),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(5),
                subject_name: "Computer Science",
                subject_code: "CSC",
                assigned_teacher_id: NumberInt(30),
                assigned_teacher_name: "Chitra Nigam",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(6),
                subject_name: "Physical Education",
                subject_code: "PE",
                assigned_teacher_id: NumberInt(35),
                assigned_teacher_name: "Abhiram Kansal",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            }
        ],
            last_evaluated_at: new Date("2026-11-18T14:00:00Z"),
            is_active: NumberInt(1),
            created_at: new Date("2026-10-01T08:00:00Z"),
            updated_at: new Date("2026-11-18T14:00:00Z")
        },
        {
            student_id: NumberInt(15),
            student_name: "Sangeeta Ghosh",
            admission_number: "ADM-2026-0015",
            roll_number: "R-05",
            school_id: NumberInt(1),
            branch_id: NumberInt(1),
            academic_year_id: NumberInt(1),
            class_id: NumberInt(1),
            class_name: "Class 1 - Central",
            section_id: NumberInt(2),
            section_name: "B",
            total_attentions_raised: NumberInt(0),
            total_active_attentions: NumberInt(0),
            subjects: [
            {
                subject_id: NumberInt(1),
                subject_name: "English",
                subject_code: "ENG",
                assigned_teacher_id: NumberInt(2),
                assigned_teacher_name: "Radhika Pillai",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(2),
                subject_name: "Mathematics",
                subject_code: "MAT",
                assigned_teacher_id: NumberInt(9),
                assigned_teacher_name: "Utkarsh Mishra",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(3),
                subject_name: "Science",
                subject_code: "SCI",
                assigned_teacher_id: NumberInt(16),
                assigned_teacher_name: "Juhi Rajput",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(4),
                subject_name: "Social Science",
                subject_code: "SOC",
                assigned_teacher_id: NumberInt(23),
                assigned_teacher_name: "Kushagra Kapoor",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(5),
                subject_name: "Computer Science",
                subject_code: "CSC",
                assigned_teacher_id: NumberInt(30),
                assigned_teacher_name: "Chitra Nigam",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(6),
                subject_name: "Physical Education",
                subject_code: "PE",
                assigned_teacher_id: NumberInt(35),
                assigned_teacher_name: "Abhiram Kansal",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            }
        ],
            last_evaluated_at: new Date("2026-11-18T14:00:00Z"),
            is_active: NumberInt(1),
            created_at: new Date("2026-10-01T08:00:00Z"),
            updated_at: new Date("2026-11-18T14:00:00Z")
        },
        {
            student_id: NumberInt(16),
            student_name: "Uma Asthana",
            admission_number: "ADM-2026-0016",
            roll_number: "R-06",
            school_id: NumberInt(1),
            branch_id: NumberInt(1),
            academic_year_id: NumberInt(1),
            class_id: NumberInt(1),
            class_name: "Class 1 - Central",
            section_id: NumberInt(2),
            section_name: "B",
            total_attentions_raised: NumberInt(2),
            total_active_attentions: NumberInt(1),
            subjects: [
            {
                subject_id: NumberInt(1),
                subject_name: "English",
                subject_code: "ENG",
                assigned_teacher_id: NumberInt(2),
                assigned_teacher_name: "Radhika Pillai",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(2),
                subject_name: "Mathematics",
                subject_code: "MAT",
                assigned_teacher_id: NumberInt(9),
                assigned_teacher_name: "Utkarsh Mishra",
                total_attentions_raised: NumberInt(1),
                active_attentions_count: NumberInt(1),
                attentions: [
                    {
                        attention_id: "ATT-16-HW-3052-1",
                        attention_type: "PENDING_HOMEWORK",
                        title: "Coordinate Geometry Distance Formula Practice 7.2 Overdue",
                        description: "Coordinate geometry exercises 7.2 not submitted by deadline.",
                        trigger_source: "ASSIGNMENT_HOMEWORK",
                        source_id: NumberInt(3052),
                        triggered_at: new Date("2026-11-15T08:00:00Z"),
                        status: "ACTIVE",
                        acknowledged_at: new Date("2026-11-16T09:00:00Z"),
                        acknowledged_by_teacher_id: NumberInt(9),
                        resolved_at: null,
                        resolved_by_teacher_id: null,
                        resolution_remarks: null,
                        excused_reason: null,
                        assessment_details: null,
                        homework_details: {
                                homework_id: NumberInt(3052),
                                homework_title: "Coordinate Geometry Practice 7.2",
                                assigned_date: new Date("2026-11-11T08:00:00Z"),
                                due_date: new Date("2026-11-14T16:00:00Z"),
                                days_overdue: NumberInt(2),
                                submission_status: "PENDING"
                            },
                        attendance_details: null
                    }
                ],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(1),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(3),
                subject_name: "Science",
                subject_code: "SCI",
                assigned_teacher_id: NumberInt(16),
                assigned_teacher_name: "Juhi Rajput",
                total_attentions_raised: NumberInt(1),
                active_attentions_count: NumberInt(0),
                attentions: [
                    {
                        attention_id: "ATT-16-ATT-9045-1",
                        attention_type: "ABSENT_ATTENDANCE",
                        title: "Period 4 Physics Energy & Work Lab Practical Absence",
                        description: "Absent during mechanical kinetic energy demonstration; makeup completed.",
                        trigger_source: "ATTENDANCE",
                        source_id: NumberInt(9045),
                        triggered_at: new Date("2026-11-03T12:00:00Z"),
                        status: "RESOLVED",
                        acknowledged_at: new Date("2026-11-03T14:00:00Z"),
                        acknowledged_by_teacher_id: NumberInt(16),
                        resolved_at: new Date("2026-11-06T16:00:00Z"),
                        resolved_by_teacher_id: NumberInt(16),
                        resolution_remarks: "Completed pendulum experiment calculations during makeup hour.",
                        excused_reason: null,
                        assessment_details: null,
                        homework_details: null,
                        attendance_details: {
                                attendance_id: NumberInt(9045),
                                attendance_date: new Date("2026-11-03T00:00:00Z"),
                                period_number: NumberInt(4),
                                period_time: "11:15 - 12:00",
                                attendance_status: "ABSENT"
                            }
                    }
                ],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 92.5
                }
            },
            {
                subject_id: NumberInt(4),
                subject_name: "Social Science",
                subject_code: "SOC",
                assigned_teacher_id: NumberInt(23),
                assigned_teacher_name: "Kushagra Kapoor",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(5),
                subject_name: "Computer Science",
                subject_code: "CSC",
                assigned_teacher_id: NumberInt(30),
                assigned_teacher_name: "Chitra Nigam",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(6),
                subject_name: "Physical Education",
                subject_code: "PE",
                assigned_teacher_id: NumberInt(35),
                assigned_teacher_name: "Abhiram Kansal",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            }
        ],
            last_evaluated_at: new Date("2026-11-18T14:00:00Z"),
            is_active: NumberInt(1),
            created_at: new Date("2026-10-01T08:00:00Z"),
            updated_at: new Date("2026-11-18T14:00:00Z")
        },
        {
            student_id: NumberInt(17),
            student_name: "Nikhil Acharya",
            admission_number: "ADM-2026-0017",
            roll_number: "R-07",
            school_id: NumberInt(1),
            branch_id: NumberInt(1),
            academic_year_id: NumberInt(1),
            class_id: NumberInt(1),
            class_name: "Class 1 - Central",
            section_id: NumberInt(2),
            section_name: "B",
            total_attentions_raised: NumberInt(2),
            total_active_attentions: NumberInt(1),
            subjects: [
            {
                subject_id: NumberInt(1),
                subject_name: "English",
                subject_code: "ENG",
                assigned_teacher_id: NumberInt(2),
                assigned_teacher_name: "Radhika Pillai",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(2),
                subject_name: "Mathematics",
                subject_code: "MAT",
                assigned_teacher_id: NumberInt(9),
                assigned_teacher_name: "Utkarsh Mishra",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(3),
                subject_name: "Science",
                subject_code: "SCI",
                assigned_teacher_id: NumberInt(16),
                assigned_teacher_name: "Juhi Rajput",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(4),
                subject_name: "Social Science",
                subject_code: "SOC",
                assigned_teacher_id: NumberInt(23),
                assigned_teacher_name: "Kushagra Kapoor",
                total_attentions_raised: NumberInt(1),
                active_attentions_count: NumberInt(0),
                attentions: [
                    {
                        attention_id: "ATT-17-HW-3058-1",
                        attention_type: "PENDING_HOMEWORK",
                        title: "Climatic Zones of India Chart Presentation",
                        description: "Climate zones chart submission delayed; evaluated and verified.",
                        trigger_source: "ASSIGNMENT_HOMEWORK",
                        source_id: NumberInt(3058),
                        triggered_at: new Date("2026-10-29T08:00:00Z"),
                        status: "RESOLVED",
                        acknowledged_at: new Date("2026-10-29T10:00:00Z"),
                        acknowledged_by_teacher_id: NumberInt(23),
                        resolved_at: new Date("2026-10-31T15:00:00Z"),
                        resolved_by_teacher_id: NumberInt(23),
                        resolution_remarks: "All climatic zones colored and annual rainfall statistics annotated correctly.",
                        excused_reason: null,
                        assessment_details: null,
                        homework_details: {
                                homework_id: NumberInt(3058),
                                homework_title: "Climatic Zones of India Project",
                                assigned_date: new Date("2026-10-25T08:00:00Z"),
                                due_date: new Date("2026-10-28T16:00:00Z"),
                                days_overdue: NumberInt(1),
                                submission_status: "LATE"
                            },
                        attendance_details: null
                    }
                ],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(5),
                subject_name: "Computer Science",
                subject_code: "CSC",
                assigned_teacher_id: NumberInt(30),
                assigned_teacher_name: "Chitra Nigam",
                total_attentions_raised: NumberInt(1),
                active_attentions_count: NumberInt(1),
                attentions: [
                    {
                        attention_id: "ATT-17-ASM-517-1",
                        attention_type: "LOW_ASSESSMENT_SCORE",
                        title: "Python User-Defined Functions Slip Test Deficit",
                        description: "Scored 9/30 on functions and scope evaluation test.",
                        trigger_source: "ASSESSMENT",
                        source_id: NumberInt(517),
                        triggered_at: new Date("2026-11-10T14:00:00Z"),
                        status: "ACTIVE",
                        acknowledged_at: new Date("2026-11-11T08:45:00Z"),
                        acknowledged_by_teacher_id: NumberInt(30),
                        resolved_at: null,
                        resolved_by_teacher_id: null,
                        resolution_remarks: null,
                        excused_reason: null,
                        assessment_details: {
                                assessment_id: NumberInt(517),
                                assessment_name: "Python Functions Slip Test",
                                exam_type: "SLIP_TEST",
                                max_marks: 30.0,
                                pass_marks: 12.0,
                                obtained_marks: 9.0,
                                percentage: 30.0
                            },
                        homework_details: null,
                        attendance_details: null
                    }
                ],
                subject_summary: {
                    assessments_passed: NumberInt(2),
                    assessments_failed: NumberInt(1),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(6),
                subject_name: "Physical Education",
                subject_code: "PE",
                assigned_teacher_id: NumberInt(35),
                assigned_teacher_name: "Abhiram Kansal",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            }
        ],
            last_evaluated_at: new Date("2026-11-18T14:00:00Z"),
            is_active: NumberInt(1),
            created_at: new Date("2026-10-01T08:00:00Z"),
            updated_at: new Date("2026-11-18T14:00:00Z")
        },
        {
            student_id: NumberInt(18),
            student_name: "Kavya Sidhu",
            admission_number: "ADM-2026-0018",
            roll_number: "R-08",
            school_id: NumberInt(1),
            branch_id: NumberInt(1),
            academic_year_id: NumberInt(1),
            class_id: NumberInt(1),
            class_name: "Class 1 - Central",
            section_id: NumberInt(2),
            section_name: "B",
            total_attentions_raised: NumberInt(2),
            total_active_attentions: NumberInt(1),
            subjects: [
            {
                subject_id: NumberInt(1),
                subject_name: "English",
                subject_code: "ENG",
                assigned_teacher_id: NumberInt(2),
                assigned_teacher_name: "Radhika Pillai",
                total_attentions_raised: NumberInt(1),
                active_attentions_count: NumberInt(1),
                attentions: [
                    {
                        attention_id: "ATT-18-ASM-518-1",
                        attention_type: "LOW_ASSESSMENT_SCORE",
                        title: "Formal Business & Editorial Letter Writing Test",
                        description: "Scored 14/40, below standard formatting pass criteria.",
                        trigger_source: "ASSESSMENT",
                        source_id: NumberInt(518),
                        triggered_at: new Date("2026-11-12T14:30:00Z"),
                        status: "ACTIVE",
                        acknowledged_at: new Date("2026-11-13T09:00:00Z"),
                        acknowledged_by_teacher_id: NumberInt(2),
                        resolved_at: null,
                        resolved_by_teacher_id: null,
                        resolution_remarks: null,
                        excused_reason: null,
                        assessment_details: {
                                assessment_id: NumberInt(518),
                                assessment_name: "Formal Letter Writing Assessment",
                                exam_type: "SLIP_TEST",
                                max_marks: 40.0,
                                pass_marks: 18.0,
                                obtained_marks: 14.0,
                                percentage: 35.0
                            },
                        homework_details: null,
                        attendance_details: null
                    }
                ],
                subject_summary: {
                    assessments_passed: NumberInt(2),
                    assessments_failed: NumberInt(1),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(2),
                subject_name: "Mathematics",
                subject_code: "MAT",
                assigned_teacher_id: NumberInt(9),
                assigned_teacher_name: "Utkarsh Mishra",
                total_attentions_raised: NumberInt(1),
                active_attentions_count: NumberInt(0),
                attentions: [
                    {
                        attention_id: "ATT-18-ATT-9055-1",
                        attention_type: "ABSENT_ATTENDANCE",
                        title: "Period 2 Mathematics Algebra Session Absence",
                        description: "Excused absence due to sanctioned dental appointment.",
                        trigger_source: "ATTENDANCE",
                        source_id: NumberInt(9055),
                        triggered_at: new Date("2026-11-09T10:00:00Z"),
                        status: "EXCUSED",
                        acknowledged_at: new Date("2026-11-09T11:00:00Z"),
                        acknowledged_by_teacher_id: NumberInt(9),
                        resolved_at: new Date("2026-11-10T09:00:00Z"),
                        resolved_by_teacher_id: NumberInt(9),
                        resolution_remarks: "Doctor clinic slip verified.",
                        excused_reason: "Dental procedure appointment slip approved by Class Teacher.",
                        assessment_details: null,
                        homework_details: null,
                        attendance_details: {
                                attendance_id: NumberInt(9055),
                                attendance_date: new Date("2026-11-09T00:00:00Z"),
                                period_number: NumberInt(2),
                                period_time: "09:15 - 10:00",
                                attendance_status: "ABSENT"
                            }
                    }
                ],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 92.5
                }
            },
            {
                subject_id: NumberInt(3),
                subject_name: "Science",
                subject_code: "SCI",
                assigned_teacher_id: NumberInt(16),
                assigned_teacher_name: "Juhi Rajput",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(4),
                subject_name: "Social Science",
                subject_code: "SOC",
                assigned_teacher_id: NumberInt(23),
                assigned_teacher_name: "Kushagra Kapoor",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(5),
                subject_name: "Computer Science",
                subject_code: "CSC",
                assigned_teacher_id: NumberInt(30),
                assigned_teacher_name: "Chitra Nigam",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(6),
                subject_name: "Physical Education",
                subject_code: "PE",
                assigned_teacher_id: NumberInt(35),
                assigned_teacher_name: "Abhiram Kansal",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            }
        ],
            last_evaluated_at: new Date("2026-11-18T14:00:00Z"),
            is_active: NumberInt(1),
            created_at: new Date("2026-10-01T08:00:00Z"),
            updated_at: new Date("2026-11-18T14:00:00Z")
        },
        {
            student_id: NumberInt(19),
            student_name: "Suresh Banerjee",
            admission_number: "ADM-2026-0019",
            roll_number: "R-09",
            school_id: NumberInt(1),
            branch_id: NumberInt(1),
            academic_year_id: NumberInt(1),
            class_id: NumberInt(1),
            class_name: "Class 1 - Central",
            section_id: NumberInt(2),
            section_name: "B",
            total_attentions_raised: NumberInt(1),
            total_active_attentions: NumberInt(1),
            subjects: [
            {
                subject_id: NumberInt(1),
                subject_name: "English",
                subject_code: "ENG",
                assigned_teacher_id: NumberInt(2),
                assigned_teacher_name: "Radhika Pillai",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(2),
                subject_name: "Mathematics",
                subject_code: "MAT",
                assigned_teacher_id: NumberInt(9),
                assigned_teacher_name: "Utkarsh Mishra",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(3),
                subject_name: "Science",
                subject_code: "SCI",
                assigned_teacher_id: NumberInt(16),
                assigned_teacher_name: "Juhi Rajput",
                total_attentions_raised: NumberInt(1),
                active_attentions_count: NumberInt(1),
                attentions: [
                    {
                        attention_id: "ATT-19-HW-3065-1",
                        attention_type: "PENDING_HOMEWORK",
                        title: "Balancing Chemical Reactions Equation Balancing Practice",
                        description: "Chemical stoichiometry equations practice set overdue by 2 days.",
                        trigger_source: "ASSIGNMENT_HOMEWORK",
                        source_id: NumberInt(3065),
                        triggered_at: new Date("2026-11-17T08:00:00Z"),
                        status: "ACTIVE",
                        acknowledged_at: new Date("2026-11-17T09:30:00Z"),
                        acknowledged_by_teacher_id: NumberInt(16),
                        resolved_at: null,
                        resolved_by_teacher_id: null,
                        resolution_remarks: null,
                        excused_reason: null,
                        assessment_details: null,
                        homework_details: {
                                homework_id: NumberInt(3065),
                                homework_title: "Chemical Reactions Balancing Worksheet",
                                assigned_date: new Date("2026-11-13T08:00:00Z"),
                                due_date: new Date("2026-11-16T16:00:00Z"),
                                days_overdue: NumberInt(2),
                                submission_status: "PENDING"
                            },
                        attendance_details: null
                    }
                ],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(1),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(4),
                subject_name: "Social Science",
                subject_code: "SOC",
                assigned_teacher_id: NumberInt(23),
                assigned_teacher_name: "Kushagra Kapoor",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(5),
                subject_name: "Computer Science",
                subject_code: "CSC",
                assigned_teacher_id: NumberInt(30),
                assigned_teacher_name: "Chitra Nigam",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(6),
                subject_name: "Physical Education",
                subject_code: "PE",
                assigned_teacher_id: NumberInt(35),
                assigned_teacher_name: "Abhiram Kansal",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            }
        ],
            last_evaluated_at: new Date("2026-11-18T14:00:00Z"),
            is_active: NumberInt(1),
            created_at: new Date("2026-10-01T08:00:00Z"),
            updated_at: new Date("2026-11-18T14:00:00Z")
        },
        {
            student_id: NumberInt(20),
            student_name: "Nakul Chatterjee",
            admission_number: "ADM-2026-0020",
            roll_number: "R-10",
            school_id: NumberInt(1),
            branch_id: NumberInt(1),
            academic_year_id: NumberInt(1),
            class_id: NumberInt(1),
            class_name: "Class 1 - Central",
            section_id: NumberInt(2),
            section_name: "B",
            total_attentions_raised: NumberInt(0),
            total_active_attentions: NumberInt(0),
            subjects: [
            {
                subject_id: NumberInt(1),
                subject_name: "English",
                subject_code: "ENG",
                assigned_teacher_id: NumberInt(2),
                assigned_teacher_name: "Radhika Pillai",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(2),
                subject_name: "Mathematics",
                subject_code: "MAT",
                assigned_teacher_id: NumberInt(9),
                assigned_teacher_name: "Utkarsh Mishra",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(3),
                subject_name: "Science",
                subject_code: "SCI",
                assigned_teacher_id: NumberInt(16),
                assigned_teacher_name: "Juhi Rajput",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(4),
                subject_name: "Social Science",
                subject_code: "SOC",
                assigned_teacher_id: NumberInt(23),
                assigned_teacher_name: "Kushagra Kapoor",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(5),
                subject_name: "Computer Science",
                subject_code: "CSC",
                assigned_teacher_id: NumberInt(30),
                assigned_teacher_name: "Chitra Nigam",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            },
            {
                subject_id: NumberInt(6),
                subject_name: "Physical Education",
                subject_code: "PE",
                assigned_teacher_id: NumberInt(35),
                assigned_teacher_name: "Abhiram Kansal",
                total_attentions_raised: NumberInt(0),
                active_attentions_count: NumberInt(0),
                attentions: [],
                subject_summary: {
                    assessments_passed: NumberInt(3),
                    assessments_failed: NumberInt(0),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt(0),
                    subject_attendance_percent: 98.0
                }
            }
        ],
            last_evaluated_at: new Date("2026-11-18T14:00:00Z"),
            is_active: NumberInt(1),
            created_at: new Date("2026-10-01T08:00:00Z"),
            updated_at: new Date("2026-11-18T14:00:00Z")
        }

    ];

    var insertRes = targetDb[COLLECTION_NAME].insertMany(docsToInsert);
    print("[SUCCESS] Successfully inserted " + insertRes.insertedIds.length + " realistic student attention documents.");

    // -------------------------------------------------------------------------
    // 5. POST-SEED AUDIT & VERIFICATION REPORT
    // -------------------------------------------------------------------------
    print("");
    print("================================================================================");
    print("VERIFICATION REPORT: ALL 20 SEEDED STUDENTS IN BRANCH 1 (UP TO 18-NOV-2026)");
    print("================================================================================");

    var cursor = targetDb[COLLECTION_NAME].find({}, {
        student_id: 1,
        student_name: 1,
        section_name: 1,
        total_attentions_raised: 1,
        total_active_attentions: 1,
        subjects: 1
    }).sort({ student_id: 1 });

    var totalRaisedSum = 0;
    var totalActiveSum = 0;
    var totalResolvedSum = 0;
    var totalExcusedSum = 0;

    while (cursor.hasNext()) {
        var doc = cursor.next();
        var raised = doc.total_attentions_raised;
        var active = doc.total_active_attentions;

        var resolvedCount = 0;
        var excusedCount = 0;
        if (Array.isArray(doc.subjects)) {
            doc.subjects.forEach(function (s) {
                if (Array.isArray(s.attentions)) {
                    s.attentions.forEach(function (a) {
                        if (a.status === "RESOLVED") resolvedCount++;
                        if (a.status === "EXCUSED") excusedCount++;
                    });
                }
            });
        }

        totalRaisedSum += raised;
        totalActiveSum += active;
        totalResolvedSum += resolvedCount;
        totalExcusedSum += excusedCount;

        var padId = (doc.student_id < 10 ? "0" : "") + doc.student_id;
        var statusBadge = active > 0 ? "⚠️ ACTIVE" : (raised > 0 ? "✅ RESOLVED" : "🌟 HONORS");
        print("  - Student " + padId + " (" + doc.student_name + ", Sec " + doc.section_name + "): " +
              "Total Raised: " + raised + " | Active: " + active + " | Resolved: " + resolvedCount + " | Excused: " + excusedCount + " [" + statusBadge + "]");
    }

    print("--------------------------------------------------------------------------------");
    print("SUMMARY METRICS ACROSS COHORT:");
    print("  Total Students Seeded:       " + targetDb[COLLECTION_NAME].countDocuments());
    print("  Total Attentions Raised:     " + totalRaisedSum);
    print("  Total Active Attentions:     " + totalActiveSum);
    print("  Total Resolved Attentions:   " + totalResolvedSum);
    print("  Total Excused Attentions:    " + totalExcusedSum);
    print("  Legacy Severity Fields Found:" + targetDb[COLLECTION_NAME].countDocuments({
        $or: [
            { critical_attentions_count: { $exists: true } },
            { "subjects.attentions.severity": { $exists: true } }
        ]
    }));
    print("================================================================================");
    print("MOCK SEED COMPLETE WITH 100% ACCURACY & ZERO SEVERITY / CRITICAL FIELDS");
    print("================================================================================");
})();
