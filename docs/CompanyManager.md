
Mục tiêu:

- **Quản lý nhà cung cấp** CRUD cơ bản
- **Relationship:** 1 nhà cung cấp → nhiều sản phẩm, 1 sản phẩm → 1 nhà cung cấp
- **Nhập lô sỉ:** Chọn nhà cung cấp → Add nhiều sản phẩm vào "giỏ hàng nhập kho"
- **Liên kết:** Với product management để chỉnh giá theo mùa/lô

**ĐÃ CÓ SẴN:**

✅ `Company` model trong `/features/products/models/company.dart`  
✅ Database schema có bảng `companies` với đầy đủ fields  
✅ ProductService đã query `company_id` và `company_name`  
✅ Relationships đã setup sẵn trong database (1 company → nhiều products) 


/lib/features/products/services/company_service.dart

`
```

// lib/features/products/services/company_service.dart

  

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/company.dart';

  

class CompanyService {

final SupabaseClient _supabase = Supabase.instance.client;

  

// Lấy tất cả companies

Future<List<Company>> getCompanies() async {

try {

final response = await _supabase

.from('companies')

.select('*')

.order('name', ascending: true);

return (response as List)

.map((json) => Company.fromJson(json))

.toList();

} catch (e) {

throw Exception('Lỗi lấy danh sách nhà cung cấp: $e');

}

}

  

// Tạo company mới

Future<Company> createCompany(Company company) async {

try {

final response = await _supabase

.from('companies')

.insert(company.toJson())

.select()

.single();

return Company.fromJson(response);

} catch (e) {

throw Exception('Lỗi tạo nhà cung cấp: $e');

}

}

  

// Cập nhật company

Future<Company> updateCompany(Company company) async {

try {

final response = await _supabase

.from('companies')

.update(company.toJson())

.eq('id', company.id)

.select()

.single();

return Company.fromJson(response);

} catch (e) {

throw Exception('Lỗi cập nhật nhà cung cấp: $e');

}

}

  

// Xóa company (soft delete nếu có products)

Future<void> deleteCompany(String companyId) async {

try {

// Check xem có products nào đang dùng company này không

final products = await _supabase

.from('products')

.select('id')

.eq('company_id', companyId)

.eq('is_active', true);

  

if (products.isNotEmpty) {

throw Exception('Không thể xóa nhà cung cấp vì còn ${products.length} sản phẩm đang sử dụng');

}

  

await _supabase

.from('companies')

.delete()

.eq('id', companyId);

} catch (e) {

throw Exception('Lỗi xóa nhà cung cấp: $e');

}

}

  

// Lấy sản phẩm của một company

Future<List<Map<String, dynamic>>> getCompanyProducts(String companyId) async {

try {

final response = await _supabase

.from('products_with_details')

.select('*')

.eq('company_id', companyId)

.eq('is_active', true)

.order('name', ascending: true);

return List<Map<String, dynamic>>.from(response);

} catch (e) {

throw Exception('Lỗi lấy sản phẩm của nhà cung cấp: $e');

}

}

}

```


/lib/features/products/providers/company_provider.dart

```
// lib/features/products/providers/company_provider.dart

  

import 'package:flutter/foundation.dart';

import '../models/company.dart';

import '../services/company_service.dart';

  

enum CompanyStatus { idle, loading, success, error }

  

class CompanyProvider extends ChangeNotifier {

final CompanyService _companyService = CompanyService();

List<Company> _companies = [];

Company? _selectedCompany;

CompanyStatus _status = CompanyStatus.idle;

String _errorMessage = '';

  

// Getters

List<Company> get companies => _companies;

Company? get selectedCompany => _selectedCompany;

CompanyStatus get status => _status;

String get errorMessage => _errorMessage;

bool get isLoading => _status == CompanyStatus.loading;

  

// Load tất cả companies

Future<void> loadCompanies() async {

_status = CompanyStatus.loading;

notifyListeners();

  

try {

_companies = await _companyService.getCompanies();

_status = CompanyStatus.success;

_errorMessage = '';

} catch (e) {

_status = CompanyStatus.error;

_errorMessage = e.toString();

}

notifyListeners();

}

  

// Thêm company mới

Future<bool> addCompany(Company company) async {

try {

final newCompany = await _companyService.createCompany(company);

_companies.add(newCompany);

notifyListeners();

return true;

} catch (e) {

_errorMessage = e.toString();

notifyListeners();

return false;

}

}

  

// Cập nhật company

Future<bool> updateCompany(Company company) async {

try {

final updatedCompany = await _companyService.updateCompany(company);

final index = _companies.indexWhere((c) => c.id == company.id);

if (index != -1) {

_companies[index] = updatedCompany;

notifyListeners();

}

return true;

} catch (e) {

_errorMessage = e.toString();

notifyListeners();

return false;

}

}

  

// Xóa company

Future<bool> deleteCompany(String companyId) async {

try {

await _companyService.deleteCompany(companyId);

_companies.removeWhere((c) => c.id == companyId);

notifyListeners();

return true;

} catch (e) {

_errorMessage = e.toString();

notifyListeners();

return false;

}

}

  

// Select company

void selectCompany(Company? company) {

_selectedCompany = company;

notifyListeners();

}

  

// Clear error

void clearError() {

_errorMessage = '';

notifyListeners();

}

}
```


Cần các screens:

**Company List Screen** (giống Product List)

- Danh sách nhà cung cấp (giống như product list)
- Add/Edit supplier form
- Supplier detail với danh sách sản phẩm của họ

**Add/Edit Company Form**

- Chọn nhà cung cấp từ dropdown
- "Shopping cart" để add sản phẩm vào PO
- Mỗi item có: product picker, quantity, unit price
- Tính tổng tiền tự động
- Save thành draft hoặc send cho supplier


**Company Detail Screen** với danh sách sản phẩm

- Thêm supplier dropdown vào form thêm sản phẩm
- Required field khi tạo sản phẩm mới


Cần thêm models và logic cho Purchase Orders: 

```// Các models cần thêm:
- PurchaseOrder (đơn nhập hàng)
- PurchaseOrderItem (chi tiết sản phẩm trong đơn)
- PurchaseOrderService
- PurchaseOrderProvider
```

**Product Batch từ Purchase Order** Khi PO được delivered, tự động tạo product batches: 

```// Khi mark PO as "DELIVERED"
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

- Seasonal prices có thể reference đến supplier pricing
- Cost analysis: so sánh giá nhập vs giá bán 

# UI WORKFLOW CHO NHẬP LÔ SỈ 

- **Chọn Supplier** → Dropdown suppliers
- **Add products to cart** → Giống shopping cart, có product picker
- **Set quantity & price** → Input fields cho từng item
- **Review & Save** → Tổng tiền, notes, save as PO 

# **Shopping Cart Style Interface:


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


- Products table chỉ thêm supplier_id (nullable)
- Existing products có thể để supplier_id = null
- Gradual migration: assign suppliers cho products từ từ 
-  Track cost từ supplier
- Better inventory management
- Purchase order history
- Supplier performance analysis


# Quy tắc nghiệp vụ 

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

### Áp dụng thực tế
- **UI:** Các màn hình như `CompanyListScreen`, `AddEditCompanyForm`, `CompanyDetailScreen` sẽ dựa vào `CompanyProvider` để hiển thị và thao tác. Ví dụ, `AddEditCompanyForm` sẽ dùng dropdown từ `companies` và giỏ hàng PO với tính tổng tự động.
- **Provider:** `CompanyProvider` sẽ quản lý state giỏ hàng PO và gọi `CompanyService.getCompanyProducts` để lấy danh sách sản phẩm liên kết.
- **Service:** `CompanyService` sẽ xử lý lưu PO, tạo `ProductBatch`, và kiểm tra mối quan hệ trước khi xóa.

Các quy tắc này đảm bảo chức năng quản lý nhà cung cấp hoạt động liền mạch, dữ liệu nhất quán, và mở rộng được trong tương lai. 


Đã có database

```
-- =============================================================================

-- MIGRATION: ADD PURCHASE ORDER TABLES CHO NHẬP LÔ SỈ

-- =============================================================================

-- File này để mày copy vào Supabase SQL Editor

  

-- =====================================================

-- 1. PURCHASE ORDERS TABLE - ĐƠN NHẬP HÀNG

-- =====================================================

CREATE TABLE purchase_orders (

id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

supplier_id UUID NOT NULL REFERENCES companies(id), -- Dùng companies table

po_number TEXT UNIQUE, -- Số PO tự generate

order_date DATE DEFAULT CURRENT_DATE,

expected_delivery_date DATE,

delivery_date DATE, -- Ngày nhận hàng thực tế

status TEXT CHECK (status IN ('DRAFT', 'SENT', 'CONFIRMED', 'DELIVERED', 'CANCELLED')) DEFAULT 'DRAFT',

subtotal DECIMAL(15,2) DEFAULT 0,

tax_amount DECIMAL(15,2) DEFAULT 0,

total_amount DECIMAL(15,2) DEFAULT 0,

discount_amount DECIMAL(15,2) DEFAULT 0,

payment_terms TEXT, -- Net 30, Cash, etc.

notes TEXT,

created_by TEXT, -- User ID hoặc username

created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

-- Business constraints

CHECK (total_amount >= 0),

CHECK (subtotal >= 0),

CHECK (expected_delivery_date >= order_date OR expected_delivery_date IS NULL)

);

  

-- Indexes cho performance

CREATE INDEX idx_purchase_orders_supplier ON purchase_orders (supplier_id);

CREATE INDEX idx_purchase_orders_status ON purchase_orders (status);

CREATE INDEX idx_purchase_orders_date ON purchase_orders (order_date DESC);

CREATE INDEX idx_purchase_orders_po_number ON purchase_orders (po_number);

  

-- =====================================================

-- 2. PURCHASE ORDER ITEMS TABLE - CHI TIẾT SẢN PHẨM

-- =====================================================

CREATE TABLE purchase_order_items (

id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

purchase_order_id UUID NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,

product_id UUID NOT NULL REFERENCES products(id),

quantity INTEGER NOT NULL CHECK (quantity > 0),

unit_cost DECIMAL(10,2) NOT NULL CHECK (unit_cost >= 0),

total_cost DECIMAL(12,2) GENERATED ALWAYS AS (quantity * unit_cost) STORED,

received_quantity INTEGER DEFAULT 0 CHECK (received_quantity >= 0),

notes TEXT,

created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

-- Business constraint: không nhận quá số đặt

CHECK (received_quantity <= quantity)

);

  

-- Indexes cho queries

CREATE INDEX idx_po_items_po ON purchase_order_items (purchase_order_id);

CREATE INDEX idx_po_items_product ON purchase_order_items (product_id);

  

-- =====================================================

-- 3. AUTO-UPDATE PO TOTALS TRIGGER

-- =====================================================

CREATE OR REPLACE FUNCTION update_po_totals()

RETURNS TRIGGER AS $$

BEGIN

-- Tính lại totals cho PO

UPDATE purchase_orders

SET

subtotal = (

SELECT COALESCE(SUM(total_cost), 0)

FROM purchase_order_items

WHERE purchase_order_id = COALESCE(NEW.purchase_order_id, OLD.purchase_order_id)

),

total_amount = (

SELECT COALESCE(SUM(total_cost), 0)

FROM purchase_order_items

WHERE purchase_order_id = COALESCE(NEW.purchase_order_id, OLD.purchase_order_id)

) - COALESCE(discount_amount, 0) + COALESCE(tax_amount, 0),

updated_at = NOW()

WHERE id = COALESCE(NEW.purchase_order_id, OLD.purchase_order_id);

RETURN COALESCE(NEW, OLD);

END;

$$ LANGUAGE plpgsql;

  

-- Trigger tự động update totals

CREATE TRIGGER trigger_update_po_totals

AFTER INSERT OR UPDATE OR DELETE ON purchase_order_items

FOR EACH ROW EXECUTE FUNCTION update_po_totals();

  

-- =====================================================

-- 4. AUTO-GENERATE PO NUMBER FUNCTION

-- =====================================================

CREATE OR REPLACE FUNCTION generate_po_number()

RETURNS TRIGGER AS $$

BEGIN

IF NEW.po_number IS NULL THEN

NEW.po_number := 'PO' || TO_CHAR(NEW.order_date, 'YYYYMMDD') || '-' ||

LPAD(nextval('po_sequence')::TEXT, 3, '0');

END IF;

RETURN NEW;

END;

$$ LANGUAGE plpgsql;

  

-- Sequence cho PO number

CREATE SEQUENCE IF NOT EXISTS po_sequence START 1;

  

-- Trigger tự động generate PO number

CREATE TRIGGER trigger_generate_po_number

BEFORE INSERT ON purchase_orders

FOR EACH ROW EXECUTE FUNCTION generate_po_number();

  

-- =====================================================

-- 5. BUSINESS LOGIC FUNCTIONS

-- =====================================================

  

-- Function tạo product batches từ PO khi delivered

CREATE OR REPLACE FUNCTION create_batches_from_po(po_id UUID)

RETURNS INTEGER AS $function$

DECLARE

po_record RECORD;

item_record RECORD;

batch_count INTEGER := 0;

BEGIN

-- Get PO info

SELECT * INTO po_record FROM purchase_orders WHERE id = po_id;

IF po_record.status != 'DELIVERED' THEN

RAISE EXCEPTION 'PO must be DELIVERED status to create batches';

END IF;

-- Loop through PO items

FOR item_record IN

SELECT * FROM purchase_order_items WHERE purchase_order_id = po_id

LOOP

-- Create product batch

INSERT INTO product_batches (

product_id,

batch_number,

quantity,

cost_price,

received_date,

supplier_batch_id,

notes

) VALUES (

item_record.product_id,

po_record.po_number || '-' || item_record.product_id,

item_record.received_quantity,

item_record.unit_cost,

po_record.delivery_date,

po_record.po_number,

'Auto-created from PO: ' || po_record.po_number

);

batch_count := batch_count + 1;

END LOOP;

RETURN batch_count;

END;

$function$ LANGUAGE plpgsql;

-- =====================================================

-- 6. VIEWS CHO REPORTING

-- =====================================================

  

-- View PO với supplier info

CREATE OR REPLACE VIEW purchase_orders_with_details AS

SELECT

po.*,

c.name as supplier_name,

c.phone as supplier_phone,

c.contact_person as supplier_contact,

COUNT(poi.id) as items_count,

SUM(poi.quantity) as total_quantity,

SUM(poi.received_quantity) as total_received

FROM purchase_orders po

LEFT JOIN companies c ON po.supplier_id = c.id

LEFT JOIN purchase_order_items poi ON po.id = poi.purchase_order_id

GROUP BY po.id, c.id;

  

-- View pending deliveries

CREATE OR REPLACE VIEW pending_deliveries AS

SELECT

po.*,

c.name as supplier_name,

(po.expected_delivery_date - CURRENT_DATE) as days_until_delivery

FROM purchase_orders po

LEFT JOIN companies c ON po.supplier_id = c.id

WHERE po.status IN ('SENT', 'CONFIRMED')

AND po.expected_delivery_date >= CURRENT_DATE

ORDER BY po.expected_delivery_date ASC;
```


company management nằm ở  trong main navigation drawer , thêm Route names cho các company screens, Deep linking từ product detail → company detail 


# Company Manager (Nhà Cung Cấp)

Tài liệu mô tả cách thức hoạt động module Nhà Cung Cấp (Company) trong AgriPOS, theo mô hình 3 lớp: UI (Screens) → Provider (State Management) → Service (Business Logic & API).

## Kiến trúc
- **Model**: `lib/features/products/models/company.dart`
- **Service**: `lib/features/products/services/product_service.dart`
  - Hàm: `getCompanies()`
- **Provider**: `lib/features/products/providers/company_provider.dart`
  - State: `companies`, `isLoading`
  - Hàm: `loadCompanies()`
- **Screens**: Sử dụng CompanyProvider để hiển thị/filter NCC
  - Ví dụ: `po_list_screen.dart` (lọc PO theo NCC), `product_detail_screen.dart` (lọc lô theo NCC), `batch_history_screen.dart` (lọc lịch sử lô theo NCC)

## Data Flow
1. UI gọi `CompanyProvider.loadCompanies()` (thường trong `initState` hoặc trước khi mở filter sheet).
2. Provider gọi `ProductService.getCompanies()`
3. Service gọi Supabase: `from('companies').select('*').order('name')`
4. Provider set `companies` và notify UI.

## Cách dùng trong UI (ví dụ FilterChip)
```dart
final companyProvider = context.watch<CompanyProvider>();
SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  child: Row(
    children: companyProvider.companies.map((c) {
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

## Lưu ý RLS/Policy
- Bảng `companies` cần quyền SELECT cho vai trò app (authenticated/anon tùy cấu hình) để UI có thể tải danh sách NCC trong các filter.

## Best Practices
- Tải NCC một lần và share qua Provider, hạn chế gọi lại nhiều lần.
- Với danh sách NCC dài, cân nhắc thêm text search để filter client-side.
 