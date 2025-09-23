# SPECS: Module Giao Dịch (Transaction)

## 1. Tổng Quan

Module Giao Dịch, được điều hành bởi `TransactionService`, chịu trách nhiệm xử lý toàn bộ luồng bán hàng từ khi thêm sản phẩm vào giỏ hàng, thanh toán, quản lý tồn kho, cho đến khi ghi nhận giao dịch thành công. Module này được thiết kế để tách biệt hoàn toàn logic giao dịch khỏi `ProductService`, đảm bảo tính độc lập, dễ bảo trì và mở rộng.

## 2. Các Thành Phần Chính

-   **`TransactionService` (`lib/services/transaction_service.dart`):**
    -   Là trái tim của module giao dịch.
    -   Chịu trách nhiệm giao tiếp trực tiếp với Supabase để tạo, đọc, cập nhật các bản ghi giao dịch (`transactions`, `transaction_items`).
    -   Đóng gói logic trừ kho theo FIFO (`_reduceInventoryFIFO`, `_updateBatchQuantity`).
    -   Tạo mã hóa đơn duy nhất (`_generateInvoiceNumber`).
    -   Cung cấp các hàm để lấy lịch sử giao dịch, chi tiết giao dịch, giao dịch nợ và thống kê bán hàng.
-   **`ProductProvider` (`lib/providers/product_provider.dart`):**
    -   Quản lý trạng thái giỏ hàng (`_cartItems`).
    -   Là trung gian giữa UI (màn hình POS, giỏ hàng) và `TransactionService` để thực hiện quá trình thanh toán (`checkout`).
    -   Cũng chịu trách nhiệm làm giàu dữ liệu cho `TransactionItemDetails` để hiển thị trên màn hình thành công.
-   **`Cart` (Giỏ hàng - được quản lý trong `ProductProvider`):**
    -   Tập hợp các `CartItem` (sản phẩm được chọn mua).
    -   Là dữ liệu đầu vào cho quá trình tạo giao dịch.
-   **`POSScreen` (`lib/screens/pos/pos_screen.dart`):**
    -   Giao diện người dùng để chọn sản phẩm, thêm vào giỏ hàng.
    -   Hiển thị mini-cart và điều hướng đến `CartScreen`.
-   **`CartScreen` (`lib/screens/cart/cart_screen.dart`):**
    -   Hiển thị chi tiết giỏ hàng.
    -   Cho phép người dùng xác nhận đơn hàng, chọn khách hàng, và kích hoạt quá trình thanh toán.
-   **`TransactionSuccessScreen` (`lib/screens/transaction/transaction_success_screen.dart`):**
    -   Màn hình hiển thị "biên lai" sau khi giao dịch thành công.
    -   Hiển thị chi tiết giao dịch đã được làm giàu dữ liệu.
-   **`ProductService` (`lib/services/product_service.dart`):**
    -   Hiện tại chỉ tập trung vào quản lý thông tin sản phẩm (CRUD, batch, price, banned substances).
    -   Không còn trực tiếp tham gia vào luồng tạo giao dịch hay trừ kho.
    -   `ProductProvider` vẫn gọi `ProductService` để lấy thông tin sản phẩm (ví dụ: tồn kho, giá) để hiển thị trên POSScreen và kiểm tra khi thêm vào giỏ hàng.

## 3. Luồng Hoạt Động Chi Tiết (Workflows)

### 3.1. Luồng "Thêm Sản Phẩm Vào Giỏ Hàng" (POSScreen -> Cart)

1.  **`POSScreen`:** Người dùng chọn sản phẩm và nhấn nút `+` để thêm vào giỏ hàng.
2.  **`POSScreen` -> `ProductProvider`:** `POSScreen` gọi `productProvider.addToCart(product, quantity)`.
3.  **`ProductProvider` (Logic Giỏ hàng):**
    *   Kiểm tra tồn kho khả dụng của sản phẩm bằng cách gọi `productProvider.getProductStock(product.id)` (dữ liệu tồn kho được `ProductProvider` quản lý thông qua `ProductService.getAvailableStock` khi `loadProducts`).
    *   Kiểm tra giá bán hiện tại (`productProvider.getCurrentPrice(product.id)`).
    *   Cập nhật danh sách `_cartItems` và tính toán lại `_cartTotal`.
    *   Gọi `notifyListeners()` để cập nhật UI (`POSScreen` và mini-cart).
    *   **Lưu ý:** Luồng này không tương tác trực tiếp với database cho đến khi thanh toán, giúp trải nghiệm người dùng nhanh chóng.

### 3.2. Luồng "Thanh Toán Giao Dịch" (CartScreen -> TransactionService)

1.  **`CartScreen`:** Người dùng xác nhận các mặt hàng trong giỏ, chọn khách hàng (nếu có), chọn phương thức thanh toán (Tiền mặt/Ghi nợ), và nhấn nút "Thanh toán".
2.  **`CartScreen` -> `ProductProvider`:** `CartScreen` gọi `productProvider.checkout(...)`, truyền vào `customerId`, `paymentMethod`, `notes`.
3.  **`ProductProvider` (Logic Checkout):**
    *   Chuyển đổi `_cartItems` thành danh sách `TransactionItem`.
    *   Gọi `await _transactionService.createTransaction(...)`, truyền vào `customerId`, `TransactionItem` list, `paymentMethod`, `notes`.
4.  **`TransactionService` (Tạo Giao Dịch & Trừ Kho):**
    *   Nhận yêu cầu `createTransaction`.
    *   Tính toán `total_amount` của giao dịch.
    *   Tạo `invoice_number` bằng `_generateInvoiceNumber()`.
    *   Ghi bản ghi vào bảng `transactions` trên Supabase.
    *   Ghi các bản ghi vào bảng `transaction_items` trên Supabase.
    *   **Trừ kho:** Lặp qua từng `TransactionItem`, gọi `await _reduceInventoryFIFO(item.productId, item.quantity)`.
        *   `_reduceInventoryFIFO` sẽ truy vấn các `product_batches` theo FIFO, cập nhật số lượng trong từng batch bằng cách gọi `_updateBatchQuantity`.
    *   **Logic Ghi nợ (TODO):** Nếu `paymentMethod` là `DEBT`, `TransactionService` sẽ gọi `DebtService.createDebtFromTransaction(...)` (hiện đang comment out, cần được kích hoạt khi `DebtService` hoàn thiện).
    *   Trả về `transactionId` sau khi hoàn tất.
5.  **`ProductProvider` (Sau Checkout):**
    *   Nhận `transactionId` từ `TransactionService`.
    *   Gọi `clearCart()` để dọn dẹp giỏ hàng.
    *   Cập nhật trạng thái (`ProductStatus.success`).
    *   Trả về `transactionId` cho `CartScreen`.
6.  **`CartScreen` -> `TransactionSuccessScreen`:** `CartScreen` nhận `transactionId` và điều hướng đến `TransactionSuccessScreen` để hiển thị biên lai.

### 3.3. Luồng "Hiển Thị Biên Lai Giao Dịch" (TransactionSuccessScreen)

1.  **`TransactionSuccessScreen`:** Màn hình được khởi tạo với `transactionId`.
2.  **`TransactionSuccessScreen` -> `ProductProvider`:** Màn hình gọi `productProvider.loadTransactionDetails(transactionId)`.
3.  **`ProductProvider` (Làm giàu dữ liệu):**
    *   Gọi `_transactionService.getTransactionById(transactionId)` để lấy thông tin giao dịch chính.
    *   Gọi `_transactionService.getTransactionItems(transactionId)` để lấy danh sách các mặt hàng thô.
    *   **Làm giàu dữ liệu:** Lặp qua từng `TransactionItem` thô, kết hợp với thông tin sản phẩm (`Product` object) mà `ProductProvider` đang quản lý (từ `_products` list) để tạo ra danh sách `TransactionItemDetails` (chứa `productName`, `productSku`...).
    *   Cập nhật `_activeTransaction` và `_activeTransactionItems`.
    *   Gọi `notifyListeners()` để `TransactionSuccessScreen` tự động cập nhật.
4.  **`TransactionSuccessScreen`:** Hiển thị thông tin giao dịch và các mặt hàng đã được làm giàu.
5.  **`TransactionSuccessScreen` -> `POSScreen`:** Người dùng nhấn "Tạo Giao Dịch Mới", `ProductProvider.refresh()` được gọi để làm mới dữ liệu nền (tồn kho, dashboard), và điều hướng về `POSScreen` sạch sẽ.

## 4. Tương Tác với `ProductService`

-   `ProductService` không còn trực tiếp tham gia vào quá trình tạo giao dịch hay trừ kho.
-   `ProductProvider` vẫn sử dụng `ProductService` để:
    -   Lấy danh sách sản phẩm (`getProducts`, `searchProducts`).
    -   Lấy thông tin tồn kho (`getAvailableStock`) để hiển thị trên POSScreen và kiểm tra khi thêm vào giỏ hàng.
    -   Quản lý các hoạt động CRUD cho Product, Batch, SeasonalPrice, BannedSubstance.

## 5. Các Điểm Cần Phát Triển Thêm (TODOs)

-   **Tích hợp `DebtService`:** Kích hoạt logic `_debtService.createDebtFromTransaction` trong `TransactionService.createTransaction` khi `DebtService` đã hoàn thiện.
-   **Debt Validation & Credit Limit:** Triển khai logic kiểm tra hạn mức tín dụng và các quy tắc nghiệp vụ liên quan đến nợ trong `DebtService` và tích hợp vào luồng `createTransaction` (có thể là một bước tiền kiểm tra trước khi tạo transaction).
-   **Payment Preview:** Triển khai `PaymentPreview` trong `DebtService` và tích hợp vào `AddPaymentScreen` để người dùng có thể xem trước phân bổ thanh toán.
-   **Due Date & Interest Rate Calculation:** Hoàn thiện logic tính toán ngày đến hạn và lãi suất trong `DebtService` hoặc các helper class liên quan.
-   **OVERDUE Status Automation:** Triển khai scheduled job hoặc database trigger để tự động cập nhật trạng thái `OVERDUE` cho các khoản nợ.
