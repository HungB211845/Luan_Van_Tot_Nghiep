# SPECS: Module Quản Lý Sản Phẩm (Product Management)

## 1. Tổng Quan

Đây là module phức tạp và quan trọng nhất của hệ thống AgriPOS. Nó không chỉ quản lý thông tin cơ bản của sản phẩm mà còn xử lý các logic nghiệp vụ chuyên sâu như:

-   Quản lý thuộc tính động cho từng loại sản phẩm (Phân bón, Thuốc BVTV, Lúa giống).
-   Quản lý tồn kho theo từng lô hàng (FIFO & Hạn sử dụng).
-   Quản lý giá bán linh hoạt theo mùa vụ.
-   Kiểm tra và cảnh báo về các hoạt chất bị cấm.

Kiến trúc của module tuân thủ nghiêm ngặt mô hình 3 lớp (UI -> Provider -> Service) để bóc tách các tầng logic, giúp hệ thống trở nên rõ ràng, dễ bảo trì và mở rộng.

---

## 2. Cấu Trúc Dữ Liệu (Data Structure & Models)

### a. Các Bảng trên Supabase

-   **`products`**: Bảng lõi chứa thông tin chung của tất cả sản phẩm. Điểm đặc biệt là cột `attributes` kiểu `JSONB` để lưu các thuộc tính riêng của từng loại sản phẩm.
-   **`product_batches`**: Quản lý từng lô hàng nhập về, với số lượng, giá vốn, và hạn sử dụng riêng. Đây là nền tảng cho việc quản lý tồn kho theo FIFO.
-   **`seasonal_prices`**: Quản lý giá bán của sản phẩm. Mỗi một dòng là một mức giá được áp dụng trong một khoảng thời gian nhất định.
-   **`banned_substances`**: Bảng tra cứu các hoạt chất bị cấm theo quy định.

### b. Views và Functions trên Supabase

Để tăng hiệu năng, một số logic đã được xử lý trước ở tầng database:

-   **View `products_with_details`**: Gộp thông tin từ `products` với giá bán hiện tại và tồn kho khả dụng.
-   **Function `get_current_price()`**: Tự động tìm và trả về giá bán đang được áp dụng cho một sản phẩm dựa trên ngày hiện tại.
-   **Function `get_available_stock()`**: Tự động tính tổng tồn kho của các lô hàng chưa hết hạn.

### c. Các Model trong Flutter (`lib/models/`)

-   **`Product`**: Model chính, chứa các thông tin chung và một getter để parse cột `attributes` (JSON) thành các object Dart type-safe tương ứng.
-   **`FertilizerAttributes`, `PesticideAttributes`, `SeedAttributes`**: Các class con, định nghĩa cấu trúc dữ liệu riêng cho từng loại sản phẩm.
-   **`ProductBatch`**: Đại diện cho một lô hàng trong kho.
-   **`SeasonalPrice`**: Đại diện cho một mức giá theo mùa vụ.

---

## 3. Luồng Kiến Trúc (3-Layer Architecture)

Đây là phần cốt lõi, giải thích cách các tầng tương tác với nhau.

### a. Tầng Service (`ProductService`) - Bộ Não Nghiệp Vụ

-   **Mục đích:** Là lớp duy nhất "nói chuyện" với Supabase. Nó đóng gói toàn bộ các câu lệnh SQL, gọi view, và gọi hàm RPC. Tầng trên (Provider) không cần biết đến sự tồn tại của Supabase.
-   **Các hàm chính:** Cung cấp đầy đủ các hàm CRUD cho Product, ProductBatch, và SeasonalPrice. Ví dụ: `getProducts()`, `createProduct(product)`, `addProductBatch(batch)`, `updateSeasonalPrice(price)`...

### b. Tầng Provider (`ProductProvider`) - Trung Tâm Điều Hành & Bộ Nhớ Tạm

-   **Mục đích:** Là trái tim của toàn bộ module. Nó là lớp trung gian giữa UI và Service, quản lý tất cả state liên quan đến sản phẩm.
-   **Quản lý State:** Nó không chỉ giữ một danh sách sản phẩm (`_products`), mà còn giữ rất nhiều state khác nhau để phục vụ cho các màn hình khác nhau: `_selectedProduct` (sản phẩm đang được xem chi tiết), `_productBatches` (danh sách lô hàng của sản phẩm đang xem), `_seasonalPrices` (lịch sử giá của sản phẩm đang xem), `_cartItems` (giỏ hàng ở màn hình POS), v.v.
-   **Luồng Dữ Liệu (Ví dụ: Tải danh sách lô hàng):**
    1.  **UI (`ProductDetailScreen`)** gọi `context.read<ProductProvider>().loadProductBatches(productId)`.
    2.  **Provider** nhận lệnh, ngay lập tức gọi `_setStatus(ProductStatus.loading)` để thông báo cho UI biết nó đang bận.
    3.  **Provider** gọi `await _productService.getProductBatches(productId)`.
    4.  **Service** thực hiện truy vấn đến Supabase và trả dữ liệu thô về.
    5.  **Provider** nhận dữ liệu từ Service, gán vào biến state `_productBatches`, sau đó gọi `_setStatus(ProductStatus.success)`.
    6.  Tất cả các lần gọi `_setStatus` đều kích hoạt `notifyListeners()`, khiến cho các widget `Consumer` ở UI tự động cập nhật lại giao diện (hiển thị vòng xoay loading, sau đó hiển thị danh sách lô hàng).

### c. Tầng UI (Các màn hình trong `screens/products/`)

-   **Mục đích:** Là các widget "ngu" (dumb widgets), chỉ có 2 nhiệm vụ: hiển thị state từ `ProductProvider` và gửi các hành động của người dùng (nhấn nút) lên cho `ProductProvider` xử lý.
-   **Tương tác:** Sử dụng `Consumer` hoặc `context.watch` để đọc và hiển thị dữ liệu. Sử dụng `context.read` để gọi các hàm xử lý logic (ví dụ: `context.read<ProductProvider>().addProduct(newProduct)`).

---

## 4. Luồng Hoạt Động CRUD Hoàn Chỉnh

-   **Create:** `AddProductScreen`, `AddBatchScreen`, `AddSeasonalPriceScreen` thu thập dữ liệu từ `Form`, tạo object model và gọi các hàm `add...` tương ứng của `ProductProvider`.
-   **Read:** `ProductListScreen` gọi `loadProducts` để hiển thị danh sách. `ProductDetailScreen` dựa vào `selectedProduct` để hiển thị thông tin, và dựa vào các tab để gọi các hàm `load...` chi tiết hơn (lô hàng, giá cả).
-   **Update:** Các màn hình `Edit...Screen` nhận một object có sẵn, điền thông tin vào `Form`, và khi lưu sẽ gọi các hàm `update...` của `ProductProvider`.
-   **Delete:** Hiện tại được thực hiện qua các nút bấm trong `ProductDetailScreen`, gọi các hàm `delete...` của `ProductProvider` để thực hiện xóa mềm.

## 5. Trạng Thái Hiện Tại

-   Module đã hoàn thiện 100% về mặt chức năng CRUD cho cả Sản phẩm, Lô hàng và Giá bán.
-   Kiến trúc 3 lớp rõ ràng, logic được đóng gói và xử lý ở các tầng phù hợp.
-   Các lỗi về logic, crash, và dữ liệu đã được khắc phục.