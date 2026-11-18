# Thinkigen Database — Full Table Reference

Generated from SQL module migrations `001`–`017`.

Related: [mongodb-collections-reference.md](./mongodb-collections-reference.md) · [conventions.md](./conventions.md)

## How to read

| Marker | Meaning |
|--------|---------|
| PK | Primary key (unique row ID, clustered) |
| FK | Foreign key |
| UNIQUE | Duplicate values not allowed |
| CHECK | Allowed values / business rules |
| row_version | SQL Server concurrency protection |

## Date/time API formats

| SQL type | API format |
|----------|------------|
| `DATETIME2(0)` | `2026-07-17T14:00:00` (stored UTC) |
| `DATE` | `2026-07-18` |
| `TIME(0)` | `14:00:00` |

## Table index

### `alumni_schema` (2 tables)

- `alumni_schema.alumni_profile`
- `alumni_schema.alumni_story`

### `finance_schema` (3 tables)

- `finance_schema.fee_payment_transaction`
- `finance_schema.fee_structure_term`
- `finance_schema.student_fee_record`

### `library_schema` (3 tables)

- `library_schema.library_book`
- `library_schema.library_book_borrow`
- `library_schema.library_book_copy`

### `management_schema` (14 tables)

- `management_schema.academic_year`
- `management_schema.announcement`
- `management_schema.branch`
- `management_schema.class_subject`
- `management_schema.exam`
- `management_schema.exam_schedule`
- `management_schema.grievance_department`
- `management_schema.holiday`
- `management_schema.school`
- `management_schema.school_class`
- `management_schema.section`
- `management_schema.subject`
- `management_schema.timetable`
- `management_schema.timetable_period`

### `security_schema` (3 tables)

- `security_schema.schema_version`
- `security_schema.user_login_attempt`
- `security_schema.users`

### `sports_schema` (1 tables)

- `sports_schema.student_sport_history`

### `student_schema` (15 tables)

- `student_schema.assessment_result`
- `student_schema.exam_result`
- `student_schema.grievance`
- `student_schema.grievance_history`
- `student_schema.homework_status`
- `student_schema.student`
- `student_schema.student_achievement`
- `student_schema.student_attendance`
- `student_schema.student_cultural_participation`
- `student_schema.student_exam_performance`
- `student_schema.student_guardian`
- `student_schema.student_leave`
- `student_schema.student_leave_status_history`
- `student_schema.student_personality_development`
- `student_schema.student_personality_development_review`

### `teachers_schema` (11 tables)

- `teachers_schema.assessment`
- `teachers_schema.homework`
- `teachers_schema.section_class_teacher_assignment`
- `teachers_schema.teacher`
- `teachers_schema.teacher_attendance`
- `teachers_schema.teacher_grievance`
- `teachers_schema.teacher_grievance_status_history`
- `teachers_schema.teacher_leave_allowance`
- `teachers_schema.teacher_leave_application`
- `teachers_schema.teacher_leave_status_history`
- `teachers_schema.teacher_subject_assignment`

**Total: 52 tables**

## `alumni_schema`

### `alumni_schema.alumni_profile`

- **Migration:** `020_alumni.sql`
- **Purpose:** Alumni Management Module (SSMS)

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `alumni_id` | `BIGINT` | NOT NULL |  |
| `school_id` | `BIGINT` | NOT NULL | School scope FK |
| `branch_id` | `BIGINT` | NOT NULL | Branch scope FK |
| `academic_year_id` | `BIGINT` | NOT NULL | Academic year FK |
| `class_id` | `BIGINT` | NOT NULL | Class FK |
| `section_id` | `BIGINT` | NOT NULL | Section FK |
| `student_id` | `BIGINT` | NOT NULL | Student FK |
| `passout_batch_year` | `INT` | NOT NULL |  |
| `current_role` | `NVARCHAR(150)` | NULL |  |
| `organisation_name` | `NVARCHAR(150)` | NULL |  |
| `industry_name` | `NVARCHAR(100)` | NULL |  |
| `location_city` | `NVARCHAR(100)` | NULL |  |
| `location_country` | `NVARCHAR(100)` | NULL |  |
| `linkedin_profile_url` | `NVARCHAR(500)` | NULL |  |
| `verification_status` | `NVARCHAR(20)` | NOT NULL |  |
| `verified_at` | `DATETIME2(0)` | NULL |  |
| `verified_by` | `BIGINT` | NULL |  |
| `profile_photo_url` | `NVARCHAR(500)` | NULL |  |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NOT NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_alumni_profile PRIMARY KEY CLUSTERED (alumni_id)`
- `CONSTRAINT UQ_alumni_profile_student UNIQUE NONCLUSTERED (student_id)`
- `CONSTRAINT CK_alumni_profile_status CHECK (verification_status IN (N'PENDING', N'VERIFIED', N'REJECTED'))`
- `CONSTRAINT CK_alumni_profile_batch CHECK (passout_batch_year BETWEEN 1950 AND 2100)`
- `CONSTRAINT FK_alumni_profile_student FOREIGN KEY (student_id) REFERENCES student_schema.student (student_id)`
- `CONSTRAINT FK_alumni_profile_school FOREIGN KEY (school_id) REFERENCES management_schema.school (school_id)`
- `CONSTRAINT FK_alumni_profile_branch FOREIGN KEY (branch_id) REFERENCES management_schema.branch (branch_id)`
- `CONSTRAINT FK_alumni_profile_academic_year FOREIGN KEY (academic_year_id) REFERENCES management_schema.academic_year (academic_year_id)`
- `CONSTRAINT FK_alumni_profile_class FOREIGN KEY (class_id) REFERENCES management_schema.school_class (class_id)`
- `CONSTRAINT FK_alumni_profile_section FOREIGN KEY (section_id) REFERENCES management_schema.section (section_id)`
- `CONSTRAINT FK_alumni_profile_verified_by FOREIGN KEY (verified_by) REFERENCES security_schema.users (user_id)`
- `CONSTRAINT FK_alumni_profile_created_by FOREIGN KEY (created_by) REFERENCES security_schema.users (user_id)`
- `CONSTRAINT FK_alumni_profile_updated_by FOREIGN KEY (updated_by) REFERENCES security_schema.users (user_id)`

**Indexes**

- `IX_alumni_profile_school_status`
- `IX_alumni_profile_batch`
- `IX_alumni_profile_scope`

### `alumni_schema.alumni_story`

- **Migration:** `020_alumni.sql`
- **Purpose:** Alumni Management Module (SSMS)

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `alumni_story_id` | `BIGINT` | NOT NULL |  |
| `school_id` | `BIGINT` | NOT NULL | School scope FK |
| `branch_id` | `BIGINT` | NOT NULL | Branch scope FK |
| `alumni_id` | `BIGINT` | NOT NULL |  |
| `story_title` | `NVARCHAR(200)` | NOT NULL |  |
| `story_content` | `NVARCHAR(MAX)` | NOT NULL |  |
| `is_published` | `BIT` | NOT NULL |  |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NOT NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_alumni_story PRIMARY KEY CLUSTERED (alumni_story_id)`
- `CONSTRAINT FK_alumni_story_alumni FOREIGN KEY (alumni_id) REFERENCES alumni_schema.alumni_profile (alumni_id)`
- `CONSTRAINT FK_alumni_story_school FOREIGN KEY (school_id) REFERENCES management_schema.school (school_id)`
- `CONSTRAINT FK_alumni_story_branch FOREIGN KEY (branch_id) REFERENCES management_schema.branch (branch_id)`
- `CONSTRAINT FK_alumni_story_created_by FOREIGN KEY (created_by) REFERENCES security_schema.users (user_id)`
- `CONSTRAINT FK_alumni_story_updated_by FOREIGN KEY (updated_by) REFERENCES security_schema.users (user_id)`

**Indexes**

- `IX_alumni_story_school_pub`

## `finance_schema`

### `finance_schema.fee_payment_transaction`

- **Migration:** `016_finance.sql`
- **Purpose:** Thinkigen module table

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `fee_payment_transaction_id` | `BIGINT` | NOT NULL |  |
| `student_fee_record_id` | `BIGINT` | NOT NULL |  |
| `school_id` | `BIGINT` | NOT NULL | School scope FK |
| `branch_id` | `BIGINT` | NOT NULL | Branch scope FK |
| `academic_year_id` | `BIGINT` | NOT NULL | Academic year FK |
| `student_id` | `BIGINT` | NOT NULL | Student FK |
| `class_id` | `BIGINT` | NOT NULL | Class FK |
| `section_id` | `BIGINT` | NOT NULL | Section FK |
| `fee_type` | `NVARCHAR(20)` | NOT NULL |  |
| `term_number` | `TINYINT` | NULL |  |
| `transaction_type` | `NVARCHAR(20)` | NOT NULL |  |
| `status` | `NVARCHAR(20)` | NOT NULL |  |
| `amount` | `DECIMAL(12,2)` | NOT NULL |  |
| `receipt_number` | `NVARCHAR(20)` | NOT NULL |  |
| `payment_method` | `NVARCHAR(20)` | NOT NULL |  |
| `payment_gateway` | `NVARCHAR(50)` | NULL |  |
| `gateway_transaction_id` | `NVARCHAR(100)` | NULL |  |
| `transaction_reference` | `NVARCHAR(100)` | NULL |  |
| `parent_transaction_id` | `BIGINT` | NULL |  |
| `remarks` | `NVARCHAR(500)` | NULL |  |
| `paid_at` | `DATETIME2(0)` | NOT NULL |  |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NOT NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_fee_payment_transaction PRIMARY KEY CLUSTERED (fee_payment_transaction_id)`
- `CONSTRAINT CK_fee_payment_transaction_amount CHECK (amount > 0)`
- `CONSTRAINT CK_fee_payment_transaction_fee_type CHECK (fee_type IN (N'TUITION', N'HOSTEL', N'TRANSPORT', N'OTHER'))`
- `CONSTRAINT CK_fee_payment_transaction_term CHECK (`
- `CONSTRAINT CK_fee_payment_transaction_type CHECK (transaction_type IN (N'PAYMENT', N'REFUND'))`
- `CONSTRAINT CK_fee_payment_transaction_status CHECK (status IN (N'PENDING', N'SUCCESS', N'FAILED', N'CANCELLED'))`
- `CONSTRAINT CK_fee_payment_transaction_method CHECK (payment_method IN (N'CASH', N'CARD', N'UPI', N'BANK_TRANSFER', N'CHEQUE', N'ONLINE'))`
- `CONSTRAINT CK_fee_payment_transaction_receipt CHECK (`
- `CONSTRAINT CK_fee_payment_transaction_refund_parent CHECK (`
- `CONSTRAINT FK_fee_payment_transaction_parent FOREIGN KEY (parent_transaction_id)`
- `CONSTRAINT FK_fee_payment_transaction_record FOREIGN KEY (`
- `CONSTRAINT FK_fee_payment_transaction_school FOREIGN KEY (school_id)`
- `CONSTRAINT FK_fee_payment_transaction_branch_scope FOREIGN KEY (school_id, branch_id)`
- `CONSTRAINT FK_fee_payment_transaction_year_scope FOREIGN KEY (school_id, academic_year_id)`
- `CONSTRAINT FK_fee_payment_transaction_class_scope FOREIGN KEY (school_id, class_id)`
- `CONSTRAINT FK_fee_payment_transaction_section_scope FOREIGN KEY (class_id, section_id)`
- `CONSTRAINT FK_fee_payment_transaction_student FOREIGN KEY (student_id)`
- `CONSTRAINT FK_fee_payment_transaction_created_by FOREIGN KEY (created_by)`
- `CONSTRAINT FK_fee_payment_transaction_updated_by FOREIGN KEY (updated_by)`

**Indexes**

- `UX_fee_payment_transaction_receipt`
- `IX_fee_payment_transaction_student_created`
- `IX_fee_payment_transaction_record_created`
- `IX_fee_payment_transaction_type`
- `IX_fee_payment_transaction_gateway`
- `IX_fee_payment_transaction_parent`

### `finance_schema.fee_structure_term`

- **Migration:** `016_finance.sql`
- **Purpose:** Thinkigen module table

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `fee_structure_term_id` | `BIGINT` | NOT NULL |  |
| `school_id` | `BIGINT` | NOT NULL | School scope FK |
| `branch_id` | `BIGINT` | NOT NULL | Branch scope FK |
| `academic_year_id` | `BIGINT` | NOT NULL | Academic year FK |
| `class_id` | `BIGINT` | NOT NULL | Class FK |
| `total_amount` | `DECIMAL(12,2)` | NOT NULL |  |
| `term1_amount` | `DECIMAL(12,2)` | NOT NULL |  |
| `term1_due_date` | `DATE` | NOT NULL |  |
| `term2_amount` | `DECIMAL(12,2)` | NOT NULL |  |
| `term2_due_date` | `DATE` | NOT NULL |  |
| `term3_amount` | `DECIMAL(12,2)` | NOT NULL |  |
| `term3_due_date` | `DATE` | NOT NULL |  |
| `status` | `NVARCHAR(20)` | NOT NULL |  |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NOT NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_fee_structure_term PRIMARY KEY CLUSTERED (fee_structure_term_id)`
- `CONSTRAINT UQ_fee_structure_term_scope UNIQUE NONCLUSTERED (fee_structure_term_id, school_id, branch_id, academic_year_id, class_id)`
- `CONSTRAINT CK_fee_structure_term_amounts CHECK (`
- `CONSTRAINT CK_fee_structure_term_status CHECK (status IN (N'DRAFT', N'ACTIVE', N'INACTIVE'))`
- `CONSTRAINT CK_fee_structure_term_due_dates CHECK (term2_due_date >= term1_due_date AND term3_due_date >= term2_due_date)`
- `CONSTRAINT FK_fee_structure_term_school FOREIGN KEY (school_id)`
- `CONSTRAINT FK_fee_structure_term_branch_scope FOREIGN KEY (school_id, branch_id)`
- `CONSTRAINT FK_fee_structure_term_year_scope FOREIGN KEY (school_id, academic_year_id)`
- `CONSTRAINT FK_fee_structure_term_class_scope FOREIGN KEY (school_id, class_id)`
- `CONSTRAINT FK_fee_structure_term_created_by FOREIGN KEY (created_by)`
- `CONSTRAINT FK_fee_structure_term_updated_by FOREIGN KEY (updated_by)`

**Indexes**

- `UX_fee_structure_term_active_scope`
- `IX_fee_structure_term_active_lookup`

### `finance_schema.student_fee_record`

- **Migration:** `016_finance.sql`
- **Purpose:** Thinkigen module table

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `student_fee_record_id` | `BIGINT` | NOT NULL |  |
| `fee_structure_term_id` | `BIGINT` | NOT NULL |  |
| `school_id` | `BIGINT` | NOT NULL | School scope FK |
| `branch_id` | `BIGINT` | NOT NULL | Branch scope FK |
| `academic_year_id` | `BIGINT` | NOT NULL | Academic year FK |
| `class_id` | `BIGINT` | NOT NULL | Class FK |
| `section_id` | `BIGINT` | NOT NULL | Section FK |
| `student_id` | `BIGINT` | NOT NULL | Student FK |
| `residency_type` | `NVARCHAR(20)` | NOT NULL |  |
| `term1_tuition_amount` | `DECIMAL(12,2)` | NOT NULL |  |
| `term1_tuition_paid` | `DECIMAL(12,2)` | NOT NULL |  |
| `term1_tuition_balance` | `DECIMAL(12,2)` | NOT NULL |  |
| `term1_tuition_status` | `NVARCHAR(20)` | NOT NULL |  |
| `term1_residency_amount` | `DECIMAL(12,2)` | NOT NULL |  |
| `term1_residency_paid` | `DECIMAL(12,2)` | NOT NULL |  |
| `term1_residency_balance` | `DECIMAL(12,2)` | NOT NULL |  |
| `term1_residency_status` | `NVARCHAR(20)` | NOT NULL |  |
| `term1_total_amount` | `DECIMAL(12,2)` | NOT NULL |  |
| `term1_total_paid` | `DECIMAL(12,2)` | NOT NULL |  |
| `term1_total_balance` | `DECIMAL(12,2)` | NOT NULL |  |
| `term1_status` | `NVARCHAR(20)` | NOT NULL |  |
| `term2_tuition_amount` | `DECIMAL(12,2)` | NOT NULL |  |
| `term2_tuition_paid` | `DECIMAL(12,2)` | NOT NULL |  |
| `term2_tuition_balance` | `DECIMAL(12,2)` | NOT NULL |  |
| `term2_tuition_status` | `NVARCHAR(20)` | NOT NULL |  |
| `term2_residency_amount` | `DECIMAL(12,2)` | NOT NULL |  |
| `term2_residency_paid` | `DECIMAL(12,2)` | NOT NULL |  |
| `term2_residency_balance` | `DECIMAL(12,2)` | NOT NULL |  |
| `term2_residency_status` | `NVARCHAR(20)` | NOT NULL |  |
| `term2_total_amount` | `DECIMAL(12,2)` | NOT NULL |  |
| `term2_total_paid` | `DECIMAL(12,2)` | NOT NULL |  |
| `term2_total_balance` | `DECIMAL(12,2)` | NOT NULL |  |
| `term2_status` | `NVARCHAR(20)` | NOT NULL |  |
| `term3_tuition_amount` | `DECIMAL(12,2)` | NOT NULL |  |
| `term3_tuition_paid` | `DECIMAL(12,2)` | NOT NULL |  |
| `term3_tuition_balance` | `DECIMAL(12,2)` | NOT NULL |  |
| `term3_tuition_status` | `NVARCHAR(20)` | NOT NULL |  |
| `term3_residency_amount` | `DECIMAL(12,2)` | NOT NULL |  |
| `term3_residency_paid` | `DECIMAL(12,2)` | NOT NULL |  |
| `term3_residency_balance` | `DECIMAL(12,2)` | NOT NULL |  |
| `term3_residency_status` | `NVARCHAR(20)` | NOT NULL |  |
| `term3_total_amount` | `DECIMAL(12,2)` | NOT NULL |  |
| `term3_total_paid` | `DECIMAL(12,2)` | NOT NULL |  |
| `term3_total_balance` | `DECIMAL(12,2)` | NOT NULL |  |
| `term3_status` | `NVARCHAR(20)` | NOT NULL |  |
| `other_fee_amount` | `DECIMAL(12,2)` | NOT NULL |  |
| `other_fee_paid` | `DECIMAL(12,2)` | NOT NULL |  |
| `other_fee_balance` | `DECIMAL(12,2)` | NOT NULL |  |
| `other_fee_status` | `NVARCHAR(20)` | NOT NULL |  |
| `scholarship_amount` | `DECIMAL(12,2)` | NOT NULL |  |
| `total_fee_amount` | `DECIMAL(12,2)` | NOT NULL |  |
| `total_paid_amount` | `DECIMAL(12,2)` | NOT NULL |  |
| `total_balance_amount` | `DECIMAL(12,2)` | NOT NULL |  |
| `overall_status` | `NVARCHAR(20)` | NOT NULL |  |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NOT NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_student_fee_record PRIMARY KEY CLUSTERED (student_fee_record_id)`
- `CONSTRAINT UQ_student_fee_record_scope UNIQUE NONCLUSTERED (school_id, branch_id, academic_year_id, student_id)`
- `CONSTRAINT UQ_student_fee_record_hierarchy UNIQUE NONCLUSTERED (student_fee_record_id, school_id, branch_id, academic_year_id, student_id, class_id, section_id)`
- `CONSTRAINT CK_student_fee_record_residency_type CHECK (residency_type IN (N'DAY_SCHOLAR', N'HOSTELLER'))`
- `CONSTRAINT CK_student_fee_record_residency CHECK (`
- `CONSTRAINT CK_student_fee_record_tuition CHECK (`
- `CONSTRAINT CK_student_fee_record_other_fee CHECK (`
- `CONSTRAINT CK_student_fee_record_term_totals CHECK (`
- `CONSTRAINT CK_student_fee_record_overall_totals CHECK (`
- `CONSTRAINT FK_student_fee_record_structure FOREIGN KEY (fee_structure_term_id, school_id, branch_id, academic_year_id, class_id)`
- `CONSTRAINT FK_student_fee_record_school FOREIGN KEY (school_id)`
- `CONSTRAINT FK_student_fee_record_branch_scope FOREIGN KEY (school_id, branch_id)`
- `CONSTRAINT FK_student_fee_record_year_scope FOREIGN KEY (school_id, academic_year_id)`
- `CONSTRAINT FK_student_fee_record_class_scope FOREIGN KEY (school_id, class_id)`
- `CONSTRAINT FK_student_fee_record_section_scope FOREIGN KEY (class_id, section_id)`
- `CONSTRAINT FK_student_fee_record_student FOREIGN KEY (student_id)`
- `CONSTRAINT FK_student_fee_record_created_by FOREIGN KEY (created_by)`
- `CONSTRAINT FK_student_fee_record_updated_by FOREIGN KEY (updated_by)`

**Indexes**

- `IX_student_fee_record_student_year`
- `IX_student_fee_record_scope`
- `IX_student_fee_record_outstanding`

## `library_schema`

### `library_schema.library_book`

- **Migration:** `014_library.sql`
- **Purpose:** Drops legacy library tables and recreates the final, clean 3-table

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `book_id` | `BIGINT` | NOT NULL |  |
| `school_id` | `BIGINT` | NOT NULL | School scope FK |
| `branch_id` | `BIGINT` | NOT NULL | Branch scope FK |
| `title` | `NVARCHAR(300)` | NOT NULL |  |
| `author` | `NVARCHAR(200)` | NOT NULL |  |
| `subject` | `NVARCHAR(100)` | NOT NULL |  |
| `category` | `NVARCHAR(100)` | NOT NULL |  |
| `language` | `NVARCHAR(50)` | NOT NULL |  |
| `edition` | `NVARCHAR(50)` | NULL |  |
| `description` | `NVARCHAR(MAX)` | NULL |  |
| `total_copies` | `INT` | NOT NULL |  |
| `available_copies` | `INT` | NOT NULL |  |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NOT NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_library_book PRIMARY KEY CLUSTERED (book_id)`
- `CONSTRAINT UQ_library_book_scope UNIQUE NONCLUSTERED (school_id, branch_id, book_id)`
- `CONSTRAINT CK_library_book_title CHECK (LEN(LTRIM(RTRIM(title))) > 0)`
- `CONSTRAINT CK_library_book_author CHECK (LEN(LTRIM(RTRIM(author))) > 0)`
- `CONSTRAINT CK_library_book_subject CHECK (LEN(LTRIM(RTRIM(subject))) > 0)`
- `CONSTRAINT CK_library_book_category CHECK (LEN(LTRIM(RTRIM(category))) > 0)`
- `CONSTRAINT CK_library_book_language CHECK (LEN(LTRIM(RTRIM(language))) > 0)`
- `CONSTRAINT CK_library_book_total_copies CHECK (total_copies >= 0)`
- `CONSTRAINT CK_library_book_available_copies CHECK (available_copies >= 0)`
- `CONSTRAINT CK_library_book_available_lte_total CHECK (available_copies <= total_copies)`
- `CONSTRAINT FK_library_book_school FOREIGN KEY (school_id)`
- `CONSTRAINT FK_library_book_branch FOREIGN KEY (school_id, branch_id)`
- `CONSTRAINT FK_library_book_created_by FOREIGN KEY (created_by)`
- `CONSTRAINT FK_library_book_updated_by FOREIGN KEY (updated_by)`

**Indexes**

- `IX_library_book_branch_search`

### `library_schema.library_book_borrow`

- **Migration:** `014_library.sql`
- **Purpose:** Drops legacy library tables and recreates the final, clean 3-table

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `borrow_id` | `BIGINT` | NOT NULL |  |
| `school_id` | `BIGINT` | NOT NULL | School scope FK |
| `branch_id` | `BIGINT` | NOT NULL | Branch scope FK |
| `academic_year_id` | `BIGINT` | NOT NULL | Academic year FK |
| `student_id` | `BIGINT` | NOT NULL | Student FK |
| `class_id` | `BIGINT` | NOT NULL | Class FK |
| `section_id` | `BIGINT` | NOT NULL | Section FK |
| `book_id` | `BIGINT` | NOT NULL |  |
| `book_copy_id` | `BIGINT` | NOT NULL |  |
| `borrow_status` | `NVARCHAR(20)` | NOT NULL |  |
| `borrowed_at` | `DATETIME2(0)` | NOT NULL |  |
| `due_date` | `DATE` | NOT NULL |  |
| `returned_at` | `DATETIME2(0)` | NULL |  |
| `returned_to` | `BIGINT` | NULL |  |
| `issued_by` | `BIGINT` | NOT NULL |  |
| `remarks` | `NVARCHAR(500)` | NULL |  |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_library_book_borrow PRIMARY KEY CLUSTERED (borrow_id)`
- `CONSTRAINT CK_library_book_borrow_status CHECK`
- `CONSTRAINT CK_library_book_borrow_due_date CHECK`
- `CONSTRAINT CK_library_book_borrow_returned_status CHECK`
- `CONSTRAINT FK_library_book_borrow_school FOREIGN KEY (school_id)`
- `CONSTRAINT FK_library_book_borrow_branch FOREIGN KEY (school_id, branch_id)`
- `CONSTRAINT FK_library_book_borrow_academic_year FOREIGN KEY (school_id, academic_year_id)`
- `CONSTRAINT FK_library_book_borrow_student_scope FOREIGN KEY (school_id, branch_id, student_id)`
- `CONSTRAINT FK_library_book_borrow_class_scope FOREIGN KEY (school_id, class_id)`
- `CONSTRAINT FK_library_book_borrow_section_scope FOREIGN KEY (class_id, section_id)`
- `CONSTRAINT FK_library_book_borrow_copy_scope FOREIGN KEY (school_id, branch_id, book_id, book_copy_id)`
- `CONSTRAINT FK_library_book_borrow_issued_by FOREIGN KEY (issued_by)`
- `CONSTRAINT FK_library_book_borrow_returned_to FOREIGN KEY (returned_to)`
- `CONSTRAINT FK_library_book_borrow_updated_by FOREIGN KEY (updated_by)`

**Indexes**

- `UX_library_book_borrow_active_copy`
- `IX_library_book_borrow_student_history`
- `IX_library_book_borrow_student_year`
- `IX_library_book_borrow_active_loans`
- `IX_library_book_borrow_overdue_loans`
- `IX_library_book_borrow_branch_circulation`
- `IX_library_book_borrow_copy_history`
- `IX_library_book_borrow_issued_by`
- `IX_library_book_borrow_lost`

### `library_schema.library_book_copy`

- **Migration:** `014_library.sql`
- **Purpose:** Drops legacy library tables and recreates the final, clean 3-table

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `book_copy_id` | `BIGINT` | NOT NULL |  |
| `book_id` | `BIGINT` | NOT NULL |  |
| `school_id` | `BIGINT` | NOT NULL | School scope FK |
| `branch_id` | `BIGINT` | NOT NULL | Branch scope FK |
| `copy_number` | `INT` | NOT NULL |  |
| `barcode` | `NVARCHAR(50)` | NULL |  |
| `copy_status` | `NVARCHAR(20)` | NOT NULL |  |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NOT NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_library_book_copy PRIMARY KEY CLUSTERED (book_copy_id)`
- `CONSTRAINT UQ_library_book_copy_number UNIQUE NONCLUSTERED (school_id, branch_id, book_id, copy_number)`
- `CONSTRAINT UQ_library_book_copy_scope UNIQUE NONCLUSTERED (school_id, branch_id, book_id, book_copy_id)`
- `CONSTRAINT CK_library_book_copy_number CHECK (copy_number > 0)`
- `CONSTRAINT CK_library_book_copy_status CHECK`
- `CONSTRAINT CK_library_book_copy_active_status CHECK`
- `CONSTRAINT FK_library_book_copy_book_scope FOREIGN KEY (school_id, branch_id, book_id)`
- `CONSTRAINT FK_library_book_copy_school FOREIGN KEY (school_id)`
- `CONSTRAINT FK_library_book_copy_branch FOREIGN KEY (school_id, branch_id)`
- `CONSTRAINT FK_library_book_copy_created_by FOREIGN KEY (created_by)`
- `CONSTRAINT FK_library_book_copy_updated_by FOREIGN KEY (updated_by)`

**Indexes**

- `UQ_library_book_copy_branch_barcode`
- `IX_library_book_copy_book_status`
- `IX_library_book_copy_branch_status`
- `IX_library_book_copy_available`

## `management_schema`

### `management_schema.academic_year`

- **Migration:** `003_management.sql`
- **Purpose:** Institutional master data required by student_schema.student foreign keys

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `academic_year_id` | `BIGINT` | NOT NULL | Academic year FK |
| `school_id` | `BIGINT` | NOT NULL | School scope FK |
| `year_name` | `NVARCHAR(50)` | NOT NULL |  |
| `start_date` | `DATE` | NOT NULL |  |
| `end_date` | `DATE` | NOT NULL |  |
| `is_current` | `BIT` | NOT NULL |  |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_academic_year PRIMARY KEY CLUSTERED (academic_year_id)`
- `CONSTRAINT UQ_academic_year_school_name UNIQUE NONCLUSTERED (school_id, year_name)`
- `CONSTRAINT CK_academic_year_dates CHECK (end_date >= start_date)`
- `CONSTRAINT FK_academic_year_school FOREIGN KEY (school_id) REFERENCES management_schema.school (school_id)`
- `CONSTRAINT FK_academic_year_created_by FOREIGN KEY (created_by) REFERENCES security_schema.users (user_id)`
- `CONSTRAINT FK_academic_year_updated_by FOREIGN KEY (updated_by) REFERENCES security_schema.users (user_id)`

**Indexes**

- `UQ_academic_year_school_scope`

### `management_schema.announcement`

- **Migration:** `007_announcement.sql`
- **Purpose:** School/branch announcements for Student Overview (events, academic notices, general instructions)

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `announcement_id` | `BIGINT` | NOT NULL |  |
| `school_id` | `BIGINT` | NOT NULL | School scope FK |
| `branch_id` | `BIGINT` | NOT NULL | Branch scope FK |
| `academic_year_id` | `BIGINT` | NOT NULL | Academic year FK |
| `announcement_type` | `NVARCHAR(20)` | NOT NULL |  |
| `sub_category` | `NVARCHAR(50)` | NOT NULL |  |
| `title` | `NVARCHAR(200)` | NOT NULL |  |
| `description` | `NVARCHAR(MAX)` | NULL |  |
| `target_audience` | `NVARCHAR(100)` | NOT NULL |  |
| `registration_url` | `NVARCHAR(2048)` | NULL |  |
| `start_date` | `DATE` | NULL |  |
| `end_date` | `DATE` | NULL |  |
| `publish_at` | `DATETIME2(0)` | NOT NULL |  |
| `status` | `NVARCHAR(20)` | NOT NULL |  |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NOT NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |

**Constraints**

- `CONSTRAINT PK_announcement PRIMARY KEY CLUSTERED (announcement_id)`
- `CONSTRAINT CK_announcement_type CHECK`
- `CONSTRAINT CK_announcement_sub_category CHECK`
- `CONSTRAINT CK_announcement_registration_url CHECK`
- `CONSTRAINT CK_announcement_status CHECK`
- `CONSTRAINT CK_announcement_date_range CHECK`
- `CONSTRAINT FK_announcement_school FOREIGN KEY (school_id) REFERENCES management_schema.school (school_id)`
- `CONSTRAINT FK_announcement_branch FOREIGN KEY (branch_id) REFERENCES management_schema.branch (branch_id)`
- `CONSTRAINT FK_announcement_academic_year FOREIGN KEY (academic_year_id) REFERENCES management_schema.academic_year (academic_year_id)`
- `CONSTRAINT FK_announcement_created_by FOREIGN KEY (created_by) REFERENCES security_schema.users (user_id)`
- `CONSTRAINT FK_announcement_updated_by FOREIGN KEY (updated_by) REFERENCES security_schema.users (user_id)`

**Indexes**

- `IX_announcement_branch_status_publish`
- `IX_announcement_branch_date`
- `IX_announcement_type_date`
- `IX_announcement_academic_year`
- `IX_announcement_type_sub_category`

### `management_schema.branch`

- **Migration:** `003_management.sql`
- **Purpose:** Institutional master data required by student_schema.student foreign keys

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `branch_id` | `BIGINT` | NOT NULL | Branch scope FK |
| `school_id` | `BIGINT` | NOT NULL | School scope FK |
| `branch_code` | `NVARCHAR(50)` | NOT NULL |  |
| `branch_name` | `NVARCHAR(150)` | NOT NULL |  |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_branch PRIMARY KEY CLUSTERED (branch_id)`
- `CONSTRAINT UQ_branch_school_code UNIQUE NONCLUSTERED (school_id, branch_code)`
- `CONSTRAINT FK_branch_school FOREIGN KEY (school_id) REFERENCES management_schema.school (school_id)`
- `CONSTRAINT FK_branch_created_by FOREIGN KEY (created_by) REFERENCES security_schema.users (user_id)`
- `CONSTRAINT FK_branch_updated_by FOREIGN KEY (updated_by) REFERENCES security_schema.users (user_id)`

**Indexes**

- `UQ_branch_school_scope`

### `management_schema.class_subject`

- **Migration:** `003_management.sql`
- **Purpose:** Institutional master data required by student_schema.student foreign keys

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `class_subject_id` | `BIGINT` | NOT NULL |  |
| `school_id` | `BIGINT` | NOT NULL | School scope FK |
| `branch_id` | `BIGINT` | NOT NULL | Branch scope FK |
| `academic_year_id` | `BIGINT` | NOT NULL | Academic year FK |
| `class_id` | `BIGINT` | NOT NULL | Class FK |
| `subject_id` | `BIGINT` | NOT NULL | Subject FK |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NOT NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_class_subject PRIMARY KEY CLUSTERED (class_subject_id)`
- `CONSTRAINT UQ_class_subject_scope UNIQUE NONCLUSTERED`
- `CONSTRAINT FK_class_subject_school FOREIGN KEY (school_id) REFERENCES management_schema.school (school_id)`
- `CONSTRAINT FK_class_subject_branch FOREIGN KEY (branch_id) REFERENCES management_schema.branch (branch_id)`
- `CONSTRAINT FK_class_subject_academic_year FOREIGN KEY (academic_year_id) REFERENCES management_schema.academic_year (academic_year_id)`
- `CONSTRAINT FK_class_subject_class FOREIGN KEY (class_id) REFERENCES management_schema.school_class (class_id)`
- `CONSTRAINT FK_class_subject_subject FOREIGN KEY (subject_id) REFERENCES management_schema.subject (subject_id)`
- `CONSTRAINT FK_class_subject_created_by FOREIGN KEY (created_by) REFERENCES security_schema.users (user_id)`
- `CONSTRAINT FK_class_subject_updated_by FOREIGN KEY (updated_by) REFERENCES security_schema.users (user_id)`

**Indexes**

- `IX_class_subject_class_active`
- `IX_class_subject_subject_active`

### `management_schema.exam`

- **Migration:** `017_exam.sql`
- **Purpose:** Exam master, subject schedule, and per-student results

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `exam_id` | `BIGINT` | NOT NULL |  |
| `school_id` | `BIGINT` | NOT NULL | School scope FK |
| `branch_id` | `BIGINT` | NOT NULL | Branch scope FK |
| `academic_year_id` | `BIGINT` | NOT NULL | Academic year FK |
| `class_id` | `BIGINT` | NOT NULL | Class FK |
| `section_id` | `BIGINT` | NOT NULL | Section FK |
| `exam_name` | `NVARCHAR(150)` | NOT NULL |  |
| `exam_category` | `NVARCHAR(50)` | NOT NULL |  |
| `start_date` | `DATE` | NOT NULL |  |
| `end_date` | `DATE` | NOT NULL |  |
| `status` | `NVARCHAR(20)` | NOT NULL |  |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NOT NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_exam PRIMARY KEY CLUSTERED (exam_id)`
- `CONSTRAINT UQ_exam_section_name UNIQUE NONCLUSTERED`
- `CONSTRAINT CK_exam_date_range CHECK (end_date >= start_date)`
- `CONSTRAINT CK_exam_status CHECK`
- `CONSTRAINT FK_exam_school FOREIGN KEY (school_id) REFERENCES management_schema.school (school_id)`
- `CONSTRAINT FK_exam_branch FOREIGN KEY (branch_id) REFERENCES management_schema.branch (branch_id)`
- `CONSTRAINT FK_exam_academic_year FOREIGN KEY (academic_year_id) REFERENCES management_schema.academic_year (academic_year_id)`
- `CONSTRAINT FK_exam_class FOREIGN KEY (class_id) REFERENCES management_schema.school_class (class_id)`
- `CONSTRAINT FK_exam_section FOREIGN KEY (section_id) REFERENCES management_schema.section (section_id)`
- `CONSTRAINT FK_exam_created_by FOREIGN KEY (created_by) REFERENCES security_schema.users (user_id)`
- `CONSTRAINT FK_exam_updated_by FOREIGN KEY (updated_by) REFERENCES security_schema.users (user_id)`

**Indexes**

- `IX_exam_academic_scope_status`
- `IX_exam_category_scope`

### `management_schema.exam_schedule`

- **Migration:** `017_exam.sql`
- **Purpose:** Exam master, subject schedule, and per-student results

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `exam_schedule_id` | `BIGINT` | NOT NULL |  |
| `exam_id` | `BIGINT` | NOT NULL |  |
| `school_id` | `BIGINT` | NOT NULL | School scope FK |
| `branch_id` | `BIGINT` | NOT NULL | Branch scope FK |
| `academic_year_id` | `BIGINT` | NOT NULL | Academic year FK |
| `class_id` | `BIGINT` | NOT NULL | Class FK |
| `section_id` | `BIGINT` | NOT NULL | Section FK |
| `subject_id` | `BIGINT` | NOT NULL | Subject FK |
| `teacher_id` | `BIGINT` | NOT NULL | Teacher FK |
| `exam_date` | `DATE` | NOT NULL |  |
| `start_time` | `TIME(0)` | NOT NULL |  |
| `end_time` | `TIME(0)` | NOT NULL |  |
| `max_marks` | `DECIMAL(6, 2)` | NOT NULL |  |
| `pass_marks` | `DECIMAL(6, 2)` | NULL |  |
| `evaluation_start_date` | `DATE` | NULL | Paper evaluation start date by teachers (>= exam_date) |
| `evaluation_end_date` | `DATE` | NULL | Deadline for paper evaluation (>= evaluation_start_date) |
| `status` | `NVARCHAR(20)` | NOT NULL |  |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NOT NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_exam_schedule PRIMARY KEY CLUSTERED (exam_schedule_id)`
- `CONSTRAINT UQ_exam_schedule_exam_subject UNIQUE NONCLUSTERED (exam_id, subject_id)`
- `CONSTRAINT CK_exam_schedule_time CHECK (end_time > start_time)`
- `CONSTRAINT CK_exam_schedule_max_marks CHECK (max_marks > 0)`
- `CONSTRAINT CK_exam_schedule_pass_marks CHECK`
- `CONSTRAINT CK_exam_schedule_status CHECK`
- `CONSTRAINT CK_exam_schedule_evaluation_dates CHECK (evaluation_end_date IS NULL OR evaluation_start_date IS NULL OR evaluation_end_date >= evaluation_start_date)`
- `CONSTRAINT CK_exam_schedule_evaluation_start_date CHECK (evaluation_start_date IS NULL OR evaluation_start_date >= exam_date)`
- `CONSTRAINT FK_exam_schedule_exam FOREIGN KEY (exam_id) REFERENCES management_schema.exam (exam_id)`
- `CONSTRAINT FK_exam_schedule_school FOREIGN KEY (school_id) REFERENCES management_schema.school (school_id)`
- `CONSTRAINT FK_exam_schedule_branch FOREIGN KEY (branch_id) REFERENCES management_schema.branch (branch_id)`
- `CONSTRAINT FK_exam_schedule_academic_year FOREIGN KEY (academic_year_id) REFERENCES management_schema.academic_year (academic_year_id)`
- `CONSTRAINT FK_exam_schedule_class FOREIGN KEY (class_id) REFERENCES management_schema.school_class (class_id)`
- `CONSTRAINT FK_exam_schedule_section FOREIGN KEY (section_id) REFERENCES management_schema.section (section_id)`
- `CONSTRAINT FK_exam_schedule_subject FOREIGN KEY (subject_id) REFERENCES management_schema.subject (subject_id)`
- `CONSTRAINT FK_exam_schedule_teacher FOREIGN KEY (teacher_id) REFERENCES teachers_schema.teacher (teacher_id)`
- `CONSTRAINT FK_exam_schedule_created_by FOREIGN KEY (created_by) REFERENCES security_schema.users (user_id)`
- `CONSTRAINT FK_exam_schedule_updated_by FOREIGN KEY (updated_by) REFERENCES security_schema.users (user_id)`

**Indexes**

- `IX_exam_schedule_academic_scope`
- `IX_exam_schedule_teacher_date`
- `IX_exam_schedule_exam_date`
- `IX_exam_schedule_teacher_evaluation`

### `management_schema.grievance_department`

- **Migration:** `025_sports_and_grievance_department.sql`
- **Purpose:** Synchronize missing application tables, schemas, and columns from SSMS server:

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `department_id` | `BIGINT` | NOT NULL |  |
| `school_id` | `BIGINT` | NOT NULL | School scope FK |
| `branch_id` | `BIGINT` | NULL | Branch scope FK |
| `responsible_user_id` | `BIGINT` | NOT NULL |  |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_grievance_department PRIMARY KEY CLUSTERED (department_id)`
- `CONSTRAINT UQ_grievance_department_school_branch UNIQUE NONCLUSTERED (school_id, branch_id)`
- `CONSTRAINT FK_grievance_department_school FOREIGN KEY (school_id) REFERENCES management_schema.school (school_id)`
- `CONSTRAINT FK_grievance_department_branch FOREIGN KEY (branch_id) REFERENCES management_schema.branch (branch_id)`
- `CONSTRAINT FK_grievance_department_responsible_user FOREIGN KEY (responsible_user_id) REFERENCES security_schema.users (user_id)`
- `CONSTRAINT FK_grievance_department_created_by FOREIGN KEY (created_by) REFERENCES security_schema.users (user_id)`
- `CONSTRAINT FK_grievance_department_updated_by FOREIGN KEY (updated_by) REFERENCES security_schema.users (user_id)`

### `management_schema.holiday`

- **Migration:** `012_holidays.sql`
- **Purpose:** School/branch holiday calendar master (academic calendar)

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `holiday_id` | `BIGINT` | NOT NULL |  |
| `school_id` | `BIGINT` | NOT NULL | School scope FK |
| `branch_id` | `BIGINT` | NOT NULL | Branch scope FK |
| `academic_year_id` | `BIGINT` | NOT NULL | Academic year FK |
| `holiday_type` | `NVARCHAR(30)` | NOT NULL |  |
| `holiday_name` | `NVARCHAR(150)` | NOT NULL |  |
| `description` | `NVARCHAR(MAX)` | NULL |  |
| `start_date` | `DATE` | NOT NULL |  |
| `end_date` | `DATE` | NOT NULL |  |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NOT NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_holiday PRIMARY KEY CLUSTERED (holiday_id)`
- `CONSTRAINT CK_holiday_type CHECK`
- `CONSTRAINT CK_holiday_date_range CHECK (end_date >= start_date)`
- `CONSTRAINT FK_holiday_school FOREIGN KEY (school_id) REFERENCES management_schema.school (school_id)`
- `CONSTRAINT FK_holiday_branch FOREIGN KEY (branch_id) REFERENCES management_schema.branch (branch_id)`
- `CONSTRAINT FK_holiday_academic_year FOREIGN KEY (academic_year_id) REFERENCES management_schema.academic_year (academic_year_id)`
- `CONSTRAINT FK_holiday_created_by FOREIGN KEY (created_by) REFERENCES security_schema.users (user_id)`
- `CONSTRAINT FK_holiday_updated_by FOREIGN KEY (updated_by) REFERENCES security_schema.users (user_id)`

**Indexes**

- `IX_holiday_branch_year_dates`
- `IX_holiday_branch_type_date`

### `management_schema.school`

- **Migration:** `003_management.sql`
- **Purpose:** Institutional master data required by student_schema.student foreign keys

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `school_id` | `BIGINT` | NOT NULL | School scope FK |
| `school_code` | `NVARCHAR(50)` | NOT NULL |  |
| `school_name` | `NVARCHAR(150)` | NOT NULL |  |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_school PRIMARY KEY CLUSTERED (school_id)`
- `CONSTRAINT UQ_school_code UNIQUE NONCLUSTERED (school_code)`
- `CONSTRAINT FK_school_created_by FOREIGN KEY (created_by) REFERENCES security_schema.users (user_id)`
- `CONSTRAINT FK_school_updated_by FOREIGN KEY (updated_by) REFERENCES security_schema.users (user_id)`

### `management_schema.school_class`

- **Migration:** `003_management.sql`
- **Purpose:** Institutional master data required by student_schema.student foreign keys

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `class_id` | `BIGINT` | NOT NULL | Class FK |
| `school_id` | `BIGINT` | NOT NULL | School scope FK |
| `class_name` | `NVARCHAR(150)` | NOT NULL |  |
| `display_order` | `INT` | NULL |  |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_school_class PRIMARY KEY CLUSTERED (class_id)`
- `CONSTRAINT UQ_school_class_school_name UNIQUE NONCLUSTERED (school_id, class_name)`
- `CONSTRAINT FK_school_class_school FOREIGN KEY (school_id) REFERENCES management_schema.school (school_id)`
- `CONSTRAINT FK_school_class_created_by FOREIGN KEY (created_by) REFERENCES security_schema.users (user_id)`
- `CONSTRAINT FK_school_class_updated_by FOREIGN KEY (updated_by) REFERENCES security_schema.users (user_id)`

**Indexes**

- `UQ_school_class_school_scope`

### `management_schema.section`

- **Migration:** `003_management.sql`
- **Purpose:** Institutional master data required by student_schema.student foreign keys

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `section_id` | `BIGINT` | NOT NULL | Section FK |
| `class_id` | `BIGINT` | NOT NULL | Class FK |
| `section_name` | `NVARCHAR(50)` | NOT NULL |  |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_section PRIMARY KEY CLUSTERED (section_id)`
- `CONSTRAINT UQ_section_class_name UNIQUE NONCLUSTERED (class_id, section_name)`
- `CONSTRAINT FK_section_class FOREIGN KEY (class_id) REFERENCES management_schema.school_class (class_id)`
- `CONSTRAINT FK_section_created_by FOREIGN KEY (created_by) REFERENCES security_schema.users (user_id)`
- `CONSTRAINT FK_section_updated_by FOREIGN KEY (updated_by) REFERENCES security_schema.users (user_id)`

**Indexes**

- `UQ_section_class_scope`

### `management_schema.subject`

- **Migration:** `003_management.sql`
- **Purpose:** Institutional master data required by student_schema.student foreign keys

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `subject_id` | `BIGINT` | NOT NULL | Subject FK |
| `school_id` | `BIGINT` | NOT NULL | School scope FK |
| `subject_code` | `NVARCHAR(50)` | NOT NULL |  |
| `subject_name` | `NVARCHAR(150)` | NOT NULL |  |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_subject PRIMARY KEY CLUSTERED (subject_id)`
- `CONSTRAINT UQ_subject_school_code UNIQUE NONCLUSTERED (school_id, subject_code)`
- `CONSTRAINT FK_subject_school FOREIGN KEY (school_id) REFERENCES management_schema.school (school_id)`
- `CONSTRAINT FK_subject_created_by FOREIGN KEY (created_by) REFERENCES security_schema.users (user_id)`
- `CONSTRAINT FK_subject_updated_by FOREIGN KEY (updated_by) REFERENCES security_schema.users (user_id)`

### `management_schema.timetable`

- **Migration:** `008_timetable.sql`
- **Purpose:** Section-wise academic timetable (master + dated period slots)

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `timetable_id` | `BIGINT` | NOT NULL |  |
| `school_id` | `BIGINT` | NOT NULL | School scope FK |
| `branch_id` | `BIGINT` | NOT NULL | Branch scope FK |
| `academic_year_id` | `BIGINT` | NOT NULL | Academic year FK |
| `class_id` | `BIGINT` | NOT NULL | Class FK |
| `section_id` | `BIGINT` | NOT NULL | Section FK |
| `timetable_name` | `NVARCHAR(150)` | NOT NULL |  |
| `status` | `NVARCHAR(20)` | NOT NULL |  |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NOT NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_timetable PRIMARY KEY CLUSTERED (timetable_id)`
- `CONSTRAINT CK_timetable_status CHECK`
- `CONSTRAINT FK_timetable_school FOREIGN KEY (school_id) REFERENCES management_schema.school (school_id)`
- `CONSTRAINT FK_timetable_branch FOREIGN KEY (branch_id) REFERENCES management_schema.branch (branch_id)`
- `CONSTRAINT FK_timetable_academic_year FOREIGN KEY (academic_year_id) REFERENCES management_schema.academic_year (academic_year_id)`
- `CONSTRAINT FK_timetable_class FOREIGN KEY (class_id) REFERENCES management_schema.school_class (class_id)`
- `CONSTRAINT FK_timetable_section FOREIGN KEY (section_id) REFERENCES management_schema.section (section_id)`
- `CONSTRAINT FK_timetable_created_by FOREIGN KEY (created_by) REFERENCES security_schema.users (user_id)`
- `CONSTRAINT FK_timetable_updated_by FOREIGN KEY (updated_by) REFERENCES security_schema.users (user_id)`

**Indexes**

- `UX_timetable_section_active`
- `IX_timetable_section_status`

### `management_schema.timetable_period`

- **Migration:** `008_timetable.sql`
- **Purpose:** Section-wise academic timetable (master + dated period slots)

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `timetable_period_id` | `BIGINT` | NOT NULL |  |
| `timetable_id` | `BIGINT` | NOT NULL |  |
| `period_date` | `DATE` | NOT NULL |  |
| `period_number` | `TINYINT` | NOT NULL |  |
| `period_name` | `NVARCHAR(50)` | NULL |  |
| `start_time` | `TIME(0)` | NOT NULL |  |
| `end_time` | `TIME(0)` | NOT NULL |  |
| `period_type` | `NVARCHAR(30)` | NOT NULL |  |
| `subject_id` | `BIGINT` | NULL | Subject FK |
| `subject_topic` | `NVARCHAR(200)` | NULL | Lesson/chapter topic for CLASS period |
| `teacher_id` | `BIGINT` | NULL | Teacher FK |
| `room_name` | `NVARCHAR(150)` | NULL |  |
| `activity_name` | `NVARCHAR(150)` | NULL |  |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NOT NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_timetable_period PRIMARY KEY CLUSTERED (timetable_period_id)`
- `CONSTRAINT UQ_timetable_period_slot UNIQUE NONCLUSTERED`
- `CONSTRAINT CK_timetable_period_number CHECK (period_number > 0)`
- `CONSTRAINT CK_timetable_period_time CHECK (end_time > start_time)`
- `CONSTRAINT CK_timetable_period_type CHECK`
- `CONSTRAINT CK_timetable_period_class CHECK`
- `CONSTRAINT FK_timetable_period_timetable FOREIGN KEY (timetable_id) REFERENCES management_schema.timetable (timetable_id)`
- `CONSTRAINT FK_timetable_period_subject FOREIGN KEY (subject_id) REFERENCES management_schema.subject (subject_id)`
- `CONSTRAINT FK_timetable_period_teacher FOREIGN KEY (teacher_id) REFERENCES teachers_schema.teacher (teacher_id)`
- `CONSTRAINT FK_timetable_period_created_by FOREIGN KEY (created_by) REFERENCES security_schema.users (user_id)`
- `CONSTRAINT FK_timetable_period_updated_by FOREIGN KEY (updated_by) REFERENCES security_schema.users (user_id)`

**Indexes**

- `IX_timetable_period_my_day`
- `IX_timetable_period_teacher_day`

## `security_schema`

### `security_schema.schema_version`

- **Migration:** `002_security.sql`
- **Purpose:** Identity + credentials (one users table), login audit, migration tracking

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `schema_version_id` | `INT` | NOT NULL |  |
| `migration_name` | `NVARCHAR(200)` | NOT NULL |  |
| `applied_at` | `DATETIME2(0)` | NOT NULL |  |

**Constraints**

- `CONSTRAINT PK_schema_version PRIMARY KEY CLUSTERED (schema_version_id)`
- `CONSTRAINT UQ_schema_version_name UNIQUE NONCLUSTERED (migration_name)`

### `security_schema.user_login_attempt`

- **Migration:** `002_security.sql`
- **Purpose:** Identity + credentials (one users table), login audit, migration tracking

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `login_attempt_id` | `BIGINT` | NOT NULL |  |
| `user_id` | `BIGINT` | NOT NULL | User FK |
| `is_success` | `BIT` | NOT NULL |  |
| `failure_reason` | `NVARCHAR(50)` | NULL |  |
| `ip_address` | `NVARCHAR(45)` | NULL |  |
| `user_agent` | `NVARCHAR(500)` | NULL |  |
| `attempted_at` | `DATETIME2(0)` | NOT NULL |  |

**Constraints**

- `CONSTRAINT PK_user_login_attempt PRIMARY KEY CLUSTERED (login_attempt_id)`
- `CONSTRAINT CK_user_login_attempt_result CHECK`
- `CONSTRAINT CK_user_login_attempt_failure_reason CHECK`
- `CONSTRAINT FK_user_login_attempt_user FOREIGN KEY (user_id) REFERENCES security_schema.users (user_id)`

**Indexes**

- `IX_user_login_attempt_user_time`
- `IX_user_login_attempt_ip_time`

### `security_schema.users`

- **Migration:** `002_security.sql`
- **Purpose:** Identity + credentials (one users table), login audit, migration tracking

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `user_id` | `BIGINT` | NOT NULL | User FK |
| `email_address` | `NVARCHAR(254)` | NOT NULL |  |
| `user_type` | `NVARCHAR(30)` | NOT NULL |  |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `password_hash` | `NVARCHAR(255)` | NULL |  |
| `password_plain_dev` | `NVARCHAR(255)` | NULL |  |
| `password_set_at` | `DATETIME2(0)` | NULL |  |
| `failed_login_count` | `INT` | NOT NULL |  |
| `locked_until` | `DATETIME2(0)` | NULL |  |
| `last_login_at` | `DATETIME2(0)` | NULL |  |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_users PRIMARY KEY CLUSTERED (user_id)`
- `CONSTRAINT UQ_users_email_address UNIQUE NONCLUSTERED (email_address)`
- `CONSTRAINT CK_users_failed_login CHECK (failed_login_count >= 0)`

**Indexes**

- `IX_users_user_type_active`

## `sports_schema`

### `sports_schema.student_sport_history`

- **Migration:** `025_sports_and_grievance_department.sql`
- **Purpose:** Synchronize missing application tables, schemas, and columns from SSMS server:

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `student_sport_history_id` | `BIGINT` | NOT NULL |  |
| `student_id` | `BIGINT` | NOT NULL | Student FK |
| `school_id` | `BIGINT` | NOT NULL | School scope FK |
| `branch_id` | `BIGINT` | NOT NULL | Branch scope FK |
| `class_id` | `BIGINT` | NOT NULL | Class FK |
| `section_id` | `BIGINT` | NOT NULL | Section FK |
| `sport_name` | `VARCHAR(100)` | NOT NULL |  |
| `announcement_id` | `BIGINT` | NULL |  |
| `activity_date` | `DATE` | NOT NULL |  |
| `activity_name` | `VARCHAR(200)` | NOT NULL |  |
| `result` | `VARCHAR(200)` | NULL |  |
| `participation_status` | `VARCHAR(50)` | NOT NULL |  |
| `created_at` | `DATETIME2(3)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NOT NULL | User who created |
| `updated_at` | `DATETIME2(3)` | NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |
| `sport_category` | `VARCHAR(100)` | NOT NULL |  |

**Constraints**

- `CONSTRAINT PK_student_sport_history PRIMARY KEY CLUSTERED (student_sport_history_id)`
- `CONSTRAINT CK_student_sport_history_status CHECK (participation_status IN ('REGISTERED', 'PARTICIPATED'))`
- `CONSTRAINT FK_student_sport_history_student FOREIGN KEY (student_id) REFERENCES student_schema.student (student_id)`
- `CONSTRAINT FK_student_sport_history_school FOREIGN KEY (school_id) REFERENCES management_schema.school (school_id)`
- `CONSTRAINT FK_student_sport_history_branch FOREIGN KEY (branch_id) REFERENCES management_schema.branch (branch_id)`
- `CONSTRAINT FK_student_sport_history_class FOREIGN KEY (class_id) REFERENCES management_schema.school_class (class_id)`
- `CONSTRAINT FK_student_sport_history_section FOREIGN KEY (section_id) REFERENCES management_schema.section (section_id)`
- `CONSTRAINT FK_student_sport_history_created_by FOREIGN KEY (created_by) REFERENCES security_schema.users (user_id)`
- `CONSTRAINT FK_student_sport_history_updated_by FOREIGN KEY (updated_by) REFERENCES security_schema.users (user_id)`

**Indexes**

- `IX_student_sport_history_student`

## `student_schema`

### `student_schema.assessment_result`

- **Migration:** `006_assessment.sql`
- **Purpose:** Assessment master (project works, slip tests, quizzes - subject-wise) and per-student assessment marks

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `assessment_result_id` | `BIGINT` | NOT NULL |  |
| `assessment_id` | `BIGINT` | NOT NULL |  |
| `school_id` | `BIGINT` | NOT NULL | School scope FK |
| `branch_id` | `BIGINT` | NOT NULL | Branch scope FK |
| `academic_year_id` | `BIGINT` | NOT NULL | Academic year FK |
| `class_id` | `BIGINT` | NOT NULL | Class FK |
| `section_id` | `BIGINT` | NOT NULL | Section FK |
| `student_id` | `BIGINT` | NOT NULL | Student FK |
| `marks_obtained` | `DECIMAL(6, 2)` | NULL |  |
| `grade` | `NVARCHAR(10)` | NULL |  |
| `remarks` | `NVARCHAR(500)` | NULL |  |
| `graded_at` | `DATETIME2(0)` | NULL |  |
| `graded_by` | `BIGINT` | NULL |  |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NOT NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_assessment_result PRIMARY KEY CLUSTERED (assessment_result_id)`
- `CONSTRAINT UQ_assessment_result_assessment_student UNIQUE NONCLUSTERED (assessment_id, student_id)`
- `CONSTRAINT CK_assessment_result_marks CHECK`
- `CONSTRAINT CK_assessment_result_graded CHECK`
- `CONSTRAINT FK_assessment_result_assessment FOREIGN KEY (assessment_id) REFERENCES teachers_schema.assessment (assessment_id)`
- `CONSTRAINT FK_assessment_result_school FOREIGN KEY (school_id) REFERENCES management_schema.school (school_id)`
- `CONSTRAINT FK_assessment_result_branch_scope FOREIGN KEY (school_id, branch_id)`
- `CONSTRAINT FK_assessment_result_academic_year_scope FOREIGN KEY (school_id, academic_year_id)`
- `CONSTRAINT FK_assessment_result_class_scope FOREIGN KEY (school_id, class_id)`
- `CONSTRAINT FK_assessment_result_section_scope FOREIGN KEY (class_id, section_id)`
- `CONSTRAINT FK_assessment_result_student FOREIGN KEY (student_id) REFERENCES student_schema.student (student_id)`
- `CONSTRAINT FK_assessment_result_graded_by FOREIGN KEY (graded_by) REFERENCES security_schema.users (user_id)`
- `CONSTRAINT FK_assessment_result_created_by FOREIGN KEY (created_by) REFERENCES security_schema.users (user_id)`
- `CONSTRAINT FK_assessment_result_updated_by FOREIGN KEY (updated_by) REFERENCES security_schema.users (user_id)`

**Indexes**

- `IX_assessment_result_student_scope`
- `IX_assessment_result_student_assessment`
- `IX_assessment_result_assessment`

### `student_schema.exam_result`

- **Migration:** `005_student.sql`
- **Purpose:** Student master identity, current academic placement, and guardians

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `exam_result_id` | `BIGINT` | NOT NULL |  |
| `exam_schedule_id` | `BIGINT` | NOT NULL |  |
| `school_id` | `BIGINT` | NOT NULL | School scope FK |
| `branch_id` | `BIGINT` | NOT NULL | Branch scope FK |
| `academic_year_id` | `BIGINT` | NOT NULL | Academic year FK |
| `class_id` | `BIGINT` | NOT NULL | Class FK |
| `section_id` | `BIGINT` | NOT NULL | Section FK |
| `student_id` | `BIGINT` | NOT NULL | Student FK |
| `marks_obtained` | `DECIMAL(6, 2)` | NULL |  |
| `result_status` | `NVARCHAR(20)` | NOT NULL |  |
| `grade` | `NVARCHAR(10)` | NULL |  |
| `rank_in_class` | `INT` | NULL |  |
| `remarks` | `NVARCHAR(500)` | NULL |  |
| `published_at` | `DATETIME2(0)` | NULL |  |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NOT NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_exam_result PRIMARY KEY CLUSTERED (exam_result_id)`
- `CONSTRAINT UQ_exam_result_schedule_student UNIQUE NONCLUSTERED (exam_schedule_id, student_id)`
- `CONSTRAINT CK_exam_result_status CHECK`
- `CONSTRAINT CK_exam_result_marks CHECK`
- `CONSTRAINT CK_exam_result_absent_marks CHECK`
- `CONSTRAINT CK_exam_result_rank CHECK`
- `CONSTRAINT FK_exam_result_exam_schedule FOREIGN KEY (exam_schedule_id) REFERENCES management_schema.exam_schedule (exam_schedule_id)`
- `CONSTRAINT FK_exam_result_school FOREIGN KEY (school_id) REFERENCES management_schema.school (school_id)`
- `CONSTRAINT FK_exam_result_branch_scope FOREIGN KEY (school_id, branch_id) REFERENCES management_schema.branch (school_id, branch_id)`
- `CONSTRAINT FK_exam_result_academic_year_scope FOREIGN KEY (school_id, academic_year_id) REFERENCES management_schema.academic_year (school_id, academic_year_id)`
- `CONSTRAINT FK_exam_result_class_scope FOREIGN KEY (school_id, class_id) REFERENCES management_schema.school_class (school_id, class_id)`
- `CONSTRAINT FK_exam_result_section_scope FOREIGN KEY (class_id, section_id) REFERENCES management_schema.section (class_id, section_id)`
- `CONSTRAINT FK_exam_result_student FOREIGN KEY (student_id) REFERENCES student_schema.student (student_id)`
- `CONSTRAINT FK_exam_result_created_by FOREIGN KEY (created_by) REFERENCES security_schema.users (user_id)`
- `CONSTRAINT FK_exam_result_updated_by FOREIGN KEY (updated_by) REFERENCES security_schema.users (user_id)`

**Indexes**

- `IX_exam_result_student_scope`
- `IX_exam_result_schedule_status`
- `IX_exam_result_student_published`

### `student_schema.grievance`

- **Migration:** `013_grievance.sql`
- **Purpose:** Student grievance (complaint) and lifecycle tracking

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `grievance_id` | `BIGINT` | NOT NULL |  |
| `grievance_number` | `NVARCHAR(30)` | NOT NULL |  |
| `school_id` | `BIGINT` | NOT NULL | School scope FK |
| `branch_id` | `BIGINT` | NOT NULL | Branch scope FK |
| `academic_year_id` | `BIGINT` | NOT NULL | Academic year FK |
| `class_id` | `BIGINT` | NOT NULL | Class FK |
| `section_id` | `BIGINT` | NOT NULL | Section FK |
| `student_id` | `BIGINT` | NOT NULL | Student FK |
| `department_id` | `BIGINT` | NOT NULL |  |
| `title` | `NVARCHAR(200)` | NOT NULL |  |
| `category` | `NVARCHAR(50)` | NOT NULL |  |
| `priority_level` | `NVARCHAR(20)` | NOT NULL |  |
| `incident_date` | `DATE` | NOT NULL |  |
| `location` | `NVARCHAR(200)` | NOT NULL |  |
| `description` | `NVARCHAR(MAX)` | NOT NULL |  |
| `status` | `NVARCHAR(30)` | NOT NULL |  |
| `submitted_at` | `DATETIME2(0)` | NOT NULL |  |
| `assigned_to` | `BIGINT` | NULL |  |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NOT NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_grievance PRIMARY KEY CLUSTERED (grievance_id)`
- `CONSTRAINT UQ_grievance_number UNIQUE NONCLUSTERED (grievance_number)`
- `CONSTRAINT CK_grievance_category CHECK`
- `CONSTRAINT CK_grievance_priority CHECK`
- `CONSTRAINT CK_grievance_status CHECK`
- `CONSTRAINT CK_grievance_assigned_to_required CHECK`
- `CONSTRAINT FK_grievance_school FOREIGN KEY (school_id) REFERENCES management_schema.school (school_id)`
- `CONSTRAINT FK_grievance_branch FOREIGN KEY (branch_id) REFERENCES management_schema.branch (branch_id)`
- `CONSTRAINT FK_grievance_academic_year FOREIGN KEY (academic_year_id) REFERENCES management_schema.academic_year (academic_year_id)`
- `CONSTRAINT FK_grievance_class FOREIGN KEY (class_id) REFERENCES management_schema.school_class (class_id)`
- `CONSTRAINT FK_grievance_section FOREIGN KEY (section_id) REFERENCES management_schema.section (section_id)`
- `CONSTRAINT FK_grievance_student FOREIGN KEY (student_id) REFERENCES student_schema.student (student_id)`
- `CONSTRAINT FK_grievance_assigned_to FOREIGN KEY (assigned_to) REFERENCES security_schema.users (user_id)`
- `CONSTRAINT FK_grievance_created_by FOREIGN KEY (created_by) REFERENCES security_schema.users (user_id)`
- `CONSTRAINT FK_grievance_updated_by FOREIGN KEY (updated_by) REFERENCES security_schema.users (user_id)`

**Indexes**

- `IX_grievance_student_status`
- `IX_grievance_department_status`
- `IX_grievance_assigned_to_status`
- `IX_grievance_submitted`

### `student_schema.grievance_history`

- **Migration:** `013_grievance.sql`
- **Purpose:** Student grievance (complaint) and lifecycle tracking

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `grievance_history_id` | `BIGINT` | NOT NULL |  |
| `grievance_id` | `BIGINT` | NOT NULL |  |
| `submitted_by` | `BIGINT` | NOT NULL |  |
| `submitted_at` | `DATETIME2(0)` | NOT NULL |  |
| `assigned_to` | `BIGINT` | NULL |  |
| `reviewed_at` | `DATETIME2(0)` | NULL |  |
| `resolved_at` | `DATETIME2(0)` | NULL |  |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_grievance_history PRIMARY KEY CLUSTERED (grievance_history_id)`
- `CONSTRAINT UQ_grievance_history_grievance_id UNIQUE NONCLUSTERED (grievance_id)`
- `CONSTRAINT CK_grievance_history_resolved_requires_reviewed CHECK`
- `CONSTRAINT CK_grievance_history_reviewed_requires_assigned CHECK`
- `CONSTRAINT FK_grievance_history_grievance FOREIGN KEY (grievance_id) REFERENCES student_schema.grievance (grievance_id)`
- `CONSTRAINT FK_grievance_history_submitted_by FOREIGN KEY (submitted_by) REFERENCES security_schema.users (user_id)`
- `CONSTRAINT FK_grievance_history_assigned_to FOREIGN KEY (assigned_to) REFERENCES security_schema.users (user_id)`
- `CONSTRAINT FK_grievance_history_updated_by FOREIGN KEY (updated_by) REFERENCES security_schema.users (user_id)`

**Indexes**

- `IX_grievance_history_assigned_to`
- `IX_grievance_history_submitted_by`

### `student_schema.homework_status`

- **Migration:** `009_homework.sql`
- **Purpose:** Section-scoped homework / learning tasks (no marks) with deadlines

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `homework_status_id` | `BIGINT` | NOT NULL |  |
| `homework_id` | `BIGINT` | NOT NULL |  |
| `school_id` | `BIGINT` | NOT NULL | School scope FK |
| `branch_id` | `BIGINT` | NOT NULL | Branch scope FK |
| `academic_year_id` | `BIGINT` | NOT NULL | Academic year FK |
| `class_id` | `BIGINT` | NOT NULL | Class FK |
| `section_id` | `BIGINT` | NOT NULL | Section FK |
| `student_id` | `BIGINT` | NOT NULL | Student FK |
| `submission_status` | `NVARCHAR(20)` | NOT NULL |  |
| `submitted_at` | `DATETIME2(0)` | NULL |  |
| `submission_timing` | `NVARCHAR(20)` | NULL |  |
| `remarks` | `NVARCHAR(500)` | NULL |  |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NOT NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_homework_status PRIMARY KEY CLUSTERED (homework_status_id)`
- `CONSTRAINT UQ_homework_status_homework_student UNIQUE NONCLUSTERED (homework_id, student_id)`
- `CONSTRAINT CK_homework_status_submission_status CHECK`
- `CONSTRAINT CK_homework_status_submitted_at CHECK`
- `CONSTRAINT CK_homework_status_submission_timing CHECK`
- `CONSTRAINT FK_homework_status_homework FOREIGN KEY (homework_id) REFERENCES teachers_schema.homework (homework_id)`
- `CONSTRAINT FK_homework_status_school FOREIGN KEY (school_id) REFERENCES management_schema.school (school_id)`
- `CONSTRAINT FK_homework_status_branch FOREIGN KEY (branch_id) REFERENCES management_schema.branch (branch_id)`
- `CONSTRAINT FK_homework_status_academic_year FOREIGN KEY (academic_year_id) REFERENCES management_schema.academic_year (academic_year_id)`
- `CONSTRAINT FK_homework_status_class FOREIGN KEY (class_id) REFERENCES management_schema.school_class (class_id)`
- `CONSTRAINT FK_homework_status_section FOREIGN KEY (section_id) REFERENCES management_schema.section (section_id)`
- `CONSTRAINT FK_homework_status_student FOREIGN KEY (student_id) REFERENCES student_schema.student (student_id)`
- `CONSTRAINT FK_homework_status_created_by FOREIGN KEY (created_by) REFERENCES security_schema.users (user_id)`
- `CONSTRAINT FK_homework_status_updated_by FOREIGN KEY (updated_by) REFERENCES security_schema.users (user_id)`

**Indexes**

- `IX_homework_status_student_scope`
- `IX_homework_status_student_submission`
- `IX_homework_status_student_homework`
- `IX_homework_status_homework_submission`

### `student_schema.student`

- **Migration:** `005_student.sql`
- **Purpose:** Student master identity, current academic placement, and guardians

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `student_id` | `BIGINT` | NOT NULL | Student FK |
| `user_id` | `BIGINT` | NULL | User FK |
| `school_id` | `BIGINT` | NOT NULL | School scope FK |
| `branch_id` | `BIGINT` | NOT NULL | Branch scope FK |
| `academic_year_id` | `BIGINT` | NOT NULL | Academic year FK |
| `class_id` | `BIGINT` | NOT NULL | Class FK |
| `section_id` | `BIGINT` | NOT NULL | Section FK |
| `admission_number` | `NVARCHAR(50)` | NOT NULL |  |
| `roll_number` | `NVARCHAR(30)` | NULL |  |
| `first_name` | `NVARCHAR(100)` | NOT NULL |  |
| `middle_name` | `NVARCHAR(100)` | NULL |  |
| `last_name` | `NVARCHAR(100)` | NULL |  |
| `date_of_birth` | `DATE` | NOT NULL |  |
| `gender` | `NVARCHAR(30)` | NOT NULL |  |
| `blood_group` | `NVARCHAR(10)` | NULL |  |
| `nationality` | `NVARCHAR(100)` | NULL |  |
| `mother_tongue` | `NVARCHAR(100)` | NULL |  |
| `religion` | `NVARCHAR(100)` | NULL |  |
| `student_category` | `NVARCHAR(100)` | NULL |  |
| `admission_date` | `DATE` | NOT NULL |  |
| `student_status` | `NVARCHAR(30)` | NOT NULL |  |
| `status_effective_date` | `DATE` | NULL |  |
| `mobile_number` | `NVARCHAR(20)` | NULL |  |
| `email_address` | `NVARCHAR(254)` | NULL |  |
| `address_line_1` | `NVARCHAR(200)` | NULL |  |
| `address_line_2` | `NVARCHAR(200)` | NULL |  |
| `landmark` | `NVARCHAR(150)` | NULL |  |
| `city` | `NVARCHAR(100)` | NULL |  |
| `district` | `NVARCHAR(100)` | NULL |  |
| `state` | `NVARCHAR(100)` | NULL |  |
| `postal_code` | `NVARCHAR(20)` | NULL |  |
| `country` | `NVARCHAR(100)` | NULL |  |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NOT NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |
| `residency_type` | `NVARCHAR(20)` | NOT NULL |  |

**Constraints**

- `CONSTRAINT PK_student PRIMARY KEY CLUSTERED (student_id)`
- `CONSTRAINT UQ_student_school_admission_number UNIQUE NONCLUSTERED (school_id, admission_number)`
- `CONSTRAINT UQ_student_user_id UNIQUE NONCLUSTERED (user_id)`
- `CONSTRAINT FK_student_user FOREIGN KEY (user_id) REFERENCES security_schema.users (user_id)`
- `CONSTRAINT FK_student_school FOREIGN KEY (school_id) REFERENCES management_schema.school (school_id)`
- `CONSTRAINT FK_student_branch_scope FOREIGN KEY (school_id, branch_id) REFERENCES management_schema.branch (school_id, branch_id)`
- `CONSTRAINT FK_student_academic_year_scope FOREIGN KEY (school_id, academic_year_id) REFERENCES management_schema.academic_year (school_id, academic_year_id)`
- `CONSTRAINT FK_student_class_scope FOREIGN KEY (school_id, class_id) REFERENCES management_schema.school_class (school_id, class_id)`
- `CONSTRAINT FK_student_section_scope FOREIGN KEY (class_id, section_id) REFERENCES management_schema.section (class_id, section_id)`
- `CONSTRAINT FK_student_created_by FOREIGN KEY (created_by) REFERENCES security_schema.users (user_id)`
- `CONSTRAINT FK_student_updated_by FOREIGN KEY (updated_by) REFERENCES security_schema.users (user_id)`

**Indexes**

- `IX_student_academic_scope`
- `IX_student_branch_status`
- `IX_student_name`
- `IX_student_roll_number`
- `UQ_student_school_branch_student`
- `UQ_student_placement_scope`
- `UQ_student_id_placement_scope`

### `student_schema.student_achievement`

- **Migration:** `018_student_achievements.sql`
- **Purpose:** Student achievements catalog and tracking

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `achievement_id` | `BIGINT` | NOT NULL |  |
| `school_id` | `BIGINT` | NOT NULL | School scope FK |
| `branch_id` | `BIGINT` | NOT NULL | Branch scope FK |
| `student_id` | `BIGINT` | NOT NULL | Student FK |
| `achievement_title` | `NVARCHAR(200)` | NOT NULL |  |
| `category` | `NVARCHAR(100)` | NOT NULL |  |
| `description` | `NVARCHAR(MAX)` | NULL |  |
| `achievement_place` | `NVARCHAR(50)` | NOT NULL |  |
| `achievement_level` | `NVARCHAR(50)` | NOT NULL |  |
| `date_issued` | `DATE` | NOT NULL |  |
| `certificate_url` | `NVARCHAR(500)` | NULL |  |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NOT NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_student_achievement PRIMARY KEY CLUSTERED (achievement_id)`
- `CONSTRAINT CK_student_achievement_title CHECK (LEN(LTRIM(RTRIM(achievement_title))) > 0)`
- `CONSTRAINT CK_student_achievement_category CHECK (LEN(LTRIM(RTRIM(category))) > 0)`
- `CONSTRAINT CK_student_achievement_place CHECK (LEN(LTRIM(RTRIM(achievement_place))) > 0)`
- `CONSTRAINT CK_student_achievement_level CHECK`
- `CONSTRAINT FK_student_achievement_school FOREIGN KEY (school_id) REFERENCES management_schema.school (school_id)`
- `CONSTRAINT FK_student_achievement_branch FOREIGN KEY (branch_id) REFERENCES management_schema.branch (branch_id)`
- `CONSTRAINT FK_student_achievement_student_scope FOREIGN KEY (school_id, branch_id, student_id)`
- `CONSTRAINT FK_student_achievement_created_by FOREIGN KEY (created_by) REFERENCES security_schema.users (user_id)`
- `CONSTRAINT FK_student_achievement_updated_by FOREIGN KEY (updated_by) REFERENCES security_schema.users (user_id)`

**Indexes**

- `IX_student_achievement_student_branch`
- `IX_student_achievement_branch_date`
- `IX_student_achievement_category_level`

### `student_schema.student_attendance`

- **Migration:** `010_attendance.sql`
- **Purpose:** Period-wise student attendance linked to timetable

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `student_attendance_id` | `BIGINT` | NOT NULL |  |
| `school_id` | `BIGINT` | NOT NULL | School scope FK |
| `branch_id` | `BIGINT` | NOT NULL | Branch scope FK |
| `academic_year_id` | `BIGINT` | NOT NULL | Academic year FK |
| `class_id` | `BIGINT` | NOT NULL | Class FK |
| `section_id` | `BIGINT` | NOT NULL | Section FK |
| `student_id` | `BIGINT` | NOT NULL | Student FK |
| `timetable_id` | `BIGINT` | NOT NULL |  |
| `timetable_period_id` | `BIGINT` | NOT NULL |  |
| `attendance_date` | `DATE` | NOT NULL |  |
| `subject_id` | `BIGINT` | NOT NULL | Subject FK |
| `teacher_id` | `BIGINT` | NOT NULL | Teacher FK |
| `period_number` | `TINYINT` | NOT NULL |  |
| `start_time` | `TIME(0)` | NOT NULL |  |
| `end_time` | `TIME(0)` | NOT NULL |  |
| `attendance_status` | `NVARCHAR(10)` | NOT NULL |  |
| `recorded_at` | `DATETIME2(0)` | NOT NULL | Recorded timestamp (UTC) |
| `recorded_by` | `BIGINT` | NOT NULL | User who recorded |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NOT NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_student_attendance PRIMARY KEY CLUSTERED (student_attendance_id)`
- `CONSTRAINT UQ_student_attendance_student_period_date UNIQUE NONCLUSTERED`
- `CONSTRAINT CK_student_attendance_status CHECK`
- `CONSTRAINT CK_student_attendance_period_number CHECK (period_number > 0)`
- `CONSTRAINT CK_student_attendance_time CHECK (end_time > start_time)`
- `CONSTRAINT FK_student_attendance_school FOREIGN KEY (school_id) REFERENCES management_schema.school (school_id)`
- `CONSTRAINT FK_student_attendance_branch FOREIGN KEY (branch_id) REFERENCES management_schema.branch (branch_id)`
- `CONSTRAINT FK_student_attendance_academic_year FOREIGN KEY (academic_year_id) REFERENCES management_schema.academic_year (academic_year_id)`
- `CONSTRAINT FK_student_attendance_class FOREIGN KEY (class_id) REFERENCES management_schema.school_class (class_id)`
- `CONSTRAINT FK_student_attendance_section FOREIGN KEY (section_id) REFERENCES management_schema.section (section_id)`
- `CONSTRAINT FK_student_attendance_student FOREIGN KEY (student_id) REFERENCES student_schema.student (student_id)`
- `CONSTRAINT FK_student_attendance_timetable FOREIGN KEY (timetable_id) REFERENCES management_schema.timetable (timetable_id)`
- `CONSTRAINT FK_student_attendance_timetable_period FOREIGN KEY (timetable_period_id) REFERENCES management_schema.timetable_period (timetable_period_id)`
- `CONSTRAINT FK_student_attendance_subject FOREIGN KEY (subject_id) REFERENCES management_schema.subject (subject_id)`
- `CONSTRAINT FK_student_attendance_teacher FOREIGN KEY (teacher_id) REFERENCES teachers_schema.teacher (teacher_id)`
- `CONSTRAINT FK_student_attendance_recorded_by FOREIGN KEY (recorded_by) REFERENCES security_schema.users (user_id)`
- `CONSTRAINT FK_student_attendance_created_by FOREIGN KEY (created_by) REFERENCES security_schema.users (user_id)`
- `CONSTRAINT FK_student_attendance_updated_by FOREIGN KEY (updated_by) REFERENCES security_schema.users (user_id)`

**Indexes**

- `IX_student_attendance_student_date`
- `IX_student_attendance_student_year_date`
- `IX_student_attendance_section_date`
- `IX_student_attendance_section_period_date`
- `IX_student_attendance_teacher_date`
- `IX_student_attendance_status_date`
- `IX_student_attendance_timetable_period_date`

### `student_schema.student_cultural_participation`

- **Migration:** `023_cultural_participation.sql`
- **Purpose:** Store student-wise, event-wise cultural participation and performance details

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `cultural_participation_id` | `BIGINT` | NOT NULL |  |
| `student_id` | `BIGINT` | NOT NULL | Student FK |
| `school_id` | `BIGINT` | NOT NULL | School scope FK |
| `branch_id` | `BIGINT` | NOT NULL | Branch scope FK |
| `academic_year_id` | `BIGINT` | NOT NULL | Academic year FK |
| `class_id` | `BIGINT` | NOT NULL | Class FK |
| `section_id` | `BIGINT` | NOT NULL | Section FK |
| `announcement_id` | `BIGINT` | NOT NULL |  |
| `event_name` | `NVARCHAR(200)` | NOT NULL |  |
| `teacher_id` | `BIGINT` | NOT NULL | Teacher FK |
| `category` | `NVARCHAR(100)` | NOT NULL |  |
| `role_involvement` | `NVARCHAR(100)` | NULL |  |
| `result` | `NVARCHAR(100)` | NULL |  |
| `participation_status` | `NVARCHAR(30)` | NOT NULL |  |
| `participation_date` | `DATE` | NULL |  |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_student_cultural_participation`
- `CONSTRAINT CK_student_cultural_part_status`
- `CONSTRAINT CK_student_cultural_part_category`
- `CONSTRAINT CK_student_cultural_part_role`
- `CONSTRAINT CK_student_cultural_part_result`
- `CONSTRAINT FK_student_cultural_part_student`
- `CONSTRAINT FK_student_cultural_part_school`
- `CONSTRAINT FK_student_cultural_part_branch`
- `CONSTRAINT FK_student_cultural_part_academic_year`
- `CONSTRAINT FK_student_cultural_part_class`
- `CONSTRAINT FK_student_cultural_part_section`
- `CONSTRAINT FK_student_cultural_part_announcement`
- `CONSTRAINT FK_student_cultural_part_teacher`

**Indexes**

- `UX_student_cultural_part_student_announcement_active`
- `IX_student_cultural_part_student_history`
- `IX_student_cultural_part_announcement_active`
- `IX_student_cultural_part_section_year`
- `IX_student_cultural_part_teacher_active`
- `IX_student_cultural_part_school_branch_year`

### `student_schema.student_exam_performance`

- **Migration:** `021_student_exam_performance.sql`
- **Purpose:** Store backend-generated exam performance summary metrics for each student

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `student_exam_performance_id` | `BIGINT` | NOT NULL |  |
| `student_id` | `BIGINT` | NOT NULL | Student FK |
| `academic_year_id` | `BIGINT` | NOT NULL | Academic year FK |
| `class_id` | `BIGINT` | NOT NULL | Class FK |
| `section_id` | `BIGINT` | NOT NULL | Section FK |
| `total_exams_count` | `INT` | NOT NULL |  |
| `overall_percentage` | `DECIMAL(5, 2)` | NOT NULL |  |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_student_exam_performance PRIMARY KEY CLUSTERED (student_exam_performance_id)`
- `CONSTRAINT UQ_student_exam_performance_student_scope UNIQUE NONCLUSTERED`
- `CONSTRAINT CK_student_exam_performance_total_exams CHECK`
- `CONSTRAINT CK_student_exam_performance_overall_percentage CHECK`
- `CONSTRAINT FK_student_exam_performance_student FOREIGN KEY (student_id)`
- `CONSTRAINT FK_student_exam_performance_academic_year FOREIGN KEY (academic_year_id)`
- `CONSTRAINT FK_student_exam_performance_class FOREIGN KEY (class_id)`
- `CONSTRAINT FK_student_exam_performance_section FOREIGN KEY (section_id)`

**Indexes**

- `IX_student_exam_performance_scope`
- `IX_student_exam_performance_student`

### `student_schema.student_guardian`

- **Migration:** `005_student.sql`
- **Purpose:** Student master identity, current academic placement, and guardians

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `student_guardian_id` | `BIGINT` | NOT NULL |  |
| `student_id` | `BIGINT` | NOT NULL | Student FK |
| `guardian_name` | `NVARCHAR(200)` | NOT NULL |  |
| `relationship_type` | `NVARCHAR(50)` | NOT NULL |  |
| `mobile_number` | `NVARCHAR(20)` | NULL |  |
| `alternate_mobile_number` | `NVARCHAR(20)` | NULL |  |
| `email_address` | `NVARCHAR(254)` | NULL |  |
| `occupation` | `NVARCHAR(150)` | NULL |  |
| `organization_name` | `NVARCHAR(200)` | NULL |  |
| `is_legal_guardian` | `BIT` | NOT NULL |  |
| `is_primary_contact` | `BIT` | NOT NULL |  |
| `is_emergency_contact` | `BIT` | NOT NULL |  |
| `is_pickup_authorized` | `BIT` | NOT NULL |  |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NOT NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_student_guardian PRIMARY KEY CLUSTERED (student_guardian_id)`
- `CONSTRAINT FK_student_guardian_student FOREIGN KEY (student_id) REFERENCES student_schema.student (student_id)`
- `CONSTRAINT FK_student_guardian_created_by FOREIGN KEY (created_by) REFERENCES security_schema.users (user_id)`
- `CONSTRAINT FK_student_guardian_updated_by FOREIGN KEY (updated_by) REFERENCES security_schema.users (user_id)`

**Indexes**

- `IX_student_guardian_student`
- `IX_student_guardian_relationship`
- `UX_student_guardian_primary_contact`

### `student_schema.student_leave`

- **Migration:** `011_leave.sql`
- **Purpose:** Student leave applications (students only â€" not teacher/staff leave)

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `student_leave_id` | `BIGINT` | NOT NULL |  |
| `school_id` | `BIGINT` | NOT NULL | School scope FK |
| `branch_id` | `BIGINT` | NOT NULL | Branch scope FK |
| `academic_year_id` | `BIGINT` | NOT NULL | Academic year FK |
| `class_id` | `BIGINT` | NOT NULL | Class FK |
| `section_id` | `BIGINT` | NOT NULL | Section FK |
| `student_id` | `BIGINT` | NOT NULL | Student FK |
| `leave_type` | `NVARCHAR(30)` | NOT NULL |  |
| `duration_type` | `NVARCHAR(20)` | NOT NULL |  |
| `half_day_session` | `NVARCHAR(20)` | NULL |  |
| `start_date` | `DATE` | NOT NULL |  |
| `end_date` | `DATE` | NOT NULL |  |
| `reason` | `NVARCHAR(500)` | NOT NULL |  |
| `status` | `NVARCHAR(20)` | NOT NULL |  |
| `applied_at` | `DATETIME2(0)` | NOT NULL |  |
| `reviewed_at` | `DATETIME2(0)` | NULL |  |
| `reviewed_by` | `BIGINT` | NULL |  |
| `review_remarks` | `NVARCHAR(500)` | NULL |  |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NOT NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |
| `cancelled_at` | `DATETIME2(0)` | NULL |  |
| `cancelled_by` | `BIGINT` | NULL |  |
| `cancellation_remarks` | `NVARCHAR(500)` | NULL |  |
| `duration` | `DECIMAL(4, 2)` | NOT NULL |  |

**Constraints**

- `CONSTRAINT PK_student_leave PRIMARY KEY CLUSTERED (student_leave_id)`
- `CONSTRAINT CK_student_leave_type CHECK`
- `CONSTRAINT CK_student_leave_duration_type CHECK`
- `CONSTRAINT CK_student_leave_half_day_session CHECK`
- `CONSTRAINT CK_student_leave_status CHECK`
- `CONSTRAINT CK_student_leave_date_range CHECK (end_date >= start_date)`
- `CONSTRAINT CK_student_leave_half_day CHECK`
- `CONSTRAINT CK_student_leave_full_day CHECK`
- `CONSTRAINT CK_student_leave_multiple_days CHECK`
- `CONSTRAINT CK_student_leave_apply_before_leave_day CHECK`
- `CONSTRAINT CK_student_leave_reviewed CHECK`
- `CONSTRAINT FK_student_leave_school FOREIGN KEY (school_id) REFERENCES management_schema.school (school_id)`
- `CONSTRAINT FK_student_leave_branch FOREIGN KEY (branch_id) REFERENCES management_schema.branch (branch_id)`
- `CONSTRAINT FK_student_leave_academic_year FOREIGN KEY (academic_year_id) REFERENCES management_schema.academic_year (academic_year_id)`
- `CONSTRAINT FK_student_leave_class FOREIGN KEY (class_id) REFERENCES management_schema.school_class (class_id)`
- `CONSTRAINT FK_student_leave_section FOREIGN KEY (section_id) REFERENCES management_schema.section (section_id)`
- `CONSTRAINT FK_student_leave_student FOREIGN KEY (student_id) REFERENCES student_schema.student (student_id)`
- `CONSTRAINT FK_student_leave_reviewed_by FOREIGN KEY (reviewed_by) REFERENCES security_schema.users (user_id)`
- `CONSTRAINT FK_student_leave_cancelled_by FOREIGN KEY (cancelled_by) REFERENCES security_schema.users (user_id)`
- `CONSTRAINT FK_student_leave_created_by FOREIGN KEY (created_by) REFERENCES security_schema.users (user_id)`
- `CONSTRAINT FK_student_leave_updated_by FOREIGN KEY (updated_by) REFERENCES security_schema.users (user_id)`

**Indexes**

- `IX_student_leave_student_dates`
- `IX_student_leave_section_status`
- `IX_student_leave_approved_student_dates`
- `IX_student_leave_pending`
- `IX_student_leave_approved_student_dates`

### `student_schema.student_leave_status_history`

- **Migration:** `025_sports_and_grievance_department.sql`
- **Purpose:** Synchronize missing application tables, schemas, and columns from SSMS server:

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `student_leave_status_history_id` | `BIGINT` | NOT NULL |  |
| `student_leave_id` | `BIGINT` | NOT NULL |  |
| `old_status` | `NVARCHAR(20)` | NULL |  |
| `new_status` | `NVARCHAR(20)` | NOT NULL |  |
| `changed_by` | `BIGINT` | NOT NULL |  |
| `changed_at` | `DATETIME2(0)` | NOT NULL |  |
| `remarks` | `NVARCHAR(500)` | NULL |  |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_student_leave_status_history PRIMARY KEY CLUSTERED (student_leave_status_history_id)`
- `CONSTRAINT FK_student_leave_status_history_leave FOREIGN KEY (student_leave_id)`
- `CONSTRAINT FK_student_leave_status_history_changed_by FOREIGN KEY (changed_by)`

**Indexes**

- `IX_student_leave_status_history_leave`

### `student_schema.student_personality_development`

- **Migration:** `022_personal_development.sql`
- **Purpose:** Store official student personality development ratings maintained by

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `personality_development_id` | `BIGINT` | NOT NULL |  |
| `school_id` | `BIGINT` | NOT NULL | School scope FK |
| `branch_id` | `BIGINT` | NOT NULL | Branch scope FK |
| `academic_year_id` | `BIGINT` | NOT NULL | Academic year FK |
| `class_id` | `BIGINT` | NOT NULL | Class FK |
| `section_id` | `BIGINT` | NOT NULL | Section FK |
| `student_id` | `BIGINT` | NOT NULL | Student FK |
| `class_teacher_id` | `BIGINT` | NOT NULL |  |
| `leadership_rating` | `DECIMAL(3, 2)` | NULL |  |
| `communication_rating` | `DECIMAL(3, 2)` | NULL |  |
| `collaboration_rating` | `DECIMAL(3, 2)` | NULL |  |
| `responsibility_rating` | `DECIMAL(3, 2)` | NULL |  |
| `overall_rating` | `DECIMAL(3, 2)` | NULL |  |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NOT NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_student_personality_development PRIMARY KEY CLUSTERED (personality_development_id)`
- `CONSTRAINT UQ_student_personality_dev_student_year UNIQUE NONCLUSTERED (student_id, academic_year_id)`
- `CONSTRAINT CK_student_personality_dev_leadership`
- `CONSTRAINT CK_student_personality_dev_communication`
- `CONSTRAINT CK_student_personality_dev_collaboration`
- `CONSTRAINT CK_student_personality_dev_responsibility`
- `CONSTRAINT CK_student_personality_dev_overall`
- `CONSTRAINT FK_student_personality_dev_school`
- `CONSTRAINT FK_student_personality_dev_branch`
- `CONSTRAINT FK_student_personality_dev_academic_year`
- `CONSTRAINT FK_student_personality_dev_class`
- `CONSTRAINT FK_student_personality_dev_section`
- `CONSTRAINT FK_student_personality_dev_student`
- `CONSTRAINT FK_student_personality_dev_class_teacher`
- `CONSTRAINT FK_student_personality_dev_created_by`
- `CONSTRAINT FK_student_personality_dev_updated_by`

**Indexes**

- `IX_student_personality_dev_student_year`
- `IX_student_personality_dev_scope`

### `student_schema.student_personality_development_review`

- **Migration:** `022_personal_development.sql`
- **Purpose:** Store official student personality development ratings maintained by

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `personality_review_id` | `BIGINT` | NOT NULL |  |
| `school_id` | `BIGINT` | NOT NULL | School scope FK |
| `branch_id` | `BIGINT` | NOT NULL | Branch scope FK |
| `academic_year_id` | `BIGINT` | NOT NULL | Academic year FK |
| `class_id` | `BIGINT` | NOT NULL | Class FK |
| `section_id` | `BIGINT` | NOT NULL | Section FK |
| `student_id` | `BIGINT` | NOT NULL | Student FK |
| `teacher_id` | `BIGINT` | NOT NULL | Teacher FK |
| `subject_id` | `BIGINT` | NOT NULL | Subject FK |
| `category_type` | `NVARCHAR(50)` | NOT NULL |  |
| `rating` | `INT` | NOT NULL |  |
| `review` | `NVARCHAR(MAX)` | NOT NULL |  |
| `review_date` | `DATE` | NOT NULL |  |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NOT NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_student_personality_development_review PRIMARY KEY CLUSTERED (personality_review_id)`
- `CONSTRAINT UQ_student_personality_dev_rev_session UNIQUE NONCLUSTERED`
- `CONSTRAINT CK_student_personality_dev_rev_text`
- `CONSTRAINT CK_student_personality_dev_rev_category`
- `CONSTRAINT CK_student_personality_dev_rev_rating`
- `CONSTRAINT FK_student_personality_dev_rev_school`
- `CONSTRAINT FK_student_personality_dev_rev_branch`
- `CONSTRAINT FK_student_personality_dev_rev_academic_year`
- `CONSTRAINT FK_student_personality_dev_rev_class`
- `CONSTRAINT FK_student_personality_dev_rev_section`
- `CONSTRAINT FK_student_personality_dev_rev_student`
- `CONSTRAINT FK_student_personality_dev_rev_teacher`
- `CONSTRAINT FK_student_personality_dev_rev_subject`
- `CONSTRAINT FK_student_personality_dev_rev_created_by`
- `CONSTRAINT FK_student_personality_dev_rev_updated_by`

**Indexes**

- `IX_student_personality_dev_rev_student_year`
- `IX_student_personality_dev_rev_student_subject_year`
- `IX_student_personality_dev_rev_teacher_subject`

## `teachers_schema`

### `teachers_schema.assessment`

- **Migration:** `006_assessment.sql`
- **Purpose:** Assessment master (project works, slip tests, quizzes - subject-wise) and per-student assessment marks

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `assessment_id` | `BIGINT` | NOT NULL |  |
| `school_id` | `BIGINT` | NOT NULL | School scope FK |
| `academic_year_id` | `BIGINT` | NOT NULL | Academic year FK |
| `branch_id` | `BIGINT` | NOT NULL | Branch scope FK |
| `class_id` | `BIGINT` | NOT NULL | Class FK |
| `section_id` | `BIGINT` | NOT NULL | Section FK |
| `subject_id` | `BIGINT` | NOT NULL | Subject FK |
| `teacher_id` | `BIGINT` | NOT NULL | Teacher FK |
| `title` | `NVARCHAR(200)` | NOT NULL |  |
| `assessment_type` | `NVARCHAR(50)` | NOT NULL |  |
| `assessment_date` | `DATE` | NOT NULL |  |
| `max_marks` | `DECIMAL(6, 2)` | NOT NULL |  |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NOT NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_assessment PRIMARY KEY CLUSTERED (assessment_id)`
- `CONSTRAINT CK_assessment_type CHECK`
- `CONSTRAINT CK_assessment_max_marks CHECK (max_marks > 0)`
- `CONSTRAINT FK_assessment_school FOREIGN KEY (school_id) REFERENCES management_schema.school (school_id)`
- `CONSTRAINT FK_assessment_academic_year_scope FOREIGN KEY (school_id, academic_year_id)`
- `CONSTRAINT FK_assessment_branch_scope FOREIGN KEY (school_id, branch_id)`
- `CONSTRAINT FK_assessment_class_scope FOREIGN KEY (school_id, class_id)`
- `CONSTRAINT FK_assessment_section_scope FOREIGN KEY (class_id, section_id)`
- `CONSTRAINT FK_assessment_subject FOREIGN KEY (subject_id) REFERENCES management_schema.subject (subject_id)`
- `CONSTRAINT FK_assessment_teacher FOREIGN KEY (teacher_id) REFERENCES teachers_schema.teacher (teacher_id)`
- `CONSTRAINT FK_assessment_created_by FOREIGN KEY (created_by) REFERENCES security_schema.users (user_id)`
- `CONSTRAINT FK_assessment_updated_by FOREIGN KEY (updated_by) REFERENCES security_schema.users (user_id)`

**Indexes**

- `IX_assessment_scope_date`
- `IX_assessment_teacher_active`
- `IX_assessment_subject`

### `teachers_schema.homework`

- **Migration:** `009_homework.sql`
- **Purpose:** Section-scoped homework / learning tasks (no marks) with deadlines

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `homework_id` | `BIGINT` | NOT NULL |  |
| `school_id` | `BIGINT` | NOT NULL | School scope FK |
| `academic_year_id` | `BIGINT` | NOT NULL | Academic year FK |
| `branch_id` | `BIGINT` | NOT NULL | Branch scope FK |
| `class_id` | `BIGINT` | NOT NULL | Class FK |
| `section_id` | `BIGINT` | NOT NULL | Section FK |
| `subject_id` | `BIGINT` | NOT NULL | Subject FK |
| `teacher_id` | `BIGINT` | NOT NULL | Teacher FK |
| `homework_type` | `NVARCHAR(50)` | NOT NULL |  |
| `title` | `NVARCHAR(200)` | NOT NULL |  |
| `description` | `NVARCHAR(MAX)` | NULL |  |
| `priority_level` | `NVARCHAR(20)` | NOT NULL |  |
| `assigned_at` | `DATETIME2(0)` | NOT NULL |  |
| `deadline_at` | `DATETIME2(0)` | NOT NULL |  |
| `status` | `NVARCHAR(20)` | NOT NULL |  |
| `estimated_minutes` | `INT` | NULL |  |
| `published_at` | `DATETIME2(0)` | NULL |  |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NOT NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_homework PRIMARY KEY CLUSTERED (homework_id)`
- `CONSTRAINT CK_homework_type CHECK`
- `CONSTRAINT CK_homework_priority CHECK (priority_level IN (N'HIGH', N'MEDIUM', N'LOW'))`
- `CONSTRAINT CK_homework_status CHECK (status IN (N'DRAFT', N'PUBLISHED', N'CLOSED', N'CANCELLED'))`
- `CONSTRAINT CK_homework_estimated_minutes CHECK (estimated_minutes IS NULL OR estimated_minutes >= 0)`
- `CONSTRAINT CK_homework_deadline CHECK (deadline_at >= assigned_at)`
- `CONSTRAINT CK_homework_published_at CHECK`
- `CONSTRAINT FK_homework_school FOREIGN KEY (school_id) REFERENCES management_schema.school (school_id)`
- `CONSTRAINT FK_homework_academic_year FOREIGN KEY (academic_year_id) REFERENCES management_schema.academic_year (academic_year_id)`
- `CONSTRAINT FK_homework_branch FOREIGN KEY (branch_id) REFERENCES management_schema.branch (branch_id)`
- `CONSTRAINT FK_homework_class FOREIGN KEY (class_id) REFERENCES management_schema.school_class (class_id)`
- `CONSTRAINT FK_homework_section FOREIGN KEY (section_id) REFERENCES management_schema.section (section_id)`
- `CONSTRAINT FK_homework_subject FOREIGN KEY (subject_id) REFERENCES management_schema.subject (subject_id)`
- `CONSTRAINT FK_homework_teacher FOREIGN KEY (teacher_id) REFERENCES teachers_schema.teacher (teacher_id)`
- `CONSTRAINT FK_homework_created_by FOREIGN KEY (created_by) REFERENCES security_schema.users (user_id)`
- `CONSTRAINT FK_homework_updated_by FOREIGN KEY (updated_by) REFERENCES security_schema.users (user_id)`

**Indexes**

- `IX_homework_scope_status_deadline`
- `IX_homework_teacher_active`

### `teachers_schema.section_class_teacher_assignment`

- **Migration:** `019_student_residency_and_section_class_teacher.sql`
- **Purpose:** - Classify each student as a hosteller or day scholar.

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `section_class_teacher_assignment_id` | `BIGINT` | NOT NULL |  |
| `school_id` | `BIGINT` | NOT NULL | School scope FK |
| `branch_id` | `BIGINT` | NOT NULL | Branch scope FK |
| `academic_year_id` | `BIGINT` | NOT NULL | Academic year FK |
| `class_id` | `BIGINT` | NOT NULL | Class FK |
| `section_id` | `BIGINT` | NOT NULL | Section FK |
| `teacher_id` | `BIGINT` | NOT NULL | Teacher FK |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NOT NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_section_class_teacher_assignment PRIMARY KEY CLUSTERED (section_class_teacher_assignment_id)`
- `CONSTRAINT FK_section_class_teacher_assignment_school FOREIGN KEY (school_id) REFERENCES management_schema.school (school_id)`
- `CONSTRAINT FK_section_class_teacher_assignment_branch_scope FOREIGN KEY (school_id, branch_id)`
- `CONSTRAINT FK_section_class_teacher_assignment_academic_year_scope FOREIGN KEY (school_id, academic_year_id)`
- `CONSTRAINT FK_section_class_teacher_assignment_class_scope FOREIGN KEY (school_id, class_id)`
- `CONSTRAINT FK_section_class_teacher_assignment_section_scope FOREIGN KEY (class_id, section_id)`
- `CONSTRAINT FK_section_class_teacher_assignment_teacher_scope FOREIGN KEY (school_id, branch_id, teacher_id)`
- `CONSTRAINT FK_section_class_teacher_assignment_created_by FOREIGN KEY (created_by)`
- `CONSTRAINT FK_section_class_teacher_assignment_updated_by FOREIGN KEY (updated_by)`

**Indexes**

- `UX_section_class_teacher_assignment_active_scope`
- `IX_section_class_teacher_assignment_teacher_active`

### `teachers_schema.teacher`

- **Migration:** `004_teacher.sql`
- **Purpose:** Teacher master identity within school/branch scope

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `teacher_id` | `BIGINT` | NOT NULL | Teacher FK |
| `user_id` | `BIGINT` | NULL | User FK |
| `school_id` | `BIGINT` | NOT NULL | School scope FK |
| `branch_id` | `BIGINT` | NOT NULL | Branch scope FK |
| `subject_id` | `BIGINT` | NULL | Subject FK |
| `designation` | `VARCHAR(100)` | NOT NULL |  |
| `employee_code` | `NVARCHAR(50)` | NOT NULL |  |
| `first_name` | `NVARCHAR(100)` | NOT NULL |  |
| `middle_name` | `NVARCHAR(100)` | NULL |  |
| `last_name` | `NVARCHAR(100)` | NULL |  |
| `mobile_number` | `NVARCHAR(20)` | NULL |  |
| `email_address` | `NVARCHAR(254)` | NULL |  |
| `status` | `NVARCHAR(20)` | NOT NULL |  |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_teacher PRIMARY KEY CLUSTERED (teacher_id)`
- `CONSTRAINT UQ_teacher_school_employee_code UNIQUE NONCLUSTERED (school_id, employee_code)`
- `CONSTRAINT UQ_teacher_user_id UNIQUE NONCLUSTERED (user_id)`
- `CONSTRAINT CK_teacher_status CHECK (status IN (N'ACTIVE', N'INACTIVE', N'ON_LEAVE'))`
- `CONSTRAINT FK_teacher_user FOREIGN KEY (user_id) REFERENCES security_schema.users (user_id)`
- `CONSTRAINT FK_teacher_school FOREIGN KEY (school_id) REFERENCES management_schema.school (school_id)`
- `CONSTRAINT FK_teacher_branch_scope FOREIGN KEY (school_id, branch_id) REFERENCES management_schema.branch (school_id, branch_id)`
- `CONSTRAINT FK_teacher_subject FOREIGN KEY (subject_id) REFERENCES management_schema.subject (subject_id)`
- `CONSTRAINT FK_teacher_created_by FOREIGN KEY (created_by) REFERENCES security_schema.users (user_id)`
- `CONSTRAINT FK_teacher_updated_by FOREIGN KEY (updated_by) REFERENCES security_schema.users (user_id)`

**Indexes**

- `IX_teacher_school_branch_active`
- `IX_teacher_subject_active`

### `teachers_schema.teacher_attendance`

- **Migration:** `027_teacher_attendance.sql`
- **Purpose:** teachers_schema

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `teacher_attendance_id` | `BIGINT` | NOT NULL |  |
| `school_id` | `BIGINT` | NOT NULL | School scope FK |
| `branch_id` | `BIGINT` | NOT NULL | Branch scope FK |
| `academic_year_id` | `BIGINT` | NOT NULL | Academic year FK |
| `teacher_id` | `BIGINT` | NOT NULL | Teacher FK |
| `attendance_date` | `DATE` | NOT NULL |  |
| `attendance_status` | `VARCHAR(20)` | NOT NULL |  |
| `check_in_time` | `DATETIME2(0)` | NULL |  |
| `check_out_time` | `DATETIME2(0)` | NULL |  |
| `total_worked_minutes` | `INT` | NULL |  |
| `remarks` | `NVARCHAR(500)` | NULL |  |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NOT NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_teacher_attendance PRIMARY KEY CLUSTERED (teacher_attendance_id)`
- `CONSTRAINT UQ_teacher_attendance_teacher_date UNIQUE NONCLUSTERED (teacher_id, attendance_date)`
- `CONSTRAINT CK_teacher_attendance_status CHECK`
- `CONSTRAINT CK_teacher_attendance_checkout_requires_checkin CHECK`
- `CONSTRAINT CK_teacher_attendance_time_order CHECK`
- `CONSTRAINT CK_teacher_attendance_worked_minutes CHECK`
- `CONSTRAINT CK_teacher_attendance_checkout_requires_duration CHECK`
- `CONSTRAINT CK_teacher_attendance_present_requires_checkin CHECK`
- `CONSTRAINT CK_teacher_attendance_inactive_no_timestamps CHECK`
- `CONSTRAINT FK_teacher_attendance_school FOREIGN KEY (school_id)`
- `CONSTRAINT FK_teacher_attendance_branch_scope FOREIGN KEY (school_id, branch_id)`
- `CONSTRAINT FK_teacher_attendance_academic_year_scope FOREIGN KEY (school_id, academic_year_id)`
- `CONSTRAINT FK_teacher_attendance_teacher FOREIGN KEY (teacher_id)`
- `CONSTRAINT FK_teacher_attendance_created_by FOREIGN KEY (created_by)`
- `CONSTRAINT FK_teacher_attendance_updated_by FOREIGN KEY (updated_by)`

**Indexes**

- `IX_teacher_attendance_branch_daily`
- `IX_teacher_attendance_teacher_history`

### `teachers_schema.teacher_grievance`

- **Migration:** `026_teacher_leave_and_grievance.sql`
- **Purpose:** Production-ready, non-destructive DDL migration for:

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `teacher_grievance_id` | `BIGINT` | NOT NULL |  |
| `school_id` | `BIGINT` | NOT NULL | School scope FK |
| `branch_id` | `BIGINT` | NOT NULL | Branch scope FK |
| `academic_year_id` | `BIGINT` | NULL | Academic year FK |
| `teacher_id` | `BIGINT` | NOT NULL | Teacher FK |
| `grievance_title` | `NVARCHAR(200)` | NOT NULL |  |
| `grievance_category` | `VARCHAR(50)` | NOT NULL |  |
| `priority` | `VARCHAR(20)` | NOT NULL |  |
| `incident_date` | `DATE` | NULL |  |
| `incident_location` | `NVARCHAR(200)` | NULL |  |
| `description` | `NVARCHAR(2000)` | NOT NULL |  |
| `status` | `NVARCHAR(20)` | NOT NULL |  |
| `assigned_to` | `BIGINT` | NULL |  |
| `resolution_remarks` | `NVARCHAR(2000)` | NULL |  |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NOT NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_teacher_grievance PRIMARY KEY CLUSTERED (teacher_grievance_id)`
- `CONSTRAINT CK_teacher_grievance_category CHECK`
- `CONSTRAINT CK_teacher_grievance_priority CHECK`
- `CONSTRAINT CK_teacher_grievance_status CHECK`
- `CONSTRAINT FK_teacher_grievance_school FOREIGN KEY (school_id)`
- `CONSTRAINT FK_teacher_grievance_branch_scope FOREIGN KEY (school_id, branch_id)`
- `CONSTRAINT FK_teacher_grievance_academic_year_scope FOREIGN KEY (school_id, academic_year_id)`
- `CONSTRAINT FK_teacher_grievance_teacher FOREIGN KEY (teacher_id)`
- `CONSTRAINT FK_teacher_grievance_assigned_to FOREIGN KEY (assigned_to)`
- `CONSTRAINT FK_teacher_grievance_created_by FOREIGN KEY (created_by)`
- `CONSTRAINT FK_teacher_grievance_updated_by FOREIGN KEY (updated_by)`

**Indexes**

- `IX_teacher_grievance_teacher_scope`
- `IX_teacher_grievance_school_branch_status`

### `teachers_schema.teacher_grievance_status_history`

- **Migration:** `026_teacher_leave_and_grievance.sql`
- **Purpose:** Production-ready, non-destructive DDL migration for:

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `teacher_grievance_status_history_id` | `BIGINT` | NOT NULL |  |
| `teacher_grievance_id` | `BIGINT` | NOT NULL |  |
| `old_status` | `NVARCHAR(20)` | NULL |  |
| `new_status` | `NVARCHAR(20)` | NOT NULL |  |
| `changed_by` | `BIGINT` | NOT NULL |  |
| `changed_at` | `DATETIME2(0)` | NOT NULL |  |
| `remarks` | `NVARCHAR(500)` | NULL |  |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_teacher_grievance_status_history PRIMARY KEY CLUSTERED (teacher_grievance_status_history_id)`
- `CONSTRAINT CK_teacher_grievance_status_history_old CHECK`
- `CONSTRAINT CK_teacher_grievance_status_history_new CHECK`
- `CONSTRAINT FK_teacher_grievance_status_history_grievance FOREIGN KEY (teacher_grievance_id)`
- `CONSTRAINT FK_teacher_grievance_status_history_changed_by FOREIGN KEY (changed_by)`

**Indexes**

- `IX_teacher_grievance_history_grievance_date`

### `teachers_schema.teacher_leave_allowance`

- **Migration:** `026_teacher_leave_and_grievance.sql`
- **Purpose:** Production-ready, non-destructive DDL migration for:

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `teacher_leave_allowance_id` | `BIGINT` | NOT NULL |  |
| `school_id` | `BIGINT` | NOT NULL | School scope FK |
| `branch_id` | `BIGINT` | NOT NULL | Branch scope FK |
| `academic_year_id` | `BIGINT` | NOT NULL | Academic year FK |
| `teacher_id` | `BIGINT` | NOT NULL | Teacher FK |
| `sick_total_days` | `DECIMAL(4, 1)` | NOT NULL |  |
| `sick_used_days` | `DECIMAL(4, 1)` | NOT NULL |  |
| `sick_remaining_days` | `AS (sick_total_days - sick_used_days) PERSISTED` | computed |  |
| `casual_total_days` | `DECIMAL(4, 1)` | NOT NULL |  |
| `casual_used_days` | `DECIMAL(4, 1)` | NOT NULL |  |
| `casual_remaining_days` | `AS (casual_total_days - casual_used_days) PERSISTED` | computed |  |
| `privilege_total_days` | `DECIMAL(4, 1)` | NOT NULL |  |
| `privilege_used_days` | `DECIMAL(4, 1)` | NOT NULL |  |
| `privilege_remaining_days` | `AS (privilege_total_days - privilege_used_days) PERSISTED` | computed |  |
| `on_duty_total_days` | `DECIMAL(4, 1)` | NOT NULL |  |
| `on_duty_used_days` | `DECIMAL(4, 1)` | NOT NULL |  |
| `on_duty_remaining_days` | `AS (on_duty_total_days - on_duty_used_days) PERSISTED` | computed |  |
| `compensatory_total_days` | `DECIMAL(4, 1)` | NOT NULL |  |
| `compensatory_used_days` | `DECIMAL(4, 1)` | NOT NULL |  |
| `compensatory_remaining_days` | `AS (compensatory_total_days - compensatory_used_days) PERSISTED` | computed |  |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NOT NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_teacher_leave_allowance PRIMARY KEY CLUSTERED (teacher_leave_allowance_id)`
- `CONSTRAINT UQ_teacher_leave_allowance UNIQUE NONCLUSTERED (school_id, branch_id, academic_year_id, teacher_id)`
- `CONSTRAINT CK_teacher_leave_allowance_days_valid CHECK (`
- `CONSTRAINT FK_teacher_leave_allowance_school FOREIGN KEY (school_id)`
- `CONSTRAINT FK_teacher_leave_allowance_branch_scope FOREIGN KEY (school_id, branch_id)`
- `CONSTRAINT FK_teacher_leave_allowance_academic_year_scope FOREIGN KEY (school_id, academic_year_id)`
- `CONSTRAINT FK_teacher_leave_allowance_teacher FOREIGN KEY (teacher_id)`
- `CONSTRAINT FK_teacher_leave_allowance_created_by FOREIGN KEY (created_by)`
- `CONSTRAINT FK_teacher_leave_allowance_updated_by FOREIGN KEY (updated_by)`

**Indexes**

- `IX_teacher_leave_allowance_teacher_year`

### `teachers_schema.teacher_leave_application`

- **Migration:** `026_teacher_leave_and_grievance.sql`
- **Purpose:** Production-ready, non-destructive DDL migration for:

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `teacher_leave_application_id` | `BIGINT` | NOT NULL |  |
| `school_id` | `BIGINT` | NOT NULL | School scope FK |
| `branch_id` | `BIGINT` | NOT NULL | Branch scope FK |
| `academic_year_id` | `BIGINT` | NOT NULL | Academic year FK |
| `teacher_id` | `BIGINT` | NOT NULL | Teacher FK |
| `leave_type` | `VARCHAR(30)` | NOT NULL |  |
| `leave_duration_type` | `VARCHAR(20)` | NOT NULL |  |
| `start_date` | `DATE` | NOT NULL |  |
| `end_date` | `DATE` | NOT NULL |  |
| `total_days` | `DECIMAL(4, 1)` | NOT NULL |  |
| `reason` | `NVARCHAR(500)` | NOT NULL |  |
| `status` | `NVARCHAR(20)` | NOT NULL |  |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NOT NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_teacher_leave_application PRIMARY KEY CLUSTERED (teacher_leave_application_id)`
- `CONSTRAINT CK_teacher_leave_application_type CHECK`
- `CONSTRAINT CK_teacher_leave_application_duration CHECK`
- `CONSTRAINT CK_teacher_leave_application_status CHECK`
- `CONSTRAINT CK_teacher_leave_application_dates CHECK (end_date >= start_date)`
- `CONSTRAINT CK_teacher_leave_application_total_days CHECK (total_days > 0.0)`
- `CONSTRAINT CK_teacher_leave_application_half_day CHECK`
- `CONSTRAINT CK_teacher_leave_application_full_day CHECK`
- `CONSTRAINT FK_teacher_leave_application_school FOREIGN KEY (school_id)`
- `CONSTRAINT FK_teacher_leave_application_branch_scope FOREIGN KEY (school_id, branch_id)`
- `CONSTRAINT FK_teacher_leave_application_academic_year_scope FOREIGN KEY (school_id, academic_year_id)`
- `CONSTRAINT FK_teacher_leave_application_teacher FOREIGN KEY (teacher_id)`
- `CONSTRAINT FK_teacher_leave_application_allowance_scope FOREIGN KEY`
- `CONSTRAINT FK_teacher_leave_application_created_by FOREIGN KEY (created_by)`
- `CONSTRAINT FK_teacher_leave_application_updated_by FOREIGN KEY (updated_by)`

**Indexes**

- `IX_teacher_leave_application_teacher_year_status`
- `IX_teacher_leave_application_school_branch_dates`
- `IX_teacher_leave_application_active_overlap`

### `teachers_schema.teacher_leave_status_history`

- **Migration:** `026_teacher_leave_and_grievance.sql`
- **Purpose:** Production-ready, non-destructive DDL migration for:

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `teacher_leave_status_history_id` | `BIGINT` | NOT NULL |  |
| `teacher_leave_application_id` | `BIGINT` | NOT NULL |  |
| `old_status` | `NVARCHAR(20)` | NULL |  |
| `new_status` | `NVARCHAR(20)` | NOT NULL |  |
| `changed_by` | `BIGINT` | NOT NULL |  |
| `changed_at` | `DATETIME2(0)` | NOT NULL |  |
| `remarks` | `NVARCHAR(500)` | NULL |  |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_teacher_leave_status_history PRIMARY KEY CLUSTERED (teacher_leave_status_history_id)`
- `CONSTRAINT CK_teacher_leave_status_history_old CHECK`
- `CONSTRAINT CK_teacher_leave_status_history_new CHECK`
- `CONSTRAINT FK_teacher_leave_status_history_app FOREIGN KEY (teacher_leave_application_id)`
- `CONSTRAINT FK_teacher_leave_status_history_changed_by FOREIGN KEY (changed_by)`

**Indexes**

- `IX_teacher_leave_status_history_app_date`

### `teachers_schema.teacher_subject_assignment`

- **Migration:** `004_teacher.sql`
- **Purpose:** Teacher master identity within school/branch scope

| Column | Type | Null | Notes |
|--------|------|------|-------|
| `teacher_subject_assignment_id` | `BIGINT` | NOT NULL |  |
| `school_id` | `BIGINT` | NOT NULL | School scope FK |
| `branch_id` | `BIGINT` | NOT NULL | Branch scope FK |
| `academic_year_id` | `BIGINT` | NOT NULL | Academic year FK |
| `class_id` | `BIGINT` | NOT NULL | Class FK |
| `section_id` | `BIGINT` | NOT NULL | Section FK |
| `class_subject_id` | `BIGINT` | NOT NULL |  |
| `subject_id` | `BIGINT` | NOT NULL | Subject FK |
| `teacher_id` | `BIGINT` | NOT NULL | Teacher FK |
| `is_active` | `BIT` | NOT NULL | Soft active flag |
| `created_at` | `DATETIME2(0)` | NOT NULL | Record created (UTC) |
| `created_by` | `BIGINT` | NOT NULL | User who created |
| `updated_at` | `DATETIME2(0)` | NOT NULL | Record last updated (UTC) |
| `updated_by` | `BIGINT` | NULL | User who last updated |
| `row_version` | `ROWVERSION` | NOT NULL | Concurrency token |

**Constraints**

- `CONSTRAINT PK_teacher_subject_assignment PRIMARY KEY CLUSTERED (teacher_subject_assignment_id)`
- `CONSTRAINT UQ_teacher_subject_assignment_scope UNIQUE NONCLUSTERED`
- `CONSTRAINT FK_teacher_subject_assignment_school FOREIGN KEY (school_id) REFERENCES management_schema.school (school_id)`
- `CONSTRAINT FK_teacher_subject_assignment_branch_scope FOREIGN KEY (school_id, branch_id) REFERENCES management_schema.branch (school_id, branch_id)`
- `CONSTRAINT FK_teacher_subject_assignment_academic_year_scope FOREIGN KEY (school_id, academic_year_id) REFERENCES management_schema.academic_year (school_id, academic_year_id)`
- `CONSTRAINT FK_teacher_subject_assignment_class_scope FOREIGN KEY (school_id, class_id) REFERENCES management_schema.school_class (school_id, class_id)`
- `CONSTRAINT FK_teacher_subject_assignment_section_scope FOREIGN KEY (class_id, section_id) REFERENCES management_schema.section (class_id, section_id)`
- `CONSTRAINT FK_teacher_subject_assignment_class_subject FOREIGN KEY (class_subject_id) REFERENCES management_schema.class_subject (class_subject_id)`
- `CONSTRAINT FK_teacher_subject_assignment_subject FOREIGN KEY (subject_id) REFERENCES management_schema.subject (subject_id)`
- `CONSTRAINT FK_teacher_subject_assignment_teacher FOREIGN KEY (teacher_id) REFERENCES teachers_schema.teacher (teacher_id)`
- `CONSTRAINT FK_teacher_subject_assignment_created_by FOREIGN KEY (created_by) REFERENCES security_schema.users (user_id)`
- `CONSTRAINT FK_teacher_subject_assignment_updated_by FOREIGN KEY (updated_by) REFERENCES security_schema.users (user_id)`

**Indexes**

- `IX_teacher_subject_assignment_teacher_active`
- `IX_teacher_subject_assignment_section_active`

## Appendix: SQL vs MongoDB vs Redis vs Blob

### SQL Server (52 tables)

Core ERP: students, teachers, masters, timetable, attendance, exams, assignments, homework, fees, receipts, library, transport, security (auth), leave, grievance, announcements.

### MongoDB

See [mongodb-collections-reference.md](./mongodb-collections-reference.md).

- Student Overview / Compass snapshots
- Learning Hub (syllabus, resources, exam papers, progress)
- Connect masters (chat threads, meetings, community)
- Auth JWT session hashes (`user_jwt_token`)
- Document / attachment metadata + Blob refs

### Azure Blob Storage

Actual file bytes (PDF, images) linked from MongoDB metadata.

### Redis (live only)

- Live bus GPS lat/long and ETA
- Connect unread / presence / recent message cache
- Optional access-token blacklist on logout

### Auth in SQL (`security_schema`)

- `users` (identity + credentials), `user_login_attempt`, `schema_version`
- Access + refresh token hashes: MongoDB `user_jwt_token`
- Authorization: `user_type` + FastAPI domain rules (no SQL RBAC / `user_scope`)
