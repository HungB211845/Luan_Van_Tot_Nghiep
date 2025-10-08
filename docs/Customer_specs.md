# SPECS: Module Quản Lý Khách Hàng (Customer Management)

> **Template Version**: 1.0  
> **Last Updated**: January 2025  
> **Implementation Status**: 90% Complete  
> **Multi-Tenant Ready**: ✅  
> **Responsive Design**: ✅

## 1. Tổng Quan

### a. Business Purpose
Module Customer Management cung cấp đầy đủ chức năng quản lý khách hàng thân thiết cho AgriPOS system, hỗ trợ bán chịu, theo dõi công nợ và phân tích hành vi mua hàng. Module này là nền tảng cho debt management và customer analytics.

### b. Key Features
- **CRUD Operations**: Create, Read, Update, Delete customers với validation
- **Advanced Search**: Multi-field search với filtering và sorting
- **Debt Integration**: Seamless integration với [Debt Management](./DebtManager.md)
- **Transaction History**: Complete purchase history per customer
- **Customer Analytics**: Statistics và behavior analysis
- **Master-Detail Layout**: Responsive design với adaptive layouts

### c. Architecture Compliance
- **3-Layer Pattern**: UI → Provider → Service với proper separation
- **Multi-Tenant**: Store isolation enforced via BaseService
- **Responsive**: Universal design system với `ResponsiveScaffold`

---

## 2. Cấu Trúc Dữ Liệu & Models

### a. Database Schema
```sql
-- customers table với store isolation
CREATE TABLE customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id UUID NOT NULL REFERENCES stores(id),
  name TEXT NOT NULL,
  phone TEXT,
  address TEXT,
  email TEXT,
  debt_limit DECIMAL(15,2) DEFAULT 0,
  interest_rate DECIMAL(5,2) DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Performance indexes
CREATE INDEX idx_customers_store_id ON customers(store_id);
CREATE INDEX idx_customers_name ON customers(name);
CREATE INDEX idx_customers_phone ON customers(phone);
```

### b. Flutter Models
```dart
// lib/features/customers/models/customer.dart
class Customer {
  final String id;
  final String storeId; // Multi-tenant field
  final String name;
  final String? phone;
  final String? address;
  final String? email;
  final double debtLimit;
  final double interestRate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Required methods
  factory Customer.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
  Customer copyWith({...});
}
```

### c. Relationships
- **1-to-Many**: 1 Customer → nhiều Transactions ([POS Integration](./POS_specs.md))
- **1-to-Many**: 1 Customer → nhiều Debts ([Debt Management](./DebtManager.md))
- **Cross-Module**: Customer selection trong POS checkout workflow

---

## 3. Luồng Kiến Trúc (3-Layer Implementation)

### a. Service Layer
**File**: `lib/features/customers/services/customer_service.dart`

```dart
class CustomerService extends BaseService {
  // CRUD operations với store isolation
  Future<List<Customer>> getCustomers() async {
    final response = await addStoreFilter(
      _supabase.from('customers').select('*')
    ).order('name', ascending: true);
    
    return (response as List)
        .map((json) => Customer.fromJson(json))
        .toList();
  }
  
  Future<Customer> createCustomer(Customer customer) async {
    final data = addStoreId(customer.toJson());
    final response = await _supabase
        .from('customers')
        .insert(data)
        .select()
        .single();
    return Customer.fromJson(response);
  }
  
  Future<List<Customer>> searchCustomers(String query) async {
    final response = await addStoreFilter(
      _supabase.from('customers').select('*')
        .or('name.ilike.%$query%,phone.ilike.%$query%,address.ilike.%$query%')
    ).order('name', ascending: true);
    
    return (response as List)
        .map((json) => Customer.fromJson(json))
        .toList();
  }
  
  // Customer statistics integration
  Future<Map<String, dynamic>> getCustomerStatistics(String customerId) async {
    ensureAuthenticated();
    return await _supabase.rpc('get_customer_statistics', params: {
      'p_customer_id': customerId,
      'p_store_id': currentStoreId,
    });
  }
}
```

### b. Provider Layer  
**File**: `lib/features/customers/providers/customer_provider.dart`

```dart
enum CustomerStatus { idle, loading, success, error }

class CustomerProvider extends ChangeNotifier {
  final CustomerService _customerService = CustomerService();
  
  // State management
  List<Customer> _customers = [];
  List<Customer> _filteredCustomers = [];
  Customer? _selectedCustomer;
  CustomerStatus _status = CustomerStatus.idle;
  String _errorMessage = '';
  String _searchQuery = '';
  Map<String, dynamic>? _customerStatistics;
  bool _loadingStatistics = false;
  
  // Getters với proper encapsulation
  List<Customer> get customers => _filteredCustomers.isEmpty && _searchQuery.isEmpty
      ? _customers : _filteredCustomers;
  Customer? get selectedCustomer => _selectedCustomer;
  CustomerStatus get status => _status;
  String get errorMessage => _errorMessage;
  bool get isLoading => _status == CustomerStatus.loading;
  
  // Safe loading pattern - CRITICAL ANTI-PATTERN PREVENTION
  Future<void> loadCustomers() async {
    _status = CustomerStatus.loading;
    _errorMessage = '';
    // DO NOT notifyListeners() here to prevent setState during build
    
    try {
      _customers = await _customerService.getCustomers();
      _status = CustomerStatus.success;
      _clearError();
    } catch (e) {
      _status = CustomerStatus.error;
      _errorMessage = e.toString();
    } finally {
      notifyListeners(); // Only notify once at end
    }
  }
  
  Future<void> searchCustomers(String query) async {
    _searchQuery = query.trim();
    
    if (_searchQuery.isEmpty) {
      _filteredCustomers = [];
      notifyListeners();
      return;
    }
    
    _status = CustomerStatus.loading;
    // No notifyListeners() here
    
    try {
      _filteredCustomers = await _customerService.searchCustomers(_searchQuery);
      _status = CustomerStatus.success;
      _clearError();
    } catch (e) {
      _status = CustomerStatus.error;
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }
}
```

### c. UI Layer
**File**: `lib/features/customers/screens/customers/customer_list_screen.dart`

```dart
class CustomerListScreen extends StatefulWidget {
  final bool isSelectionMode;

  const CustomerListScreen({Key? key, this.isSelectionMode = false})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return context.adaptiveWidget( // Standard responsive pattern
      mobile: _buildMobileLayout(),
      tablet: isSelectionMode ? _buildMobileLayout() : _buildTabletLayout(),
      desktop: _buildDesktopLayout(),
    );
  }
  
  Widget _buildMobileLayout() {
    return ResponsiveScaffold( // Standard responsive wrapper
      title: 'Khách Hàng',
      body: Consumer<CustomerProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) return LoadingWidget();
          if (provider.hasError) return ErrorWidget(provider.errorMessage);
          return _buildCustomerList(provider.customers);
        },
      ),
      floatingActionButton: _buildAddCustomerFAB(),
    );
  }
}
```

---

## 4. Responsive Design Implementation

### a. Screen Adaptation
```dart
return context.adaptiveWidget(
  mobile: _buildMobileLayout(),     // Single column list với swipe actions
  tablet: _buildTabletLayout(),     // Two columns với enhanced cards  
  desktop: _buildDesktopLayout(),   // Master-detail với top navigation bar
);
```

### b. Platform-Aware Features
- **Mobile**: Touch optimizations, swipe-to-delete, pull-to-refresh
- **Desktop**: Keyboard shortcuts, bulk operations, advanced search filters
- **Universal**: Auto-spacing với `context.sectionPadding`, `context.cardSpacing`

### c. Master-Detail Pattern
- **Tablet/Desktop**: Customer list on left, details on right
- **Mobile**: Full-screen customer details với navigation

---

## 5. Business Rules & Validation

### a. Core Business Rules
1. **Unique Phone per Store**: Phone numbers must be unique within store context
2. **Name Required**: Customer name is mandatory field với minimum length validation
3. **Debt Limit Validation**: Non-negative debt limits với reasonable upper bounds
4. **Soft Delete**: Customers với active debts cannot be hard deleted

### b. Multi-Tenant Rules
- **Store Isolation**: All customer operations scoped to user's store automatically
- **Permission Checks**: Role-based access cho customer management features
- **Cross-Store Prevention**: No data leakage between different stores

---

## 6. Integration Points

### a. Module Dependencies
- **[Debt Management](./DebtManager.md)**: Customer selection cho credit sales, payment processing
- **[POS System](./POS_specs.md)**: Customer lookup durante checkout, transaction history
- **[Product Management](./Product_specs.md)**: Customer-specific pricing (planned feature)

### b. Cross-Module Operations
```dart
// POS Integration - Customer selection for credit sales
final selectedCustomer = await Navigator.push(context, 
  MaterialPageRoute(builder: (_) => CustomerListScreen(isSelectionMode: true))
);

// Debt Management Integration - Customer debt summary
final debtSummary = await context.read<DebtProvider>().loadCustomerDebts(customerId);

// Transaction History Integration  
final transactions = await context.read<TransactionProvider>()
    .loadTransactionsByCustomer(customerId);
```

---

## 7. Performance Considerations

### a. Database Optimization
- **Indexes**: Optimized for name, phone, store_id queries
- **Search Performance**: Multi-field search với proper ILIKE indexing
- **Statistics RPC**: Efficient customer analytics với single query

### b. Memory Management
- **Provider Memory**: Efficient list management với filtered results caching
- **Search Debouncing**: Reduced API calls với user input debouncing
- **Resource Cleanup**: Proper controller disposal trong StatefulWidgets

---

## 8. Implementation Status

### ✅ **COMPLETED (90%)**
- Complete CRUD operations với store isolation
- Advanced search và filtering capabilities
- Responsive design với master-detail layouts
- Customer statistics và analytics
- Integration với debt management system
- Multi-field validation và error handling

### 🔶 **IN PROGRESS (5%)**  
- Enhanced customer segmentation
- Advanced analytics dashboard

### ❌ **PLANNED (5%)**
- Customer loyalty programs
- Purchase behavior predictions
- Automated marketing campaigns

---

## 9. Usage Examples

### a. Basic CRUD Operations
```dart
// Create new customer
final newCustomer = Customer(
  name: 'Nguyễn Văn A',
  phone: '0123456789',
  address: 'Hà Nội',
  debtLimit: 1000000,
);
final success = await customerProvider.addCustomer(newCustomer);

// Search customers
await customerProvider.searchCustomers('Nguyễn');
final results = customerProvider.customers;

// Load customer statistics
await customerProvider.loadCustomerStatistics(customerId);
final stats = customerProvider.customerStatistics;
```

### b. Integration Examples
```dart
// POS Integration - Select customer for checkout
class POSCheckoutDialog extends StatefulWidget {
  Widget _buildCustomerSelector() {
    return ListTile(
      title: Text(selectedCustomer?.name ?? 'Chọn khách hàng'),
      onTap: () async {
        final customer = await Navigator.push(context,
          MaterialPageRoute(builder: (_) => 
            CustomerListScreen(isSelectionMode: true))
        );
        if (customer != null) {
          setState(() => selectedCustomer = customer);
        }
      },
    );
  }
}

// Debt Management Integration - Customer debt overview
class CustomerDetailScreen extends StatelessWidget {
  Widget _buildDebtSummary(String customerId) {
    return Consumer<DebtProvider>(
      builder: (context, debtProvider, child) {
        return FutureBuilder(
          future: debtProvider.loadCustomerDebts(customerId),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return DebtSummaryCard(debts: snapshot.data);
            }
            return LoadingWidget();
          },
        );
      },
    );
  }
}
```

---

## 10. Testing & Quality Assurance

### a. Test Coverage
- **Unit Tests**: CustomerService business logic và validation rules
- **Widget Tests**: Customer list, search functionality, form validation  
- **Integration Tests**: POS checkout workflow, debt management integration

### b. Quality Metrics
- **Performance**: <100ms response time cho customer operations
- **Memory**: Efficient list rendering với virtualization
- **Security**: Store isolation verification với cross-tenant access prevention

---

**Related Documentation**: 
- [Debt Management Specs](./DebtManager.md) - Customer debt tracking và payment processing
- [POS System Specs](./POS_specs.md) - Customer selection trong checkout workflow
- [Architecture Overview](./architecture.md) - System-wide architecture patterns

**Implementation Files**:
- Models: `lib/features/customers/models/customer.dart`
- Services: `lib/features/customers/services/customer_service.dart`  
- Providers: `lib/features/customers/providers/customer_provider.dart`
- Screens: `lib/features/customers/screens/customers/`
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