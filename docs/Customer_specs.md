# SPECS: Module Quản Lý Khách Hàng (Customer Management)

## 1. Tổng Quan

Module này cung cấp đầy đủ các chức năng CRUD (Tạo, Đọc, Cập nhật, Xóa) cho đối tượng Khách hàng. Nó cho phép người dùng quản lý một danh sách khách hàng thân thiết, tìm kiếm, sắp xếp, và xem chi tiết từng người. Module được xây dựng trên kiến trúc 3 lớp (UI -> Provider -> Service) và kết nối với backend Supabase.

---

## 2. Cấu Trúc Dữ Liệu (Data Structure)

### a. Bảng `customers` trên Supabase

Dựa trên model, bảng `customers` trong Supabase sẽ có các cột sau:

- `id`: `UUID` - Khóa chính, tự động tạo.
- `name`: `TEXT` - Tên khách hàng, không được null.
- `phone`: `TEXT` - Số điện thoại, có thể null.
- `address`: `TEXT` - Địa chỉ, có thể null.
- `email`: `TEXT` - Email, có thể null.
- `debt_limit`: `NUMERIC` - Hạn mức công nợ cho phép, mặc định là 0.
- `interest_rate`: `NUMERIC` - Lãi suất áp dụng khi quá hạn, mặc định là 0.
- `is_active`: `BOOLEAN` - Trạng thái hoạt động, dùng cho xóa mềm.
- `created_at`: `TIMESTAMP WITH TIME ZONE` - Ngày tạo.

### b. Model `Customer` trong Flutter (`lib/models/customer.dart`)

Đây là class Dart đại diện cho một khách hàng trong ứng dụng. Nó chứa các thuộc tính tương ứng với các cột trong database và có các hàm `fromJson` để phân tích dữ liệu từ Supabase và `toJson` để gửi dữ liệu lên.

---

## 3. Luồng Kiến Trúc (3-Layer Architecture)

### a. Tầng Service (`CustomerService.dart`)

- **Mục đích:** Là lớp duy nhất chịu trách nhiệm giao tiếp trực tiếp với bảng `customers` trên Supabase.
- **Các hàm chính:**
  - `getCustomers()`: Lấy toàn bộ danh sách khách hàng đang hoạt động.
  - `searchCustomers(String query)`: Tìm kiếm khách hàng theo tên, SĐT, hoặc địa chỉ.
  - `createCustomer(Customer customer)`: Gửi yêu cầu `INSERT` một khách hàng mới lên Supabase.
  - `updateCustomer(Customer customer)`: Gửi yêu cầu `UPDATE` thông tin một khách hàng.
  - `deleteCustomer(String customerId)`: Thực hiện xóa mềm bằng cách cập nhật `is_active = false`.

### b. Tầng Provider (`CustomerProvider.dart`)

- **Mục đích:** Quản lý state của module khách hàng, là "bộ nhớ tạm" và trung tâm điều hành cho UI.
- **State chính:**
  - `_customers`: `List<Customer>` - Danh sách khách hàng đang được hiển thị.
  - `_isLoading`: `bool` - Cờ báo hiệu đang tải dữ liệu.
  - `_errorMessage`: `String` - Lưu thông báo lỗi nếu có.
- **Các hàm chính:**
  - `loadCustomers()`: Gọi `CustomerService.getCustomers()` và cập nhật `_customers`, sau đó gọi `notifyListeners()`.
  - `addCustomer(Customer customer)`: Gọi `CustomerService.createCustomer()` và nếu thành công, thêm khách hàng mới vào `_customers` và thông báo cho UI.
  - `updateCustomer(Customer customer)`: Tương tự, gọi service và cập nhật lại danh sách.
  - `deleteCustomer(String customerId)`: Tương tự, gọi service và xóa khách hàng khỏi danh sách.

### c. Tầng UI (`screens/customers/`)

- **Mục đích:** Hiển thị dữ liệu khách hàng và nhận tương tác từ người dùng.
- **Các màn hình chính:**
  - `CustomerListScreen.dart`: Màn hình chính, hiển thị danh sách khách hàng. Nó dùng `Consumer<CustomerProvider>` để tự động cập nhật khi danh sách thay đổi. Nó chứa thanh tìm kiếm, menu sắp xếp và nút `+` để điều hướng đến màn hình `AddCustomerScreen`.
  - `AddCustomerScreen.dart`: Chứa một `Form` để người dùng nhập thông tin khách hàng mới. Nút "Lưu" sẽ gọi hàm `addCustomer` của `CustomerProvider`.
  - `CustomerDetailScreen.dart`: Hiển thị thông tin chi tiết của một khách hàng được chọn, có thể có các nút để điều hướng đến `EditCustomerScreen` hoặc xem lịch sử giao dịch.
  - `EditCustomerScreen.dart`: Tương tự `AddCustomerScreen` nhưng form được điền sẵn dữ liệu và nút "Lưu" sẽ gọi hàm `updateCustomer`.

---

## 4. Luồng Hoạt Động CRUD (CRUD Workflows)

**Ví dụ luồng "Thêm Khách Hàng Mới":**

1.  **UI (`CustomerListScreen`):** Người dùng nhấn vào `FloatingActionButton` có icon `+`.
2.  **Navigation:** `Navigator.push` được gọi để mở màn hình `AddCustomerScreen`.
3.  **UI (`AddCustomerScreen`):** Người dùng điền thông tin vào `Form` và nhấn nút "Lưu".
4.  **UI -> Provider:** `onPressed` của nút "Lưu" gọi `context.read<CustomerProvider>().addCustomer(newCustomerObject)`.
5.  **Provider -> Service:** `CustomerProvider` nhận lệnh, có thể set trạng thái `isLoading = true`, sau đó gọi `await _customerService.createCustomer(newCustomerObject)`.
6.  **Service -> Supabase:** `CustomerService` thực hiện lệnh `INSERT` vào bảng `customers`.
7.  **Hành trình trở về:** Supabase trả về dữ liệu khách hàng vừa tạo -> Service trả về cho Provider.
8.  **Provider -> UI:** `CustomerProvider` nhận được khách hàng mới, thêm vào danh sách `_customers`, set `isLoading = false`, và quan trọng nhất là gọi `notifyListeners()` để "phát loa" thông báo có dữ liệu mới.
9.  **UI (`AddCustomerScreen`):** Nhận được kết quả thành công, tự động `Navigator.pop()` để quay về.
10. **UI (`CustomerListScreen`):** Widget `Consumer` nghe được "loa" từ `Provider`, tự động build lại `ListView` và hiển thị thêm khách hàng mới trong danh sách.