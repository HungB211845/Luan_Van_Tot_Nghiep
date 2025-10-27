sequenceDiagram
    actor User
    participant UI as UI (Screens)
    participant CP as CustomerProvider
    participant CS as CustomerService
    participant DB as Supabase (DB/RPC)

    alt Create Customer
        User->>+UI: Mở màn hình "Thêm Khách Hàng" (AddCustomerScreen)
        User->>UI: Nhập thông tin khách hàng và nhấn "Lưu"
        UI->>+CP: addCustomer(newCustomer)
        CP->>+CS: createCustomer(customer)
        CS->>+DB: INSERT INTO customers (data)
        Note over DB: Dữ liệu đã được thêm store_id tự động qua BaseService
        DB-->>-CS: Trả về customer vừa tạo
        CS-->>-CP: Trả về Customer object
        CP->>CP: Cập nhật state _customers
        CP-->>-UI: notifyListeners()
        UI->>User: Hiển thị thông báo thành công và quay về danh sách
    end

    alt Read Customer List
        User->>+UI: Mở màn hình "Danh Sách Khách Hàng" (CustomerListScreen)
        UI->>+CP: loadCustomers()
        CP->>+CS: getCustomers()
        CS->>+DB: SELECT * FROM customers WHERE store_id = ? ORDER BY name
        Note over DB: Tự động thêm filter store_id qua BaseService
        DB-->>-CS: Trả về danh sách khách hàng
        CS-->>-CP: Trả về List<Customer>
        CP->>CP: Cập nhật state _customers
        CP-->>-UI: notifyListeners()
        UI->>User: Hiển thị danh sách khách hàng
    end

    alt Read Customer Details
        User->>+UI: Mở màn hình "Chi Tiết Khách Hàng" (CustomerDetailScreen)
        UI->>+CP: loadCustomerStatistics(customerId)
        CP->>+CS: getCustomerStatistics(customerId)
        CS->>+DB: RPC get_customer_statistics(p_customer_id, p_store_id)
        Note over DB: RPC này tính toán tổng số giao dịch, doanh thu, nợ còn lại
        DB-->>-CS: Trả về thống kê khách hàng
        CS-->>-CP: Trả về Map<String, dynamic>
        CP->>CP: Cập nhật state _customerStatistics
        CP-->>-UI: notifyListeners()
        UI->>User: Hiển thị thông tin chi tiết và thống kê khách hàng
    end

    alt Update Customer
        User->>+UI: Mở màn hình "Chỉnh Sửa Khách Hàng" (EditCustomerScreen)
        User->>UI: Sửa thông tin khách hàng và nhấn "Lưu"
        UI->>+CP: updateCustomer(updatedCustomer)
        CP->>+CS: updateCustomer(customer)
        CS->>+DB: UPDATE customers SET ... WHERE id = ? AND store_id = ?
        Note over DB: Đảm bảo cập nhật đúng khách hàng trong đúng store
        DB-->>-CS: Trả về customer đã cập nhật
        CS-->>-CP: Trả về Customer object
        CP->>CP: Cập nhật lại khách hàng trong state _customers
        CP-->>-UI: notifyListeners()
        UI->>User: Hiển thị thông báo thành công và quay về
    end

    alt Delete Customer
        User->>+UI: Nhấn nút "Xóa" trong "CustomerDetailScreen"
        UI->>UI: Xác nhận xóa
        UI->>+CP: deleteCustomer(customerId)
        CP->>+CS: deleteCustomer(customerId)
        CS->>+DB: DELETE FROM customers WHERE id = ? AND store_id = ?
        Note over DB: Xóa khách hàng khỏi database.\nCó thể có ràng buộc khóa ngoại với bảng `debts` hoặc `transactions`.
        DB-->>-CS: Xác nhận thành công
        CS-->>-CP: Trả về void
        CP->>CP: Xóa khách hàng khỏi state _customers
        CP-->>-UI: notifyListeners()
        UI->>User: Hiển thị thông báo thành công và quay về danh sách
    end