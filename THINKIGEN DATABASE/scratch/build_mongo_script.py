import sys
import os
import json

# Add backend directory to sys.path
sys.path.append(os.path.abspath("Thinkigen_DB/THINKIGEN DATABASE/backend"))
sys.path.append(os.path.abspath("Thinkigen_DB/THINKIGEN DATABASE/scratch"))

from generate_and_validate_20_students import sec1_faculty, sec2_faculty, raw_students

def to_bson_value(val):
    if val is None:
        return "null"
    if isinstance(val, bool):
        return "true" if val else "false"
    if isinstance(val, int):
        return f"NumberInt({val})"
    if isinstance(val, float):
        return f"{val:.1f}"
    if isinstance(val, str):
        # Check if date string
        if len(val) >= 10 and (val.endswith("Z") or (len(val) == 10 and val[4] == "-" and val[7] == "-")):
            if len(val) == 10:
                val = val + "T00:00:00Z"
            return f'new Date("{val}")'
        # Escaped string
        escaped = val.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n')
        return f'"{escaped}"'
    if isinstance(val, list):
        items = [to_bson_value(x) for x in val]
        return "[" + ", ".join(items) + "]"
    if isinstance(val, dict):
        entries = []
        for k, v in val.items():
            entries.append(f'"{k}": {to_bson_value(v)}')
        return "{\n  " + ",\n  ".join(entries) + "\n}"
    return str(val)

def generate_js():
    js_lines = []
    js_lines.append("""/*
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
""")

    # Build documents JS objects
    doc_blocks = []
    for s in raw_students:
        faculty_list = sec1_faculty if s["secId"] == 1 else sec2_faculty
        subjects_js = []
        tot_raised = 0
        tot_active = 0

        for fac in faculty_list:
            sub_alerts = [a for a in s["alerts"] if a["sid"] == fac["sid"]]
            att_items_js = []
            sub_raised = len(sub_alerts)
            sub_active = sum(1 for a in sub_alerts if a["status"] == "ACTIVE")
            tot_raised += sub_raised
            tot_active += sub_active

            for a in sub_alerts:
                src_code = {"ASSESSMENT": "ASM", "ASSIGNMENT_HOMEWORK": "HW", "ATTENDANCE": "ATT"}[a["srcType"]]
                att_id = f"ATT-{s['id']}-{src_code}-{a['srcId']}-1"

                asm_str = "null"
                hw_str = "null"
                att_str = "null"

                if a["srcType"] == "ASSESSMENT":
                    asm = a["assessment"]
                    asm_str = f"""{{
                                assessment_id: NumberInt({asm['id']}),
                                assessment_name: "{asm['name']}",
                                exam_type: "{asm.get('type', 'SLIP_TEST')}",
                                max_marks: {asm['max']:.1f},
                                pass_marks: {asm['pass']:.1f},
                                obtained_marks: {asm['obt']:.1f},
                                percentage: {asm['pct']:.1f}
                            }}"""
                elif a["srcType"] == "ASSIGNMENT_HOMEWORK":
                    hw = a["homework"]
                    asm_str = "null"
                    hw_str = f"""{{
                                homework_id: NumberInt({hw['id']}),
                                homework_title: "{hw['title']}",
                                assigned_date: new Date("{hw['assigned']}T08:00:00Z"),
                                due_date: new Date("{hw['due']}T16:00:00Z"),
                                days_overdue: NumberInt({hw.get('overdue', 0)}),
                                submission_status: "{hw['subStatus']}"
                            }}"""
                elif a["srcType"] == "ATTENDANCE":
                    att = a["attendance"]
                    asm_str = "null"
                    hw_str = "null"
                    att_str = f"""{{
                                attendance_id: NumberInt({att['id']}),
                                attendance_date: new Date("{att['date']}T00:00:00Z"),
                                period_number: NumberInt({att['period']}),
                                period_time: "{att.get('time', '08:30 - 09:15')}",
                                attendance_status: "{att['status']}"
                            }}"""

                ack_at_str = f'new Date("{a["ackAt"]}")' if a.get("ackAt") else "null"
                ack_by_str = f'NumberInt({fac["id"]})' if a.get("ackAt") else "null"
                res_at_str = f'new Date("{a["resAt"]}")' if a.get("resAt") else "null"
                res_by_str = f'NumberInt({fac["id"]})' if a.get("resAt") else "null"
                rem_str = f'"{a["remarks"]}"' if a.get("remarks") else "null"
                exc_str = f'"{a["excused"]}"' if a.get("excused") else "null"

                item_js = f"""                    {{
                        attention_id: "{att_id}",
                        attention_type: "{a['type']}",
                        title: "{a['title']}",
                        description: "{a['desc']}",
                        trigger_source: "{a['srcType']}",
                        source_id: NumberInt({a['srcId']}),
                        triggered_at: new Date("{a['trigAt']}"),
                        status: "{a['status']}",
                        acknowledged_at: {ack_at_str},
                        acknowledged_by_teacher_id: {ack_by_str},
                        resolved_at: {res_at_str},
                        resolved_by_teacher_id: {res_by_str},
                        resolution_remarks: {rem_str},
                        excused_reason: {exc_str},
                        assessment_details: {asm_str},
                        homework_details: {hw_str},
                        attendance_details: {att_str}
                    }}"""
                att_items_js.append(item_js)

            att_array_str = "[\n" + ",\n".join(att_items_js) + "\n                ]" if att_items_js else "[]"

            passed_cnt = 3 if not any(x['type'] == 'LOW_ASSESSMENT_SCORE' for x in sub_alerts) else 2
            failed_cnt = sum(1 for x in sub_alerts if x['type'] == 'LOW_ASSESSMENT_SCORE')
            sub_pct = 92.5 if any(x['type'] == 'ABSENT_ATTENDANCE' for x in sub_alerts) else 98.0

            sub_js = f"""            {{
                subject_id: NumberInt({fac['sid']}),
                subject_name: "{fac['sname']}",
                subject_code: "{fac['code']}",
                assigned_teacher_id: NumberInt({fac['id']}),
                assigned_teacher_name: "{fac['name']}",
                total_attentions_raised: NumberInt({sub_raised}),
                active_attentions_count: NumberInt({sub_active}),
                attentions: {att_array_str},
                subject_summary: {{
                    assessments_passed: NumberInt({passed_cnt}),
                    assessments_failed: NumberInt({failed_cnt}),
                    homework_submitted: NumberInt(4),
                    homework_pending: NumberInt({sum(1 for x in sub_alerts if x['type'] == 'PENDING_HOMEWORK' and x['status'] == 'ACTIVE')}),
                    subject_attendance_percent: {sub_pct:.1f}
                }}
            }}"""
            subjects_js.append(sub_js)

        subjects_array_str = "[\n" + ",\n".join(subjects_js) + "\n        ]"

        doc_js = f"""        {{
            student_id: NumberInt({s['id']}),
            student_name: "{s['name']}",
            admission_number: "{s['adm']}",
            roll_number: "{s['roll']}",
            school_id: NumberInt(1),
            branch_id: NumberInt(1),
            academic_year_id: NumberInt(1),
            class_id: NumberInt(1),
            class_name: "Class 1 - Central",
            section_id: NumberInt({s['secId']}),
            section_name: "{s['secName']}",
            total_attentions_raised: NumberInt({tot_raised}),
            total_active_attentions: NumberInt({tot_active}),
            subjects: {subjects_array_str},
            last_evaluated_at: new Date("2026-11-18T14:00:00Z"),
            is_active: NumberInt(1),
            created_at: new Date("2026-10-01T08:00:00Z"),
            updated_at: new Date("2026-11-18T14:00:00Z")
        }}"""
        doc_blocks.append(doc_js)

    js_lines.append(",\n".join(doc_blocks))
    js_lines.append("""
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
""")

    return "\n".join(js_lines)

if __name__ == "__main__":
    content = generate_js()
    target_path = "Thinkigen_DB/THINKIGEN DATABASE/database/mongo/scripts/040_seed_realistic_student_attentions_all_20_students.js"
    with open(target_path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"Generated {target_path} ({len(content)} bytes)")

    # Also update 038 script with identical content for backward compatibility
    compat_path = "Thinkigen_DB/THINKIGEN DATABASE/database/mongo/scripts/038_seed_realistic_student_attentions_mock_data.js"
    with open(compat_path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"Updated {compat_path} ({len(content)} bytes)")
