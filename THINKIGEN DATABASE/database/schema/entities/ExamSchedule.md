# Entity: management_schema.exam_schedule

## Purpose

Subject-wise exam paper within a parent `exam`.

## Academic hierarchy

Same scope columns as `exam`:

`school_id` → `branch_id` → `academic_year_id` → `class_id` → `section_id`

Plus: `exam_id`, `subject_id`, `teacher_id`, schedule times, marks config.

## Key columns

| Column | Type | Null | Notes |
|--------|------|------|-------|
| exam_schedule_id | BIGINT | NO | PK |
| exam_id | BIGINT | NO | FK → exam |
| school_id … section_id | BIGINT | NO | Full scope FKs |
| subject_id | BIGINT | NO | FK → subject |
| teacher_id | BIGINT | NO | FK → teacher |
| exam_date | DATE | NO | Paper date |
| start_time, end_time | TIME(0) | NO | Session time |
| max_marks | DECIMAL(6,2) | NO | > 0 |
| pass_marks | DECIMAL(6,2) | YES | <= max_marks |
| evaluation_start_date | DATE | YES | Start date of paper evaluation by teachers (>= exam_date) |
| evaluation_end_date | DATE | YES | Deadline for evaluation of papers (>= evaluation_start_date) |
| status | NVARCHAR(20) | NO | SCHEDULED / COMPLETED / CANCELLED |

## Unique & Constraints

- `(exam_id, subject_id)` — one paper per subject per exam.
- `CK_exam_schedule_evaluation_dates`: `(evaluation_end_date IS NULL OR evaluation_start_date IS NULL OR evaluation_end_date >= evaluation_start_date)`
- `CK_exam_schedule_evaluation_start_date`: `(evaluation_start_date IS NULL OR evaluation_start_date >= exam_date)`

## Indexes

- `IX_exam_schedule_teacher_evaluation` — `(teacher_id, evaluation_end_date, evaluation_start_date) WHERE is_active = 1`
