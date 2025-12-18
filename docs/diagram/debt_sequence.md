sequenceDiagram
    actor User
    participant UI as UI (Screens)
    participant DP as DebtProvider
    participant DS as DebtService
    participant DRS as DebtReminderService
    participant TS as TransactionService
    participant DB as Supabase (DB/RPC)

    alt Create Debt (Credit Sale)
        User->>+UI: Hoàn tất giao dịch bán hàng (POS) với phương thức "Ghi nợ"
        UI->>+PP: checkout(..., paymentMethod: Debt)
        PP->>+TS: createTransaction(...)
        TS->>+DB: INSERT INTO transactions, transaction_items, UPDATE product_batches
        TS->>+DS: createDebtFromTransaction(transaction, customerId, ...)
        DS->>+DB: RPC create_credit_sale(p_store_id, p_customer_id, p_transaction_id, ...)
        Note over DB: RPC này tạo bản ghi nợ mới trong bảng `debts`\nliên kết với giao dịch bán hàng.
        DB-->>-DS: Trả về debtId
        DS-->>-TS: Trả về debtId
        TS-->>-PP: Trả về transactionId
        PP-->>-UI: Cập nhật UI (thông báo thành công)
    end

    alt Create Debt (Manual)
        User->>+UI: Mở màn hình "Ghi Nợ Thủ Công" (AddTransactionSheet)
        User->>UI: Nhập số tiền, ghi chú và nhấn "Xác nhận Ghi Nợ"
        UI->>+DP: createManualDebt(customerId, amount, notes)
        DP->>+DS: createManualDebt(customerId, amount, notes)
        DS->>+DB: RPC create_manual_debt(p_store_id, p_customer_id, p_amount, p_notes)
        Note over DB: RPC này tạo bản ghi nợ mới trong bảng `debts`\nkhông liên kết với transaction.
        DB-->>-DS: Trả về debtId
        DS-->>-DP: Trả về debtId
        DP->>DP: Tải lại danh sách nợ của khách hàng
        DP-->>-UI: notifyListeners()
        UI->>User: Hiển thị thông báo thành công
    end

    alt Add Payment
        User->>+UI: Mở màn hình "Thanh Toán Công Nợ" (AddPaymentScreen)
        User->>UI: Nhập số tiền, phương thức, ghi chú và nhấn "Xác nhận thanh toán"
        UI->>+DP: addPayment(customerId, paymentAmount, paymentMethod, notes)
        DP->>+DS: addPayment(customerId, paymentAmount, paymentMethod, notes)
        DS->>+DB: RPC process_customer_payment(p_store_id, p_customer_id, p_payment_amount, ...)
        Note over DB: RPC này xử lý phân bổ thanh toán theo FIFO,\ncập nhật `paid_amount`, `remaining_amount`, `status` trong bảng `debts`,\nvà INSERT vào bảng `debt_payments`. Có cơ chế chống trả quá số nợ.
        DB-->>-DS: Trả về kết quả thanh toán
        DS-->>-DP: Trả về kết quả
        DP->>DP: Tải lại danh sách nợ và tổng hợp nợ của khách hàng
        DP-->>-UI: notifyListeners()
        UI->>User: Hiển thị thông báo thành công hoặc lỗi (quá số nợ)
    end

    alt Adjust Debt
        User->>+UI: Mở màn hình "Điều Chỉnh Công Nợ" (AdjustDebtScreen)
        User->>UI: Chọn loại điều chỉnh (tăng/giảm/xóa nợ), số tiền, lý do và nhấn "Xác nhận điều chỉnh"
        UI->>+DP: adjustDebt(debtId, adjustmentAmount, adjustmentType, reason)
        DP->>+DS: adjustDebt(debtId, adjustmentAmount, adjustmentType, reason)
        DS->>+DB: RPC adjust_debt_amount(p_debt_id, p_adjustment_amount, p_adjustment_type, p_reason)
        Note over DB: RPC này cập nhật `original_amount`, `remaining_amount` trong bảng `debts`\nvà INSERT vào bảng `debt_adjustments`.
        DB-->>-DS: Trả về kết quả điều chỉnh
        DS-->>-DP: Trả về kết quả
        DP->>DP: Tải lại lịch sử điều chỉnh và danh sách nợ
        DP-->>-UI: notifyListeners()
        UI->>User: Hiển thị thông báo thành công
    end

    alt Debt Scheduling (Client-side - Current Implementation)
        User->>+UI: Mở màn hình "Quản Lý Lịch Trả Nợ" (DebtSchedulingScreen)
        User->>UI: Chọn khoản nợ và nhấn "Thêm lịch nhắc"
        UI->>UI: Hiển thị form thêm lịch nhắc (AddReminderSheet)
        User->>UI: Nhập tiêu đề, ngày, ghi chú và nhấn "Thêm Lịch Nhắc"
        UI->>+DRS: addReminder(debtReminder)
        DRS->>+DRS: Lưu vào SharedPreferences (JSON)
        Note over DRS: Client-side storage:\nSharedPreferences với JSON serialization
        DRS-->>-UI: Trả về success/error
        UI->>User: Hiển thị thông báo thành công
    end

    alt Debt Scheduling (Server-side - Future Implementation)
        User->>+UI: Mở màn hình "Quản Lý Lịch Trả Nợ" (DebtSchedulingScreen)  
        User->>UI: Chọn khoản nợ và nhấn "Thêm lịch nhắc"
        UI->>UI: Hiển thị form thêm lịch nhắc (AddReminderSheet)
        User->>UI: Nhập tiêu đề, ngày, ghi chú, ưu tiên và nhấn "Thêm Lịch Nhắc"
        UI->>+DRS: createReminder(debtId, title, scheduledDate, ...)
        DRS->>+DB: RPC create_debt_reminder(p_debt_id, p_title, p_scheduled_date, ...)
        Note over DB: Server-side storage:\nINSERT vào bảng `debt_reminders`\nvà tự động schedule notifications
        DB->>DB: INSERT INTO debt_reminders
        DB->>DB: PERFORM schedule_reminder_notifications(reminder_id)
        DB->>DB: INSERT INTO reminder_notifications (advance, due_date types)
        DB-->>-DRS: Trả về reminderId
        DRS-->>-UI: Trả về success với reminder data
        UI->>User: Hiển thị thông báo thành công
    end

    alt Manage Reminder (Mark Complete/Delete)
        User->>+UI: Trong DebtSchedulingScreen, nhấn "Hoàn thành" hoặc "Xóa" reminder
        alt Mark Complete
            UI->>+DRS: markReminderComplete(reminderId)
            alt Client-side (Current)
                DRS->>DRS: Update reminder status trong SharedPreferences
            else Server-side (Future) 
                DRS->>+DB: RPC update_reminder_status(p_reminder_id, 'completed', ...)
                DB->>DB: UPDATE debt_reminders SET status='completed', completed_at=NOW()
                DB-->>-DRS: Trả về success
            end
            DRS-->>-UI: Trả về updated reminder list
        else Delete Reminder
            UI->>+DRS: deleteReminder(reminderId)
            alt Client-side (Current)
                DRS->>DRS: Remove reminder từ SharedPreferences
            else Server-side (Future)
                DRS->>+DB: DELETE FROM debt_reminders WHERE id = reminderId
                Note over DB: Cascade delete sẽ xóa luôn các notifications liên quan
                DB-->>-DRS: Trả về success
            end
            DRS-->>-UI: Trả về updated reminder list
        end
        UI->>User: Hiển thị danh sách đã cập nhật
    end

    alt Notification Processing (Server-side - Future)
        Note over DB: Scheduled job chạy hàng ngày
        DB->>+DB: CRON Job trigger process_pending_notifications()
        DB->>DB: SELECT pending notifications due today
        loop For each pending notification
            DB->>DB: UPDATE status = 'sent', sent_at = NOW()
            Note over DB: Integration với notification services:\n- Firebase Push Notifications\n- Email Service (SendGrid/AWS SES)\n- SMS Service (Twilio/AWS SNS)
            DB->>DB: PERFORM send_notification(notification_data)
        end
        DB-->>-DB: Return count of notifications processed
    end

    alt Read Debt List/Details
        User->>+UI: Mở màn hình "Quản Lý Công Nợ" (DebtListScreen)\nhoặc "Sổ Cái Công Nợ" (CustomerDebtDetailScreen)
        UI->>+DP: loadAllDebts() hoặc loadCustomerDebts(customerId)
        DP->>+DS: getAllDebts() hoặc getCustomerDebts(customerId)
        DS->>+DB: SELECT * FROM debts WHERE store_id = ? (có thể thêm filter status/customerId)
        DB-->>-DS: Trả về danh sách nợ
        DS-->>-DP: Trả về List<Debt>
        DP->>DP: Cập nhật state _debts
        DP-->>-UI: notifyListeners()
        UI->>User: Hiển thị danh sách hoặc chi tiết công nợ
        
        opt Load Reminders (if in Detail Screen)
            UI->>+DRS: getRemindersForDebt(debtId)
            alt Client-side (Current)
                DRS->>DRS: Load từ SharedPreferences
            else Server-side (Future)
                DRS->>+DB: RPC get_debt_reminders(p_debt_id, p_status_filter, ...)
                DB-->>-DRS: Trả về List<DebtReminder>
            end
            DRS-->>-UI: Trả về reminder list
            UI->>User: Hiển thị reminders trong scheduling section
        end
    end

    alt Analytics Dashboard (Server-side - Future)
        User->>+UI: Mở Dashboard/Reports screen
        UI->>+DRS: getDashboardSummary()
        DRS->>+DB: RPC get_reminder_dashboard_summary(p_date_range_days)
        DB->>DB: Calculate metrics from debt_reminders, reminder_notifications
        Note over DB: Tính toán các metrics:\n- Due today, Overdue, Upcoming\n- Completion rates, Notification success rates\n- Customer behavior patterns
        DB-->>-DRS: Trả về JSONB với dashboard data
        DRS-->>-UI: Trả về formatted metrics
        UI->>User: Hiển thị dashboard với charts và summaries
    end