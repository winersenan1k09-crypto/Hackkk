# Ghi chú Kỹ thuật & Các Lỗi Cần Tránh (Pet Simulator 99 / Reallloween)

Tài liệu này lưu lại toàn bộ kinh nghiệm và cấu trúc API thực tế đã tìm ra để các lần viết script tiếp theo chạy chuẩn ngay từ lần đầu tiên.

---

## 1. Cấu trúc Mở Hộp Quà / Lootbox (`LootboxCmds` & `PresentCmds`)
* **Không gọi trực tiếp `KX_Release` với tọa độ tự tạo bên ngoài:**
  * Server kiểm tra tọa độ hộp quà rất chặt qua thuật toán `ComputePositions` và `PlacementConfig` bên trong `ReplicatedStorage.Library.Client.LootboxCmds`. Nếu truyền tọa độ tự tính bên ngoài không khớp `PlacementConfig`, `KX_Release` sẽ trả về `false, "Unspecified error has occured!"`.
* **Luôn gọi qua hàm chính chủ `LootboxCmds.Open(itemObj, amount)`:**
  * Tham số `itemObj` truyền vào `LootboxCmds.Open` bắt buộc phải là một bảng (Object) có đầy đủ **3 phương thức**:
    1. `GetId = function() return giftName end` (ví dụ: `"Midnight Gift"`)
    2. `GetUID = function() return giftUid end` (lấy tự động từ `Save.Get().Inventory`)
    3. `Directory = function() return cachedDirData end` (lấy từ `require(ReplicatedStorage.Library.Directory).Lootboxes[giftName]`)
* **Giải phóng hộp quà trên mặt đất để mở liên tục không bị kẹt 8 hộp đầu:**
  * Sau khi gọi `LootboxCmds.Open`, chờ khoảng `0.8s` rồi gọi `PresentCmds.OpenCurrent()`.
  * Đồng thời xóa danh sách hộp quà đang chiếm chỗ trong `PresentCmds.Current()` (gán `p._destroyed = true` và `cur[k] = nil`) để lượt mở tiếp theo không bị báo `"Not enough space, try a more open area!"`.

---

## 2. Cách tìm UID và Dữ liệu Vật phẩm trong Túi đồ (`Save`)
* Dữ liệu túi đồ nằm tại: `require(ReplicatedStorage.Library.Client.Save).Get().Inventory`.
* Các hộp quà sự kiện (như `Midnight Gift`) nằm ở nhánh `Inventory.Lootbox` hoặc `Inventory.Misc` với cấu trúc:
  ```lua
  [uid] = { id = "Midnight Gift", _am = 952 }
  ```
* Luôn dùng cơ chế **Cache `UID`** sau lần tìm đầu tiên để không phải quét lại toàn bộ túi đồ ở mỗi vòng lặp (giúp chống tuột FPS và tràn RAM).

---

## 3. Lưu ý về Công cụ Thực thi (`Reallloween`) & GitHub Raw
* **Cách đọc API nhanh nhất:** Dùng `debug.getconstants(fn)` và `debug.info(fn, "la")` trên các hàm trong `ReplicatedStorage.Library.Client` để xem toàn bộ hằng số và cấu trúc tham số bên trong.
* **Chống kẹt bộ nhớ đệm (Cache 5 phút) của GitHub Raw:**
  * Khi vừa Push code mới lên GitHub, đường dẫn `/main/auto_gift.lua` sẽ bị GitHub lưu cache cũ trong 5 phút (kể cả khi thêm `?t=...`).
  * **Giải pháp:** Luôn lấy mã **Commit Hash** (`git rev-parse HEAD`) gắn vào link:
    `https://raw.githubusercontent.com/winersenan1k09-crypto/Hackkk/<COMMIT_HASH>/auto_gift.lua` để tải bản mới tức thì 100%.
* **Chống Crash khi treo mở số lượng lớn (900+ hộp):**
  * Luôn dùng biến phiên `_G.AutoGiftSession` để tự hủy vòng lặp cũ nếu bấm Execute nhiều lần.
  * Tự động tắt `ParticleEmitter`, `Trail`, `Beam`, `Explosion`, `Sound` sinh ra trong `Workspace.__THINGS` và ngắt kết nối (`Disconnect`) sự kiện khi kết thúc vòng lặp.
