import sys
import os
import json
from datetime import datetime, timezone

# Add backend directory to sys.path
sys.path.append(os.path.abspath("Thinkigen_DB/THINKIGEN DATABASE/backend"))

from app.schemas.student_attentions import (
    AttentionType, TriggerSource, AttentionStatus, AttentionItemBase,
    AssessmentDetails, HomeworkDetails, AttendanceDetails,
    HomeworkSubmissionStatus, AttendancePeriodStatus,
    SubjectAttentionItem, StudentSubjectAttentionDocument, SubjectSummary
)
from app.services.student_attentions_service import generate_deterministic_attention_id

sec1_faculty = [
    {"id": 1, "name": "Keshav Kulkarni", "sid": 1, "sname": "English", "code": "ENG"},
    {"id": 8, "name": "Zara Pai", "sid": 2, "sname": "Mathematics", "code": "MAT"},
    {"id": 15, "name": "Bhuvan Solanki", "sid": 3, "sname": "Science", "code": "SCI"},
    {"id": 22, "name": "Rashmi Chopra", "sid": 4, "sname": "Social Science", "code": "SOC"},
    {"id": 29, "name": "Raghunath Mathur", "sid": 5, "sname": "Computer Science", "code": "CSC"},
    {"id": 35, "name": "Abhiram Kansal", "sid": 6, "sname": "Physical Education", "code": "PE"}
]

sec2_faculty = [
    {"id": 2, "name": "Radhika Pillai", "sid": 1, "sname": "English", "code": "ENG"},
    {"id": 9, "name": "Utkarsh Mishra", "sid": 2, "sname": "Mathematics", "code": "MAT"},
    {"id": 16, "name": "Juhi Rajput", "sid": 3, "sname": "Science", "code": "SCI"},
    {"id": 23, "name": "Kushagra Kapoor", "sid": 4, "sname": "Social Science", "code": "SOC"},
    {"id": 30, "name": "Chitra Nigam", "sid": 5, "sname": "Computer Science", "code": "CSC"},
    {"id": 35, "name": "Abhiram Kansal", "sid": 6, "sname": "Physical Education", "code": "PE"}
]

raw_students = [
    # ================= SECTION 1 (CLASS 1 - CENTRAL, SECTION A) =================
    {
        "id": 1, "name": "Karishma Shaik", "adm": "ADM-2026-0001", "roll": "R-01", "secId": 1, "secName": "A",
        "alerts": [
            {
                "sid": 2, "type": "LOW_ASSESSMENT_SCORE", "title": "Linear Equations Slip Test Below Benchmark",
                "desc": "Scored 14/50 on algebra diagnostic slip test.", "srcId": 501, "srcType": "ASSESSMENT", "status": "ACTIVE",
                "trigAt": "2026-10-28T14:30:00Z", "ackAt": "2026-10-29T08:30:00Z",
                "assessment": {"id": 501, "name": "Linear Equations Slip Test", "type": "SLIP_TEST", "max": 50.0, "pass": 20.0, "obt": 14.0, "pct": 28.0}
            },
            {
                "sid": 2, "type": "PENDING_HOMEWORK", "title": "Polynomial Algebraic Identities Exercise 3.2 Overdue",
                "desc": "Exercise 3.2 textbook problems overdue by 3 days.", "srcId": 3002, "srcType": "ASSIGNMENT_HOMEWORK", "status": "ACTIVE",
                "trigAt": "2026-10-26T08:00:00Z", "ackAt": "2026-10-27T09:00:00Z",
                "homework": {"id": 3002, "title": "Polynomial Identities Exercise 3.2", "assigned": "2026-10-20", "due": "2026-10-23", "overdue": 3, "subStatus": "PENDING"}
            },
            {
                "sid": 1, "type": "PENDING_HOMEWORK", "title": "Overdue Poetry Analysis Essay - The Road Not Taken",
                "desc": "Poetry analysis essay assigned on Oct 12 submitted late and accepted.", "srcId": 3001, "srcType": "ASSIGNMENT_HOMEWORK", "status": "RESOLVED",
                "trigAt": "2026-10-16T09:00:00Z", "ackAt": "2026-10-16T11:00:00Z", "resAt": "2026-10-18T14:30:00Z",
                "remarks": "Completed handwritten essay with annotations evaluated and accepted.",
                "homework": {"id": 3001, "title": "Poetry Analysis - The Road Not Taken", "assigned": "2026-10-12", "due": "2026-10-15", "overdue": 2, "subStatus": "LATE"}
            },
            {
                "sid": 3, "type": "ABSENT_ATTENDANCE", "title": "Period 3 Chemistry Practical Absence",
                "desc": "Absent during Acids and Bases lab practical; medical note submitted.", "srcId": 9001, "srcType": "ATTENDANCE", "status": "EXCUSED",
                "trigAt": "2026-10-15T11:00:00Z", "ackAt": "2026-10-15T11:30:00Z", "resAt": "2026-10-16T09:00:00Z",
                "excused": "Medical certificate from Central School Clinic submitted.", "remarks": "Excused by Science teacher per clinic slip.",
                "attendance": {"id": 9001, "date": "2026-10-15", "period": 3, "time": "10:15 - 11:00", "status": "ABSENT"}
            }
        ]
    },
    {
        "id": 2, "name": "Dhamodhar Rao", "adm": "ADM-2026-0002", "roll": "R-02", "secId": 1, "secName": "A",
        "alerts": [
            {
                "sid": 5, "type": "PENDING_HOMEWORK", "title": "Overdue Python Loop Programming Lab 3",
                "desc": "Loop iterations worksheet assigned Oct 23 not submitted.", "srcId": 3012, "srcType": "ASSIGNMENT_HOMEWORK", "status": "ACTIVE",
                "trigAt": "2026-10-27T08:00:00Z", "ackAt": "2026-10-28T09:00:00Z",
                "homework": {"id": 3012, "title": "Python Lab 3: Loop Iterations", "assigned": "2026-10-23", "due": "2026-10-26", "overdue": 3, "subStatus": "PENDING"}
            },
            {
                "sid": 4, "type": "PENDING_HOMEWORK", "title": "Map Work: River Systems of Southern India",
                "desc": "Geography river basin mapping assignment submitted after 1-day delay.", "srcId": 3014, "srcType": "ASSIGNMENT_HOMEWORK", "status": "RESOLVED",
                "trigAt": "2026-10-20T08:00:00Z", "ackAt": "2026-10-20T10:00:00Z", "resAt": "2026-10-22T11:00:00Z",
                "remarks": "Map coloring and key labeling checked; verified complete.",
                "homework": {"id": 3014, "title": "River Systems Mapping Portfolio", "assigned": "2026-10-16", "due": "2026-10-19", "overdue": 1, "subStatus": "LATE"}
            }
        ]
    },
    {
        "id": 3, "name": "Sita Ram", "adm": "ADM-2026-0003", "roll": "R-03", "secId": 1, "secName": "A",
        "alerts": [
            {
                "sid": 2, "type": "LOW_ASSESSMENT_SCORE", "title": "Trigonometric Ratios Slip Test Deficit",
                "desc": "Scored 12/50 on introductory trigonometry test; remedial coaching advised.", "srcId": 503, "srcType": "ASSESSMENT", "status": "ACTIVE",
                "trigAt": "2026-10-28T14:30:00Z", "ackAt": "2026-10-29T08:45:00Z",
                "assessment": {"id": 503, "name": "Trigonometric Ratios Test", "type": "SLIP_TEST", "max": 50.0, "pass": 20.0, "obt": 12.0, "pct": 24.0}
            },
            {
                "sid": 3, "type": "ABSENT_ATTENDANCE", "title": "Period 3 Science Laboratory Absence",
                "desc": "Unexcused absence during Acids & Bases experimental practical.", "srcId": 9015, "srcType": "ATTENDANCE", "status": "ACTIVE",
                "trigAt": "2026-11-05T11:00:00Z", "ackAt": "2026-11-06T08:30:00Z",
                "attendance": {"id": 9015, "date": "2026-11-05", "period": 3, "time": "10:15 - 11:00", "status": "ABSENT"}
            }
        ]
    },
    {
        "id": 4, "name": "Krupa Joseph", "adm": "ADM-2026-0004", "roll": "R-04", "secId": 1, "secName": "A",
        "alerts": [
            {
                "sid": 4, "type": "LOW_ASSESSMENT_SCORE", "title": "Indian Constitution Principles Diagnostic Retest",
                "desc": "Scored 15/40 on Indian Constitution foundational principles slip test.", "srcId": 504, "srcType": "ASSESSMENT", "status": "ACTIVE",
                "trigAt": "2026-10-27T15:00:00Z", "ackAt": "2026-10-28T09:15:00Z",
                "assessment": {"id": 504, "name": "Constitution Principles Diagnostic", "type": "SLIP_TEST", "max": 40.0, "pass": 18.0, "obt": 15.0, "pct": 37.5}
            },
            {
                "sid": 1, "type": "PENDING_HOMEWORK", "title": "Active & Passive Voice Transformation Practice Overdue",
                "desc": "Grammar transformation exercise 4.1 pending submission.", "srcId": 3020, "srcType": "ASSIGNMENT_HOMEWORK", "status": "ACTIVE",
                "trigAt": "2026-11-06T08:00:00Z", "ackAt": "2026-11-07T08:30:00Z",
                "homework": {"id": 3020, "title": "Voice Transformation Practice 4.1", "assigned": "2026-11-02", "due": "2026-11-05", "overdue": 2, "subStatus": "PENDING"}
            }
        ]
    },
    {
        "id": 5, "name": "Jeswanth Reddy", "adm": "ADM-2026-0005", "roll": "R-05", "secId": 1, "secName": "A",
        "alerts": [
            {
                "sid": 1, "type": "PENDING_HOMEWORK", "title": "Direct & Indirect Speech Exercise 5.1 Overdue",
                "desc": "Grammar transformation exercise 5.1 not submitted by due date.", "srcId": 3025, "srcType": "ASSIGNMENT_HOMEWORK", "status": "ACTIVE",
                "trigAt": "2026-11-08T08:00:00Z", "ackAt": "2026-11-09T09:00:00Z",
                "homework": {"id": 3025, "title": "Direct & Indirect Speech Exercise 5.1", "assigned": "2026-11-04", "due": "2026-11-07", "overdue": 2, "subStatus": "PENDING"}
            },
            {
                "sid": 2, "type": "PENDING_HOMEWORK", "title": "Linear Graphs Problem Set 2",
                "desc": "Graph sheet problems submitted after verification.", "srcId": 3026, "srcType": "ASSIGNMENT_HOMEWORK", "status": "RESOLVED",
                "trigAt": "2026-10-18T08:00:00Z", "ackAt": "2026-10-18T10:00:00Z", "resAt": "2026-10-20T12:00:00Z",
                "remarks": "All 5 plotted lines and intersection points verified accurate.",
                "homework": {"id": 3026, "title": "Linear Equations Graph Plotting Set", "assigned": "2026-10-14", "due": "2026-10-17", "overdue": 1, "subStatus": "LATE"}
            }
        ]
    },
    {
        "id": 6, "name": "Sravan Kumar", "adm": "ADM-2026-0006", "roll": "R-06", "secId": 1, "secName": "A",
        "alerts": [
            {
                "sid": 3, "type": "LOW_ASSESSMENT_SCORE", "title": "Force and Laws of Motion Slip Test Benchmark Deficit",
                "desc": "Scored 8/40, below passing threshold of 16 in mechanics slip test.", "srcId": 506, "srcType": "ASSESSMENT", "status": "ACTIVE",
                "trigAt": "2026-10-29T14:30:00Z", "ackAt": "2026-10-30T08:30:00Z",
                "assessment": {"id": 506, "name": "Force & Laws of Motion Test", "type": "SLIP_TEST", "max": 40.0, "pass": 16.0, "obt": 8.0, "pct": 20.0}
            },
            {
                "sid": 5, "type": "PENDING_HOMEWORK", "title": "HTML/CSS Form Creation Lab Assignment Overdue",
                "desc": "Web page form styling exercise pending upload.", "srcId": 3030, "srcType": "ASSIGNMENT_HOMEWORK", "status": "ACTIVE",
                "trigAt": "2026-11-10T08:00:00Z", "ackAt": "2026-11-11T09:00:00Z",
                "homework": {"id": 3030, "title": "HTML Form Creation Lab", "assigned": "2026-11-05", "due": "2026-11-08", "overdue": 2, "subStatus": "PENDING"}
            }
        ]
    },
    {
        "id": 7, "name": "Gaurav Joshi", "adm": "ADM-2026-0007", "roll": "R-07", "secId": 1, "secName": "A",
        "alerts": [
            {
                "sid": 3, "type": "ABSENT_ATTENDANCE", "title": "Period 2 Science Biology Microscopy Session Absence",
                "desc": "Absent during onion cell mount practical; student made up practical in zero period.", "srcId": 9020, "srcType": "ATTENDANCE", "status": "RESOLVED",
                "trigAt": "2026-10-18T10:00:00Z", "ackAt": "2026-10-18T11:00:00Z", "resAt": "2026-10-21T16:00:00Z",
                "remarks": "Slide preparation and sketch verified during zero period makeup.",
                "attendance": {"id": 9020, "date": "2026-10-18", "period": 2, "time": "09:15 - 10:00", "status": "ABSENT"}
            }
        ]
    },
    {
        "id": 8, "name": "Manish Talwar", "adm": "ADM-2026-0008", "roll": "R-08", "secId": 1, "secName": "A",
        "alerts": [
            {
                "sid": 1, "type": "LOW_ASSESSMENT_SCORE", "title": "Unseen Prose Reading Comprehension Diagnostic Below 40%",
                "desc": "Scored 15/50 on comprehension diagnostic test.", "srcId": 508, "srcType": "ASSESSMENT", "status": "ACTIVE",
                "trigAt": "2026-11-04T14:00:00Z", "ackAt": "2026-11-05T08:30:00Z",
                "assessment": {"id": 508, "name": "Reading Comprehension Diagnostic", "type": "SLIP_TEST", "max": 50.0, "pass": 20.0, "obt": 15.0, "pct": 30.0}
            }
        ]
    },
    {
        "id": 9, "name": "Zara Tiwari", "adm": "ADM-2026-0009", "roll": "R-09", "secId": 1, "secName": "A",
        "alerts": [
            {
                "sid": 2, "type": "LOW_ASSESSMENT_SCORE", "title": "Mensuration Surface Areas & Volumes Test Deficit",
                "desc": "Scored 13/50 on Mensuration diagnostic test.", "srcId": 509, "srcType": "ASSESSMENT", "status": "ACTIVE",
                "trigAt": "2026-11-05T14:30:00Z", "ackAt": "2026-11-06T08:30:00Z",
                "assessment": {"id": 509, "name": "Surface Areas Diagnostic", "type": "SLIP_TEST", "max": 50.0, "pass": 20.0, "obt": 13.0, "pct": 26.0}
            }
        ]
    },
    {
        "id": 10, "name": "Sarita Sengupta", "adm": "ADM-2026-0010", "roll": "R-10", "secId": 1, "secName": "A",
        "alerts": []
    },

    # ================= SECTION 2 (CLASS 1 - CENTRAL, SECTION B) =================
    {
        "id": 11, "name": "Gurpreet Pillai", "adm": "ADM-2026-0011", "roll": "R-01", "secId": 2, "secName": "B",
        "alerts": [
            {
                "sid": 2, "type": "LOW_ASSESSMENT_SCORE", "title": "Section B Quadratic Equation Slip Test Benchmark Deficit",
                "desc": "Scored 16/50 on algebra quadratic polynomials diagnostic slip test.", "srcId": 511, "srcType": "ASSESSMENT", "status": "ACTIVE",
                "trigAt": "2026-10-28T14:30:00Z", "ackAt": "2026-10-29T09:00:00Z",
                "assessment": {"id": 511, "name": "Section B Quadratic Diagnostic", "type": "SLIP_TEST", "max": 50.0, "pass": 20.0, "obt": 16.0, "pct": 32.0}
            },
            {
                "sid": 1, "type": "PENDING_HOMEWORK", "title": "English Reading Journal Entry 4 Late Submission",
                "desc": "Reading journal submitted 2 days late; evaluated by Radhika Pillai.", "srcId": 3040, "srcType": "ASSIGNMENT_HOMEWORK", "status": "RESOLVED",
                "trigAt": "2026-10-20T08:00:00Z", "ackAt": "2026-10-20T10:00:00Z", "resAt": "2026-10-23T14:00:00Z",
                "remarks": "Journal log checked and stamped.",
                "homework": {"id": 3040, "title": "Reading Journal Entry 4", "assigned": "2026-10-16", "due": "2026-10-19", "overdue": 2, "subStatus": "LATE"}
            }
        ]
    },
    {
        "id": 12, "name": "Deepika Pathak", "adm": "ADM-2026-0012", "roll": "R-02", "secId": 2, "secName": "B",
        "alerts": [
            {
                "sid": 1, "type": "ABSENT_ATTENDANCE", "title": "Period 1 English Literature Attendance Absence",
                "desc": "Absent without prior leave slip during Merchant of Venice introduction.", "srcId": 9032, "srcType": "ATTENDANCE", "status": "ACTIVE",
                "trigAt": "2026-11-06T09:30:00Z", "ackAt": "2026-11-07T08:30:00Z",
                "attendance": {"id": 9032, "date": "2026-11-06", "period": 1, "time": "08:30 - 09:15", "status": "ABSENT"}
            }
        ]
    },
    {
        "id": 13, "name": "Varun Venkataraman", "adm": "ADM-2026-0013", "roll": "R-03", "secId": 2, "secName": "B",
        "alerts": [
            {
                "sid": 3, "type": "PENDING_HOMEWORK", "title": "Physics Ray Optics Diagram Portfolio Overdue",
                "desc": "Refraction ray diagrams lab homework not submitted.", "srcId": 3045, "srcType": "ASSIGNMENT_HOMEWORK", "status": "ACTIVE",
                "trigAt": "2026-11-09T08:00:00Z", "ackAt": "2026-11-10T09:00:00Z",
                "homework": {"id": 3045, "title": "Ray Optics Lab Homework Portfolio", "assigned": "2026-11-04", "due": "2026-11-07", "overdue": 2, "subStatus": "PENDING"}
            }
        ]
    },
    {
        "id": 14, "name": "Reena Mitra", "adm": "ADM-2026-0014", "roll": "R-04", "secId": 2, "secName": "B",
        "alerts": [
            {
                "sid": 4, "type": "LOW_ASSESSMENT_SCORE", "title": "Medieval Indian Architecture Map Test Re-evaluation",
                "desc": "Scored 13/40 on Mughal architecture and monuments mapping evaluation.", "srcId": 514, "srcType": "ASSESSMENT", "status": "ACTIVE",
                "trigAt": "2026-11-08T14:30:00Z", "ackAt": "2026-11-09T09:00:00Z",
                "assessment": {"id": 514, "name": "Mughal Architecture Map Test", "type": "SLIP_TEST", "max": 40.0, "pass": 18.0, "obt": 13.0, "pct": 32.5}
            }
        ]
    },
    {
        "id": 15, "name": "Sangeeta Ghosh", "adm": "ADM-2026-0015", "roll": "R-05", "secId": 2, "secName": "B",
        "alerts": []
    },
    {
        "id": 16, "name": "Uma Asthana", "adm": "ADM-2026-0016", "roll": "R-06", "secId": 2, "secName": "B",
        "alerts": [
            {
                "sid": 2, "type": "PENDING_HOMEWORK", "title": "Coordinate Geometry Distance Formula Practice 7.2 Overdue",
                "desc": "Coordinate geometry exercises 7.2 not submitted by deadline.", "srcId": 3052, "srcType": "ASSIGNMENT_HOMEWORK", "status": "ACTIVE",
                "trigAt": "2026-11-15T08:00:00Z", "ackAt": "2026-11-16T09:00:00Z",
                "homework": {"id": 3052, "title": "Coordinate Geometry Practice 7.2", "assigned": "2026-11-11", "due": "2026-11-14", "overdue": 2, "subStatus": "PENDING"}
            },
            {
                "sid": 3, "type": "ABSENT_ATTENDANCE", "title": "Period 4 Physics Energy & Work Lab Practical Absence",
                "desc": "Absent during mechanical kinetic energy demonstration; makeup completed.", "srcId": 9045, "srcType": "ATTENDANCE", "status": "RESOLVED",
                "trigAt": "2026-11-03T12:00:00Z", "ackAt": "2026-11-03T14:00:00Z", "resAt": "2026-11-06T16:00:00Z",
                "remarks": "Completed pendulum experiment calculations during makeup hour.",
                "attendance": {"id": 9045, "date": "2026-11-03", "period": 4, "time": "11:15 - 12:00", "status": "ABSENT"}
            }
        ]
    },
    {
        "id": 17, "name": "Nikhil Acharya", "adm": "ADM-2026-0017", "roll": "R-07", "secId": 2, "secName": "B",
        "alerts": [
            {
                "sid": 5, "type": "LOW_ASSESSMENT_SCORE", "title": "Python User-Defined Functions Slip Test Deficit",
                "desc": "Scored 9/30 on functions and scope evaluation test.", "srcId": 517, "srcType": "ASSESSMENT", "status": "ACTIVE",
                "trigAt": "2026-11-10T14:00:00Z", "ackAt": "2026-11-11T08:45:00Z",
                "assessment": {"id": 517, "name": "Python Functions Slip Test", "type": "SLIP_TEST", "max": 30.0, "pass": 12.0, "obt": 9.0, "pct": 30.0}
            },
            {
                "sid": 4, "type": "PENDING_HOMEWORK", "title": "Climatic Zones of India Chart Presentation",
                "desc": "Climate zones chart submission delayed; evaluated and verified.", "srcId": 3058, "srcType": "ASSIGNMENT_HOMEWORK", "status": "RESOLVED",
                "trigAt": "2026-10-29T08:00:00Z", "ackAt": "2026-10-29T10:00:00Z", "resAt": "2026-10-31T15:00:00Z",
                "remarks": "All climatic zones colored and annual rainfall statistics annotated correctly.",
                "homework": {"id": 3058, "title": "Climatic Zones of India Project", "assigned": "2026-10-25", "due": "2026-10-28", "overdue": 1, "subStatus": "LATE"}
            }
        ]
    },
    {
        "id": 18, "name": "Kavya Sidhu", "adm": "ADM-2026-0018", "roll": "R-08", "secId": 2, "secName": "B",
        "alerts": [
            {
                "sid": 1, "type": "LOW_ASSESSMENT_SCORE", "title": "Formal Business & Editorial Letter Writing Test",
                "desc": "Scored 14/40, below standard formatting pass criteria.", "srcId": 518, "srcType": "ASSESSMENT", "status": "ACTIVE",
                "trigAt": "2026-11-12T14:30:00Z", "ackAt": "2026-11-13T09:00:00Z",
                "assessment": {"id": 518, "name": "Formal Letter Writing Assessment", "type": "SLIP_TEST", "max": 40.0, "pass": 18.0, "obt": 14.0, "pct": 35.0}
            },
            {
                "sid": 2, "type": "ABSENT_ATTENDANCE", "title": "Period 2 Mathematics Algebra Session Absence",
                "desc": "Excused absence due to sanctioned dental appointment.", "srcId": 9055, "srcType": "ATTENDANCE", "status": "EXCUSED",
                "trigAt": "2026-11-09T10:00:00Z", "ackAt": "2026-11-09T11:00:00Z", "resAt": "2026-11-10T09:00:00Z",
                "excused": "Dental procedure appointment slip approved by Class Teacher.", "remarks": "Doctor clinic slip verified.",
                "attendance": {"id": 9055, "date": "2026-11-09", "period": 2, "time": "09:15 - 10:00", "status": "ABSENT"}
            }
        ]
    },
    {
        "id": 19, "name": "Suresh Banerjee", "adm": "ADM-2026-0019", "roll": "R-09", "secId": 2, "secName": "B",
        "alerts": [
            {
                "sid": 3, "type": "PENDING_HOMEWORK", "title": "Balancing Chemical Reactions Equation Balancing Practice",
                "desc": "Chemical stoichiometry equations practice set overdue by 2 days.", "srcId": 3065, "srcType": "ASSIGNMENT_HOMEWORK", "status": "ACTIVE",
                "trigAt": "2026-11-17T08:00:00Z", "ackAt": "2026-11-17T09:30:00Z",
                "homework": {"id": 3065, "title": "Chemical Reactions Balancing Worksheet", "assigned": "2026-11-13", "due": "2026-11-16", "overdue": 2, "subStatus": "PENDING"}
            }
        ]
    },
    {
        "id": 20, "name": "Nakul Chatterjee", "adm": "ADM-2026-0020", "roll": "R-10", "secId": 2, "secName": "B",
        "alerts": []
    }
]

print("Validating all 20 students against Pydantic schema...")
validated_documents = []

for s in raw_students:
    faculty_list = sec1_faculty if s["secId"] == 1 else sec2_faculty
    subjects_items = []

    for fac in faculty_list:
        sub_alerts = [a for a in s["alerts"] if a["sid"] == fac["sid"]]
        att_items = []

        for a in sub_alerts:
            # Deterministic ID
            trig_src = TriggerSource(a["srcType"])
            att_id = generate_deterministic_attention_id(s["id"], trig_src, a["srcId"], 1)

            # Build details
            asm_details = None
            hw_details = None
            att_details = None

            if trig_src == TriggerSource.ASSESSMENT:
                asm = a["assessment"]
                asm_details = AssessmentDetails(
                    assessment_id=asm["id"],
                    assessment_name=asm["name"],
                    exam_type=asm.get("type"),
                    max_marks=asm["max"],
                    pass_marks=asm["pass"],
                    obtained_marks=asm["obt"],
                    percentage=asm["pct"]
                )
            elif trig_src == TriggerSource.ASSIGNMENT_HOMEWORK:
                hw = a["homework"]
                hw_details = HomeworkDetails(
                    homework_id=hw["id"],
                    homework_title=hw["title"],
                    assigned_date=datetime.fromisoformat(hw["assigned"] + "T08:00:00Z"),
                    due_date=datetime.fromisoformat(hw["due"] + "T16:00:00Z"),
                    days_overdue=hw.get("overdue"),
                    submission_status=HomeworkSubmissionStatus(hw["subStatus"])
                )
            elif trig_src == TriggerSource.ATTENDANCE:
                att = a["attendance"]
                att_details = AttendanceDetails(
                    attendance_id=att["id"],
                    attendance_date=datetime.fromisoformat(att["date"] + "T00:00:00Z"),
                    period_number=att["period"],
                    period_time=att.get("time"),
                    attendance_status=AttendancePeriodStatus(att["status"])
                )

            item = AttentionItemBase(
                attention_id=att_id,
                attention_type=AttentionType(a["type"]),
                title=a["title"],
                description=a["desc"],
                trigger_source=trig_src,
                source_id=a["srcId"],
                triggered_at=datetime.fromisoformat(a["trigAt"]),
                status=AttentionStatus(a["status"]),
                acknowledged_at=datetime.fromisoformat(a["ackAt"]) if a.get("ackAt") else None,
                acknowledged_by_teacher_id=fac["id"] if a.get("ackAt") else None,
                resolved_at=datetime.fromisoformat(a["resAt"]) if a.get("resAt") else None,
                resolved_by_teacher_id=fac["id"] if a.get("resAt") else None,
                resolution_remarks=a.get("remarks"),
                excused_reason=a.get("excused"),
                assessment_details=asm_details,
                homework_details=hw_details,
                attendance_details=att_details
            )
            att_items.append(item)

        # Subject Summary
        summary = SubjectSummary(
            assessments_passed=3 if len([x for x in att_items if x.attention_type == AttentionType.LOW_ASSESSMENT_SCORE]) == 0 else 2,
            assessments_failed=len([x for x in att_items if x.attention_type == AttentionType.LOW_ASSESSMENT_SCORE]),
            homework_submitted=4,
            homework_pending=len([x for x in att_items if x.attention_type == AttentionType.PENDING_HOMEWORK and x.status == AttentionStatus.ACTIVE]),
            subject_attendance_percent=92.5 if len([x for x in att_items if x.attention_type == AttentionType.ABSENT_ATTENDANCE]) > 0 else 98.0
        )

        sub_item = SubjectAttentionItem(
            subject_id=fac["sid"],
            subject_name=fac["sname"],
            subject_code=fac["code"],
            assigned_teacher_id=fac["id"],
            assigned_teacher_name=fac["name"],
            total_attentions_raised=len(att_items),
            active_attentions_count=sum(1 for x in att_items if x.status == AttentionStatus.ACTIVE),
            attentions=att_items,
            subject_summary=summary
        )
        subjects_items.append(sub_item)

    doc = StudentSubjectAttentionDocument(
        student_id=s["id"],
        student_name=s["name"],
        admission_number=s["adm"],
        roll_number=s["roll"],
        school_id=1,
        branch_id=1,
        academic_year_id=1,
        class_id=1,
        class_name="Class 1 - Central",
        section_id=s["secId"],
        section_name=s["secName"],
        total_attentions_raised=0,
        total_active_attentions=0,
        subjects=subjects_items,
        last_evaluated_at=datetime(2026, 11, 18, 14, 0, 0, tzinfo=timezone.utc),
        is_active=1,
        created_at=datetime(2026, 10, 1, 8, 0, 0, tzinfo=timezone.utc),
        updated_at=datetime(2026, 11, 18, 14, 0, 0, tzinfo=timezone.utc)
    )
    doc.recalculate_counts()
    validated_documents.append(doc)

print(f"Successfully validated all {len(validated_documents)} documents!")
for d in validated_documents:
    print(f"  Student {d.student_id:02d} ({d.student_name}, Sec {d.section_name}): Total: {d.total_attentions_raised} | Active: {d.total_active_attentions}")
