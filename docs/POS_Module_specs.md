# SPECS: Module Bán Hàng (POS)

## 1. Tổng Quan

Module này cung cấp một luồng bán hàng hoàn chỉnh, được thiết kế theo hướng mobile-first. Luồng hoạt động bắt đầu từ việc chọn sản phẩm tại màn hình POS, tiến đến giỏ hàng, thanh toán, và kết thúc ở màn hình hiển thị "biên lai" giao dịch thành công. Kiến trúc tuân thủ nghiêm ngặt mô hình 3 lớp (UI -> Provider -> Service) để đảm bảo sự ổn định, dễ bảo trì và mở rộng.

---

## 2. Các Thành Phần Giao Diện (UI Screens)

### a. `POSScreen` (Màn hình bán hàng chính)

- **Mục đích:** Giao diện chính để nhân viên thực hiện thao tác bán hàng.
- **Bố cục:** Thiết kế theo chiều dọc, bao gồm 3 khu vực chính:
  1.  **Thanh tìm kiếm:** Cho phép tìm sản phẩm nhanh.
  2.  **Bộ lọc danh mục:** Các chip filter để lọc sản phẩm theo loại (Phân bón, Thuốc BVTV, Lúa giống).
  3.  **Lưới sản phẩm:** Hiển thị các sản phẩm dưới dạng lưới. Mỗi sản phẩm có cụm nút `+/-` để thay đổi số lượng trực tiếp.
- **Thành phần đặc biệt:** Dưới chân màn hình là một thanh tóm tắt giỏ hàng (mini-cart) cố định, luôn hiển thị tổng số món và tổng tiền, cho phép truy cập nhanh vào giỏ hàng chi tiết.

### b. `CartScreen` (Màn hình giỏ hàng & thanh toán)

- **Mục đích:** Kiểm tra lại các sản phẩm đã chọn và thực hiện quy trình thanh toán.
- **Chức năng:**
  - Hiển thị chi tiết danh sách các món hàng trong giỏ.
  - Cho phép sửa số lượng hoặc xóa từng món hàng.
  - Tích hợp chức năng chọn khách hàng từ danh sách có sẵn.
  - Kích hoạt hộp thoại thanh toán, cho phép chọn phương thức (Tiền mặt / Ghi nợ).

### c. `TransactionSuccessScreen` (Màn hình giao dịch thành công)

- **Mục đích:** Hoạt động như một "biên lai" kỹ thuật số, xác nhận giao dịch đã hoàn tất.
- **Chức năng:**
  - Hiển thị thông báo thành công, mã đơn hàng, tổng tiền.
  - Liệt kê chi tiết các sản phẩm đã mua, bao gồm **tên sản phẩm** (không phải ID), số lượng và giá.
  - Có nút "Tạo Giao Dịch Mới" để quay về màn hình `POSScreen` sạch sẽ, sẵn sàng cho phiên làm việc tiếp theo.

---

## 3. Luồng Hoạt Động Chính (End-to-End Flow)

1.  **Bán hàng:** Từ `POSScreen`, người dùng tìm/lọc sản phẩm và nhấn `+` để thêm vào giỏ. Mini-cart ở dưới cập nhật theo thời gian thực.
2.  **Kiểm tra giỏ hàng:** Người dùng nhấn vào mini-cart để điều hướng tới `CartScreen`.
3.  **Thanh toán:** Tại `CartScreen`, người dùng xác nhận đơn hàng, có thể chọn khách hàng, sau đó nhấn "Thanh toán" và chọn phương thức trong hộp thoại.
4.  **Xử lý:** Logic checkout được kích hoạt. `ProductProvider` gọi `ProductService` để tạo giao dịch và trừ kho trong database.
5.  **Hiển thị kết quả:** Sau khi backend xác nhận thành công, `CartScreen` được thay thế bằng `TransactionSuccessScreen`.
6.  **Giao dịch mới:** Từ `TransactionSuccessScreen`, người dùng nhấn nút "Tạo Giao Dịch Mới". Ứng dụng ra lệnh cho `ProductProvider` làm mới dữ liệu ở dưới nền, đồng thời dọn dẹp stack điều hướng và đưa người dùng về lại màn hình `POSScreen` mới tinh.

---

## 4. Các Cải Tiến Kiến Trúc & Sửa Lỗi Quan Trọng

Module này đã được refactor và sửa các lỗi nghiêm trọng để đảm bảo hoạt động ổn định.

- **Luồng Refresh Dữ Liệu An Toàn:** Logic làm mới dữ liệu (tồn kho, dashboard) đã được tách ra khỏi hàm `checkout`. Nó được kích hoạt một cách an toàn ở dưới nền khi người dùng rời khỏi màn hình `TransactionSuccessScreen`, đảm bảo UI không bị "đơ" và người dùng luôn nhận được phản hồi thành công ngay lập tức.

- **Xử Lý `Context` Bất Đồng Bộ An Toàn:** Đã khắc phục triệt để lỗi `deactivated widget` bằng cách áp dụng kỹ thuật "chụp" `Navigator` và `ScaffoldMessenger` vào các biến cục bộ trước khi thực hiện các tác vụ `await`. Đây là giải pháp chuẩn để tránh crash liên quan đến context trong Flutter.

- **Data Enrichment & View Model:** Đã tạo ra một model "ảo" là `TransactionItemDetails`. `ProductProvider` giờ đây chịu trách nhiệm "làm giàu" dữ liệu, kết hợp `TransactionItem` (chỉ có ID) với `Product` (có tên, SKU) để tạo ra danh sách `TransactionItemDetails` hoàn chỉnh. Việc này giúp cho tầng UI (`TransactionSuccessScreen`) chỉ việc hiển thị mà không cần xử lý logic, tuân thủ đúng kiến trúc.

- **Mã Hóa Đơn Duy Nhất:** Hàm tạo mã hóa đơn (`_generateInvoiceNumber`) đã được sửa để bao gồm cả giây và mili giây, đảm bảo không bao giờ xảy ra lỗi `duplicate key` khi thực hiện nhiều giao dịch trong cùng một phút.

## 5. Trạng Thái Hiện Tại

- Luồng bán hàng cốt lõi (thêm sản phẩm -> giỏ hàng -> thanh toán -> biên lai -> quay về) đã **hoàn thiện** và **ổn định**.
- Các lỗi nghiêm trọng về logic, crash, và dữ liệu đã được khắc phục.
- Các công việc tiếp theo để hoàn thiện module Product Manager bao gồm xây dựng các màn hình còn lại như `AddBatchScreen` và `AddSeasonalPriceScreen`.