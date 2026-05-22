# FUGE App — Đặc tả nghiệp vụ & Kỹ thuật

> Phiên bản: 1.0 | Nền tảng: Flutter

---

## 1. Tổng quan hệ thống

FUGE là app Flutter dùng để GVHD (Giảng viên hướng dẫn) **quản lý và điền phiếu đánh giá đồ án** của sinh viên. App thay thế hoàn toàn phần mềm FuGrade cũ (C# .NET desktop).

### Các tác nhân

| Tác nhân | Vai trò |
|---|---|
| **GVHD** | Người dùng chính. Nhập đánh giá, save, export file |
| **Sinh viên** | Điền Google Form trước (không dùng app trực tiếp) |
| **Người xem file .cmt** | Mở file .cmt bằng FUGE app để xem kết quả |

---

## 2. Nguồn dữ liệu & Các loại file

### 2.1 File `.xlsx` — Dữ liệu đầu vào

Export từ Google Sheet (kết quả Google Form sinh viên đã điền). Cấu trúc các cột:

```
Timestamp | Fullname | Roll_number | Email | Group_code | Topic_code |
Topic_title(English) | Topic_title(Vietnamese) | Student_evaluation
```

> **Lưu ý:** Mỗi sinh viên là 1 row. Các sinh viên cùng nhóm có cùng `Group_code` và `Topic_code`.

---

### 2.2 File `.fg` — File dữ liệu chính của app

- Do **app tạo ra** từ file `.xlsx`
- Lưu toàn bộ danh sách dự án + đánh giá của GVHD (sau khi save)
- **Định dạng:** `Base64( AES_encrypt( JSON, APP_MASTER_KEY ) )`
- App giữ `APP_MASTER_KEY` cố định trong code → app luôn có thể đọc/ghi lại

**Cấu trúc JSON bên trong:**

```json
{
  "version": "1.0",
  "metadata": {
    "teacher": "phuonglhk",
    "semester": "SP2024",
    "subject_code": "SEP490",
    "class_name": "SE1811",
    "created_at": "2024-01-15T08:00:00Z"
  },
  "projects": [
    {
      "topic_code": "01",
      "group_code": "SE1111",
      "title_vn": "Dự án IOT nông nghiệp",
      "title_en": "Agricultural IoT Project",
      "students": [
        {
          "roll": "SE196253",
          "name": "Phạm Thành Phúc",
          "email": "pham@gmail.com",
          "student_evaluation": "The project is practical..."
        }
      ],
      "gv_evaluation": {
        "content": "",
        "form": "",
        "attitude": "",
        "achievement": "",
        "limitation": "",
        "student_verdicts": [
          {
            "roll": "SE196253",
            "agree_to_defense": false,
            "revised_for_second_defense": false,
            "disagree_to_defense": false,
            "note": ""
          }
        ]
      }
    }
  ]
}
```

---

### 2.3 File `.cmt` — Phiếu đánh giá 1 đề tài (có mật khẩu)

- Mỗi đề tài → 1 file `.cmt` riêng
- **Định dạng:** `Base64( AES_encrypt( JSON, derive_key(password) ) )`
- Xác thực password bằng cách lưu kèm `MD5(password)` → khi mở app hash password nhập vào và so sánh
- File `.cmt` là **read-only** khi mở — không cho sửa

**Cấu trúc JSON bên trong:**

```json
{
  "version": "1.0",
  "teacher": "phuonglhk",
  "dt": "2024-01-15",
  "subject_code": "SEP490",
  "class_name": "SE1811",
  "semester": "SP2024",
  "password_hash": "c4ca4238a0b923820dcc509a6f75849b",
  "topic_code": "01",
  "group_code": "SE1111",
  "title_vn": "Dự án IOT nông nghiệp",
  "title_en": "Agricultural IoT Project",
  "content": "Khóa luận đáp ứng đúng mục tiêu...",
  "form": "Trình bày rõ ràng, bố cục hợp lý...",
  "attitude": "Nhóm làm việc nghiêm túc...",
  "achievement": "Đạt mức tương đối",
  "limitation": "Sinh viên có nhiều cố gắng",
  "students": [
    {
      "roll": "SE196253",
      "name": "Phạm Thành Phúc",
      "agree_to_defense": true,
      "revised_for_second_defense": false,
      "disagree_to_defense": false,
      "note": ""
    }
  ]
}
```

---

## 3. Luồng nghiệp vụ chi tiết

### Flow A — Tạo file `.fg` từ `.xlsx` (lần đầu)

```
1. GVHD mở app
2. Chọn "Import từ file XLSX"
3. App parse xlsx → group sinh viên theo Group_code + Topic_code
4. App hiển thị preview: số nhóm tìm thấy, danh sách tên đề tài
5. GVHD nhập metadata: Tên GV, Học kỳ, Mã môn, Tên lớp
6. Nhấn "Tạo file .fg" → chọn nơi lưu → app encrypt + save
7. Chuyển thẳng vào màn hình Danh sách dự án
```

---

### Flow B — Mở file `.fg` đã có

```
1. GVHD chọn "Mở file .fg"
2. App decrypt + parse JSON
3. Hiển thị màn hình Danh sách dự án
```

---

### Flow C — Xem & lọc danh sách dự án

**Màn hình Danh sách dự án:**

- Hiển thị list card, mỗi card gồm:
  - Mã đề tài, Mã nhóm
  - Tên đề tài (VN)
  - Số sinh viên trong nhóm
  - Badge trạng thái: `Chưa đánh giá` / `Đã điền` / `Đã export`

- **Bộ lọc:**
  - Theo Group_code (dropdown)
  - Theo Topic_code (text search)
  - Theo trạng thái đánh giá

---

### Flow D — Điền đánh giá cho 1 đề tài

```
1. GVHD chọn 1 đề tài từ danh sách
2. Màn hình chi tiết hiển thị (xem mục 4 bên dưới)
3. Phần thông tin đề tài + sinh viên: auto-filled, read-only
4. Phần đánh giá GV: GVHD điền vào các ô
5. Nhấn "Save":
   a. Validate: kiểm tra các field bắt buộc (xem mục 5)
   b. Nếu pass → cập nhật JSON → encrypt → ghi đè file .fg
   c. Hiển thị toast "Đã lưu"
```

---

### Flow E — Export file `.cmt` (1 đề tài)

```
1. Trên màn hình chi tiết đề tài → nhấn "Export .cmt"
2. Validate đầy đủ thông tin (phải Save trước hoặc validate lại)
3. Hiển thị dialog: "Nhập mật khẩu bảo vệ file"
4. GVHD nhập password + confirm password
5. App tạo JSON của đề tài → hash MD5(password) → AES encrypt → Base64 → lưu file .cmt
6. Tên file gợi ý: {semester}_{group_code}_{topic_code}.cmt
7. Thông báo "Export thành công"
```

---

### Flow F — Export All `.cmt` (toàn bộ đề tài)

```
1. Từ màn hình danh sách → nhấn "Export All"
2. Dialog cảnh báo: "X đề tài chưa điền đầy đủ, chỉ export đề tài đã hoàn chỉnh?"
   → Chọn "Chỉ export đề tài đã đủ" hoặc "Hủy"
3. Nhập 1 password dùng chung cho tất cả file
4. App tạo từng file .cmt → đóng gói thành 1 file .zip
5. Tên file zip: {semester}_{class_name}_all_cmt.zip
```

---

### Flow G — Mở file `.cmt` để xem

```
1. GVHD/người dùng chọn "Mở file .cmt"
2. Chọn file .cmt từ bộ nhớ
3. App Base64 decode → AES decrypt thử với password rỗng trước
4. Hiển thị dialog: "Nhập mật khẩu"
5. Nhập password → app hash MD5 → so sánh với password_hash trong file
   - Đúng: decrypt thành công → hiển thị phiếu đánh giá (read-only)
   - Sai: báo lỗi "Sai mật khẩu"
6. Giao diện xem giống hệt form đánh giá nhưng không cho chỉnh sửa
```

---

## 4. Màn hình chi tiết đề tài — Cấu trúc field

### Phần 1 — Thông tin đề tài *(auto-filled, read-only)*

| Field | Nguồn dữ liệu |
|---|---|
| Tên khóa luận (Tiếng Việt) | Từ xlsx → .fg |
| Tên khóa luận (Tiếng Anh) | Từ xlsx → .fg |
| Danh sách sinh viên (Roll + Họ tên) | Từ xlsx → .fg |

---

### Phần 2 — Đánh giá của sinh viên *(read-only, từ Google Form)*

Hiển thị `Student_evaluation` của từng sinh viên (text tự do, không cần cấu trúc).

---

### Phần 3 — Đánh giá của GVHD *(GVHD điền)*

| Mục | Field name | Loại input | Bắt buộc |
|---|---|---|---|
| 3.1 Nội dung khóa luận | `content` | Textarea | ✅ |
| 3.2 Hình thức khóa luận | `form` | Textarea | ✅ |
| 3.3 Thái độ sinh viên | `attitude` | Textarea | ✅ |
| 4.1 Mức độ đạt được | `achievement` | Textarea | ✅ |
| 4.2 Hạn chế | `limitation` | Textarea | ✅ |

---

### Phần 4 — Kết luận từng sinh viên *(GVHD điền)*

Bảng, mỗi hàng là 1 sinh viên:

| Cột | Loại |
|---|---|
| Roll | Text, read-only |
| Họ tên | Text, read-only |
| Đồng ý bảo vệ | Radio / Checkbox |
| Bảo vệ lần 2 | Radio / Checkbox |
| Không đồng ý | Radio / Checkbox |
| Ghi chú | Text input |

> **Logic:** 3 cột kết luận là mutually exclusive — chọn 1 thì 2 cái kia tự uncheck.

---

## 5. Validation Rules

### Trước khi Save

| Rule | Thông báo lỗi |
|---|---|
| `content` không rỗng | "Vui lòng điền mục 3.1 - Nội dung khóa luận" |
| `form` không rỗng | "Vui lòng điền mục 3.2 - Hình thức" |
| `attitude` không rỗng | "Vui lòng điền mục 3.3 - Thái độ" |
| `achievement` không rỗng | "Vui lòng điền mục 4.1 - Mức độ đạt được" |
| `limitation` không rỗng | "Vui lòng điền mục 4.2 - Hạn chế" |
| Mỗi sinh viên phải chọn đúng 1 kết luận | "Sinh viên [Tên] chưa có kết luận" |

### Trước khi Export `.cmt`

- Tất cả validation của Save phải pass
- Password không rỗng
- Confirm password trùng khớp

---

## 6. Màn hình & Navigation

```
App
├── HomeScreen
│   ├── [Button] Import xlsx → tạo .fg mới
│   └── [Button] Mở file .fg
│   └── [Button] Mở file .cmt
│
├── ImportXlsxScreen
│   ├── Chọn file xlsx
│   ├── Preview danh sách nhóm
│   ├── Nhập metadata (GV, học kỳ, môn, lớp)
│   └── [Button] Tạo .fg → lưu file
│
├── ProjectListScreen (sau khi mở .fg)
│   ├── Header: tên GV, học kỳ, môn, lớp
│   ├── Filter bar (group, topic, status)
│   ├── List<ProjectCard>
│   └── [Button] Export All → Flow F
│
├── ProjectDetailScreen
│   ├── Phần 1: Thông tin đề tài (read-only)
│   ├── Phần 2: Đánh giá SV (read-only)
│   ├── Phần 3: Form đánh giá GV (editable)
│   ├── Phần 4: Bảng kết luận SV (editable)
│   ├── [Button] Save → Flow D
│   └── [Button] Export .cmt → Flow E
│
└── CmtViewerScreen (sau khi mở .cmt)
    ├── Dialog nhập password
    └── Hiển thị phiếu đánh giá (read-only)
```

---

## 7. Thiết kế kỹ thuật file format

### Mã hóa file `.fg`

```dart
// Encrypt
String encryptFG(Map<String, dynamic> json, String masterKey) {
  final jsonStr = jsonEncode(json);
  final encrypted = AES(key: masterKey).encrypt(jsonStr);
  return base64Encode(encrypted.bytes);
}

// Decrypt
Map<String, dynamic> decryptFG(String fileContent, String masterKey) {
  final bytes = base64Decode(fileContent);
  final decrypted = AES(key: masterKey).decrypt(bytes);
  return jsonDecode(decrypted);
}
```

### Xuất file `.cmt` (Nhị phân .NET)

Do yêu cầu tương thích với hệ thống quản lý/chấm điểm khóa luận cũ của nhà trường, file `.cmt` được xuất dưới dạng **Binary Serialization** của đối tượng .NET (thông qua tiến trình chạy chương trình C# `FuGrade.exe`).

Quy trình xuất như sau:
1. Flutter tạo file JSON tạm chứa cấu trúc dữ liệu `ExportDto`.
2. Flutter gọi Subprocess thực thi `FuGrade.exe <input.json> <output.cmt>`.
3. `FuGrade.exe` ánh xạ dữ liệu sang lớp đối tượng C# `ThesisComment`, thực hiện băm MD5 mật khẩu (nếu trống mặc định băm mật khẩu "1") và serialize nhị phân đối tượng này ghi xuống file `.cmt`.

Cấu trúc đối tượng C# được serialize:
```csharp
[Serializable]
public class ThesisComment {
    public string Teacher { get; set; }
    public string DT { get; set; }
    public string SubjectCode { get; set; }
    public string ClassName { get; set; }
    public string Semester { get; set; }
    public string Password { get; set; } // Chuỗi MD5 hash của mật khẩu
    public string TitleVN { get; set; }
    public string TitleEN { get; set; }
    public string Content { get; set; }
    public string Form { get; set; }
    public string Attitude { get; set; }
    public string Achievement { get; set; }
    public string Limitation { get; set; }
    public string Conclusion { get; set; }
    public List<ThesisStudent> Students { get; set; }
}
```

> **Recommended packages:** `archive` (tạo file .zip đóng gói nhiều file .cmt), `flutter_riverpod` (quản lý trạng thái), `file_picker` (chọn file).

---

## 8. Edge Cases cần xử lý

| Tình huống | Xử lý |
|---|---|
| Mở file `.fg` bị hỏng / sai key | Hiện thông báo lỗi, không crash |
| File `.xlsx` có sinh viên trùng roll number | Merge hoặc báo warning |
| File `.xlsx` có nhóm chỉ có 1 sinh viên | Cho phép bình thường |
| Export All nhưng có đề tài chưa đầy đủ | Hỏi user: bỏ qua hay hủy tất cả |
| Password `.cmt` sai 3 lần | Có thể thêm cooldown (optional) |
| File `.fg` quá lớn (nhiều nhóm) | Lazy load danh sách |

---

## 9. Feature tùy chọn (có thể bỏ qua ở MVP)

### 9.1 AI Check nội dung

- Sau khi GVHD điền xong → nhấn nút "Kiểm tra AI"
- Gọi API AI (Gemini/GPT) với prompt: *"Đây là nhận xét đồ án của giảng viên. Kiểm tra xem nội dung có đủ ý, chuyên nghiệp, và phù hợp không. Gợi ý cải thiện nếu cần."*
- Hiển thị gợi ý bên dưới từng field (không tự điền vào)

### 9.2 Template nhận xét

- GVHD có thể lưu nhận xét hay dùng lại làm template
- Ứng dụng cho các đề tài tương tự

---

## 10. Tóm tắt nhanh cho developer

```
INPUT:  file .xlsx (từ Google Form export)
↓
[Import Screen] parse xlsx → group by Group_code
↓
[Save as .fg] JSON → AES encrypt (app key) → Base64 → file .fg
↓
[Project List] filter/search danh sách đề tài
↓
[Project Detail] GVHD điền 5 textarea + 1 bảng verdict
↓
[Save] validate → AES encrypt → ghi đè file .fg
↓
[Export .cmt] nhập password → AES encrypt (password key) → file .cmt
   hoặc
[Export All] → nhiều .cmt → zip lại

OUTPUT: file .cmt → mở lại bằng FUGE app → nhập password → xem read-only
```
Navigation — Thay vì mobile stack navigation, Windows desktop phù hợp hơn với layout kiểu sidebar + main panel hoặc top menu bar. Không dùng bottom navigation bar.
File operations — Dùng package file_picker (hỗ trợ Windows), mở/lưu file qua Windows native dialog. Không cần "chọn nơi lưu" kiểu mobile — dùng FilePicker.platform.saveFile() và pickFiles() bình thường.
Layout — Màn hình rộng hơn nhiều. Project Detail có thể split 2 cột: bên trái thông tin SV, bên phải form đánh giá GV — thay vì scroll dọc kiểu mobile.
Export .zip — Package archive dùng được bình thường trên Windows, không có vấn đề gì.