Đặc Tả Kỹ Thuật: Module Quản Lý Công Nợ (DebtManager) - v4 (Hoàn thiện logic)

# 1. Tổng Quan & Mục Tiêu

(Không thay đổi)

# 2. Luồng Hoạt Động Của Người Dùng (User Flow)

(Không thay đổi so với v3)

# 3. Thiết Kế Data Model (Cho Supabase) - ĐÃ THAY ĐỔI

**Bảng `debts`:** (Không thay đổi)
**Bảng `debt_payments`:** (Không thay đổi)
**Bảng `debt_adjustments`:** (Không thay đổi)

**~~Bảng `customer_credits`~~:** (ĐÃ LOẠI BỎ) - Nghiệp vụ mới không yêu cầu lưu trữ tiền thừa của khách.

**RPC Functions trên Supabase - ĐÃ THAY ĐỔI:**

- **`create_credit_sale(...)`:** (Không thay đổi so với v3)

- **`process_customer_payment(p_customer_id, p_payment_amount, ...)` (CẬP NHẬT LOGIC):**
  - **Mục đích:** Xử lý thanh toán cho khách hàng, đảm bảo không trả thừa.
  - **Logic Mới:**
    1.  **Kiểm tra tổng nợ:** Tính tổng `remaining_amount` của khách hàng (`total_debt`).
    2.  **Xác thực số tiền trả:** `IF p_payment_amount > total_debt THEN RAISE EXCEPTION 'Số tiền trả (%s) vượt quá tổng nợ (%s). Vui lòng nhập lại.'; END IF;`. Logic này đảm bảo RPC sẽ thất bại ngay từ đầu nếu người dùng nhập thừa tiền.
    3.  **Phân bổ thanh toán:** Nếu số tiền hợp lệ, tiếp tục chạy vòng lặp `FOR` để phân bổ thanh toán như logic cũ (FIFO hoặc chiến lược khác).
    4.  Toàn bộ logic nằm trong một transaction.

- **`adjust_debt_amount(...)`:** (Không thay đổi so với v3, vẫn giữ validation chống nợ âm)

- **`calculate_overdue_interest(debt_id)`:** (Không thay đổi)

# 4. Thiết Kế Tầng Logic (Service & Provider)

(Không thay đổi so với v3)

# 5. Thiết Kế Giao Diện (UI Screens)

**Màn hình `AddPaymentScreen.dart` - Cập nhật luồng xử lý lỗi:**
- Khi người dùng bấm "Lưu" và `debtProvider.addPayment(...)` được gọi, nếu `DebtService` nhận về lỗi từ RPC (do trả thừa tiền), `DebtProvider` phải cập nhật một state lỗi (ví dụ: `paymentError`).
- UI sẽ lắng nghe `paymentError` này và hiển thị một thông báo lỗi rõ ràng cho người dùng, ví dụ: "Số tiền trả vượt quá tổng nợ. Vui lòng kiểm tra lại."

(Các màn hình khác không thay đổi so với v2)

# 6. Các quy tắc nghiệp vụ cốt lõi - ĐÃ THAY ĐỔI

(Các quy tắc cũ vẫn giữ nguyên)

**Cập nhật & Bổ sung quy tắc mới:**

- **Tính nguyên tử khi tạo nợ:** (Không thay đổi so với v3)

- **Xử Lý Tiền Trả Thừa (Overpayment Handling) - QUY TẮC MỚI:**
  - Hệ thống không chấp nhận một khoản thanh toán có giá trị lớn hơn tổng số nợ còn lại của khách hàng.
  - Khi người dùng nhập một số tiền vượt quá tổng nợ, tầng database (thông qua RPC `process_customer_payment`) sẽ từ chối giao dịch và trả về một lỗi.
  - Tầng giao diện (UI) phải bắt được lỗi này và hiển thị một thông báo rõ ràng, yêu cầu người dùng nhập lại số tiền chính xác. Điều này tương ứng với quy trình nghiệp vụ ngoài đời thực là nhân viên thu ngân sẽ nhận đúng số tiền và thối lại tiền mặt cho khách, thay vì ghi nhận công nợ thừa vào hệ thống.

- **Toàn vẹn dữ liệu khi điều chỉnh nợ:** (Không thay đổi so với v3)