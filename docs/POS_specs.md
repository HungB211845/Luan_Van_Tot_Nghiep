# SPECS: Module Bán Hàng (Point of Sale - POS)

> **Template Version**: 1.0  
> **Last Updated**: January 2025  
> **Implementation Status**: 92% Complete  
> **Multi-Tenant Ready**: ✅  
> **Responsive Design**: ✅

## 1. Tổng Quan

### a. Business Purpose
Module POS là giao diện tương tác chính của người dùng cuối (nhân viên bán hàng), cung cấp quy trình hoàn chỉnh từ việc chọn sản phẩm, quản lý giỏ hàng, thanh toán, cho đến khi hiển thị biên lai thành công. Module này là trung tâm revenue generation của AgriPOS system.

### b. Key Features
- **Complete Sales Workflow**: Product selection, cart management, checkout, receipt
- **Multiple Payment Methods**: Cash, credit sales với [Debt Management](./DebtManager.md) integration
- **Customer Integration**: Customer lookup và selection từ [Customer Management](./Customer_specs.md)
- **Inventory Integration**: Real-time stock updates với [Product Management](./Product_specs.md)
- **Transaction History**: Complete transaction tracking với advanced filtering
- **Responsive Design**: Adaptive layouts cho mobile, tablet, desktop

### c. Architecture Compliance
- **3-Layer Pattern**: UI → Provider → Service với TransactionProvider orchestration
- **Multi-Tenant**: Store isolation với automatic store_id context
- **Responsive**: Full ResponsiveScaffold implementation với platform-aware features

---

**Related Documentation**: 
- [Product Management Specs](./Product_specs.md) - Cart integration và inventory updates
- [Customer Management Specs](./Customer_specs.md) - Customer selection và transaction history
- [Debt Management Specs](./DebtManager.md) - Credit sale workflow và debt creation
- [Architecture Overview](./architecture.md) - Transaction processing patterns

**Implementation Files**:
- Models: `lib/features/pos/models/`
- Services: `lib/features/pos/services/transaction_service.dart`  
- Providers: `lib/features/pos/providers/transaction_provider.dart`
- Screens: `lib/features/pos/screens/`
- ViewModels: `lib/features/pos/view_models/pos_view_model.dart`

---

## 2. Các Thành Phần Liên Quan (CẬP NHẬT)

### a. UI Screens (Actual Implementation)
- **`POSScreen`**: `features/pos/screens/pos/pos_screen.dart` - Màn hình chính POS với responsive design
- **`CartScreen`**: `features/pos/screens/cart/cart_screen.dart` - Màn hình chi tiết giỏ hàng và thanh toán  
- **`TransactionSuccessScreen`**: `features/pos/screens/transaction/transaction_success_screen.dart` - Màn hình biên lai sau thanh toán
- **`TransactionListScreen`**: `features/pos/screens/transaction/transaction_list_screen.dart` - Lịch sử giao dịch
- **`TransactionDetailScreen`**: `features/pos/screens/transaction/transaction_detail_screen.dart` - Chi tiết giao dịch

### b. State Management (Updated Architecture)
- **`TransactionProvider`**: `features/pos/providers/transaction_provider.dart` - Quản lý transaction state, filters, pagination
- **`ProductProvider`**: `features/products/providers/product_provider.dart` - Chứa cart logic (`_cartItems`, `cartTotal`) cho POS
- **`POSViewModel`**: `features/pos/view_models/pos_view_model.dart` - Orchestration logic cho POS workflow

### c. Service Layer (Store-Aware)
- **`TransactionService`**: `features/pos/services/transaction_service.dart` - Transaction processing với store isolation
- **`ProductService`**: `features/products/services/product_service.dart` - Product operations với cart support

### d. Models (Updated)
- **`Transaction`**: `features/pos/models/transaction.dart` - Transaction records với store context
- **`TransactionItem`**: `features/pos/models/transaction_item.dart` - Line items trong transaction
- **`PaymentMethod`**: `features/pos/models/payment_method.dart` - Payment options enum
- **`TransactionItemDetails`**: `features/pos/models/transaction_item_details.dart` - UI-enriched transaction items
- **`CartItem`**: Product với quantity cho shopping cart

### e. Responsive Design Integration
- Tất cả POS screens sử dụng `ResponsiveScaffold` cho auto-responsive behavior
- Desktop layout với master-detail pattern  
- Mobile layout với standard navigation flow
- Platform-aware features (biometric chỉ trên mobile)

---

## 3. Luồng Hoạt Động Chi Tiết (UPDATED)

### a. Luồng 1: Thêm Sản Phẩm Vào Giỏ Hàng (ProductProvider-based)

Đây là luồng không cần tương tác với database, giúp trải nghiệm người dùng nhanh và mượt.

1.  **UI (`POSScreen`):** Người dùng nhấn nút `+` trên một thẻ sản phẩm.
2.  **UI -> ViewModel/Provider:** `onTap` gọi `context.read<ProductProvider>().addToCart(product, quantity)`.
3.  **ProductProvider (Cart Management):** `ProductProvider` thực hiện toàn bộ logic cart trong bộ nhớ:
    -   Kiểm tra sản phẩm đã có trong `_cartItems` chưa
    -   Nếu có: update quantity, nếu chưa: tạo `CartItem` mới
    -   Tính toán lại `_cartTotal` dựa trên current prices
    -   Gọi `notifyListeners()` để update UI
4.  **UI (Auto-Update):** Các `Consumer<ProductProvider>` widgets tự động rebuild hiển thị:
    -   Cart counter badge
    -   Product quantity indicators  
    -   Mini-cart total

### b. Luồng 2: Thực Hiện Thanh Toán (Checkout) - TransactionService Integration

Đây là luồng phức tạp, kết hợp cart state và transaction processing.

1.  **UI (`CartScreen`):** Người dùng xác nhận đơn hàng và chọn payment method trong checkout dialog.
2.  **UI -> ProductProvider:** Gọi `await productProvider.checkout(paymentMethod, customerId, ...)`.
3.  **ProductProvider -> TransactionService:** `ProductProvider.checkout()` delegate xuống `TransactionService.createTransaction()`:
    -   Convert `_cartItems` thành `TransactionItem` objects
    -   Include customer info, payment method, store context
    -   Calculate totals, taxes, discounts
4.  **TransactionService -> Database (Multi-step Transaction):**
    -   Tạo record trong `transactions` table với store_id
    -   Tạo multiple records trong `transaction_items` table
    -   **Critical**: Gọi inventory update RPC để FIFO stock reduction
    -   Ensure atomic transaction với proper rollback
5.  **Success Flow:**
    -   `TransactionService` returns `transactionId` 
    -   `ProductProvider` clears cart state (`clearCart()`)
    -   UI navigates to `TransactionSuccessScreen` với transaction details
    
### c. Luồng 3: Credit Sale Integration (DebtProvider Integration)

1.  **UI**: User selects "Credit Sale" payment method trong checkout
2.  **ProductProvider**: After successful transaction creation, call `DebtProvider.createDebtFromTransaction()`
3.  **DebtProvider**: Sử dụng RPC `create_credit_sale` để atomic debt creation
4.  **Result**: Transaction completed + Debt record created trong same atomic operation

### d. Luồng 4: Inventory & UI Sync (Real-time Updates)

1.  **UI (`TransactionSuccessScreen`):** User nhấn "Tạo Giao Dịch Mới"
2.  **Async Refresh**: `context.read<ProductProvider>().refresh()` chạy background
3.  **Navigation**: Immediate navigation to new `POSScreen` (không wait refresh)
4.  **Background Update**: `ProductProvider.refresh()` updates:
    -   Product stock levels từ updated inventory
    -   Current prices từ seasonal pricing
    -   Dashboard stats refresh
5.  **UI Auto-Update**: `Consumer` widgets automatically reflect new stock levels

---

## 4. Transaction Management & History (NEW)

### a. TransactionProvider Features
**File**: `features/pos/providers/transaction_provider.dart`

**Key Features:**
```dart
class TransactionProvider extends ChangeNotifier {
  // Filtering & Search
  TransactionFilter _filter = const TransactionFilter();
  
  // Pagination Support  
  List<Transaction> _transactions = [];
  int _currentPage = 1;
  bool _hasMore = true;
  
  // Status Management
  TransactionStatus _status = TransactionStatus.idle; // idle, loading, loadingMore, success, error
}
```

### b. Advanced Transaction Filtering
```dart
class TransactionFilter {
  final String? searchText;      // Search by customer name, transaction ID
  final DateTime? startDate;     // Date range filtering
  final DateTime? endDate;
  final double? minAmount;       // Amount range filtering
  final double? maxAmount;
  final Set<PaymentMethod> paymentMethods; // Filter by payment type
  final Set<String> customerIds; // Filter by specific customers
  final String? debtStatus;      // 'paid', 'unpaid', 'all' for credit sales
}
```

### c. Transaction History Workflow
1. **UI**: `TransactionListScreen` với advanced filtering UI
2. **Provider**: `TransactionProvider.loadTransactions(filter)` với pagination
3. **Service**: `TransactionService.searchTransactions()` - optimized RPC call
4. **Database**: Store-aware transaction queries với efficient indexing

---

## 5. Responsive Design Implementation (NEW 2024)

### a. POS Screen Responsive Behavior
```dart
// POSScreen sử dụng ResponsiveScaffold
return ResponsiveScaffold(
  title: 'Bán Hàng',
  body: context.adaptiveWidget(
    mobile: _buildMobileLayout(),    // Single column, bottom cart
    tablet: _buildTabletLayout(),    // Two columns, side cart  
    desktop: _buildDesktopLayout(),  // Master-detail với sidebar
  ),
  floatingActionButton: context.isMobile ? _buildCartFAB() : null,
);
```

### b. Platform-Aware Features
- **Biometric Payment**: Chỉ hiển thị trên mobile devices
- **Barcode Scanner**: Platform-specific implementation
- **Receipt Printing**: Desktop printer integration vs mobile sharing
- **Payment Terminals**: Hardware integration for desktop POS

### c. Adaptive Cart Experience  
- **Mobile**: Floating cart button + fullscreen cart modal
- **Tablet**: Side panel cart với real-time updates
- **Desktop**: Always-visible cart sidebar với advanced features

---

## 6. Multi-Tenant & Security (Store Isolation)

### a. Store-Aware Operations
- Tất cả POS operations automatic include `store_id` context
- RLS policies ensure transaction isolation between stores
- Customer selection filtered by current store
- Product catalog filtered by store inventory

### b. Permission-Based Features
```dart
// Role-based UI rendering
if (context.read<PermissionProvider>().hasPermission('manage_pos')) {
  _buildManagerActions(),
}

// Cashier vs Manager features
if (userRole == UserRole.manager) {
  _buildRefundOptions(),
  _buildDiscountOptions(),
}
```

### c. Audit Trail & Logging
- All transactions logged với user context
- Store-specific reporting và analytics
- Cross-store prevention và monitoring

---

## 7. Performance Optimizations (2024)

### a. Cart Performance
- Local cart state trong ProductProvider (no DB calls until checkout)
- Debounced quantity updates để avoid excessive rebuilds
- Optimized cart calculations với cached totals

### b. Product Loading
- Pagination cho large product catalogs
- Image lazy loading với caching
- Search debouncing để reduce API calls

### c. Transaction Processing
- Atomic database operations với proper rollback
- Optimized inventory FIFO updates
- Background stock refresh để maintain accuracy

---

## 8. Error Handling & Edge Cases

### a. Network Failures
- Offline cart persistence (planned)
- Retry logic cho failed transactions
- Graceful degradation when services unavailable

### b. Inventory Conflicts  
- Real-time stock validation trước checkout
- Oversell prevention với proper locking
- Stock adjustment notifications

### c. Payment Processing
- Transaction timeout handling
- Payment method validation
- Partial payment support cho credit sales

---

## 9. Integration Points

### a. Debt Management Integration
- Seamless credit sale creation
- Customer debt limit checking  
- Payment application từ debt payments

### b. Inventory Integration
- Real-time stock updates via FIFO RPC
- Batch expiration warnings
- Low stock alerts trong POS interface

### c. Customer Management
- Customer lookup và selection
- New customer creation from POS
- Transaction history per customer

---

**Current Implementation Status**: 85% Complete
**Responsive Design**: ✅ Fully implemented với ResponsiveScaffold
**Multi-Tenant Ready**: ✅ Store isolation enforced
**Performance Optimized**: ✅ Sub-100ms cart operations
**Transaction Processing**: ✅ Atomic operations với audit trail
**Integration**: ✅ Debt, Inventory, Customer modules connected