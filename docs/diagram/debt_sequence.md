```mermaid
sequenceDiagram
    actor User
    participant UI as "UI (Screens)"
    participant DP as "DebtProvider"
    participant DS as "DebtService"
    participant TS as "TransactionService"
    participant DB as "Supabase (DB/RPC)"

    %% === CREATE DEBT FROM POS TRANSACTION (GHI NỢ TỪ GIAO DỊCH BÁN HÀNG) ===
    alt Create Debt (Credit Sale)
        User->>+UI: Hoàn tất giao dịch bán hàng (POS) với phương thức "Ghi nợ"
        UI->>+PP: checkout(..., paymentMethod: Debt)
        PP->>+TS: createTransaction(...)
        TS->>+DB: INSERT INTO transactions, transaction_items, UPDATE product_batches
        TS->>+DS: createDebtFromTransaction(transaction, customerId, ...)
        DS->>+DB: RPC create_credit_sale(p_store_id, p_customer_id, p_transaction_id, ...)
        Note over DB: RPC này tạo bản ghi nợ mới trong bảng `debts`
và liên kết với giao dịch bán hàng.
        DB-->>-DS: Trả về debtId
        DS-->>-TS: Trả về debtId
        TS-->>-PP: Trả về transactionId
        PP-->>-UI: Cập nhật UI (thông báo thành công)
    end

    %% === CREATE DEBT MANUALLY (GHI NỢ THỦ CÔNG) ===
    alt Create Debt (Manual)
        User->>+UI: Mở màn hình "Ghi Nợ Thủ Công" (AddTransactionSheet)
        User->>UI: Nhập số tiền, ghi chú & nhấn "Xác nhận Ghi Nợ"
        UI->>+DP: createManualDebt(customerId, amount, notes)
        DP->>+DS: createManualDebt(customerId, amount, notes)
        DS->>+DB: RPC create_manual_debt(p_store_id, p_customer_id, p_amount, p_notes)
        Note over DB: RPC này tạo bản ghi nợ mới trong bảng `debts`
không liên kết với transaction.
        DB-->>-DS: Trả về debtId
        DS-->>-DP: Trả về debtId
        DP->>DP: Tải lại danh sách nợ của khách hàng
        DP-->>-UI: notifyListeners()
        UI->>User: Hiển thị thông báo thành công
    end

    %% === ADD PAYMENT (THANH TOÁN CÔNG NỢ) ===
    alt Add Payment
        User->>+UI: Mở màn hình "Thanh Toán Công Nợ" (AddPaymentScreen)
        User->>UI: Nhập số tiền, phương thức, ghi chú & nhấn "Xác nhận thanh toán"
        UI->>+DP: addPayment(customerId, paymentAmount, paymentMethod, notes)
        DP->>+DS: addPayment(customerId, paymentAmount, paymentMethod, notes)
        DS->>+DB: RPC process_customer_payment(p_store_id, p_customer_id, p_payment_amount, ...)
        Note over DB: RPC này xử lý phân bổ thanh toán theo FIFO
cập nhật `paid_amount`, `remaining_amount`, `status` trong bảng `debts`
và INSERT vào bảng `debt_payments`. Có cơ chế chống trả quá số nợ.
        DB-->>-DS: Trả về kết quả thanh toán
        DS-->>-DP: Trả về kết quả
        DP->>DP: Tải lại danh sách nợ và tổng hợp nợ của khách hàng
        DP-->>-UI: notifyListeners()
        UI->>User: Hiển thị thông báo thành công hoặc lỗi (quá số nợ)
    end

    %% === ADJUST DEBT (ĐIỀU CHỈNH CÔNG NỢ) ===
    alt Adjust Debt
        User->>+UI: Mở màn hình "Điều Chỉnh Công Nợ" (AdjustDebtScreen)
        User->>UI: Chọn loại điều chỉnh (tăng/giảm/xóa nợ), số tiền, lý do & nhấn "Xác nhận điều chỉnh"
        UI->>+DP: adjustDebt(debtId, adjustmentAmount, adjustmentType, reason)
        DP->>+DS: adjustDebt(debtId, adjustmentAmount, adjustmentType, reason)
        DS->>+DB: RPC adjust_debt_amount(p_debt_id, p_adjustment_amount, p_adjustment_type, p_reason)
        Note over DB: RPC này cập nhật `original_amount`, `remaining_amount` trong bảng `debts`
và INSERT vào bảng `debt_adjustments`.
        DB-->>-DS: Trả về kết quả điều chỉnh
        DS-->>-DP: Trả về kết quả
        DP->>DP: Tải lại lịch sử điều chỉnh và danh sách nợ
        DP-->>-UI: notifyListeners()
        UI->>User: Hiển thị thông báo thành công
    end

    %% === READ DEBT LIST/DETAILS (ĐỌC DANH SÁCH/CHI TIẾT CÔNG NỢ) ===
    alt Read Debt List/Details
        User->>+UI: Mở màn hình "Quản Lý Công Nợ" (DebtListScreen) hoặc "Sổ Cái Công Nợ" (CustomerDebtDetailScreen)
        UI->>+DP: loadAllDebts() hoặc loadCustomerDebts(customerId)
        DP->>+DS: getAllDebts() hoặc getCustomerDebts(customerId)
        DS->>+DB: SELECT * FROM debts WHERE store_id = ? (có thể thêm filter status/customerId)
        DB-->>-DS: Trả về danh sách nợ
        DS-->>-DP: Trả về List<Debt>
        DP->>DP: Cập nhật state `_debts`
        DP-->>-UI: notifyListeners()
        UI->>User: Hiển thị danh sách hoặc chi tiết công nợ
    end
```