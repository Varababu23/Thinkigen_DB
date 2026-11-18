/*
================================================================================
SCRIPT:        038_seed_realistic_student_attentions_mock_data.js
MODULE:        Teacher Portal Management & Student Academic Health
DATABASE:      thinkigen (MongoDB / mongosh)
COLLECTION:    student_subject_attentions

AUTHENTIC MAPPINGS ENFORCED (FROM SQL SERVER REALISTIC MASTER SEEDS):
- School: ID 1
- Branch: ID 1 (Central Campus) & ID 2 (North Campus)
- Academic Year: ID 1 (2026-2027)
- Class: ID 1 ("Class 8 - Central")
- Section 1 ("A") Faculty:
  * Subject 1 (English, "ENG"):         Teacher 1  (Keshav Kulkarni, HOD)
  * Subject 2 (Mathematics, "MAT"):     Teacher 8  (Zara Pai, HOD)
  * Subject 3 (Science, "SCI"):         Teacher 15 (Bhuvan Solanki, HOD)
  * Subject 4 (Social Science, "SOC"):  Teacher 22 (Rashmi Chopra, HOD)
  * Subject 5 (Computer Science, "CSC"):Teacher 29 (Raghunath Mathur, HOD)
  * Subject 6 (Physical Ed, "PE"):      Teacher 35 (Abhiram Kansal)
- Section 2 ("B") Faculty:
  * Subject 1 (English, "ENG"):         Teacher 2  (Radhika Pillai)
  * Subject 2 (Mathematics, "MAT"):     Teacher 9  (Utkarsh Mishra)
  * Subject 3 (Science, "SCI"):         Teacher 16 (Juhi Rajput)
  * Subject 4 (Social Science, "SOC"):  Teacher 23 (Kushagra Kapoor)
  * Subject 5 (Computer Science, "CSC"):Teacher 30 (Chitra Nigam)
  * Subject 6 (Physical Ed, "PE"):      Teacher 35 (Abhiram Kansal)

METRIC INVARIANTS ENFORCED:
1. total_attentions_raised: Total count of all alerts raised (ACTIVE + ACKNOWLEDGED + RESOLVED + EXCUSED).
2. total_active_attentions: Total count of currently ACTIVE alerts requiring intervention.
3. Subject level: total_attentions_raised and active_attentions_count maintained per subject.
4. NO severity or critical attention fields (completely removed per specification).
5. 100% BSON 32-bit int (NumberInt).
6. 100% Past dates (<= 2026-10-30).
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
    print("SEEDING REALISTIC MOCK DATA: " + COLLECTION_NAME);
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
    // 3. UNSET OLD SEVERITY & CRITICAL FIELDS ACROSS COLLECTION
    // -------------------------------------------------------------------------
    var unsetRes = targetDb[COLLECTION_NAME].updateMany(
        {},
        {
            $unset: {
                critical_attentions_count: "",
                "subjects.$[].attentions.$[].severity": ""
            }
        }
    );
    print("[UNSET] Cleaned legacy severity/critical fields across " + unsetRes.modifiedCount + " documents.");

    // -------------------------------------------------------------------------
    // 4. Faculty Configurations
    // -------------------------------------------------------------------------
    var sec1Faculty = [
        { id: 1, name: "Keshav Kulkarni", sid: 1, sname: "English", code: "ENG" },
        { id: 8, name: "Zara Pai", sid: 2, sname: "Mathematics", code: "MAT" },
        { id: 15, name: "Bhuvan Solanki", sid: 3, sname: "Science", code: "SCI" },
        { id: 22, name: "Rashmi Chopra", sid: 4, sname: "Social Science", code: "SOC" },
        { id: 29, name: "Raghunath Mathur", sid: 5, sname: "Computer Science", code: "CSC" },
        { id: 35, name: "Abhiram Kansal", sid: 6, sname: "Physical Education", code: "PE" }
    ];

    var sec2Faculty = [
        { id: 2, name: "Radhika Pillai", sid: 1, sname: "English", code: "ENG" },
        { id: 9, name: "Utkarsh Mishra", sid: 2, sname: "Mathematics", code: "MAT" },
        { id: 16, name: "Juhi Rajput", sid: 3, sname: "Science", code: "SCI" },
        { id: 23, name: "Kushagra Kapoor", sid: 4, sname: "Social Science", code: "SOC" },
        { id: 30, name: "Chitra Nigam", sid: 5, sname: "Computer Science", code: "CSC" },
        { id: 35, name: "Abhiram Kansal", sid: 6, sname: "Physical Education", code: "PE" }
    ];

    // -------------------------------------------------------------------------
    // 5. Student Definition Profiles (Mapped to SQL Server student_schema.student)
    // -------------------------------------------------------------------------
    var rawStudents = [
        // ================= SECTION 1 (CLASS 8 - CENTRAL, SECTION A) =================
        {
            id: 1, name: "Karishma Shaik", adm: "ADM-2026-0001", roll: "R-01", secId: 1, secName: "A",
            alerts: [
                {
                    sid: 2, type: "LOW_ASSESSMENT_SCORE", title: "Linear Equations Slip Test Below Benchmark",
                    desc: "Scored 14/50 on algebra diagnostic slip test.", srcId: 501, srcType: "ASSESSMENT", status: "ACTIVE",
                    trigAt: "2026-10-28T14:30:00Z", ackAt: "2026-10-29T08:30:00Z",
                    assessment: { id: 501, name: "Linear Equations Slip Test", type: "SLIP_TEST", max: 50.0, pass: 20.0, obt: 14.0, pct: 28.0 }
                },
                {
                    sid: 2, type: "PENDING_HOMEWORK", title: "Polynomial Algebraic Identities Exercise 3.2 Overdue",
                    desc: "Exercise 3.2 textbook problems overdue by 3 days.", srcId: 3002, srcType: "ASSIGNMENT_HOMEWORK", status: "ACTIVE",
                    trigAt: "2026-10-26T08:00:00Z", ackAt: "2026-10-27T09:00:00Z",
                    homework: { id: 3002, title: "Polynomial Identities Exercise 3.2", assigned: "2026-10-20", due: "2026-10-23", overdue: 3, subStatus: "PENDING" }
                },
                {
                    sid: 1, type: "PENDING_HOMEWORK", title: "Overdue Poetry Analysis Essay - The Road Not Taken",
                    desc: "Poetry analysis essay assigned on Oct 12 submitted late and accepted.", srcId: 3001, srcType: "ASSIGNMENT_HOMEWORK", status: "RESOLVED",
                    trigAt: "2026-10-16T09:00:00Z", ackAt: "2026-10-16T11:00:00Z", resAt: "2026-10-18T14:30:00Z",
                    remarks: "Completed handwritten essay with annotations evaluated and accepted.",
                    homework: { id: 3001, title: "Poetry Analysis - The Road Not Taken", assigned: "2026-10-12", due: "2026-10-15", overdue: 2, subStatus: "LATE" }
                },
                {
                    sid: 3, type: "ABSENT_ATTENDANCE", title: "Period 3 Chemistry Practical Absence",
                    desc: "Absent during Acids and Bases lab practical; medical note submitted.", srcId: 9001, srcType: "ATTENDANCE", status: "EXCUSED",
                    trigAt: "2026-10-15T11:00:00Z", ackAt: "2026-10-15T11:30:00Z", resAt: "2026-10-16T09:00:00Z",
                    excused: "Medical certificate from Central School Clinic submitted.", remarks: "Excused by Science teacher per clinic slip.",
                    attendance: { id: 9001, date: "2026-10-15", period: 3, time: "10:15 - 11:00", status: "ABSENT" }
                }
            ]
        },
        {
            id: 2, name: "Dhamodhar Rao", adm: "ADM-2026-0002", roll: "R-02", secId: 1, secName: "A",
            alerts: [
                {
                    sid: 5, type: "PENDING_HOMEWORK", title: "Overdue Python Loop Programming Lab 3",
                    desc: "Loop iterations worksheet assigned Oct 23 not submitted.", srcId: 3012, srcType: "ASSIGNMENT_HOMEWORK", status: "ACTIVE",
                    trigAt: "2026-10-27T08:00:00Z", ackAt: "2026-10-28T09:00:00Z",
                    homework: { id: 3012, title: "Python Lab 3: Loop Iterations", assigned: "2026-10-23", due: "2026-10-26", overdue: 3, subStatus: "PENDING" }
                },
                {
                    sid: 4, type: "PENDING_HOMEWORK", title: "Map Work: River Systems of Southern India",
                    desc: "Geography river basin mapping assignment submitted after 1-day delay.", srcId: 3014, srcType: "ASSIGNMENT_HOMEWORK", status: "RESOLVED",
                    trigAt: "2026-10-20T08:00:00Z", ackAt: "2026-10-20T10:00:00Z", resAt: "2026-10-22T11:00:00Z",
                    remarks: "Map coloring and key labeling checked; verified complete.",
                    homework: { id: 3014, title: "River Systems Mapping Portfolio", assigned: "2026-10-16", due: "2026-10-19", overdue: 1, subStatus: "LATE" }
                }
            ]
        },
        {
            id: 3, name: "Sita Ram", adm: "ADM-2026-0003", roll: "R-03", secId: 1, secName: "A",
            alerts: [
                {
                    sid: 2, type: "LOW_ASSESSMENT_SCORE", title: "Trigonometric Ratios Slip Test Deficit",
                    desc: "Scored 12/50 on introductory trigonometry test; remedial coaching advised.", srcId: 503, srcType: "ASSESSMENT", status: "ACTIVE",
                    trigAt: "2026-10-28T14:30:00Z", ackAt: "2026-10-29T08:45:00Z",
                    assessment: { id: 503, name: "Trigonometric Ratios Test", type: "SLIP_TEST", max: 50.0, pass: 20.0, obt: 12.0, pct: 24.0 }
                },
                {
                    sid: 3, type: "ABSENT_ATTENDANCE", title: "Period 3 Science Laboratory Absence",
                    desc: "Unexcused absence during Acids & Bases experimental practical.", srcId: 9015, srcType: "ATTENDANCE", status: "ACTIVE",
                    trigAt: "2026-10-29T11:00:00Z", ackAt: "2026-10-30T08:30:00Z",
                    attendance: { id: 9015, date: "2026-10-29", period: 3, time: "10:15 - 11:00", status: "ABSENT" }
                }
            ]
        },
        {
            id: 4, name: "Krupa Joseph", adm: "ADM-2026-0004", roll: "R-04", secId: 1, secName: "A",
            alerts: [
                {
                    sid: 4, type: "LOW_ASSESSMENT_SCORE", title: "Indian Constitution Principles Diagnostic Retest",
                    desc: "Scored 15/40 on Indian Constitution foundational principles slip test.", srcId: 504, srcType: "ASSESSMENT", status: "ACTIVE",
                    trigAt: "2026-10-27T15:00:00Z", ackAt: "2026-10-28T09:15:00Z",
                    assessment: { id: 504, name: "Constitution Principles Diagnostic", type: "SLIP_TEST", max: 40.0, pass: 18.0, obt: 15.0, pct: 37.5 }
                },
                {
                    sid: 1, type: "PENDING_HOMEWORK", title: "Active & Passive Voice Transformation Practice Overdue",
                    desc: "Grammar transformation exercise 4.1 pending submission.", srcId: 3020, srcType: "ASSIGNMENT_HOMEWORK", status: "ACTIVE",
                    trigAt: "2026-10-28T08:00:00Z", ackAt: "2026-10-29T08:30:00Z",
                    homework: { id: 3020, title: "Voice Transformation Practice 4.1", assigned: "2026-10-24", due: "2026-10-27", overdue: 2, subStatus: "PENDING" }
                }
            ]
        },
        {
            id: 5, name: "Jeswanth Reddy", adm: "ADM-2026-0005", roll: "R-05", secId: 1, secName: "A",
            alerts: [
                {
                    sid: 1, type: "PENDING_HOMEWORK", title: "Direct & Indirect Speech Exercise 5.1 Overdue",
                    desc: "Grammar transformation exercise 5.1 not submitted by due date.", srcId: 3025, srcType: "ASSIGNMENT_HOMEWORK", status: "ACTIVE",
                    trigAt: "2026-10-28T08:00:00Z", ackAt: "2026-10-29T09:00:00Z",
                    homework: { id: 3025, title: "Direct & Indirect Speech Exercise 5.1", assigned: "2026-10-24", due: "2026-10-27", overdue: 2, subStatus: "PENDING" }
                },
                {
                    sid: 2, type: "PENDING_HOMEWORK", title: "Linear Graphs Problem Set 2",
                    desc: "Graph sheet problems submitted after verification.", srcId: 3026, srcType: "ASSIGNMENT_HOMEWORK", status: "RESOLVED",
                    trigAt: "2026-10-18T08:00:00Z", ackAt: "2026-10-18T10:00:00Z", resAt: "2026-10-20T12:00:00Z",
                    remarks: "All 5 plotted lines and intersection points verified accurate.",
                    homework: { id: 3026, title: "Linear Equations Graph Plotting Set", assigned: "2026-10-14", due: "2026-10-17", overdue: 1, subStatus: "LATE" }
                }
            ]
        },
        {
            id: 6, name: "Sravan Kumar", adm: "ADM-2026-0006", roll: "R-06", secId: 1, secName: "A",
            alerts: [
                {
                    sid: 3, type: "LOW_ASSESSMENT_SCORE", title: "Force and Laws of Motion Slip Test Benchmark Deficit",
                    desc: "Scored 8/40, below passing threshold of 16 in mechanics slip test.", srcId: 506, srcType: "ASSESSMENT", status: "ACTIVE",
                    trigAt: "2026-10-29T14:30:00Z", ackAt: "2026-10-30T08:30:00Z",
                    assessment: { id: 506, name: "Force & Laws of Motion Test", type: "SLIP_TEST", max: 40.0, pass: 16.0, obt: 8.0, pct: 20.0 }
                },
                {
                    sid: 5, type: "PENDING_HOMEWORK", title: "HTML/CSS Form Creation Lab Assignment Overdue",
                    desc: "Web page form styling exercise pending upload.", srcId: 3030, srcType: "ASSIGNMENT_HOMEWORK", status: "ACTIVE",
                    trigAt: "2026-10-29T08:00:00Z", ackAt: "2026-10-30T09:00:00Z",
                    homework: { id: 3030, title: "HTML Form Creation Lab", assigned: "2026-10-25", due: "2026-10-28", overdue: 2, subStatus: "PENDING" }
                }
            ]
        },
        {
            id: 7, name: "Gaurav Joshi", adm: "ADM-2026-0007", roll: "R-07", secId: 1, secName: "A",
            alerts: [
                {
                    sid: 3, type: "ABSENT_ATTENDANCE", title: "Period 2 Science Biology Microscopy Session Absence",
                    desc: "Absent during onion cell mount practical; student made up practical in zero period.", srcId: 9020, srcType: "ATTENDANCE", status: "RESOLVED",
                    trigAt: "2026-10-18T10:00:00Z", ackAt: "2026-10-18T11:00:00Z", resAt: "2026-10-21T16:00:00Z",
                    remarks: "Slide preparation and sketch verified during zero period makeup.",
                    attendance: { id: 9020, date: "2026-10-18", period: 2, time: "09:15 - 10:00", status: "ABSENT" }
                }
            ]
        },
        {
            id: 8, name: "Manish Talwar", adm: "ADM-2026-0008", roll: "R-08", secId: 1, secName: "A",
            alerts: [
                {
                    sid: 1, type: "LOW_ASSESSMENT_SCORE", title: "Unseen Prose Reading Comprehension Diagnostic Below 40%",
                    desc: "Scored 15/50 on comprehension diagnostic test.", srcId: 508, srcType: "ASSESSMENT", status: "ACTIVE",
                    trigAt: "2026-10-28T14:00:00Z", ackAt: "2026-10-29T08:30:00Z",
                    assessment: { id: 508, name: "Reading Comprehension Diagnostic", type: "SLIP_TEST", max: 50.0, pass: 20.0, obt: 15.0, pct: 30.0 }
                }
            ]
        },
        {
            id: 9, name: "Zara Tiwari", adm: "ADM-2026-0009", roll: "R-09", secId: 1, secName: "A",
            alerts: [
                {
                    sid: 2, type: "LOW_ASSESSMENT_SCORE", title: "Mensuration Surface Areas & Volumes Test Deficit",
                    desc: "Scored 13/50 on Mensuration diagnostic test.", srcId: 509, srcType: "ASSESSMENT", status: "ACTIVE",
                    trigAt: "2026-10-29T14:30:00Z", ackAt: "2026-10-30T08:30:00Z",
                    assessment: { id: 509, name: "Surface Areas Diagnostic", type: "SLIP_TEST", max: 50.0, pass: 20.0, obt: 13.0, pct: 26.0 }
                }
            ]
        },
        {
            id: 10, name: "Sarita Sengupta", adm: "ADM-2026-0010", roll: "R-10", secId: 1, secName: "A",
            alerts: [] // Clean track record: 0 alerts raised
        },

        // ================= SECTION 2 (CLASS 8 - CENTRAL, SECTION B) =================
        {
            id: 11, name: "Gurpreet Pillai", adm: "ADM-2026-0011", roll: "R-01", secId: 2, secName: "B",
            alerts: [
                {
                    sid: 2, type: "LOW_ASSESSMENT_SCORE", title: "Section B Quadratic Equation Slip Test Benchmark Deficit",
                    desc: "Scored 16/50 on algebra quadratic polynomials diagnostic slip test.", srcId: 511, srcType: "ASSESSMENT", status: "ACTIVE",
                    trigAt: "2026-10-28T14:30:00Z", ackAt: "2026-10-29T09:00:00Z",
                    assessment: { id: 511, name: "Section B Quadratic Diagnostic", type: "SLIP_TEST", max: 50.0, pass: 20.0, obt: 16.0, pct: 32.0 }
                },
                {
                    sid: 1, type: "PENDING_HOMEWORK", title: "English Reading Journal Entry 4 Late Submission",
                    desc: "Reading journal submitted 2 days late; evaluated by Radhika Pillai.", srcId: 3040, srcType: "ASSIGNMENT_HOMEWORK", status: "RESOLVED",
                    trigAt: "2026-10-20T08:00:00Z", ackAt: "2026-10-20T10:00:00Z", resAt: "2026-10-23T14:00:00Z",
                    remarks: "Journal log checked and stamped.",
                    homework: { id: 3040, title: "Reading Journal Entry 4", assigned: "2026-10-16", due: "2026-10-19", overdue: 2, subStatus: "LATE" }
                }
            ]
        },
        {
            id: 12, name: "Deepika Pathak", adm: "ADM-2026-0012", roll: "R-02", secId: 2, secName: "B",
            alerts: [
                {
                    sid: 1, type: "ABSENT_ATTENDANCE", title: "Period 1 English Literature Attendance Absence",
                    desc: "Absent without prior leave slip during Merchant of Venice introduction.", srcId: 9032, srcType: "ATTENDANCE", status: "ACTIVE",
                    trigAt: "2026-10-28T09:30:00Z", ackAt: "2026-10-29T08:30:00Z",
                    attendance: { id: 9032, date: "2026-10-28", period: 1, time: "08:30 - 09:15", status: "ABSENT" }
                }
            ]
        },
        {
            id: 13, name: "Varun Venkataraman", adm: "ADM-2026-0013", roll: "R-03", secId: 2, secName: "B",
            alerts: [
                {
                    sid: 3, type: "PENDING_HOMEWORK", title: "Physics Ray Optics Diagram Portfolio Overdue",
                    desc: "Refraction ray diagrams lab homework not submitted.", srcId: 3045, srcType: "ASSIGNMENT_HOMEWORK", status: "ACTIVE",
                    trigAt: "2026-10-29T08:00:00Z", ackAt: "2026-10-30T09:00:00Z",
                    homework: { id: 3045, title: "Ray Optics Lab Homework Portfolio", assigned: "2026-10-25", due: "2026-10-28", overdue: 2, subStatus: "PENDING" }
                }
            ]
        },
        {
            id: 14, name: "Reena Mitra", adm: "ADM-2026-0014", roll: "R-04", secId: 2, secName: "B",
            alerts: [
                {
                    sid: 4, type: "LOW_ASSESSMENT_SCORE", title: "Medieval Indian Architecture Map Test Re-evaluation",
                    desc: "Scored 13/40 on Mughal architecture and monuments mapping evaluation.", srcId: 514, srcType: "ASSESSMENT", status: "ACTIVE",
                    trigAt: "2026-10-28T14:30:00Z", ackAt: "2026-10-29T09:00:00Z",
                    assessment: { id: 514, name: "Mughal Architecture Map Test", type: "SLIP_TEST", max: 40.0, pass: 18.0, obt: 13.0, pct: 32.5 }
                }
            ]
        },
        {
            id: 15, name: "Sangeeta Ghosh", adm: "ADM-2026-0015", roll: "R-05", secId: 2, secName: "B",
            alerts: [] // Clean track record: 0 alerts raised
        }
    ];

    // -------------------------------------------------------------------------
    // 6. Build and Assemble Student Documents
    // -------------------------------------------------------------------------
    var attentionDocs = [];

    rawStudents.forEach(function (st) {
        var facultyList = st.secId === 1 ? sec1Faculty : sec2Faculty;
        var subjectsArr = [];

        var studentTotalRaised = 0;
        var studentTotalActive = 0;

        facultyList.forEach(function (f) {
            var matchingAlerts = st.alerts.filter(function (a) { return a.sid === f.sid; });
            var attList = [];

            var subjTotalRaised = matchingAlerts.length;
            var subjActiveCount = 0;

            matchingAlerts.forEach(function (a) {
                var isAct = a.status === "ACTIVE";
                if (isAct) {
                    subjActiveCount++;
                    studentTotalActive++;
                }
                studentTotalRaised++;

                var asmDetails = a.assessment ? {
                    assessment_id: NumberInt(a.assessment.id),
                    assessment_name: a.assessment.name,
                    exam_type: a.assessment.type,
                    max_marks: a.assessment.max,
                    pass_marks: a.assessment.pass,
                    obtained_marks: a.assessment.obt,
                    percentage: a.assessment.pct
                } : null;

                var hwDetails = a.homework ? {
                    homework_id: NumberInt(a.homework.id),
                    homework_title: a.homework.title,
                    assigned_date: new Date(a.homework.assigned + "T00:00:00Z"),
                    due_date: new Date(a.homework.due + "T23:59:59Z"),
                    days_overdue: NumberInt(a.homework.overdue),
                    submission_status: a.homework.subStatus
                } : null;

                var attDetails = a.attendance ? {
                    attendance_id: NumberInt(a.attendance.id),
                    attendance_date: new Date(a.attendance.date + "T00:00:00Z"),
                    period_number: NumberInt(a.attendance.period),
                    period_time: a.attendance.time,
                    attendance_status: a.attendance.status
                } : null;

                attList.push({
                    attention_id: "ATT-S" + ("00" + st.id).slice(-3) + "-" + f.code + "-" + a.srcId + "-2026",
                    attention_type: a.type,
                    title: a.title,
                    description: a.desc,
                    trigger_source: a.srcType,
                    source_id: NumberInt(a.srcId),
                    triggered_at: new Date(a.trigAt),
                    status: a.status,
                    acknowledged_at: a.ackAt ? new Date(a.ackAt) : null,
                    acknowledged_by_teacher_id: a.ackAt ? NumberInt(f.id) : null,
                    resolved_at: a.resAt ? new Date(a.resAt) : null,
                    resolved_by_teacher_id: a.resAt ? NumberInt(f.id) : null,
                    resolution_remarks: a.remarks || null,
                    excused_reason: a.excused || null,
                    assessment_details: asmDetails,
                    homework_details: hwDetails,
                    attendance_details: attDetails
                });
            });

            subjectsArr.push({
                subject_id: NumberInt(f.sid),
                subject_name: f.sname,
                subject_code: f.code,
                assigned_teacher_id: NumberInt(f.id),
                assigned_teacher_name: f.name,
                total_attentions_raised: NumberInt(subjTotalRaised),
                active_attentions_count: NumberInt(subjActiveCount),
                attentions: attList,
                subject_summary: {
                    assessments_passed: NumberInt(matchingAlerts.some(function (a) { return a.assessment; }) ? 3 : 4),
                    assessments_failed: NumberInt(matchingAlerts.some(function (a) { return a.assessment; }) ? 1 : 0),
                    homework_submitted: NumberInt(8),
                    homework_pending: NumberInt(matchingAlerts.some(function (a) { return a.homework && a.status === "ACTIVE"; }) ? 1 : 0),
                    subject_attendance_percent: 95.0
                }
            });
        });

        attentionDocs.push({
            student_id: NumberInt(st.id),
            student_name: st.name,
            admission_number: st.adm,
            roll_number: st.roll,
            school_id: NumberInt(1),
            branch_id: NumberInt(1),
            academic_year_id: NumberInt(1),
            class_id: NumberInt(1),
            class_name: "Class 8 - Central",
            section_id: NumberInt(st.secId),
            section_name: st.secName,
            total_attentions_raised: NumberInt(studentTotalRaised),
            total_active_attentions: NumberInt(studentTotalActive),
            subjects: subjectsArr,
            last_evaluated_at: new Date("2026-10-30T16:00:00Z"),
            is_active: NumberInt(1),
            created_at: new Date("2026-10-26T08:00:00Z"),
            updated_at: new Date("2026-10-30T16:00:00Z")
        });
    });

    // -------------------------------------------------------------------------
    // 7. Execution: Clean Idempotent Upsert
    // -------------------------------------------------------------------------
    var targetStudentIds = rawStudents.map(function (s) { return NumberInt(s.id); });
    var deleteRes = targetDb[COLLECTION_NAME].deleteMany({
        student_id: { $in: targetStudentIds },
        academic_year_id: NumberInt(1)
    });
    print("[CLEANUP] Deleted " + deleteRes.deletedCount + " existing mock documents for targeted students.");

    var insertRes = targetDb[COLLECTION_NAME].insertMany(attentionDocs);
    print("[SUCCESS] Successfully inserted " + attentionDocs.length + " realistic student attention documents.");

    // -------------------------------------------------------------------------
    // 8. Post-Insertion Verification
    // -------------------------------------------------------------------------
    print("\n[VERIFICATION] Verifying metric totals across seeded documents:");
    var cursor = targetDb[COLLECTION_NAME].find({ student_id: { $in: targetStudentIds }, academic_year_id: NumberInt(1) }).sort({ section_id: 1, student_id: 1 });
    while (cursor.hasNext()) {
        var doc = cursor.next();
        print("  - Student " + ("00" + doc.student_id).slice(-2) + " (" + doc.student_name + ", Sec " + doc.section_name + "): " +
              "Total Raised: " + doc.total_attentions_raised + " | " +
              "Active: " + doc.total_active_attentions);
    }

    print("\n================================================================================");
    print("MOCK SEED COMPLETE WITH 100% ACCURATE MAPPINGS & SCHEMA COMPLIANCE");
    print("================================================================================");
})();
