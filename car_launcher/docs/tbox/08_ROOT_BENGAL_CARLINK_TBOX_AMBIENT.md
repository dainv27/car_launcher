# Hướng dẫn root Bengal Carlink TBox Ambient

> Cập nhật: 2026-06-15
> Mục tiêu đã biết trong dự án: Android 13, product `bengal_515`, model ADB
> `Bengal_for_arm64`.

## Cảnh báo quan trọng

Hiện không có quy trình root công khai đã được xác minh riêng cho mọi biến thể
**Carlink TBox Ambient / bengal_515**. Tên `Bengal` chỉ họ nền tảng Qualcomm,
không xác định duy nhất bo mạch, partition layout hoặc firmware.

Root/bootloader unlock có thể:

- xóa toàn bộ dữ liệu;
- làm OTA ngừng hoạt động;
- gây boot-loop hoặc brick nếu dùng sai `boot.img`, `init_boot.img`, `vbmeta`;
- làm mất cấu hình modem, GPS, Bluetooth hoặc CarPlay nếu ghi nhầm partition;
- làm thiết bị không còn được bảo hành.

**Không flash image được chia sẻ bởi người khác. Không dùng firmware của TBox
khác dù cùng tên Bengal. Không erase/flash `persist`, `modemst1`, `modemst2`,
`fsg`, `frp`, `devinfo` hoặc partition không hiểu rõ.**

## Kết luận nhanh

Chỉ tiếp tục root khi đáp ứng đủ cả bốn điều kiện:

1. Có firmware stock đúng tuyệt đối với build đang chạy.
2. Có cách phục hồi đã kiểm chứng: fastboot hoặc gói Qualcomm EDL chính hãng.
3. Bootloader hỗ trợ unlock chính thức.
4. Đã xác định đúng image cần patch: `init_boot`, `boot` hoặc `recovery`.

Nếu thiếu một điều kiện, dừng ở bước thu thập thông tin và yêu cầu firmware từ
nhà bán/vendor.

## Root có giải quyết quyền launcher không?

Không hoàn toàn. Root cho phép chạy lệnh `su`, chỉnh file hệ thống và hỗ trợ
debug ROM, nhưng **không tự cấp** các permission Android dạng
signature/privileged:

- `android.permission.INJECT_EVENTS`;
- `android.permission.ADD_TRUSTED_DISPLAY`;
- `android.permission.MANAGE_ACTIVITY_TASKS`;
- `android.permission.ACTIVITY_EMBEDDING`.

Để launcher hoạt động gần CarCar, vẫn có thể cần:

- APK nằm trong đúng `priv-app` partition;
- priv-app permission allowlist;
- platform certificate/shared UID phù hợp;
- SELinux policy và hidden API policy của ROM.

Xem thêm [06_ROM_PERMISSIONS.md](06_ROM_PERMISSIONS.md).

## Giai đoạn 0: Chuẩn bị phục hồi

Chuẩn bị trước khi thay đổi thiết bị:

- nguồn điện ổn định; không thực hiện trong khi xe đang chạy;
- cáp USB data tốt và máy tính có `adb`, `fastboot`;
- firmware stock đúng build từ vendor;
- checksum SHA-256 của firmware/image;
- bản sao dữ liệu cá nhân, APK và cấu hình cần giữ;
- hướng dẫn đưa đúng model vào fastboot/recovery/EDL.

Không coi EDL là đường root mặc định. Qualcomm EDL chỉ nên dùng để phục hồi khi
có **đúng firehose programmer, rawprogram và patch XML của firmware này**.
Flash EDL bằng programmer/gói của model khác có thể brick cứng.

## Giai đoạn 1: Thu thập định danh thiết bị

Bật Developer options, USB debugging, kết nối ADB và lưu toàn bộ output:

```bash
mkdir -p /tmp/bengal-root-audit

adb devices -l
adb shell getprop > /tmp/bengal-root-audit/getprop.txt
adb shell cat /proc/cpuinfo > /tmp/bengal-root-audit/cpuinfo.txt
adb shell cat /proc/partitions > /tmp/bengal-root-audit/partitions.txt
adb shell ls -l /dev/block/by-name > /tmp/bengal-root-audit/by-name.txt
adb shell getprop ro.build.fingerprint
adb shell getprop ro.build.display.id
adb shell getprop ro.product.device
adb shell getprop ro.product.board
adb shell getprop ro.boot.hardware
adb shell getprop ro.boot.slot_suffix
adb shell getprop ro.boot.flash.locked
adb shell getprop ro.boot.verifiedbootstate
adb shell getprop ro.boot.vbmeta.device_state
adb shell getprop ro.build.ab_update
adb shell uname -a
```

Kiểm tra trạng thái root hiện tại:

```bash
adb shell id
adb shell which su
adb shell su -c id
```

Lưu ảnh chụp màn hình phần **About**, **Build number** và **Developer options**.
Đối chiếu build fingerprint với firmware stock. Nếu không khớp tuyệt đối, không
dùng image trong firmware đó.

## Giai đoạn 2: Xác định bootloader có unlock được không

Trong Developer options, kiểm tra tùy chọn **OEM unlocking**. Nếu không có hoặc
bị vendor khóa, không cố dùng lệnh flash/EDL không rõ nguồn gốc.

Thử reboot vào bootloader:

```bash
adb reboot bootloader
fastboot devices
fastboot getvar product
fastboot getvar current-slot
fastboot getvar unlocked
fastboot getvar secure
fastboot getvar all
```

Nếu `fastboot devices` không thấy thiết bị, quay lại Android bằng nút nguồn hoặc
phương thức vendor. Không tiếp tục flash.

Nếu fastboot hoạt động và vendor cho phép unlock:

```bash
fastboot flashing get_unlock_ability
fastboot flashing unlock
```

Xác nhận unlock trên màn hình thiết bị nếu có. Unlock thường factory-reset toàn
bộ dữ liệu. Một số firmware dùng lệnh cũ:

```bash
fastboot oem unlock
```

Chỉ thử lệnh cũ khi tài liệu vendor xác nhận. Nếu bootloader từ chối unlock,
dừng lại. Không dùng dịch vụ/file unlock không rõ nguồn gốc.

## Giai đoạn 3: Lấy image stock đúng build

Ưu tiên lấy image từ gói firmware chính hãng. Xác định partition hiện có:

```bash
adb shell ls -l /dev/block/by-name | grep -E 'boot|init_boot|vendor_boot|recovery|vbmeta'
```

Android 13 có thể dùng A/B slots và có thể chứa:

- `init_boot_a` / `init_boot_b`;
- `boot_a` / `boot_b`;
- `vendor_boot_a` / `vendor_boot_b`;
- `vbmeta_a` / `vbmeta_b`.

Theo hướng dẫn chính thức của Magisk:

- nếu có `init_boot.img`, thường patch `init_boot.img`;
- nếu boot chứa ramdisk, patch `boot.img`;
- nếu thiết bị không có boot ramdisk, Magisk có thể cần `recovery.img`.

Không đọc partition bằng `dd` khi chưa root chỉ để “thử”. Nếu vendor không cung
cấp firmware và chưa có đường backup đáng tin cậy, dừng.

Kiểm tra checksum trước và sau khi sao chép:

```bash
shasum -a 256 init_boot.img boot.img recovery.img vbmeta.img 2>/dev/null
```

## Giai đoạn 4: Patch image bằng Magisk

1. Tải Magisk từ repository chính thức của `topjohnwu`.
2. Cài APK Magisk lên chính TBox cần root.
3. Chép image stock đúng build vào TBox:

```bash
adb push init_boot.img /sdcard/Download/
# Hoặc boot.img/recovery.img tùy partition đã xác định.
```

4. Trong Magisk chọn **Install → Select and Patch a File**.
5. Chọn image stock vừa chép.
6. Kéo image đã patch về máy tính:

```bash
adb pull /sdcard/Download/magisk_patched_*.img .
shasum -a 256 magisk_patched_*.img
```

Luôn patch image trên chính thiết bị mục tiêu. Không dùng patched image của
người khác.

## Giai đoạn 5: Test boot trước khi flash khi có thể

Nếu image đã patch là `boot.img` hoặc `recovery.img`, và bootloader hỗ trợ boot
tạm thời, ưu tiên:

```bash
adb reboot bootloader
fastboot devices
fastboot boot magisk_patched_boot.img
```

Sau khi Android boot:

```bash
adb wait-for-device
adb shell su -c id
```

Nếu lệnh trả về `uid=0(root)`, image hoạt động. Nếu không boot, giữ nút nguồn để
khởi động lại; vì chưa flash nên stock image vẫn còn.

`fastboot boot` không phải cách thử `init_boot.img`. Nếu cần patch `init_boot`,
hoặc nếu bootloader không hỗ trợ boot tạm, không có bước thử an toàn tương
đương. Chỉ flash sau khi chắc chắn có firmware stock và quy trình restore đúng
model.

## Giai đoạn 6: Flash image đã kiểm chứng

Xác định active slot:

```bash
fastboot getvar current-slot
```

Flash đúng partition đã patch, ví dụ:

```bash
fastboot flash init_boot magisk_patched_*.img
# Hoặc:
fastboot flash boot magisk_patched_*.img
```

Trên thiết bị A/B, fastboot của vendor có thể yêu cầu tên có suffix slot. Chỉ
dùng tên partition được `fastboot getvar all` và firmware xác nhận.

Không mặc định disable AVB/verity. Chỉ thay đổi `vbmeta` nếu tài liệu chính thức
của đúng firmware yêu cầu và đã có image stock để phục hồi. Thao tác `vbmeta`
có thể xóa dữ liệu hoặc gây boot-loop.

Khởi động lại:

```bash
fastboot reboot
adb wait-for-device
adb shell su -c id
```

Mở Magisk và hoàn tất bước setup bổ sung nếu ứng dụng yêu cầu.

## Kiểm tra sau root

```bash
adb shell su -c id
adb shell getprop ro.boot.verifiedbootstate
adb shell getprop ro.boot.vbmeta.device_state
adb shell getenforce
adb shell su -c 'ls -l /data/adb'
```

Kiểm tra các chức năng TBox trước khi triển khai launcher:

- modem/SIM và dữ liệu mạng;
- GPS;
- Wi-Fi, Bluetooth;
- CarPlay/Android Auto;
- audio;
- boot lại nhiều lần;
- sleep/wake và nhiệt độ thiết bị.

## Phục hồi

Nếu còn vào fastboot và biết đúng partition đã flash:

```bash
fastboot flash init_boot init_boot_stock.img
# Hoặc boot_stock.img tương ứng.
fastboot reboot
```

Không relock bootloader khi thiết bị vẫn chạy image đã sửa. Relock với partition
không hoàn toàn stock có thể gây brick.

Nếu không vào Android/fastboot:

1. Dừng thử flash ngẫu nhiên.
2. Xác định chính xác chế độ Qualcomm 9008/EDL.
3. Chỉ dùng gói phục hồi và programmer chính hãng đúng board/build.
4. Nhờ vendor hoặc kỹ thuật viên có dump đúng model phục hồi.

## Khi nào nên dừng

Dừng ngay nếu gặp một trong các tình huống:

- không có firmware stock đúng build;
- không có restore path đã kiểm chứng;
- bootloader không cho unlock;
- không xác định được `init_boot`/`boot`/`recovery`;
- fastboot không nhận thiết bị;
- firmware hoặc programmer chỉ được quảng cáo là “cùng Bengal”;
- người bán yêu cầu flash file không có checksum/nguồn rõ ràng.

## Nguồn tham chiếu

- Magisk Installation:
  <https://topjohnwu.github.io/Magisk/install.html>
- AOSP Lock and unlock the bootloader:
  <https://source.android.com/docs/core/architecture/bootloader/locking_unlocking>
- Android SDK Platform Tools:
  <https://developer.android.com/tools/releases/platform-tools>
