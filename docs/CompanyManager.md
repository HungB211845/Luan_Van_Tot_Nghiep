
# SPECS: Module Quản Lý Nhà Cung Cấp (Company Management)

> **Template Version**: 1.0  
> **Last Updated**: January 2025  
> **Implementation Status**: 75% Complete  
> **Multi-Tenant Ready**: ✅  
> **Responsive Design**: 🔶

## 1. Tổng Quan

### a. Business Purpose
Module Quản lý Nhà Cung Cấp (Company Management) là một phần quan trọng của hệ thống AgriPOS, chịu trách nhiệm quản lý thông tin các nhà cung cấp và tích hợp với hệ thống Purchase Order để thực hiện việc nhập lô sỉ. Module này là nền tảng cho supplier relationship management và procurement workflow.

### b. Key Features
- **CRUD Operations**: Complete supplier management với validation
- **Purchase Order Integration**: Seamless PO workflow với automatic batch creation
- **Supplier Analytics**: Performance tracking và cost analysis  
- **Product Relationship**: 1-nhiều relationship với [Product Management](./Product_specs.md)
- **Search & Filtering**: Advanced supplier filtering cho các modules khác

### c. Architecture Compliance
- **3-Layer Pattern**: UI → Provider → Service với proper separation
- **Multi-Tenant**: Store isolation enforced via BaseService pattern
- **Responsive**: Planned ResponsiveScaffold integration

---

**Related Documentation**: 
- [Product Management Specs](./Product_specs.md) - Company-product relationships và supplier tracking
- [Purchase Order Workflow](./po_workflow.md) - Complete PO process với supplier integration
- [Architecture Overview](./architecture.md) - Multi-tenant patterns và BaseService usage

**Implementation Files**:
- Models: `lib/features/products/models/company.dart`
- Services: `lib/features/products/services/company_service.dart`  
- Providers: `lib/features/products/providers/company_provider.dart`
- Screens: `lib/features/products/screens/company/` (planned)

---

## 2. Implementation Status & Codebase Hiện Tại

### ✅ **ĐÃ CÓ SẴN (PRODUCTION READY):**

- ✅ `Company` model trong `lib/features/products/models/company.dart`  
- ✅ Database schema có bảng `companies` với đầy đủ fields và store isolation
- ✅ `CompanyService` trong `lib/features/products/services/company_service.dart` extends BaseService
- ✅ `CompanyProvider` trong `lib/features/products/providers/company_provider.dart` với state management
- ✅ Relationships đã setup sẵn trong database (1 company → nhiều products)
- ✅ Purchase Order integration với `create_batches_from_po` RPC function
- ✅ RLS policies và store-based filtering 


## 3. Luồng Kiến Trúc (3-Layer Architecture)

### a. Service Layer (`CompanyService`)
**File**: `lib/features/products/services/company_service.dart`

**Đặc điểm:**
- Extends `BaseService` để inherit store isolation (khác với code example cũ)
- Sử dụng `addStoreFilter()` cho tất cả queries để đảm bảo multi-tenant
- Duplicate name checking với store context và case-insensitive
- Product relationship validation trước khi delete

**Methods chính thực tế:**
```dart
Future<List<Company>> getCompanies() // với addStoreFilter
Future<Company> createCompany(Company company) // với duplicate check  
Future<Company> updateCompany(Company company) // với name normalization
Future<void> deleteCompany(String companyId) // với relationship check
Future<List<Product>> getCompanyProducts(String companyId) // trả Product objects
Future<bool> existsCompanyName(String name, {String? excludeId}) // cho validation
```

### b. Provider Layer (`CompanyProvider`) 
**File**: `lib/features/products/providers/company_provider.dart`

**State Management thực tế:**
```dart
enum CompanyStatus { idle, loading, success, error }

class CompanyProvider extends ChangeNotifier {
  List<Company> _companies = [];
  Company? _selectedCompany;
  List<Product> _companyProducts = []; // Chứa Product objects, không phải Map
  String _searchQuery = ''; // Search functionality
  
  // Filtered companies based on search query
  List<Company> get filteredCompanies {
    // Search logic với name, phone, contactPerson
    // Alphabetical sorting
  }
  
  // Safe loading patterns để tránh setState during build
  Future<void> loadCompanies({bool forceReload = false}) // Anti-pattern prevention
}
```


### c. UI Layer (Screens) - CẦN IMPLEMENT
**Planned Locations**: `lib/features/products/screens/company/` 

Cần các screens:

**Company List Screen** (giống Product List):
- Danh sách nhà cung cấp với responsive design (`ResponsiveScaffold`)
- Search functionality sử dụng `filteredCompanies`  
- Add/Edit supplier form với validation
- Integration vào main navigation drawer

**Add/Edit Company Form**:
- Company information form với validation
- Store-aware duplicate checking
- Responsive form design theo pattern hiện có

**Company Detail Screen** với danh sách sản phẩm:
- Master-detail layout cho desktop/tablet
- Danh sách sản phẩm của company với deep linking
- Integration với product management

**Purchase Order Integration**:
- Chọn nhà cung cấp từ dropdown trong PO workflow
- "Shopping cart" để add sản phẩm vào PO
- Mỗi item có: product picker, quantity, unit price  
- Tính tổng tiền tự động
- Save thành draft hoặc send cho supplier

---

## 4. Purchase Order Workflow & Database Integration

### a. Models cần thêm (ĐÃ CÓ):
```dart
- PurchaseOrder (đơn nhập hàng) - ✅ Có
- PurchaseOrderItem (chi tiết sản phẩm trong đơn) - ✅ Có  
- PurchaseOrderService - ✅ Có
- PurchaseOrderProvider - ✅ Có
```

### b. Product Batch từ Purchase Order
**Khi PO được delivered, tự động tạo product batches:**

```dart
// RPC function: create_batches_from_po(po_id UUID) - ĐÃ CÓ
// Khi mark PO as "DELIVERED"
for (final item in purchaseOrder.items) {
  await createProductBatch(ProductBatch(
    productId: item.productId,
    batchNumber: 'PO-${purchaseOrder.poNumber}-${item.productId}',
    quantity: item.quantity,
    costPrice: item.unitPrice,
    receivedDate: DateTime.now(),
    supplierId: purchaseOrder.supplierId,
  ));
}
```

### c. Database Schema (ĐÃ IMPLEMENTED)

```sql
-- PURCHASE ORDERS TABLE - ĐÃ CÓ
CREATE TABLE purchase_orders (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  supplier_id UUID NOT NULL REFERENCES companies(id),
  po_number TEXT UNIQUE,
  status TEXT CHECK (status IN ('DRAFT', 'SENT', 'CONFIRMED', 'DELIVERED', 'CANCELLED')),
  -- ... other fields với triggers và constraints
);

-- RPC Functions - ĐÃ CÓ  
CREATE OR REPLACE FUNCTION create_batches_from_po(po_id UUID)
CREATE OR REPLACE FUNCTION generate_po_number()
CREATE OR REPLACE FUNCTION update_po_totals()

-- Views - ĐÃ CÓ
CREATE VIEW purchase_orders_with_details AS SELECT ...
CREATE VIEW pending_deliveries AS SELECT ...
```

---

## 5. UI Workflow cho Nhập Lô Sỉ

### Shopping Cart Style Interface:

```
┌─────────────────────────────────────┐
│ 🏢 Nhà cung cấp: [Dropdown]        │
├─────────────────────────────────────┤
│ 📦 Giỏ hàng nhập                   │
│                                     │
│ [+] Thêm sản phẩm                  │
│                                     │
│ 🌱 NPK 16-8-8                      │
│ SL: [100] kg × [50,000]đ = 5,000k   │
│ [🗑️]                               │
│                                     │
│ 🌾 Lúa OM18                        │ 
│ SL: [50] kg × [25,000]đ = 1,250k    │
│ [🗑️]                               │
│                                     │
├─────────────────────────────────────┤
│ 💰 Tổng cộng: 6,250,000đ           │
│ 📝 [Ghi chú...]                    │
│                                     │
│ [Lưu nháp] [Gửi đơn hàng]         │
└─────────────────────────────────────┘
```

### Workflow Steps:
- **Chọn Supplier** → Dropdown suppliers từ CompanyProvider
- **Add products to cart** → Giống shopping cart, có product picker
- **Set quantity & price** → Input fields cho từng item với validation
- **Review & Save** → Tổng tiền auto-calculate, notes, save as PO

---

## 6. Usage Patterns cho Other Modules

### a. Filter Companies trong UI (ĐANG ĐƯỢC DÙNG):
```dart
final companyProvider = context.watch<CompanyProvider>();
SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  child: Row(
    children: companyProvider.filteredCompanies.map((c) {
      final selected = selectedSupplierIds.contains(c.id);
      return Padding(
        padding: const EdgeInsets.only(right: 8.0),
        child: FilterChip(
          label: Text(c.name),
          selected: selected,
          onSelected: (val) {
            // toggle supplier filter
          },
        ),
      );
    }).toList(),
  ),
);
```

### b. Company Selection trong Forms:
```dart
DropdownButtonFormField<String>(
  value: selectedCompanyId,
  items: context.watch<CompanyProvider>().companies.map((c) =>
    DropdownMenuItem(value: c.id, child: Text(c.name))
  ).toList(),
  onChanged: (companyId) => setState(() => selectedCompanyId = companyId),
);
```

--- 

## 7. Quy Tắc Nghiệp Vụ Cốt Lõi

### 1. CRUD cơ bản phải đảm bảo tính toàn vẹn dữ liệu
- **Quy tắc:** Mọi thao tác tạo (create), đọc (read), cập nhật (update), xóa (delete) nhà cung cấp phải được thực hiện thông qua `CompanyService`, đảm bảo chỉ có một cổng giao tiếp với Supabase. Khi xóa, phải kiểm tra mối quan hệ 1-n với sản phẩm (nếu còn sản phẩm liên kết, không cho xóa).
- **Tại sao:** Đây là cách duy nhất để giữ tính nhất quán giữa client và database. `CompanyService` đóng vai trò "người gác cổng", tránh việc UI hoặc Provider tự ý can thiệp trực tiếp vào dữ liệu, gây lỗi đồng bộ. Kiểm tra mối quan hệ trước khi xóa giúp bảo vệ dữ liệu tham chiếu, tránh lỗi ngoại lệ khi sản phẩm mất nhà cung cấp.

### 2. Mối quan hệ 1-n với sản phẩm phải được duy trì chặt chẽ
- **Quy tắc:** Mỗi nhà cung cấp có thể liên kết với nhiều sản phẩm, nhưng mỗi sản phẩm chỉ thuộc về một nhà cung cấp (nullable). Khi tạo/sửa sản phẩm, phải yêu cầu chọn nhà cung cấp (trừ trường hợp di chuyển dần từ supplier_id = null).
- **Tại sao:** Mối quan hệ này là nền tảng của quản lý nhập lô sỉ và giá theo mùa. Nếu không duy trì chặt chẽ, hệ thống sẽ không thể truy ngược từ nhà cung cấp về sản phẩm hoặc ngược lại, dẫn đến lỗi logic trong `getCompanyProducts` và tính năng PO (Purchase Order). Nullable ban đầu hỗ trợ di chuyển dần, nhưng về lâu dài cần ép buộc để đảm bảo dữ liệu sạch.

### 3. Quản lý giỏ hàng nhập kho phải có logic xác nhận nguyên tử
- **Quy tắc:** Khi thêm sản phẩm vào giỏ hàng nhập kho (PO cart), phải ghi nhận thông tin nhà cung cấp, số lượng, và giá nhập ngay lập tức. Khi lưu PO (draft hoặc gửi), toàn bộ dữ liệu giỏ hàng phải được lưu nguyên vẹn vào database và tạo `ProductBatch` khi PO được đánh dấu "DELIVERED".
- **Tại sao:** Logic này đảm bảo dữ liệu nhập kho không bị mất mát giữa các bước (UI -> Provider -> Service). Việc tạo `ProductBatch` tự động khi PO delivered giữ cho tồn kho luôn nhất quán với thực tế, tránh trường hợp nhập kho thủ công gây sai lệch. Tầng Service phải xử lý nguyên tử để tránh lỗi bán lẻ giữa chừng.

### 4. Giá nhập từ nhà cung cấp phải được ghi nhận và liên kết với giá bán
- **Quy tắc:** Giá nhập (unit price) trong giỏ hàng PO phải được lưu trữ trong `PurchaseOrderItem` và sau đó truyền vào `ProductBatch.costPrice`. Giá này có thể được tham chiếu để tính toán giá bán theo mùa hoặc phân tích lợi nhuận.
- **Tại sao:** Ghi nhận giá nhập tại thời điểm nhập lô giúp hệ thống có lịch sử giá vốn chính xác, tránh phụ thuộc vào dữ liệu hiện tại có thể thay đổi. Điều này cũng hỗ trợ tầng Service tính toán hiệu quả kinh doanh (cost vs sale price) mà không cần query lại lịch sử phức tạp.

### 5. Xử lý nhập lô sỉ phải hỗ trợ tính tổng tiền và lưu nháp
- **Quy tắc:** Giỏ hàng nhập kho phải tự động tính tổng tiền dựa trên số lượng và giá nhập của từng item. Người dùng có thể lưu PO dưới dạng nháp để chỉnh sửa sau, và chỉ khi gửi mới đánh dấu trạng thái "Pending".
- **Tại sao:** Tính tổng tiền ở tầng Provider giúp giảm tải cho UI, đảm bảo UI chỉ cần hiển thị mà không xử lý logic. Lưu nháp ở Service cho phép linh hoạt trong quy trình nhập kho, phù hợp với thực tế kinh doanh (nhập lô lớn cần nhiều bước xác nhận).

### 6. Di chuyển dần dữ liệu hiện có phải được kiểm soát
- **Quy tắc:** Các sản phẩm hiện có với `supplier_id = null` phải được gán dần cho nhà cung cấp thông qua UI (ví dụ: form thêm sản phẩm mới). Quá trình này cần có cơ chế báo cáo tiến độ.
- **Tại sao:** Đây là cách để migrate dữ liệu cũ mà không gây gián đoạn. Kiểm soát ở tầng Provider và Service đảm bảo không có sản phẩm "mồ côi" sau khi hoàn tất, đồng thời cung cấp dữ liệu đầy đủ cho báo cáo nhà cung cấp.

### 7. Hỗ trợ phân tích hiệu suất nhà cung cấp
- **Quy tắc:** Dữ liệu từ PO và `ProductBatch` phải được dùng để tạo báo cáo về hiệu suất nhà cung cấp (ví dụ: tổng giá trị nhập, tỷ lệ giao hàng đúng hạn).
- **Tại sao:** Tầng Service cần chuẩn bị dữ liệu thô để Provider tổng hợp, giúp UI hiển thị báo cáo mà không cần query trực tiếp. Điều này tối ưu hóa hiệu năng và tuân thủ mô hình 3 lớp.

### 8. Store Isolation & Multi-Tenant Security (MỚI - QUAN TRỌNG)
- **Quy tắc:** Tất cả company operations phải tuân thủ store isolation rules. `CompanyService` extends `BaseService` và sử dụng `addStoreFilter()` cho mọi query, `addStoreId()` cho insert operations.
- **Tại sao:** Đây là requirement bắt buộc cho multi-tenant architecture. Store isolation đảm bảo dữ liệu companies của store này không bị leak sang store khác, đồng thời RLS policies ở database level đảm bảo security compliance.

### Áp dụng thực tế
- **UI:** Các màn hình như `CompanyListScreen`, `AddEditCompanyForm`, `CompanyDetailScreen` sẽ dựa vào `CompanyProvider` để hiển thị và thao tác. Ví dụ, `AddEditCompanyForm` sẽ dùng dropdown từ `companies` và giỏ hàng PO với tính tổng tự động.
- **Provider:** `CompanyProvider` sẽ quản lý state giỏ hàng PO và gọi `CompanyService.getCompanyProducts` để lấy danh sách sản phẩm liên kết.
- **Service:** `CompanyService` sẽ xử lý lưu PO, tạo `ProductBatch`, và kiểm tra mối quan hệ trước khi xóa.

---

## 8. Migration Strategy & Data Integrity

### Current State:
- Products table đã có `company_id` field (nullable)
- Existing products có thể có `company_id = null`  
- Gradual migration: assign suppliers cho products từ từ

### Benefits của approach này:
- Track cost từ supplier cho accurate profit analysis
- Better inventory management với supplier context
- Purchase order history và supplier performance tracking
- Enhanced business intelligence và supplier analytics

---

## 9. Navigation & Routes Integration

### Route Names cần thêm:
```dart
// lib/core/routing/route_names.dart
static const String companies = '/companies';
static const String companyDetail = '/companies/detail';  
static const String addCompany = '/companies/add';
static const String editCompany = '/companies/edit';
```

### Main Navigation Integration:
- Company management nằm trong main navigation drawer
- Deep linking từ product detail → company detail
- Integration với purchase order workflow

---

## 10. Performance & Best Practices

### Caching Strategy:
- Tải companies một lần và share qua Provider, hạn chế gọi lại nhiều lần
- Filtered results computed client-side để reduce API calls  
- Auto-refresh khi có CRUD operations

### RLS/Policy Notes:
- Bảng `companies` cần quyền SELECT cho vai trò app (authenticated) để UI có thể tải danh sách trong các filter
- Store isolation enforced ở cả application level (BaseService) và database level (RLS policies)

### Database Optimization:
- Indexed trên `store_id` và `name` cho fast filtering và search
- RLS policies optimized với proper indexing cho performance

---

**Implementation Status**: 70% Complete (Service/Provider ready, UI screens pending)  
**Multi-Tenant Ready**: ✅ Store isolation implemented với BaseService  
**Performance Optimized**: ✅ Efficient queries với proper indexing  
**Integration Ready**: ✅ PO workflow và product relationships fully functional  
**Business Rules**: ✅ Complete business logic documented và enforced
 