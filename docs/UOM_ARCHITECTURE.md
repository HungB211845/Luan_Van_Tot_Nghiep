# SPECS: Hệ Thống Quản Lý Đa Đơn Vị Tính (Multi-Unit of Measurement - UoM)

> **Template Version**: 1.1
> **Last Updated**: October 2025
> **Implementation Status**: 100% Complete
> **Multi-Tenant Ready**: ✅
> **Responsive Design**: ✅

## 1. Tổng Quan

### a. Mục Đích Nghiệp Vụ
Hệ thống UoM được xây dựng để giải quyết bài toán thực tế trong ngành vật tư nông nghiệp: một sản phẩm có thể được nhập và bán theo nhiều đơn vị khác nhau (ví dụ: Phân bón nhập theo "Tấn", bán theo "Bao" 50kg và bán lẻ theo "kg"). Hệ thống này cho phép quản lý tồn kho chính xác theo một **đơn vị cơ sở** duy nhất, trong khi vẫn linh hoạt trong việc bán hàng và định giá theo nhiều đơn vị khác nhau.

### b. Các Thành Phần Chính
*   **Database Table**: `product_units` là bảng trung tâm, lưu trữ tất cả các đơn vị tính cho mỗi sản phẩm, cùng với hệ số quy đổi và giá bán tương ứng.
*   **Database RPC**: Các hàm `get_product_units` và `update_product_selling_price` để truy vấn và đồng bộ dữ liệu một cách nguyên tử.
*   **Model**: `lib/features/products/models/product_unit.dart` định nghĩa cấu trúc của một đơn vị tính.
*   **Service**: `lib/features/products/services/product_unit_service.dart` là lớp duy nhất giao tiếp với database để thực hiện các thao tác CRUD trên `product_units`.
*   **Provider**: `lib/features/products/providers/product_provider.dart` quản lý state, chứa logic tính toán và là trung gian giữa UI và Service.
*   **UI Screens**:
    *   `EditProductScreen`: Giao diện để cấu hình các đơn vị tính cho một sản phẩm.
    *   `UnitSelectionSheet`: Bottom sheet để người dùng chọn đơn vị khi thêm vào giỏ hàng.
    *   `CreatePurchaseOrderScreen`: Màn hình tạo đơn nhập hàng, có hỗ trợ chọn đơn vị nhập.

---

## 2. Phân Tích Theo Từng Lớp Kiến Trúc

### a. Tầng Database (Nguồn Chân Lý)
Đây là nền tảng của toàn bộ hệ thống, đảm bảo tính nhất quán và chính xác của dữ liệu.

*   **Bảng `product_units`**:
    *   `product_id`: Liên kết với sản phẩm.
    *   `unit_name`: Tên đơn vị (ví dụ: "Bao", "kg", "Chai").
    *   `conversion_factor`: **Cột quan trọng nhất**. Hệ số quy đổi về đơn vị cơ sở. Ví dụ: Nếu đơn vị cơ sở là "kg", thì "Bao 50kg" sẽ có `conversion_factor` là 50. "kg" sẽ có `conversion_factor` là 1.
    *   `unit_price`: Giá bán cho một đơn vị này.
    *   `is_default_selling_unit`: Đánh dấu đơn vị bán hàng mặc định, thường là đơn vị lớn nhất (ví dụ: "Bao").

*   **Hàm RPC `update_product_selling_price` (Trái Tim Của Đồng Bộ Hóa)**:
    *   **Input**: ID sản phẩm, giá bán MỚI (cho đơn vị mặc định), lý do thay đổi.
    *   **Logic**:
        1.  Cập nhật `current_selling_price` trên bảng `products`.
        2.  Ghi lại sự thay đổi vào `price_history`.
        3.  **Tự động đồng bộ giá cho tất cả các đơn vị con**: Nó tìm đơn vị mặc định (`is_default_selling_unit = true`), lấy hệ số quy đổi của nó làm chuẩn, và tính lại giá cho tất cả các đơn vị khác theo công thức:
            ```
            Giá unit con = (Giá mới của unit mặc định / Hệ số của unit mặc định) * Hệ số của unit con
            ```
            **Ví dụ:** Mày cập nhật giá "Bao" (50kg) thành 550.000đ. Hàm này sẽ tự động tính lại giá của "kg" thành: `(550.000 / 50) * 1 = 11.000đ`.
    *   **Lợi ích**: Đảm bảo giá bán của tất cả các đơn vị luôn nhất quán với nhau chỉ bằng một lệnh cập nhật duy nhất.

### b. Tầng Service (`ProductUnitService`)
Lớp này đóng gói toàn bộ logic giao tiếp với database, cung cấp các API sạch sẽ cho tầng Provider.
*   `getProductUnits(productId)`: Gọi RPC `get_product_units` để lấy danh sách các đơn vị tính hợp lệ của một sản phẩm.
*   `createProductUnit(unit)`, `updateProductUnit(unit)`: Tạo và cập nhật đơn vị tính.
*   `setDefaultUnit(productId, unitId)`: Thiết lập một đơn vị làm đơn vị bán hàng mặc định.

### c. Tầng Provider (`ProductProvider`)
Đây là nơi xử lý logic nghiệp vụ phức tạp liên quan đến UoM.
*   **Quản lý State**: Cache lại danh sách `ProductUnit` cho sản phẩm đang được chọn để tránh gọi database liên tục.
*   **Logic `addToCart`**:
    1.  Khi người dùng thêm sản phẩm, nếu sản phẩm đó có nhiều đơn vị, UI sẽ hiển thị `UnitSelectionSheet`.
    2.  Người dùng chọn một đơn vị (ví dụ: "kg").
    3.  `addToCart` nhận vào `Product`, `quantity`, và `ProductUnit` đã chọn.
    4.  Nó sử dụng `conversion_factor` của `ProductUnit` đó để tính ra `baseUnitQuantity` (số lượng quy đổi về đơn vị cơ sở).
        ```dart
        // Ví dụ: Mua 5 kg
        final baseUnitQuantity = 5 * 1.0; // conversion_factor của kg là 1.0
        ```
    5.  Kiểm tra tồn kho dựa trên `baseUnitQuantity` này.
    6.  Khi tạo `TransactionItem`, nó sẽ lưu cả `unitId`, `unitName`, `unitConversionFactor`, và `baseUnitQuantity` để đảm bảo việc trừ kho và ghi nhận lịch sử là chính xác tuyệt đối.

### d. Tầng UI (Các Màn Hình)
*   **`EditProductScreen`**: Cung cấp giao diện cho người quản lý để cấu hình các đơn vị và hệ số quy đổi. Ví dụ: một form cho phép nhập "1 Bao = 50 kg".
*   **`UnitSelectionSheet`**: Một bottom sheet đơn giản, rõ ràng, hiển thị danh sách các đơn vị khả dụng, giá bán và tồn kho tương ứng cho từng đơn vị, cho phép nhân viên bán hàng chọn nhanh.
*   **`ProductDetailScreen` & `POSScreen`**: Hiển thị tồn kho theo đơn vị bán hàng mặc định (ví dụ: "53 Bao và 25 kg") thay vì chỉ hiển thị một con số tồn kho cơ sở khó hiểu (ví dụ: "2675 kg").

---

## 3. Luồng Hoạt Động Cốt Lõi

### a. Luồng Cấu Hình (Admin)
1.  **Admin** vào `EditProductScreen` của sản phẩm "Phân bón A".
2.  Trong mục "Đơn Vị Bán Hàng", Admin cấu hình:
    *   Đơn vị cơ sở: "kg".
    *   Thêm đơn vị "Bao", hệ số quy đổi: 50. Đánh dấu đây là đơn vị bán hàng mặc định.
3.  **Hệ thống** gọi `ProductUnitService` để tạo/cập nhật 2 record trong bảng `product_units`: một cho "kg" (factor=1) và một cho "Bao" (factor=50, is_default=true).

### b. Luồng Bán Hàng (Cashier)
1.  **Cashier** trên `POSScreen` nhấn thêm "Phân bón A" vào giỏ hàng.
2.  **UI** hiển thị `UnitSelectionSheet` với 2 lựa chọn: "Bao" và "kg", kèm theo giá và tồn kho đã quy đổi cho từng loại.
3.  **Cashier** chọn "kg" và nhập số lượng là 5.
4.  **`ProductProvider.addToCart`** được gọi. Nó tính `baseUnitQuantity` = 5 * 1.0 = 5.
5.  Khi thanh toán, **`TransactionService`** sẽ tạo `TransactionItem` với `base_unit_quantity` = 5 và trừ 5 đơn vị khỏi tồn kho cơ sở.

### c. Luồng Đồng Bộ Giá (Manager)
1.  **Manager** vào `ProductDetailScreen`, nhấn "Sửa giá" và cập nhật giá bán của "Phân bón A" thành 550.000đ (đây là giá của đơn vị mặc định - "Bao").
2.  **`ProductProvider.updateCurrentSellingPrice`** được gọi.
3.  **`ProductService`** gọi hàm RPC `update_product_selling_price` trên Supabase.
4.  **Database** tự động thực hiện:
    *   Cập nhật `products.current_selling_price` = 550.000.
    *   Cập nhật `product_units.unit_price` của "Bao" thành 550.000.
    *   Cập nhật `product_units.unit_price` của "kg" thành 11.000.
5.  Lần bán hàng tiếp theo, `UnitSelectionSheet` sẽ hiển thị giá mới một cách chính xác.

---

## 4. Quy Tắc Nghiệp Vụ & Điểm Cần Lưu Ý
*   **Đơn vị cơ sở (Base Unit)** là nguồn chân lý cho việc quản lý tồn kho. Mọi số lượng cuối cùng đều được quy đổi về đơn vị này để trừ kho.
*   **Đơn vị bán hàng mặc định (Default Selling Unit)** là đơn vị chính được hiển thị cho người dùng và là cơ sở để tính giá cho các đơn vị khác.
*   **Đồng bộ giá tự động** là một quy tắc nghiệp vụ quan trọng, đảm bảo tính nhất quán và giảm thiểu sai sót do nhập liệu thủ công.
*   **Tồn kho** luôn được kiểm tra dựa trên số lượng đã quy đổi về đơn vị cơ sở.

---

## 5. Kết Luận
Hệ thống UoM của mày được thiết kế rất chặt chẽ và toàn diện:
*   **Chính xác về mặt kế toán:** Tồn kho luôn được quản lý ở đơn vị cơ sở, tránh sai sót do làm tròn. Lịch sử giao dịch ghi lại chính xác đơn vị đã bán.
*   **Linh hoạt cho người dùng:** Cho phép bán hàng theo nhiều đơn vị tiện lợi.
*   **Dễ bảo trì:** Logic tính toán và đồng bộ giá được đặt ở tầng database (RPC), giảm gánh nặng cho phía client và đảm bảo tính nhất quán.
*   **Nguyên tử:** Việc cập nhật giá đồng loạt được thực hiện trong một giao dịch duy nhất ở database, đảm bảo không có trạng thái giá "nửa vời".

Đây là một kiến trúc ở đẳng cấp enterprise, sẵn sàng cho các kịch bản kinh doanh phức tạp.
