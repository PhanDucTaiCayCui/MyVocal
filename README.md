# MyVocab 📖🎙️

> **MyVocab** (MyVocal) là ứng dụng học từ vựng tiếng Anh cá nhân hóa trên nền tảng Android, hoạt động **100% offline-first**, không cần tài khoản, không backend, tích hợp thuật toán lặp lại ngắt quãng **SM-2 (Spaced Repetition System)** chuẩn mực.

---

## 🌟 Tính năng Nổi bật

### 1. 🔍 Thêm từ thông minh & Tự động điền 100%
- **Tự động tra từ điển & Dịch nghĩa:** Nhập từ tiếng Anh ➔ Tự động lấy phiên âm IPA, từ loại, câu ví dụ tiếng Anh (DictionaryAPI) và **tự động dịch nghĩa chính + câu ví dụ sang tiếng Việt**.
- **Gợi ý nghĩa tiếng Việt phong phú:** Hiển thị danh sách các nghĩa tiếng Việt khác nhau dưới dạng nút bấm nhanh (chips), chạm nhẹ là đổi nghĩa.
- **Tự do chỉnh sửa:** Mọi trường thông tin đều mở để người dùng tự điều chỉnh theo ý muốn.
- **Chặn trùng từ thời gian thực:** Kiểm tra trùng từ (không phân biệt hoa/thường) ngay khi gõ và chặn lưu trùng.
- **Phát âm chuẩn bản xứ:** Tích hợp bộ phát âm giọng Mỹ (en-US) chất lượng cao qua `flutter_tts`.

### 2. 🧠 Ôn tập Flashcard với thuật toán SM-2
- **Thuật toán SM-2 chuẩn:** Tự động tính toán khoảng cách ngày ôn (interval), hệ số dễ (EaseFactor tối thiểu 1.3), số lần lặp và số lần quên dựa trên 4 mức đánh giá:
  - ❌ **Quên (1)** ➔ Tự động đẩy từ về cuối hàng đợi để ôn lại ngay trong phiên.
  - ⚠️ **Mơ hồ (3)**
  -  **Nhớ (4)**
  - ✨ **Dễ (5)**
- **Thẻ Flashcard tương tác:** Chạm để lật mặt trước/sau; hỗ trợ đảo chiều ôn tập (**Anh ➔ Việt** hoặc **Việt ➔ Anh**); công tắc bật/tắt tự động phát âm khi mở thẻ.
- **Lịch nhắc nhở hằng ngày:** Đặt lịch thông báo đúng giờ mong muốn thông qua `flutter_local_notifications` và `timezone`.

### 3. 🚀 Tiện ích Mở rộng Độc đáo trên Android
- **Thêm từ từ ứng dụng khác (Native Intent):**
  - **Chia sẻ (`ACTION_SEND`):** Chọn "Chia sẻ" văn bản từ Chrome/báo chí ➔ chọn MyVocab.
  - **Bôi đen chữ (`ACTION_PROCESS_TEXT`):** Bôi đen từ trên bất kỳ app nào ➔ chọn menu "MyVocab".
  - Tự động làm sạch dấu câu ở 2 đầu từ (ví dụ: `"ubiquitous,"` ➔ `"ubiquitous"`) và mở màn hình tra từ.
- **Widget màn hình chính (Home Screen Widget):**
  - Hiển thị từ vựng kèm nghĩa tiếng Việt ngay trên màn hình chính điện thoại.
  - Ưu tiên chọn các từ đang trong quá trình học (`repetitions > 0` và `interval < 21`).
  - Nút bấm tiện lợi mở thẳng vào màn hình ôn tập.
- **Màn hình Thống kê:**
  - Theo dõi chuỗi ngày học liên tục (**Streak**).
  - Thống kê tổng số từ và số từ đã thuộc thành thạo (`interval >= 21 ngày`).
  - Biểu đồ cột biểu diễn số lượt ôn tập trong 7 ngày gần nhất sử dụng `fl_chart`.
- **Sao lưu & Khôi phục JSON:**
  - **Xuất (Export):** Gom toàn bộ dữ liệu 3 bảng ra file JSON chia sẻ qua `share_plus`, hiển thị cảnh báo nếu quá 14 ngày chưa backup.
  - **Nhập (Import):** Chọn file JSON qua `file_picker`, tự động bỏ qua từ trùng và ánh xạ lại khóa ngoại `wordId` để đảm bảo dữ liệu nguyên vẹn 100%.

---

## 🛠️ Tech Stack & Kiến trúc

- **Framework:** Flutter 3.50+ / Dart 3.14+ (Chỉ dành cho Android).
- **Kiến trúc:** Clean Architecture chia lớp (Data, Domain, Features, Services, Utils).
- **Quản lý trạng thái:** `flutter_riverpod` (v2.6+).
- **Cơ sở dữ liệu:** `drift` + `sqlite3_flutter_libs` (SQLite cục bộ với 4 bảng: `Words`, `Reviews`, `ReviewLogs`, `Settings`, bật `PRAGMA foreign_keys = ON`).
- **Mạng:** `dio` (gọi DictionaryAPI & Google Translate API).
- **Native Android:** Kotlin (`MainActivity.kt`, `MyVocabWidgetProvider.kt`), AppWidget XML Layout, R8 ProGuard rules.

```
myvocab/
├── android/app/src/main/
│   ├── AndroidManifest.xml          # Intent filter: SEND & PROCESS_TEXT, Permissions
│   └── kotlin/com/tai/myvocab/
│       ├── MainActivity.kt          # MethodChannel tiếp nhận intent từ ứng dụng khác
│       └── MyVocabWidgetProvider.kt # Android AppWidget Provider
├── lib/
│   ├── data/database.dart           # Drift Database & DAO CRUD
│   ├── domain/sm2.dart              # Thuật toán SM-2 thuần Dart
│   ├── services/                    # Tts, Dictionary, Notification, Widget, Backup
│   ├── features/
│   │   ├── add_word/                # Màn hình thêm / sửa từ vựng
│   │   ├── word_list/               # Danh sách từ, tìm kiếm, lọc tag, phát âm
│   │   ├── review/                  # Màn hình Flashcard ôn tập SM-2
│   │   ├── statistics/              # Thống kê và biểu đồ cột fl_chart
│   │   └── home/                    # BottomNavigationBar điều hướng chính
│   └── main.dart                    # Entry point
└── test/                            # 19/19 Unit tests bao phủ toàn bộ logic
```

---

## 🚀 Hướng dẫn Cài đặt & Khởi chạy

### 1. Clone repository
```bash
git clone https://github.com/PhanDucTaiCayCui/MyVocal.git
cd MyVocal/myvocab
```

### 2. Cài đặt dependencies
```bash
flutter pub get
```

### 3. Chạy kiểm thử & Phân tích mã nguồn
```bash
flutter analyze
flutter test
```

### 4. Khởi chạy trên thiết bị / Giả lập
```bash
flutter run
```

### 5. Build APK
- **Bản Debug:**
  ```bash
  flutter build apk --debug
  ```
- **Bản Release (Cài trực tiếp lên điện thoại):**
  ```bash
  flutter build apk --release
  ```
  *File APK xuất ra tại:* `build/app/outputs/flutter-apk/app-release.apk`

---

## 📄 Bản quyền
Phát triển bởi **[PhanDucTaiCayCui](https://github.com/PhanDucTaiCayCui)**.
