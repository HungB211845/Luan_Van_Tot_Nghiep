# SPECS: Module Bán Hàng (Point of Sale - POS)

## 1. Tổng Quan

Module POS là giao diện tương tác chính của người dùng cuối (nhân viên bán hàng). Nó bao gồm một quy trình hoàn chỉnh từ việc chọn sản phẩm, quản lý giỏ hàng, thanh toán, cho đến khi hiển thị biên lai thành công. Module này được thiết kế để hoạt động nhanh, hiệu quả và đáng tin cậy, với `ProductProvider` đóng vai trò là trung tâm điều hành cho tất cả các trạng thái và hành động.

---

## 2. Các Thành Phần Liên Quan

-   **UI Screens:**
    -   `POSScreen`: Màn hình chính, nơi hiển thị sản phẩm và cho phép thêm vào giỏ hàng.
    -   `CartScreen`: Màn hình chi tiết giỏ hàng và là cổng thanh toán.
    -   `TransactionSuccessScreen`: Màn hình "biên lai" sau khi thanh toán thành công.
-   **ViewModel (`POSViewModel`):** Một lớp trung gian mỏng, giúp `POSScreen` giao tiếp với các Provider một cách gọn gàng.
-   **Provider (`ProductProvider`):** Trái tim của luồng POS. Nó quản lý trạng thái của giỏ hàng (`_cartItems`), chứa logic `checkout` chính, và điều phối các lệnh gọi xuống Service.
-   **Service (`ProductService`):** "Người công nhân" làm việc với backend. Chịu trách nhiệm ghi giao dịch vào database và thực hiện logic trừ kho.

---

## 3. Luồng Hoạt Động Chi Tiết

### a. Luồng 1: Thêm Sản Phẩm Vào Giỏ Hàng

Đây là luồng không cần tương tác với database, giúp trải nghiệm người dùng nhanh và mượt.

1.  **UI (`POSScreen`):** Người dùng nhấn nút `+` trên một thẻ sản phẩm.
2.  **UI -> ViewModel:** `onTap` gọi `_viewModel.updateCartItemQuantity(product, newQuantity)`.
3.  **ViewModel -> Provider:** `POSViewModel` gọi đến hàm `productProvider.addToCart()` hoặc `updateCartItem()`.
4.  **Provider (Xử lý State):** `ProductProvider` thực hiện toàn bộ logic ngay trong bộ nhớ của nó:
    -   Nó kiểm tra xem sản phẩm đã có trong giỏ hàng (`_cartItems`) chưa.
    -   Nếu có, nó cập nhật số lượng. Nếu chưa, nó tạo một `CartItem` mới.
    -   Nó tính toán lại tổng tiền (`_cartTotal`).
    -   Cuối cùng, nó gọi `notifyListeners()` để "phát loa".
5.  **UI (Cập nhật):** Các widget `Consumer` trên `POSScreen` (cụm nút `+/-` và mini-cart) nghe thấy thông báo và tự động vẽ lại để hiển thị số lượng và tổng tiền mới nhất.

### b. Luồng 2: Thực Hiện Thanh Toán (Checkout)

Đây là luồng phức tạp, kết hợp cả state management ở client và tương tác với backend.

1.  **UI (`CartScreen`):** Người dùng xác nhận đơn hàng và nhấn nút "Xác nhận" trong hộp thoại thanh toán.
2.  **UI -> ViewModel -> Provider:** Lệnh được chuyển qua `POSViewModel` và cuối cùng gọi đến `await productProvider.checkout(...)`.
3.  **Provider -> Service:** Hàm `checkout` trong `ProductProvider` gọi `await _productService.createTransaction(...)`.
4.  **Service -> Supabase (Trái tim của giao dịch):**
    -   `createTransaction` trong `ProductService` tạo một bản ghi trong bảng `transactions`.
    -   Nó tạo nhiều bản ghi tương ứng trong bảng `transaction_items`.
    -   **Quan trọng:** Nó gọi hàm private `_reduceInventoryFIFO()` để thực hiện logic trừ kho trực tiếp trong database, đảm bảo tính toàn vẹn dữ liệu.
5.  **Hành trình trở về:**
    -   Supabase xác nhận giao dịch thành công, `ProductService` trả về `transactionId` cho `ProductProvider`.
    -   `ProductProvider` gọi `clearCart()` để dọn dẹp giỏ hàng ở client, sau đó **trả về `transactionId` ngay lập tức** cho UI.
6.  **UI (`CartScreen`):** Nhận được `transactionId` (khác null), nó hiểu rằng giao dịch đã thành công và thực hiện `Navigator.pushReplacement`, thay thế chính nó bằng màn hình `TransactionSuccessScreen`.

### c. Luồng 3: Cập Nhật Tồn Kho Trên Giao Diện

Luồng này giải quyết vấn đề làm sao để `POSScreen` biết được tồn kho đã thay đổi.

1.  **UI (`TransactionSuccessScreen`):** Người dùng xem xong "biên lai" và nhấn nút "Tạo Giao Dịch Mới".
2.  **UI -> Provider:** `onPressed` của nút này thực hiện 2 việc:
    a.  Gọi `context.read<ProductProvider>().refresh()`: Đây là một lệnh không đồng bộ, yêu cầu Provider đi lấy lại dữ liệu mới nhất (sản phẩm, tồn kho, dashboard) từ `ProductService`.
    b.  Gọi `Navigator.pushAndRemoveUntil(...)`: Ngay lập tức, không cần chờ `refresh` xong, lệnh này dọn dẹp toàn bộ các màn hình cũ và đẩy một `POSScreen` mới lên, đưa người dùng về giao diện bán hàng.
3.  **Provider & UI (Cập nhật ngầm):**
    -   Trong khi người dùng đang ở trên màn hình `POSScreen` mới, lệnh `refresh()` vẫn đang chạy ở dưới nền.
    -   Khi `refresh()` hoàn tất và có dữ liệu tồn kho mới, `ProductProvider` sẽ gọi `notifyListeners()`.
    -   `Consumer` trong `POSScreen` nghe được tín hiệu này và tự động cập nhật lại con số tồn kho trên các thẻ sản phẩm.

Luồng hoạt động này đảm bảo người dùng có trải nghiệm mượt mà (không phải chờ đợi) và dữ liệu luôn được cập nhật một cách chính xác sau mỗi giao dịch.