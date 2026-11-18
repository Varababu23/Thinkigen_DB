/*
================================================================================
SCRIPT:        033_insert_sample_lesson_plan_documents.js
MODULE:        Teacher Portal - Lesson Plan Management
DATABASE:      Thinkigen (MongoDB Atlas / mongosh)
PURPOSE:
Inserts 3 production-grade sample documents satisfying all validator constraints:
1. Science chapter-level resource (Class 9, Science, Chapter "CH-04", topic_id: null).
2. Mathematics topic-level attachment (Class 10, Mathematics, Chapter "CH-01", Topic "TOP-01").
3. Class-wide reference document (Class 8, cross-subject & cross-section guide).

Each sample contains every supported top-level field with valid types or null,
illustrative identifiers, and placeholder SHA-256 checksums.
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
    print("INSERTING SAMPLE LESSON PLAN DOCUMENTS INTO: " + COLLECTION_NAME);
    print("Database:  " + targetDb.getName());
    print("Timestamp: " + new Date().toISOString());
    print("================================================================================");

    var sampleDocuments = [
        // ---------------------------------------------------------------------
        // SAMPLE 1: Science Chapter-Level Resource (Class 9, Science, Chapter "CH-04")
        // ---------------------------------------------------------------------
        {
            _id: ObjectId("6724b0000000000000000001"),
            document_id: "DOC-LP-2026-000001",
            tenant: {
                school_id: NumberInt(1),
                branch_id: NumberInt(1),
                academic_year_id: NumberInt(1)
            },
            lesson_plan: {
                lesson_plan_id: NumberInt(101),
                teacher_id: NumberInt(1)
            },
            academic_scope: {
                class_id: NumberInt(9),
                section_id: NumberInt(1),
                subject_id: NumberInt(3),
                chapter_id: "CH-04",
                topic_id: null
            },
            owner: {
                entity_type: "LESSON_PLAN",
                entity_id: NumberInt(101)
            },
            classification: {
                category: "LESSON_PLAN",
                sub_category: "LAB_EXPERIMENT_GUIDE",
                attachment_type: "RESOURCE"
            },
            file: {
                original_name: "rutherford_alpha_scattering_lab_guide.pdf",
                extension: "pdf",
                mime_type: "application/pdf",
                size_bytes: NumberInt(2457600),
                checksum_sha256: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
            },
            storage: {
                provider: "AWS_S3",
                bucket: "thinkigen-school-documents-private",
                object_key: "lessons/1/1/1/101/DOC-LP-2026-000001/v1/rutherford_alpha_scattering_lab_guide.pdf",
                version_id: "s3.ver.sci.9.ch04.001"
            },
            security: {
                visibility: "RESTRICTED"
            },
            lifecycle: {
                status: "ACTIVE",
                deleted_at: null,
                deleted_by: null
            },
            uploaded_by: NumberInt(1),
            updated_by: null,
            preview: {
                available: true,
                object_key: "lessons/1/1/1/101/DOC-LP-2026-000001/v1/previews/thumb_page_1.png",
                mime_type: "image/png"
            },
            processing: {
                status: "COMPLETED",
                processed_at: ISODate("2026-10-26T08:35:00Z"),
                processor_version: "doc-pipeline-v2.4",
                error_code: null
            },
            storage_cleanup: null,
            created_at: ISODate("2026-10-26T08:30:00Z"),
            updated_at: ISODate("2026-10-26T08:35:00Z")
        },

        // ---------------------------------------------------------------------
        // SAMPLE 2: Mathematics Topic-Level Attachment (Class 10, Chapter "CH-01", Topic "TOP-01")
        // ---------------------------------------------------------------------
        {
            _id: ObjectId("6724b0000000000000000002"),
            document_id: "DOC-LP-2026-000002",
            tenant: {
                school_id: NumberInt(1),
                branch_id: NumberInt(1),
                academic_year_id: NumberInt(1)
            },
            lesson_plan: {
                lesson_plan_id: NumberInt(102),
                teacher_id: NumberInt(2)
            },
            academic_scope: {
                class_id: NumberInt(10),
                section_id: NumberInt(2),
                subject_id: NumberInt(1),
                chapter_id: "CH-01",
                topic_id: "TOP-01"
            },
            owner: {
                entity_type: "LESSON_PLAN",
                entity_id: NumberInt(102)
            },
            classification: {
                category: "LESSON_PLAN",
                sub_category: "PRACTICE_WORKSHEET",
                attachment_type: "ATTACHMENT"
            },
            file: {
                original_name: "euclid_division_lemma_problem_set_v2.docx",
                extension: "docx",
                mime_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                size_bytes: NumberInt(1048576),
                checksum_sha256: "875704a29a00824b0d0023a416a927a44f248eec13e9a7e0996c4d8e87e148e6"
            },
            storage: {
                provider: "AWS_S3",
                bucket: "thinkigen-school-documents-private",
                object_key: "lessons/1/1/1/102/DOC-LP-2026-000002/v1/euclid_division_lemma_problem_set_v2.docx",
                version_id: "s3.ver.math.10.ch01.002"
            },
            security: {
                visibility: "RESTRICTED"
            },
            lifecycle: {
                status: "ACTIVE",
                deleted_at: null,
                deleted_by: null
            },
            uploaded_by: NumberInt(2),
            updated_by: NumberInt(2),
            preview: null,
            processing: {
                status: "COMPLETED",
                processed_at: ISODate("2026-10-27T09:12:00Z"),
                processor_version: "doc-pipeline-v2.4",
                error_code: null
            },
            storage_cleanup: null,
            created_at: ISODate("2026-10-27T09:10:00Z"),
            updated_at: ISODate("2026-10-27T09:15:00Z")
        },

        // ---------------------------------------------------------------------
        // SAMPLE 3: Class-Wide Reference Document (Class 8, Cross-Subject & Cross-Section)
        // ---------------------------------------------------------------------
        {
            _id: ObjectId("6724b0000000000000000003"),
            document_id: "DOC-LP-2026-000003",
            tenant: {
                school_id: NumberInt(1),
                branch_id: NumberInt(1),
                academic_year_id: NumberInt(1)
            },
            lesson_plan: {
                lesson_plan_id: NumberInt(103),
                teacher_id: NumberInt(3)
            },
            academic_scope: {
                class_id: NumberInt(8),
                section_id: null,
                subject_id: null,
                chapter_id: null,
                topic_id: null
            },
            owner: {
                entity_type: "LESSON_PLAN",
                entity_id: NumberInt(103)
            },
            classification: {
                category: "LESSON_PLAN",
                sub_category: "ACADEMIC_ORIENTATION",
                attachment_type: "REFERENCE"
            },
            file: {
                original_name: "class8_term1_curriculum_and_pedagogy_guide.pdf",
                extension: "pdf",
                mime_type: "application/pdf",
                size_bytes: NumberInt(5242880),
                checksum_sha256: "ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb"
            },
            storage: {
                provider: "AWS_S3",
                bucket: "thinkigen-school-documents-private",
                object_key: "lessons/1/1/1/103/DOC-LP-2026-000003/v1/class8_term1_curriculum_and_pedagogy_guide.pdf",
                version_id: null
            },
            security: {
                visibility: "PUBLIC"
            },
            lifecycle: {
                status: "ACTIVE",
                deleted_at: null,
                deleted_by: null
            },
            uploaded_by: NumberInt(3),
            updated_by: null,
            preview: {
                available: true,
                object_key: "lessons/1/1/1/103/DOC-LP-2026-000003/v1/previews/thumb_cover.jpg",
                mime_type: "image/jpeg"
            },
            processing: {
                status: "NOT_REQUIRED",
                processed_at: null,
                processor_version: null,
                error_code: null
            },
            storage_cleanup: null,
            created_at: ISODate("2026-10-28T10:00:00Z"),
            updated_at: ISODate("2026-10-28T10:00:00Z")
        }
    ];

    sampleDocuments.forEach(function (doc, idx) {
        var res = targetDb[COLLECTION_NAME].replaceOne(
            { document_id: doc.document_id },
            doc,
            { upsert: true }
        );
        var action = res.upsertedCount > 0 ? "INSERTED" : "UPDATED";
        print("  [" + action + "] Sample #" + (idx + 1) + " -> " + doc.document_id + " (" + doc.file.original_name + ")");
    });

    print("\n[VERIFICATION] Total documents in " + COLLECTION_NAME + ": " + targetDb[COLLECTION_NAME].countDocuments());
    print("[SUCCESS] All 3 sample lesson plan documents successfully seeded.");
})();

