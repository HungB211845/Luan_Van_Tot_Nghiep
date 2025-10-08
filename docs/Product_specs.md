# SPECS: Module Quản Lý Sản Phẩm (Product Management)

> **Template Version**: 1.0  
> **Last Updated**: January 2025  
> **Implementation Status**: 98% Complete  
> **Multi-Tenant Ready**: ✅  
> **Responsive Design**: ✅

## 1. Tổng Quan

### a. Business Purpose
Module Quản Lý Sản Phẩm là module phức tạp và quan trọng nhất của hệ thống AgriPOS, không chỉ quản lý thông tin cơ bản của sản phẩm mà còn xử lý các logic nghiệp vụ chuyên sâu như inventory management, supplier relationships, và pricing strategies.

### b. Key Features
- **Dynamic Product Attributes**: Specialized attributes cho từng loại sản phẩm (Phân bón, Thuốc BVTV, Lúa giống)
- **FIFO Inventory Management**: Batch tracking với hạn sử dụng và automatic stock rotation
- **Seasonal Pricing**: Flexible pricing theo mùa vụ với auto-sync capabilities
- **Supplier Integration**: Complete integration với [Company Management](./CompanyManager.md)
- **POS Integration**: Real-time stock updates với [POS System](./POS_specs.md)
- **Advanced Search**: Vietnamese full-text search với performance optimization

### c. Architecture Compliance
- **3-Layer Pattern**: UI → Provider → Service với comprehensive separation
- **Multi-Tenant**: Store isolation với BaseService pattern
- **Responsive**: Universal ResponsiveScaffold với top navigation design

---

**Related Documentation**: 
- [Company Management Specs](./CompanyManager.md) - Supplier relationships và purchase orders
- [POS System Specs](./POS_specs.md) - Cart integration và inventory updates
- [Architecture Overview](./architecture.md) - Performance optimization patterns

**Implementation Files**:
- Models: `lib/features/products/models/`
- Services: `lib/features/products/services/product_service.dart`  
- Providers: `lib/features/products/providers/product_provider.dart`
- Screens: `lib/features/products/screens/`

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

## 5. Responsive Design Implementation (NEW 2024)

### a. Universal ResponsiveScaffold Integration
Tất cả product screens đã được upgraded với responsive system:

```dart
// ProductListScreen pattern
return ResponsiveScaffold(
  title: 'Quản Lý Sản Phẩm',
  body: context.adaptiveWidget(
    mobile: _buildMobileLayout(),     // Single column list
    tablet: _buildTabletLayout(),     // Grid với larger cards  
    desktop: _buildDesktopLayout(),   // Master-detail với top navigation bar
  ),
  floatingActionButton: _buildAddProductFAB(),
  actions: _buildResponsiveActions(),
);
```

### b. Adaptive Grid System
- **Mobile**: 1 column product list với compact cards
- **Tablet**: 2 columns với enhanced product cards
- **Desktop**: 3 columns + master-detail navigation với top navigation bar (KHÔNG có sidebar)
- **Auto-spacing**: `context.cardSpacing` và `context.sectionPadding`

### c. Platform-Aware Features
```dart
// Desktop-only features
if (context.isDesktop) {
  _buildBulkEditToolbar(),
  _buildAdvancedFiltering(), 
  _buildTopNavigationBar(), // Top navigation bar, KHÔNG phải sidebar
}

// Mobile-specific optimizations  
if (context.isMobile) {
  _buildQuickAddFAB(),
  _buildSwipeActions(),
}
```

### d. Search Bar Adaptation
- **Mobile**: Search trong AppBar với voice input
- **Desktop**: Dedicated search bar trong content area với advanced filters
- **Tablet**: Hybrid approach với expandable search

---

## 6. Performance Optimization (NEW 2024)

### a. Pagination & Memory Management
**ProductProvider Integration:**
```dart
class ProductProvider extends ChangeNotifier with MemoryManagedProvider {
  // Pagination support
  PaginatedResult<Product>? _paginatedProducts;
  bool _isLoadingMore = false;
  PaginationParams _currentPaginationParams = const PaginationParams();
  
  // Memory management
  Map<String, int> _stockMap = {}; // productId -> stock cache
  Map<String, double> _currentPrices = {}; // productId -> price cache
}
```

### b. N+1 Query Elimination
**Optimized Database Views:**
- **`products_with_details`**: Pre-aggregated view với eliminated subqueries
- **JOINs thay vì subqueries**: Company info, stock, pricing trong single query
- **Pre-calculated fields**: `available_stock`, `current_price` computed at DB level

### c. Search Performance Optimization
```dart
// ProductService optimized search
Future<List<Product>> searchProductsForPOS(String query) async {
  // SKU exact match first (fastest)
  if (query.length >= 3) {
    final exactMatch = await scanProductBySKU(query.toUpperCase());
    if (exactMatch != null) return [exactMatch];
  }
  
  // Full-text search với Vietnamese config
  final response = await addStoreFilter(
    _supabase.from('products_with_details')
      .select('*')
      .textSearch('search_vector', query, config: 'vietnamese')
      .order('ts_rank(search_vector, plainto_tsquery(\'vietnamese\', \'$query\'))', ascending: false)
      .limit(10) // Optimized limit cho POS
  );
}
```

### d. Memory & Cache Strategy
- **LRU Cache**: Frequently accessed products cached với auto-eviction
- **Estimated Counts**: Fast pagination với `get_estimated_count()` RPC
- **Debounced Search**: Reduce API calls với user input debouncing
- **Image Lazy Loading**: Product images loaded on-demand

---

## 7. Company & Purchase Order Integration (NEW 2024)

### a. Company Relationship Management
**Database Schema:**
```sql
-- Products linked to companies (suppliers)
ALTER TABLE products ADD COLUMN company_id UUID REFERENCES companies(id);
CREATE INDEX idx_products_company_id ON products(company_id);

-- Company filtering queries
SELECT p.*, c.name as company_name 
FROM products_with_details p
LEFT JOIN companies c ON p.company_id = c.id
WHERE p.store_id = $store_id AND c.id = $company_id;
```

**ProductService Integration:**
```dart
// Company-aware product operations
Future<List<Product>> getProductsByCompany(String companyId) async {
  return addStoreFilter(
    _supabase.from('products_with_details')
      .select('*')
      .eq('company_id', companyId)
      .eq('is_active', true)
  ).order('name');
}
```

### b. Purchase Order Workflow Integration
**Automatic Batch Creation:**
```sql
-- RPC function: create_batches_from_po(po_id UUID)
-- Khi PO được marked as "DELIVERED"
FOR item_record IN SELECT * FROM purchase_order_items WHERE purchase_order_id = po_id LOOP
  INSERT INTO product_batches (
    product_id, batch_number, quantity, cost_price, received_date, supplier_batch_id
  ) VALUES (
    item_record.product_id,
    po_record.po_number || '-' || item_record.product_id,
    item_record.received_quantity, 
    item_record.unit_cost,
    po_record.delivery_date,
    po_record.po_number
  );
END LOOP;
```

**ProductProvider PO Integration:**
```dart
// Refresh inventory after PO delivery
Future<void> refreshAfterPODelivery(String poId) async {
  // Call RPC to create batches
  await _productService.createBatchesFromPO(poId);
  
  // Refresh product stock levels
  await loadProductsPaginated(forceReload: true);
  
  // Update dashboard stats
  await loadDashboardStats();
  
  notifyListeners();
}
```

### c. Supplier Performance Analytics
```dart
// CompanyService integration với ProductService
Future<Map<String, dynamic>> getSupplierPerformance(String companyId) async {
  return {
    'total_products': await getCompanyProductCount(companyId),
    'total_purchase_orders': await getPOCountBySupplier(companyId), 
    'average_delivery_time': await getAverageDeliveryTime(companyId),
    'total_purchase_value': await getTotalPurchaseValue(companyId),
  };
}
```

---

## 8. Implementation Status (UPDATED 2024)

### ✅ **PRODUCTION READY (95% Complete)**
- **CRUD Operations**: Complete product, batch, pricing management
- **Responsive Design**: Full ResponsiveScaffold integration với top navigation
- **Performance Optimization**: Pagination, memory management, N+1 elimination
- **Multi-Tenant Architecture**: Store isolation với BaseService pattern
- **Company Integration**: Supplier relationships và PO workflow
- **Search Optimization**: Vietnamese full-text search với fallback
- **Cache Management**: LRU cache với auto-eviction

### 🔶 **ENHANCEMENT OPPORTUNITIES**
- **Advanced Analytics**: Deeper supplier performance insights
- **Bulk Operations**: Mass product import/export capabilities
- **AI Features**: Smart categorization, demand forecasting
- **Mobile Optimization**: Barcode scanning, offline support