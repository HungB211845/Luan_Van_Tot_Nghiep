sequenceDiagram
    actor User
    participant UI as UI (POS/Cart/Success)
    participant PP as ProductProvider
    participant TSP as TransactionService
    participant DB as Supabase (DB/RPC)

    alt Create Transaction (Bán hàng)
        User->>+UI: Chọn sản phẩm từ POSScreen
        UI->>+PP: addToCart(product, quantity, selectedUnit)
        Note over PP: 1. Kiểm tra Multi-UoM & hiển thị UnitSelectionSheet (nếu cần)\n2. Tính toán baseUnitQuantity (quantity × conversionFactor)\n3. Kiểm tra tồn kho theo baseUnitQuantity\n4. Cập nhật giỏ hàng trong bộ nhớ (_cartItems)
        PP-->>-UI: Cập nhật hiển thị giỏ hàng (mini-cart)

        User->>+UI: Nhấn "Thanh toán" từ CartScreen
        UI->>+PP: checkout(customerId, items, paymentMethod, ...)
        Note over PP: 1. Chuyển đổi _cartItems thành List<TransactionItem> (mỗi item chứa unitId, unitName, baseUnitQuantity)\n2. Tính toán tổng tiền, phụ phí (nếu có)
        PP->>+TSP: createTransaction(customerId, items, paymentMethod, ...)
        TSP->>+DB: INSERT INTO transactions (data)
        DB-->>-TSP: Trả về transactionId

        TSP->>+DB: INSERT INTO transaction_items (itemsData)
        Note over DB: Mỗi itemData chứa productId, quantity, priceAtSale, subTotal, unitId, unitName, unitConversionFactor, baseUnitQuantity
        DB-->>-TSP: Xác nhận

        TSP->>+DB: RPC update_inventory_fifo_batch(items_json)
        Note over DB: 1. Lặp qua từng item trong items_json\n2. SELECT product_batches theo FIFO (received_date ASC)\n3. UPDATE quantity của từng batch (trừ đi baseUnitQuantity)\n4. Xử lý thiếu hàng (insufficient_stock)
        DB-->>-TSP: Trả về kết quả cập nhật tồn kho (success/error)

        TSP-->>-PP: Trả về transactionId
        Note over PP: Xóa giỏ hàng (_cartItems.clear())\nCập nhật cache tồn kho (_refreshStockAfterTransaction)
        PP-->>-UI: notifyListeners()
        UI->>User: Hiển thị màn hình "Giao dịch thành công" (TransactionSuccessScreen)
    end

    alt Read Transaction History
        User->>+UI: Mở màn hình "Lịch sử giao dịch" (TransactionListScreen)
        UI->>+PP: loadTransactionDetails(transactionId)
        PP->>+TSP: getTransactionWithItems(transactionId)
        TSP->>+DB: SELECT * FROM transactions JOIN transaction_items JOIN customers WHERE id = ?
        Note over DB: Sử dụng JOIN để lấy transaction và các item liên quan trong 1 query\nĐã bao gồm thông tin UoM trong transaction_items
        DB-->>-TSP: Trả về dữ liệu giao dịch lồng nhau
        TSP->>TSP: Chuyển đổi dữ liệu Supabase thành Transaction object (bao gồm List<TransactionItem>)
        TSP-->>-PP: Trả về Transaction object
        Note over PP: "Làm giàu" dữ liệu (enrichment) cho TransactionItemDetails\n(kết hợp TransactionItem với Product object từ cache)
        PP-->>-UI: notifyListeners()
        UI->>User: Hiển thị chi tiết giao dịch
    end