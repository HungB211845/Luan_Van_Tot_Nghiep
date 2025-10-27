sequenceDiagram
    actor User
    participant UI as UI (Screens)
    participant Provider as ProductProvider
    participant Service as ProductService
    participant Supabase as Supabase (DB/View/RPC)

    alt Create Product
        User->>+UI: Mở màn hình "Thêm sản phẩm" (AddProductStep1Screen)
        User->>UI: Nhập thông tin (tên, NCC, ...) và nhấn "Tiếp tục"
        UI->>+Provider: addProduct(newProduct)
        Provider->>+Service: createProduct(product)
        Service->>+Supabase: INSERT INTO products (data)
        Supabase-->>-Service: Trả về product vừa tạo
        Service-->>-Provider: Trả về Product object
        Provider->>Provider: Cập nhật state _products
        Provider-->>-UI: notifyListeners()
        UI->>User: Hiển thị thông báo thành công và quay về danh sách
    end

    alt Read Product List
        User->>+UI: Mở màn hình "Danh sách sản phẩm" (ProductListScreen)
        UI->>+Provider: loadProductsPaginated()
        Provider->>+Service: getProductsPaginated()
        Service->>+Supabase: SELECT * FROM products_with_details
        Note right of Service: View này đã gộp sẵn Tồn kho (available_stock)\n và Giá bán (current_price) để tối ưu.
        Supabase-->>-Service: Trả về danh sách products
        Service-->>-Provider: Trả về List<Product>
        Provider->>Provider: Cập nhật state _paginatedProducts
        Provider-->>-UI: notifyListeners()
        UI->>User: Hiển thị danh sách sản phẩm
    end

    alt Update Product
        User->>+UI: Mở "EditProductScreen" và sửa thông tin
        User->>UI: Nhấn "Lưu"
        UI->>+Provider: updateProduct(updatedProduct)
        Provider->>+Service: updateProduct(product)
        Service->>+Supabase: UPDATE products SET ... WHERE id = ?
        Supabase-->>-Service: Trả về product đã cập nhật
        Service-->>-Provider: Trả về Product object
        Provider->>Provider: Cập nhật lại sản phẩm trong state _products
        Provider-->>-UI: notifyListeners()
        UI->>User: Hiển thị thông báo thành công và quay về
    end

    alt Delete Product
        User->>+UI: Nhấn nút "Xóa" trong "EditProductScreen"
        UI->>+Provider: deleteProduct(productId)
        Provider->>+Service: deleteProduct(productId)
        Service->>+Supabase: UPDATE products SET is_active = false WHERE id = ?
        Note right of Service: Đây là xóa mềm (soft delete)\nđể bảo toàn dữ liệu lịch sử.
        Supabase-->>-Service: Xác nhận thành công
        Service-->>-Provider: Trả về void
        Provider->>Provider: Xóa sản phẩm khỏi state _products
        Provider-->>-UI: notifyListeners()
        UI->>User: Hiển thị thông báo thành công và quay về danh sách
    end