# Yêu cầu build

## JDK

**Android Gradle Plugin 8.7** không hỗ trợ JDK 25 làm JVM chạy Gradle. Dùng **JDK 17 hoặc 21**, ví dụ:

- **Android Studio**: *Settings → Build, Execution, Deployment → Build Tools → Gradle → Gradle JDK* chọn **Embedded JDK** (thường là 21).
- **Dòng lệnh (PowerShell)** trước khi gọi `gradlew`:

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
```

Đường dẫn `jbr` có thể khác tùy máy; điều chỉnh cho đúng bản cài Android Studio.

## Android SDK

Tạo hoặc để Android Studio tạo file `local.properties` ở thư mục gốc project:

```properties
sdk.dir=C:/Users/<tên>/AppData/Local/Android/Sdk
```

File này đã có trong `.gitignore` — không commit.

## Lệnh build

```powershell
.\gradlew.bat assembleDebug
```
