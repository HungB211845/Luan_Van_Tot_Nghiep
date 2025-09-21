Đặc Tả Kỹ Thuật: Module Quản Lý Công Nợ (DebtManager)

1. Tổng Quan & Mục Tiêu

Module này chịu trách nhiệm theo dõi, quản lý, và xử lý toàn bộ các khoản nợ phát sinh từ chức năng "Ghi nợ" của Module Bán Hàng (POS). Mục tiêu là cung cấp cho chủ cửa hàng một công cụ rõ ràng để biết

ai đang nợ, nợ bao nhiêu, khi nào đến hạn, và thực hiện các nghiệp vụ thu nợ.

2. Luồng Hoạt Động Của Người Dùng (User Flow)

Tạo Nợ (Creation):

Tại màn hình

CartScreen, người dùng chọn khách hàng, sau đó chọn phương thức thanh toán là "Ghi nợ" và xác nhận.

Hệ thống tạo một Transaction mới và tự động tạo ra một bản ghi Debt tương ứng, liên kết với Transaction đó và Customer đã chọn.

Xem Nợ (Viewing):

Cách 1 (Theo Khách Hàng): Người dùng vào CustomerListScreen, chọn một khách hàng để xem chi tiết. Trong màn hình CustomerDetailScreen, sẽ có một tab mới là "Công Nợ", liệt kê tất cả các khoản nợ của riêng khách hàng đó.

Cách 2 (Tổng Quan): Sẽ có một mục "Quản lý Công nợ" ở menu chính, dẫn đến màn hình DebtListScreen để xem toàn bộ các khoản nợ chưa thanh toán của tất cả khách hàng.

Xử Lý Nợ (Action):

Từ màn hình

DebtDetailScreen, người dùng có thể thực hiện các hành động: "Ghi nhận Thanh toán" (mở ra một form nhỏ để nhập số tiền đã trả), "Gia Hạn", "Xóa Nợ".

3. Thiết Kế Data Model (Cho Supabase)

Mày cần tạo 2 bảng mới trong Supabase.

Bảng debts:

id (uuid, primary key)

created_at (timestamptz, default: now())

customer_id (uuid, foreign key đến customers.id)

transaction_id (uuid, foreign key đến transactions.id, unique)

initial_amount (numeric, not null) - Số tiền nợ ban đầu

amount_paid (numeric, default: 0) - Số tiền đã trả

remaining_amount (numeric, not null) - Số tiền còn lại

due_date (date, not null) - Ngày đến hạn trả

interest_rate (numeric, default: 0) - Lãi suất/tháng, ví dụ: 1.5

status (text, not null, default: 'UNPAID') - Trạng thái: UNPAID, PARTIALLY_PAID, PAID, OVERDUE

Bảng debt_payments:

id (uuid, primary key)

created_at (timestamptz, default: now())

debt_id (uuid, foreign key đến debts.id)

payment_date (date, not null) - Ngày khách trả tiền

amount (numeric, not null) - Số tiền trả lần này

notes (text) - Ghi chú

4. Thiết Kế Tầng Logic (Service & Provider)

Mày sẽ tạo một cặp DebtService và DebtProvider mới.

Trong DebtService.dart:

Future<Debt> createDebtFromTransaction(Transaction tx, Customer customer)

Future<List<Debt>> getDebtsByCustomerId(String customerId)

Future<void> recordPayment({required String debtId, required double amount}) - Hàm này sẽ tự động cập nhật amount_paid và remaining_amount trong bảng debts, đồng thời tạo một bản ghi debt_payments.

Trong DebtProvider.dart:

State: List<Debt> customerDebts, Debt? selectedDebt, bool isLoading...

Methods: loadDebts(String customerId), addPayment(String debtId, double amount)... Các hàm này sẽ gọi đến DebtService tương ứng và gọi notifyListeners().

5. Thiết Kế Giao Diện (UI Screens)

Thay đổi ở CustomerDetailScreen.dart:

Thêm một Tab mới tên là "Công Nợ".

Nội dung tab này sẽ là một ListView.builder hiển thị danh sách customerDebts từ DebtProvider. Mỗi item sẽ là một Card tóm tắt thông tin khoản nợ (số tiền còn lại, ngày đến hạn, trạng thái).

Màn hình mới: DebtDetailScreen.dart

Được mở ra khi bấm vào một item nợ.

Hiển thị chi tiết: Nợ gốc, đã trả, còn lại, ngày đến hạn, số ngày quá hạn, tiền lãi (tính tự động).

Hiển thị lịch sử trả nợ: Một ListView khác hiển thị các bản ghi từ bảng debt_payments.

Các nút hành động: "Ghi Nhận Thanh Toán" (mở ra màn hình AddPaymentScreen), "Gia Hạn", "Xóa Nợ".

Màn hình mới: AddPaymentScreen.dart

Một form đơn giản với các ô nhập: "Số tiền trả", "Ngày trả", "Ghi chú".

Nút "Lưu" sẽ gọi debtProvider.addPayment(...).
