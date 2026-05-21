# FUGE TOOL MANAGEMENT SYSTEM (FLUTTER)

## 1. Project Overview

FUGE Tool Management System is a Flutter Desktop application designed to help lecturers manage student project evaluations efficiently.

The system works in an offline-first architecture combined with Google Sheets/XLSX integration.

Main purposes:
- Import original project/group data from `.fg` files
- Import student evaluations from Google Forms / XLSX
- Synchronize and validate data
- Allow teachers to edit comments manually
- Use AI to detect invalid/spam/toxic evaluations
- Export encrypted `.cmt` files securely
- Export all evaluations into ZIP packages

---

# 2. Core Workflow

## Step 1 — Original FG File

Teacher imports an `.fg` file containing:
- project list
- group list
- student list

Example:

```json
[
  {
    "project_id": "01",
    "group_id": "SE1001",
    "project_name_en": "Agricultural IoT Project",
    "project_name_vi": "Dự án IoT nông nghiệp",
    "students": [
      {
        "student_id": "SE150001",
        "student_name": "Nguyen Van A"
      }
    ]
  }
]
```

---

## Step 2 — Student Google Form Submission

Students fill a Google Form.

The Google Form exports to Google Sheets / XLSX with columns:

| Column | Description |
|---|---|
| Timestamp | Submission time |
| Fullname | Student full name |
| Roll_number | Student ID |
| Email | Student email |
| Group_code | Group code |
| Topic_code | Project/topic code |
| Topic_title(English) | English topic title |
| Topic_title(Vietnamese) | Vietnamese topic title |
| Student_evaluation | Student evaluation/comment |

---

## Step 3 — Import XLSX / Google Sheet

Teacher:
- imports XLSX file
OR
- pastes Google Sheet link

The system:
- reads all rows
- maps evaluations to projects
- updates UI
- validates data

---

## Step 4 — Teacher Review

Teacher can:
- view grouped projects
- edit comments
- validate missing data
- run AI content checking

---

## Step 5 — Export

Teacher can:
- save updated `.fg`
- export encrypted `.cmt`
- export all `.cmt` into ZIP

---

# 3. Technical Architecture

## Architecture Style

Offline-first desktop application with local file processing.

Cloud integration only used for:
- Google Sheets
- AI validation

---

## Layers

```text
Presentation Layer
    ↓
Application Layer
    ↓
Domain Layer
    ↓
Infrastructure Layer
```

---

## Presentation Layer

Responsible for:
- desktop UI
- forms
- validation
- project sidebar
- dialogs
- export screens

---

## Application Layer

Responsible for:
- import logic
- synchronization
- validation
- encryption
- AI processing

---

## Domain Layer

Contains:
- ProjectModel
- StudentModel
- ValidationStatus
- ExportResult

---

## Infrastructure Layer

Responsible for:
- XLSX parsing
- Google Sheets API
- file encryption
- ZIP export
- Gemini API integration

---

# 4. Data Models

## ProjectModel

```json
{
  "project_id": "01",
  "group_id": "SE1001",
  "project_name_en": "Agricultural IoT Project",
  "project_name_vi": "Dự án IoT nông nghiệp",
  "students": [],
  "student_reviews": [],
  "teacher_comment": "",
  "is_validated": false,
  "ai_status": "PENDING"
}
```

---

## StudentSurveyModel

```json
{
  "timestamp": "2026-05-21 10:00:00",
  "fullname": "Pham Thanh Phuc",
  "roll_number": "SE150001",
  "email": "phuc@gmail.com",
  "group_code": "SE1001",
  "topic_code": "01",
  "topic_title_en": "Agricultural IoT Project",
  "topic_title_vi": "Dự án IoT nông nghiệp",
  "student_evaluation": "The project is practical and useful."
}
```

---

# 5. XLSX Import Logic

## XLSX Structure

The XLSX file contains:

| Timestamp | Fullname | Roll_number | Email | Group_code | Topic_code | Topic_title(English) | Topic_title(Vietnamese) | Student_evaluation |

---

## Import Flow

```text
Select XLSX
    ↓
Parse workbook
    ↓
Read rows
    ↓
Convert rows → StudentSurveyModel
    ↓
Validate required fields
    ↓
Map to ProjectModel
    ↓
Update UI
```

---

# 6. Mapping Rules

## Primary Key

Preferred matching order:

1. Topic_code
2. Group_code

---

## Topic Title Conflict Handling

Problem:
Students may enter slightly different topic titles.

Example:

- AI Attendance System
- AI attendance system
- AI Attendance Systm

---

## Conflict Resolution

The system must:

### Normalize text
- lowercase
- trim spaces
- remove duplicate spaces

### Fuzzy matching
Use:
- Levenshtein Distance
- Jaro-Winkler
- Similarity score

Rule:

```text
similarity >= 90%
→ same topic
```

Otherwise:
- show warning
- require teacher confirmation

---

# 7. Validation Rules

## Invalid Data Conditions

Project becomes INVALID if:
- missing teacher_comment
- missing student_review
- invalid topic_code
- duplicated student submissions

---

## Duplicate Detection

Duplicate if:

```text
same Roll_number
AND same Topic_code
```

---

## Validation Status

```text
VALID
MISSING_DATA
DUPLICATE
TOPIC_CONFLICT
AI_WARNING
```

---

# 8. AI Content Validation

## Purpose

Detect:
- spam
- toxic language
- meaningless evaluations
- unrelated content

---

## Gemini Prompt

```text
You are an academic quality validation assistant.

Analyze the student evaluation text.

Check whether:
- the content is meaningful
- the language is appropriate
- the evaluation is relevant to the project topic
- the text is not spam or nonsense

Return JSON:
{
  "is_appropriate": true/false,
  "reason": "..."
}
```

---

# 9. Encryption System

## Export `.cmt`

Each project can be exported as encrypted `.cmt`.

---

## Encryption Requirements

Algorithm:
- AES-256

Flow:

```text
Teacher password
    ↓
Generate encryption key
    ↓
Encrypt JSON content
    ↓
Save as .cmt
```

---

## Example Export Content

Before encryption:

```json
{
  "project_id": "01",
  "teacher_comment": "Excellent implementation"
}
```

After encryption:
- unreadable ciphertext

---

# 10. Export All

The system:
- generates all `.cmt`
- compresses into ZIP

---

# 11. Recommended Flutter Packages

```yaml
dependencies:
  flutter:
    sdk: flutter

  flutter_riverpod:
  file_picker:
  excel:
  googleapis:
  googleapis_auth:
  encrypt:
  archive:
  google_generative_ai:
  path_provider:
  fluent_ui:
  google_fonts:
```

---

# 12. UI/UX Requirements

## Desktop Layout

```text
+------------------------------------------------------+
| Toolbar                                               |
+----------------------+-------------------------------+
| Project Sidebar      | Project Detail Panel          |
|                      |                               |
| Topic List           | Topic Information             |
| Validation Status    | Student Reviews               |
| Search               | Teacher Comment Editor        |
|                      | AI Validation Panel           |
+----------------------+-------------------------------+
| Footer Actions                                       |
| Get Sheet | Save | Export | Export All               |
+------------------------------------------------------+
```

---

# 13. Accessibility Requirements

The UI must support:
- keyboard navigation
- high contrast
- scalable fonts
- screen reader semantics
- desktop responsive layout

---

# 14. State Management

Preferred:
- Riverpod
OR
- Bloc

The application should support:
- realtime UI updates
- validation state tracking
- export state tracking

---

# 15. Testing Requirements

## Test Case 1 — Valid XLSX Import

Input:
- valid XLSX

Expected:
- all projects loaded correctly

---

## Test Case 2 — Invalid Topic Code

Input:
- Topic_code not found

Expected:
- warning log shown

---

## Test Case 3 — Duplicate Submission

Input:
- same student submits twice

Expected:
- duplicate warning

---

## Test Case 4 — Encryption

Input:
- export with password

Expected:
- encrypted `.cmt` generated successfully

---

# 16. Future Improvements

Potential future features:
- Firebase sync
- Auto-save
- Role-based accounts
- AI-generated teacher comments
- Dashboard analytics
- PDF export
- Dark mode
- Cloud backup