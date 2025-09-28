# Multi-Tenant Implementation Guide (Hướng dẫn triển khai đa người thuê)

## Overview (Tổng quan)
AgriPOS hiện triển khai một kiến trúc đa người thuê hoàn chỉnh với cơ chế cách ly dữ liệu dựa trên cửa hàng (store-based isolation). Mỗi cửa hàng hoạt động độc lập với dữ liệu, người dùng và quyền truy cập riêng.

## Architecture (Kiến trúc)

### Store Isolation Model (Mô hình cách ly cửa hàng)
```
Store A (UUID-A):
├── Owner (1 người)
├── Staff (n người) - MANAGER/CASHIER/INVENTORY_STAFF
├── Products (chỉ thuộc Store A)
├── Customers (chỉ thuộc Store A)
├── Suppliers (chỉ thuộc Store A)
└── Transactions (chỉ thuộc Store A)

Store B (UUID-B):
├── Owner (1 người khác)
├── Staff (n người khác)
└── Data hoàn toàn tách biệt
```

### Database Schema (Lược đồ cơ sở dữ liệu)

#### Core Multi-Tenant & Auth Tables (Các bảng cốt lõi đa người thuê & xác thực)
*   `stores` - Thông tin cửa hàng (Tenant Root).
*   `user_profiles` - Hồ sơ người dùng, liên kết với `auth.users`, chứa `store_id` và `role`.
*   `user_sessions` - Quản lý phiên đa thiết bị cho người dùng.
*   `password_reset_tokens` - Hệ thống OTP và khôi phục mật khẩu.
*   `auth_audit_log` - Ghi nhật ký kiểm toán cho bảo mật.

#### Business Tables with `store_id` (Các bảng nghiệp vụ với `store_id`)
Tất cả các bảng nghiệp vụ chính đều bao gồm cột `store_id` để đảm bảo cách ly dữ liệu:
*   `products`, `companies`, `customers`
*   `transactions`, `transaction_items`
*   `purchase_orders`, `purchase_order_items`
*   `product_batches`, `seasonal_prices`
*   `banned_substances`

### Row Level Security (RLS) Policies (Chính sách bảo mật cấp hàng)
RLS là cơ chế cốt lõi để thực thi cách ly dữ liệu ở cấp độ cơ sở dữ liệu. Các chính sách RLS được áp dụng trên *tất cả* các bảng nghiệp vụ và xác thực liên quan, sử dụng hàm `get_user_store_id()` để xác định `store_id` của người dùng hiện tại.

```sql
-- Ví dụ chính sách cho bảng products
CREATE POLICY "Multi-tenant isolation" ON products
    FOR ALL USING (store_id = get_user_store_id());

-- Chính sách tương tự được áp dụng cho tất cả các bảng nghiệp vụ khác
-- và các bảng auth như user_profiles, user_sessions, auth_audit_log.
```
Chính sách `FOR ALL USING (store_id = get_user_store_id())` đảm bảo rằng người dùng chỉ có thể `SELECT`, `INSERT`, `UPDATE`, `DELETE` các bản ghi mà `store_id` của chúng khớp với `store_id` của người dùng đã xác thực.

## Application-Level Integration (Tích hợp cấp ứng dụng)

### 1. `BaseService` - Nền tảng cho hoạt động đa người thuê
`BaseService` là một lớp trừu tượng mà tất cả các dịch vụ nghiệp vụ (ví dụ: `ProductService`, `CustomerService`) đều kế thừa. Nó cung cấp các tiện ích cốt lõi để xử lý ngữ cảnh `store_id`:

*   **`currentStoreId`**: Getter này truy xuất `store_id` của người dùng hiện tại từ một biến tĩnh `_currentUserStoreId`.
*   **`ensureAuthenticated()`**: Đảm bảo người dùng đã xác thực và có `store_id` hợp lệ trước khi thực hiện thao tác.
*   **`addStoreFilter(query)`**: Tự động thêm điều kiện `eq('store_id', currentStoreId!)` vào các truy vấn Supabase `SELECT`. Điều này củng cố RLS bằng cách lọc dữ liệu ở cấp ứng dụng.
*   **`addStoreId(data)`**: Tự động thêm `store_id` của người dùng hiện tại vào dữ liệu khi `INSERT` hoặc `UPDATE`, đảm bảo bản ghi mới luôn được gán đúng cửa hàng.

### 2. `AuthProvider` - Quản lý ngữ cảnh xác thực và `store_id`
`AuthProvider` là trung tâm quản lý trạng thái xác thực và thiết lập ngữ cảnh đa người thuê:

*   **Thiết lập `store_id`**: Sau khi người dùng đăng nhập hoặc đăng ký thành công, `AuthProvider` sẽ:
    1.  Tìm nạp `UserProfile` của người dùng (chứa `store_id`).
    2.  Tìm nạp thông tin `Store` chi tiết dựa trên `profile.storeId`.
    3.  **Gọi `BaseService.setCurrentUserStoreId(profile.storeId)`**: Đây là bước quan trọng nhất, thiết lập `store_id` của người dùng hiện tại vào `BaseService`, làm cho nó có sẵn cho tất cả các dịch vụ khác.
    4.  Cập nhật trạng thái ứng dụng (`AuthState`) với `UserProfile` và `Store` đã tìm nạp.
*   **Đồng bộ trạng thái xác thực**: `AuthProvider` lắng nghe các thay đổi trạng thái xác thực của Supabase (`onAuthStateChange`) để đảm bảo ngữ cảnh `store_id` luôn được cập nhật.

### 3. Models - Nhận biết `store_id`
Tất cả các model nghiệp vụ cốt lõi (ví dụ: `Product`, `Customer`, `Transaction`, `PurchaseOrder`, `Company`, `ProductBatch`, `SeasonalPrice`, `TransactionItem`, `PurchaseOrderItem`) đều đã được cập nhật để bao gồm trường `final String storeId;`. Điều này cho phép dữ liệu được truyền qua các lớp ứng dụng với ngữ cảnh đa người thuê được bảo toàn.

### 4. Services - Thực thi đa người thuê
Các dịch vụ nghiệp vụ (ví dụ: `ProductService`, `CustomerService`, `TransactionService`, `PurchaseOrderService`, `CompanyService`) kế thừa `BaseService` và sử dụng các phương thức trợ giúp của nó. Điều này đảm bảo rằng mọi thao tác dữ liệu (đọc, ghi, cập nhật, xóa) đều được thực hiện trong phạm vi `store_id` của người dùng đã xác thực.

## Workflow (Luồng hoạt động)

1.  **Đăng ký (Sign-up):**
    *   Người dùng cung cấp thông tin để tạo tài khoản, đồng thời tạo một cửa hàng mới.
    *   `AuthService` tạo tài khoản Supabase, chèn một bản ghi mới vào bảng `stores` và `user_profiles` (liên kết người dùng với cửa hàng mới với vai trò `OWNER`).
    *   `AuthProvider` thiết lập `store_id` của cửa hàng mới vào `BaseService`.
2.  **Đăng nhập (Sign-in):**
    *   Người dùng đăng nhập bằng email/mật khẩu.
    *   `AuthService` xác thực người dùng với Supabase.
    *   `AuthProvider` tìm nạp `UserProfile` của người dùng (chứa `store_id`) và thông tin `Store` tương ứng.
    *   `AuthProvider` thiết lập `store_id` này vào `BaseService`.
3.  **Thao tác dữ liệu:**
    *   Khi người dùng thực hiện bất kỳ thao tác nào (ví dụ: xem danh sách sản phẩm, tạo khách hàng, nhận đơn nhập hàng), các Provider sẽ gọi các dịch vụ nghiệp vụ tương ứng.
    *   Các dịch vụ này, thông qua `BaseService`, sẽ tự động thêm bộ lọc `store_id` vào các truy vấn hoặc thêm `store_id` vào dữ liệu được chèn/cập nhật.
    *   Ở cấp độ cơ sở dữ liệu, RLS sẽ đảm bảo rằng chỉ dữ liệu thuộc về `store_id` của người dùng mới được truy cập hoặc sửa đổi.

## Security Features (Các tính năng bảo mật)

### 1. Row Level Security (RLS)
*   Tất cả các bảng nghiệp vụ và xác thực đều có RLS được bật.
*   Các chính sách RLS thực thi việc lọc theo `store_id`, đảm bảo không thể truy cập dữ liệu của các cửa hàng khác.

### 2. Role-Based Access Control (RBAC)
*   `user_profiles` chứa trường `role` (OWNER, MANAGER, CASHIER, INVENTORY_STAFF) và trường `permissions` (JSONB) cho phép kiểm soát truy cập chi tiết.
*   Các hàm trợ giúp SQL (`is_store_owner()`, `user_has_role()`, `can_manage_users()`) được sử dụng trong các chính sách RLS để thực thi quyền hạn.

### 3. Audit Logging (`auth_audit_log`)
*   Theo dõi các sự kiện nhạy cảm về bảo mật (đăng nhập, đăng xuất, thay đổi mật khẩu, v.v.) để giám sát và tuân thủ.

## Migration Guide (Hướng dẫn di chuyển)

### Running Migrations (Chạy các bản di chuyển)
1.  `supabase/migrations/auth_multi_tenant_system.sql` - Lược đồ xác thực và đa người thuê cốt lõi.
2.  Các bản di chuyển khác (ví dụ: `database_purchase_orders_migration.sql`) đã được cập nhật để bao gồm `store_id`.

### Database Helper Functions (Các hàm trợ giúp cơ sở dữ liệu)
```sql
-- Hàm trợ giúp cho các chính sách RLS
CREATE OR REPLACE FUNCTION get_user_store_id()
RETURNS UUID AS $$
BEGIN
    RETURN (
        SELECT store_id
        FROM user_profiles
        WHERE id = auth.uid()
        AND is_active = true
        LIMIT 1
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Các hàm kiểm tra vai trò khác (is_store_owner, user_has_role, can_manage_users)
-- cũng được định nghĩa để sử dụng trong các chính sách RLS và logic ứng dụng.
```

## Testing Multi-Tenant Isolation (Kiểm thử cách ly đa người thuê)

1.  **Tạo nhiều cửa hàng:** Đăng ký người dùng mới để tạo các cửa hàng khác nhau (ví dụ: `owner-a@example.com` cho Store A, `owner-b@example.com` cho Store B).
2.  **Xác minh cách ly dữ liệu:**
    *   Đăng nhập với tư cách chủ sở hữu Store A → chỉ thấy dữ liệu của Store A.
    *   Đăng nhập với tư cách chủ sở hữu Store B → chỉ thấy dữ liệu của Store B.
    *   Nhân viên chỉ thấy dữ liệu của cửa hàng được gán cho họ.
3.  **Kiểm thử quyền hạn của nhân viên:** Mời nhân viên vào một cửa hàng và kiểm tra xem các quyền hạn được gán có được thực thi đúng cách hay không.

## Best Practices (Các thực hành tốt nhất)

### 1. Luôn sử dụng `BaseService`
```dart
// Tốt ✅ - Đảm bảo lọc theo store_id
class ProductService extends BaseService {
  Future<List<Product>> getProducts() async {
    final response = await addStoreFilter(supabase.from('products').select('*'));
    return (response as List).map((json) => Product.fromJson(json)).toList();
  }
}

// Xấu ❌ - Không có lọc theo store_id, có thể bị RLS chặn hoặc trả về lỗi
// _supabase.from('products').select('*')
```

### 2. Xử lý thay đổi trạng thái xác thực
```dart
// Lắng nghe các thay đổi xác thực và cập nhật UI/ngữ cảnh store_id
Supabase.instance.client.auth.onAuthStateChange.listen((data) {
  final user = data.session?.user;
  if (user != null) {
    // AuthProvider sẽ xử lý việc tìm nạp UserProfile, Store và thiết lập BaseService.setCurrentUserStoreId
  } else {
    // Người dùng đã đăng xuất - điều hướng đến màn hình đăng nhập
    // Navigator.pushReplacementNamed(context, '/login');
  }
});
```

### 3. Xác thực quyền hạn
```dart
// Kiểm tra quyền hạn trước các thao tác nhạy cảm
if (currentUser?.canManageUsers == true) { // Ví dụ kiểm tra quyền quản lý người dùng
  // Thực hiện thao tác
} else {
  throw Exception('Không đủ quyền hạn');
}
```