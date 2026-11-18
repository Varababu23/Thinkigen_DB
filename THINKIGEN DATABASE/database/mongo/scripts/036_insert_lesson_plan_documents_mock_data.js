/*
================================================================================
SCRIPT:        036_insert_lesson_plan_documents_mock_data.js
MODULE:        Teacher Portal - Lesson Plan Management
DATABASE:      Thinkigen (MongoDB Atlas / mongosh)
PURPOSE:
Comprehensive mock data seed script for `lesson_plan_documents`.
Inserts 8 production-grade documents across multiple teachers, classes, subjects,
and curriculum scopes (chapter-level, topic-level, class-wide, and soft-deleted).

COMPLIANCE & INTEGRITY:
- 100% compliant with strict $jsonSchema validator in 028_lesson_plan_documents.js.
- BSON 32-bit int (NumberInt) for all relational IDs and user IDs.
- S3 object key convention:
  lessons/{school_id}/{branch_id}/{academic_year_id}/{lesson_plan_id}/{document_id}/v{version}/{filename}
- Strictly adheres to temporal constraint (Instructional dates in Oct 2026 <= 2026-10-30).
- Idempotent execution using replaceOne(..., { upsert: true }).
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
    print("SEEDING MOCK DOCUMENTS: " + COLLECTION_NAME);
    print("Target Database: " + targetDb.getName());
    print("Timestamp:       " + new Date().toISOString());
    print("================================================================================");

    var documents = [
        // ---------------------------------------------------------------------
        // DOC 1: Science Chapter-Level Lab Guide (Class 9, Section 1, Science)
        // Teacher 1 (lesson_plan_id: 101)
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
        // DOC 2: Mathematics Topic-Level Practice Worksheet (Class 10, Section 2, Math)
        // Teacher 2 (lesson_plan_id: 102)
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
        // DOC 3: Class-Wide Term Reference Guide (Class 8, Cross-Subject & Cross-Section)
        // Teacher 3 (lesson_plan_id: 103)
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
        },

        // ---------------------------------------------------------------------
        // DOC 4: Physics Interactive Simulation Video / Media (Class 9, Section 1, Science)
        // Teacher 1 (lesson_plan_id: 104)
        // ---------------------------------------------------------------------
        {
            _id: ObjectId("6724b0000000000000000004"),
            document_id: "DOC-LP-2026-000004",
            tenant: {
                school_id: NumberInt(1),
                branch_id: NumberInt(1),
                academic_year_id: NumberInt(1)
            },
            lesson_plan: {
                lesson_plan_id: NumberInt(104),
                teacher_id: NumberInt(1)
            },
            academic_scope: {
                class_id: NumberInt(9),
                section_id: NumberInt(1),
                subject_id: NumberInt(3),
                chapter_id: "CH-02",
                topic_id: "TOP-03"
            },
            owner: {
                entity_type: "LESSON_PLAN",
                entity_id: NumberInt(104)
            },
            classification: {
                category: "LESSON_PLAN",
                sub_category: "SIMULATION_VIDEO",
                attachment_type: "MEDIA"
            },
            file: {
                original_name: "uniform_circular_motion_simulation.mp4",
                extension: "mp4",
                mime_type: "video/mp4",
                size_bytes: NumberInt(18874368),
                checksum_sha256: "b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9"
            },
            storage: {
                provider: "AWS_S3",
                bucket: "thinkigen-school-documents-private",
                object_key: "lessons/1/1/1/104/DOC-LP-2026-000004/v1/uniform_circular_motion_simulation.mp4",
                version_id: "s3.ver.phy.9.ch02.001"
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
                object_key: "lessons/1/1/1/104/DOC-LP-2026-000004/v1/previews/poster.jpg",
                mime_type: "image/jpeg"
            },
            processing: {
                status: "COMPLETED",
                processed_at: ISODate("2026-10-28T11:45:00Z"),
                processor_version: "doc-pipeline-v2.4",
                error_code: null
            },
            storage_cleanup: null,
            created_at: ISODate("2026-10-28T11:30:00Z"),
            updated_at: ISODate("2026-10-28T11:45:00Z")
        },

        // ---------------------------------------------------------------------
        // DOC 5: English Literature Analysis Reference (Class 10, Section 1, English)
        // Teacher 4 (lesson_plan_id: 105)
        // ---------------------------------------------------------------------
        {
            _id: ObjectId("6724b0000000000000000005"),
            document_id: "DOC-LP-2026-000005",
            tenant: {
                school_id: NumberInt(1),
                branch_id: NumberInt(1),
                academic_year_id: NumberInt(1)
            },
            lesson_plan: {
                lesson_plan_id: NumberInt(105),
                teacher_id: NumberInt(4)
            },
            academic_scope: {
                class_id: NumberInt(10),
                section_id: NumberInt(1),
                subject_id: NumberInt(2),
                chapter_id: "CH-03",
                topic_id: "TOP-01"
            },
            owner: {
                entity_type: "LESSON_PLAN",
                entity_id: NumberInt(105)
            },
            classification: {
                category: "LESSON_PLAN",
                sub_category: "CRITICAL_ANALYSIS",
                attachment_type: "REFERENCE"
            },
            file: {
                original_name: "the_ball_poem_poetic_devices_and_critique.pdf",
                extension: "pdf",
                mime_type: "application/pdf",
                size_bytes: NumberInt(1572864),
                checksum_sha256: "5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8"
            },
            storage: {
                provider: "AWS_S3",
                bucket: "thinkigen-school-documents-private",
                object_key: "lessons/1/1/1/105/DOC-LP-2026-000005/v1/the_ball_poem_poetic_devices_and_critique.pdf",
                version_id: null
            },
            security: {
                visibility: "RESTRICTED"
            },
            lifecycle: {
                status: "ACTIVE",
                deleted_at: null,
                deleted_by: null
            },
            uploaded_by: NumberInt(4),
            updated_by: null,
            preview: {
                available: true,
                object_key: "lessons/1/1/1/105/DOC-LP-2026-000005/v1/previews/thumb_page_1.png",
                mime_type: "image/png"
            },
            processing: {
                status: "COMPLETED",
                processed_at: ISODate("2026-10-29T09:05:00Z"),
                processor_version: "doc-pipeline-v2.4",
                error_code: null
            },
            storage_cleanup: null,
            created_at: ISODate("2026-10-29T09:00:00Z"),
            updated_at: ISODate("2026-10-29T09:05:00Z")
        },

        // ---------------------------------------------------------------------
        // DOC 6: Chemistry Chapter Presentation Slides (Class 9, Section 2, Science)
        // Teacher 1 (lesson_plan_id: 106)
        // ---------------------------------------------------------------------
        {
            _id: ObjectId("6724b0000000000000000006"),
            document_id: "DOC-LP-2026-000006",
            tenant: {
                school_id: NumberInt(1),
                branch_id: NumberInt(1),
                academic_year_id: NumberInt(1)
            },
            lesson_plan: {
                lesson_plan_id: NumberInt(106),
                teacher_id: NumberInt(1)
            },
            academic_scope: {
                class_id: NumberInt(9),
                section_id: NumberInt(2),
                subject_id: NumberInt(3),
                chapter_id: "CH-01",
                topic_id: null
            },
            owner: {
                entity_type: "LESSON_PLAN",
                entity_id: NumberInt(106)
            },
            classification: {
                category: "LESSON_PLAN",
                sub_category: "LECTURE_SLIDES",
                attachment_type: "RESOURCE"
            },
            file: {
                original_name: "matter_in_our_surroundings_presentation.pptx",
                extension: "pptx",
                mime_type: "application/vnd.openxmlformats-officedocument.presentationml.presentation",
                size_bytes: NumberInt(7340032),
                checksum_sha256: "4b227777d4dd1fc61c6f884f48641d02b4d121d3fd328cb08b5531fcacdabf8a"
            },
            storage: {
                provider: "AWS_S3",
                bucket: "thinkigen-school-documents-private",
                object_key: "lessons/1/1/1/106/DOC-LP-2026-000006/v1/matter_in_our_surroundings_presentation.pptx",
                version_id: "s3.ver.chem.9.ch01.001"
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
            updated_by: NumberInt(1),
            preview: null,
            processing: {
                status: "COMPLETED",
                processed_at: ISODate("2026-10-29T14:15:00Z"),
                processor_version: "doc-pipeline-v2.4",
                error_code: null
            },
            storage_cleanup: null,
            created_at: ISODate("2026-10-29T14:00:00Z"),
            updated_at: ISODate("2026-10-29T14:15:00Z")
        },

        // ---------------------------------------------------------------------
        // DOC 7: Computer Science Python Algorithms Resource (Class 10, Section 2, CS)
        // Teacher 5 (lesson_plan_id: 107)
        // ---------------------------------------------------------------------
        {
            _id: ObjectId("6724b0000000000000000007"),
            document_id: "DOC-LP-2026-000007",
            tenant: {
                school_id: NumberInt(1),
                branch_id: NumberInt(1),
                academic_year_id: NumberInt(1)
            },
            lesson_plan: {
                lesson_plan_id: NumberInt(107),
                teacher_id: NumberInt(5)
            },
            academic_scope: {
                class_id: NumberInt(10),
                section_id: NumberInt(2),
                subject_id: NumberInt(5),
                chapter_id: "CH-05",
                topic_id: "TOP-02"
            },
            owner: {
                entity_type: "LESSON_PLAN",
                entity_id: NumberInt(107)
            },
            classification: {
                category: "LESSON_PLAN",
                sub_category: "CODE_REPOSITORY_SNIPPET",
                attachment_type: "RESOURCE"
            },
            file: {
                original_name: "bubble_and_selection_sort_implementations.py",
                extension: "py",
                mime_type: "text/x-python",
                size_bytes: NumberInt(12288),
                checksum_sha256: "ef2d127de37b942baad06145e54b0c619a1f22327b2ebbcfbec78f5564afe39d"
            },
            storage: {
                provider: "AWS_S3",
                bucket: "thinkigen-school-documents-private",
                object_key: "lessons/1/1/1/107/DOC-LP-2026-000007/v1/bubble_and_selection_sort_implementations.py",
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
            uploaded_by: NumberInt(5),
            updated_by: null,
            preview: null,
            processing: {
                status: "NOT_REQUIRED",
                processed_at: null,
                processor_version: null,
                error_code: null
            },
            storage_cleanup: null,
            created_at: ISODate("2026-10-30T10:15:00Z"),
            updated_at: ISODate("2026-10-30T10:15:00Z")
        },

        // ---------------------------------------------------------------------
        // DOC 8: Soft-Deleted Historical Lesson Plan Document with Full Audit Trail
        // Teacher 2 (lesson_plan_id: 108)
        // Demonstrates deletion invariant & asynchronous S3 cleanup tracking
        // ---------------------------------------------------------------------
        {
            _id: ObjectId("6724b0000000000000000008"),
            document_id: "DOC-LP-2026-000008",
            tenant: {
                school_id: NumberInt(1),
                branch_id: NumberInt(1),
                academic_year_id: NumberInt(1)
            },
            lesson_plan: {
                lesson_plan_id: NumberInt(108),
                teacher_id: NumberInt(2)
            },
            academic_scope: {
                class_id: NumberInt(10),
                section_id: NumberInt(1),
                subject_id: NumberInt(1),
                chapter_id: "CH-02",
                topic_id: "TOP-01"
            },
            owner: {
                entity_type: "LESSON_PLAN",
                entity_id: NumberInt(108)
            },
            classification: {
                category: "LESSON_PLAN",
                sub_category: "OBSOLETE_DRAFT",
                attachment_type: "ATTACHMENT"
            },
            file: {
                original_name: "polynomials_intro_draft_v1.pdf",
                extension: "pdf",
                mime_type: "application/pdf",
                size_bytes: NumberInt(819200),
                checksum_sha256: "01ba4719c80b6fe911b091a7c05124b64eeece964e09c058ef8f9805daca546b"
            },
            storage: {
                provider: "AWS_S3",
                bucket: "thinkigen-school-documents-private",
                object_key: "lessons/1/1/1/108/DOC-LP-2026-000008/v1/polynomials_intro_draft_v1.pdf",
                version_id: null
            },
            security: {
                visibility: "PRIVATE"
            },
            lifecycle: {
                status: "DELETED",
                deleted_at: ISODate("2026-10-30T16:45:00Z"),
                deleted_by: NumberInt(2)
            },
            uploaded_by: NumberInt(2),
            updated_by: NumberInt(2),
            preview: null,
            processing: {
                status: "COMPLETED",
                processed_at: ISODate("2026-10-30T15:05:00Z"),
                processor_version: "doc-pipeline-v2.4",
                error_code: null
            },
            storage_cleanup: {
                status: "PENDING",
                attempts: NumberInt(0),
                last_attempt_at: null,
                last_error: null
            },
            created_at: ISODate("2026-10-30T15:00:00Z"),
            updated_at: ISODate("2026-10-30T16:45:00Z")
        }
    ];

    print("\n[STEP 1] Upserting 8 production-grade mock documents...");
    var upsertCount = 0;
    documents.forEach(function (doc, idx) {
        var res = targetDb[COLLECTION_NAME].replaceOne(
            { document_id: doc.document_id },
            doc,
            { upsert: true }
        );
        var action = (res.upsertedCount > 0) ? "INSERTED" : "UPDATED ";
        print("  [" + action + "] #" + (idx + 1) + " -> " + doc.document_id + " (" + doc.file.original_name + ") | Status: " + doc.lifecycle.status);
        upsertCount++;
    });

    // -------------------------------------------------------------------------
    // Verification & Summary
    // -------------------------------------------------------------------------
    print("\n================================================================================");
    print("MOCK DATA SEEDING COMPLETE");
    print("Collection:        " + COLLECTION_NAME);
    print("Processed Records: " + upsertCount + " documents");
    print("Active in DB:      " + targetDb[COLLECTION_NAME].countDocuments({ "lifecycle.status": "ACTIVE" }) + " ACTIVE");
    print("Soft-Deleted:      " + targetDb[COLLECTION_NAME].countDocuments({ "lifecycle.status": "DELETED" }) + " DELETED");
    print("Total in DB:       " + targetDb[COLLECTION_NAME].countDocuments() + " total");
    print("Status:            SUCCESS (100% Schema & Invariant Compliant)");
    print("================================================================================");
})();



