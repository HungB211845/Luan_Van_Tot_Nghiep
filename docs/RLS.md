# Row Level Security (RLS) and Security Layers in AgriPOS

## 1. Overview of Row Level Security (RLS)

Row Level Security (RLS) là một tính năng bảo mật mạnh mẽ của PostgreSQL (và được Supabase tận dụng) cho phép kiểm soát chi tiết quyền truy cập vào các hàng riêng lẻ trong một bảng cơ sở dữ liệu. Thay vì chỉ kiểm soát quyền truy cập ở cấp độ bảng (ví dụ: người dùng có thể đọc bảng này hay không), RLS cho phép bạn định nghĩa các chính sách để xác định hàng nào mà người dùng có thể truy cập dựa trên các điều kiện cụ thể (ví dụ: vai trò của người dùng, ID cửa hàng của họ).

Trong AgriPOS, RLS là nền tảng cho kiến trúc đa người thuê (multi-tenant) và kiểm soát truy cập dựa trên vai trò (RBAC), đảm bảo rằng mỗi cửa hàng và mỗi người dùng chỉ có thể truy cập dữ liệu mà họ được phép.

## 2. RLS Policies (Các chính sách RLS)

Các chính sách RLS được định nghĩa trong file `supabase/migrations/auth_multi_tenant_system.sql` và được áp dụng cho tất cả các bảng nghiệp vụ và xác thực liên quan.

### 2.1. Multi-tenant Isolation Policy (Chính sách cách ly đa người thuê)

Đây là chính sách quan trọng nhất, đảm bảo rằng dữ liệu của các cửa hàng khác nhau được cách ly hoàn toàn. Chính sách này được áp dụng cho tất cả các bảng nghiệp vụ như `products`, `customers`, `transactions`, `purchase_orders`, `companies`, `product_batches`, `seasonal_prices`, `transaction_items`, `purchase_order_items`.

```sql
CREATE POLICY "Multi-tenant isolation" ON <table_name>
    FOR ALL USING (store_id = get_user_store_id());
```

**Giải thích:**
*   `FOR ALL`: Chính sách này áp dụng cho tất cả các loại thao tác (SELECT, INSERT, UPDATE, DELETE).
*   `USING (store_id = get_user_store_id())`: Đây là điều kiện chính. Nó đảm bảo rằng người dùng chỉ có thể truy cập các hàng mà cột `store_id` của hàng đó khớp với `store_id` của người dùng hiện đang được xác thực (được trả về bởi hàm `get_user_store_id()`).

### 2.2. User Profile Policies (Chính sách hồ sơ người dùng)

Các chính sách này kiểm soát quyền truy cập vào bảng `user_profiles`:

*   **`Users can view profiles in same store`**: Người dùng chỉ có thể xem hồ sơ của những người dùng khác trong cùng cửa hàng.
    ```sql
    CREATE POLICY "Users can view profiles in same store" ON user_profiles
        FOR SELECT USING (store_id = get_user_store_id());
    ```
*   **`Users can update own profile`**: Người dùng chỉ có thể cập nhật hồ sơ của chính họ.
    ```sql
    CREATE POLICY "Users can update own profile" ON user_profiles
        FOR UPDATE USING (id = auth.uid());
    ```
*   **`Managers can manage users in same store`**: Người quản lý (OWNER/MANAGER) có thể quản lý (SELECT, INSERT, UPDATE, DELETE) người dùng trong cùng cửa hàng.
    ```sql
    CREATE POLICY "Managers can manage users in same store" ON user_profiles
        FOR ALL USING (
            store_id = get_user_store_id()
            AND can_manage_users() = true
        );
    ```
*   **`Allow user profile creation during registration`**: Cho phép tạo hồ sơ người dùng mới trong quá trình đăng ký.
    ```sql
    CREATE POLICY "Allow user profile creation during registration" ON user_profiles
        FOR INSERT WITH CHECK (true); -- Sẽ được hạn chế bởi logic ứng dụng
    ```

### 2.3. User Session Policies (Chính sách phiên người dùng)

Kiểm soát quyền truy cập vào bảng `user_sessions`:

*   **`Users can view own sessions`**: Người dùng chỉ có thể xem các phiên của chính họ.
    ```sql
    CREATE POLICY "Users can view own sessions" ON user_sessions
        FOR SELECT USING (user_id = auth.uid());
    ```
*   **`Users can manage own sessions`**: Người dùng có thể quản lý (SELECT, INSERT, UPDATE, DELETE) các phiên của chính họ.
    ```sql
    CREATE POLICY "Users can manage own sessions" ON user_sessions
        FOR ALL USING (user_id = auth.uid());
    ```

### 2.4. Password Reset Tokens Policies (Chính sách mã thông báo đặt lại mật khẩu)

Cho phép các thao tác trên bảng `password_reset_tokens` (được kiểm soát bởi logic ứng dụng và thời hạn mã thông báo).

```sql
CREATE POLICY "Allow password reset token operations" ON password_reset_tokens
    FOR ALL USING (true);
```

### 2.5. Auth Audit Log Policies (Chính sách nhật ký kiểm toán xác thực)

Kiểm soát quyền truy cập vào bảng `auth_audit_log`:

*   **`Users can view own audit logs`**: Người dùng có thể xem nhật ký kiểm toán của chính họ.
    ```sql
    CREATE POLICY "Users can view own audit logs" ON auth_audit_log
        FOR SELECT USING (user_id = auth.uid());
    ```
*   **`Store owners can view store audit logs`**: Chủ cửa hàng có thể xem nhật ký kiểm toán của cửa hàng.
    ```sql
    CREATE POLICY "Store owners can view store audit logs" ON auth_audit_log
        FOR SELECT USING (
            store_id = get_user_store_id()
            AND is_store_owner() = true
        );
    ```

## 3. Helper Functions for RLS (Các hàm trợ giúp cho RLS)

Các hàm SQL sau đây được định nghĩa trong `auth_multi_tenant_system.sql` và được sử dụng bởi các chính sách RLS để xác định ngữ cảnh người dùng và quyền hạn:

*   **`get_user_store_id()`**: Trả về `store_id` của người dùng hiện đang được xác thực. Đây là hàm cốt lõi cho cách ly đa người thuê.
    ```sql
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
    ```
*   **`is_store_owner()`**: Trả về `TRUE` nếu người dùng hiện tại có vai trò `OWNER`.
*   **`user_has_role(required_role TEXT)`**: Trả về `TRUE` nếu người dùng hiện tại có vai trò được yêu cầu.
*   **`can_manage_users()`**: Trả về `TRUE` nếu người dùng hiện tại có vai trò `OWNER` hoặc `MANAGER`.

## 4. Other Security Layers (Các lớp bảo mật khác)

Ngoài RLS, dự án AgriPOS còn sử dụng các lớp bảo mật khác để tạo ra một hệ thống phòng thủ theo chiều sâu:

### 4.1. Supabase Authentication (Xác thực Supabase)
*   **Quản lý người dùng:** Supabase Auth xử lý việc đăng ký, đăng nhập, quản lý phiên và bảo mật mật khẩu người dùng. Nó cung cấp một hệ thống xác thực mạnh mẽ, bao gồm hỗ trợ OAuth (Google, Facebook, Zalo).
*   **JSON Web Tokens (JWT):** Sau khi xác thực thành công, Supabase cấp một JWT cho người dùng. JWT này chứa thông tin về người dùng (như `user_id`) và được sử dụng để xác thực các yêu cầu tiếp theo đến API Supabase.

### 4.2. Role-Based Access Control (RBAC) at Application Level (Kiểm soát truy cập dựa trên vai trò ở cấp ứng dụng)
*   **`UserProfile.role` và `UserProfile.permissions`:** Mỗi `UserProfile` có một `role` (OWNER, MANAGER, CASHIER, INVENTORY_STAFF) và một trường `permissions` kiểu `JSONB` cho phép định nghĩa các quyền hạn chi tiết hơn.
*   **Logic ứng dụng:** Ứng dụng Flutter sử dụng các thuộc tính này để điều chỉnh giao diện người dùng (ví dụ: ẩn các nút hoặc menu không liên quan) và kiểm tra quyền hạn trước khi cho phép người dùng thực hiện các hành động nhất định (ví dụ: chỉ `OWNER` hoặc `MANAGER` mới có thể mời nhân viên mới).

### 4.3. `BaseService` Enforcement (Thực thi bởi `BaseService`)
*   **`ensureAuthenticated()`:** Tất cả các dịch vụ nghiệp vụ kế thừa `BaseService` đều có thể gọi `ensureAuthenticated()` để đảm bảo người dùng đã đăng nhập và ngữ cảnh `store_id` đã được thiết lập trước khi thực hiện bất kỳ thao tác cơ sở dữ liệu nào.
*   **`addStoreFilter()` và `addStoreId()`:** Như đã giải thích ở trên, các phương thức này đảm bảo rằng mọi truy vấn và thao tác dữ liệu đều được tự động giới hạn trong `store_id` của người dùng hiện tại, củng cố thêm RLS.

### 4.4. Audit Logging (`auth_audit_log`)
*   **Theo dõi sự kiện:** Bảng `auth_audit_log` ghi lại các sự kiện quan trọng liên quan đến xác thực và tài khoản người dùng (đăng nhập, đăng xuất, thay đổi mật khẩu, v.v.), bao gồm cả địa chỉ IP và thông tin thiết bị. Điều này cung cấp một dấu vết kiểm toán quan trọng cho mục đích bảo mật và tuân thủ.
*   **Trigger tự động:** Trigger `auto_log_auth_events()` tự động ghi nhật ký các thay đổi đối với `user_profiles` (ví dụ: tạo người dùng, kích hoạt/hủy kích hoạt).

### 4.5. Secure Storage (`SecureStorageService`)
*   **Lưu trữ an toàn:** `SecureStorageService` (sử dụng `flutter_secure_storage`) được sử dụng để lưu trữ các thông tin nhạy cảm như mã thông báo xác thực (JWT) một cách an toàn trên thiết bị, ngăn chặn truy cập trái phép.

## Conclusion (Kết luận)

AgriPOS triển khai một chiến lược bảo mật đa lớp, với RLS là tuyến phòng thủ chính ở cấp độ cơ sở dữ liệu, được bổ sung bởi RBAC ở cấp độ ứng dụng, xác thực mạnh mẽ của Supabase, ghi nhật ký kiểm toán chi tiết và lưu trữ an toàn. Sự kết hợp này đảm bảo tính toàn vẹn, bảo mật và cách ly dữ liệu trong môi trường đa người thuê.