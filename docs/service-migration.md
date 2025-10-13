# Service Migration Checklist

Tài liệu này liệt kê toàn bộ hàm public trong các service Flutter hiện tại. Mỗi mục được gắn với endpoint/method đề xuất cho hệ Next.js mới. Sử dụng danh sách này làm backlog cho Giai đoạn 2 (Backend → Service → ViewModel → View).

## ProductService (`lib/features/products/services/product_service.dart`)
- [x] ✅ `getProductsPaginated(params)` → GET `/api/products` (query: `category`, `offset`, `limit`, `sortBy`, `ascending`)
- [x] ✅ `getProducts(category)` → GET `/api/products` (giữ để tương thích legacy, dùng cùng endpoint)
- [x] ✅ `getProductsByCompany(companyId)` → GET `/api/products?companyId={companyId}`
- [x] ✅ `searchProductsPaginated(filters)` → GET `/api/products/search` (query: `q`, `category`, `minPrice`, `maxPrice`, `inStock`, pagination)
- [x] ✅ `searchProducts(query)` → GET `/api/products/search` (legacy wrapper)
- [x] ✅ `getProductBatchesPaginated(productId, params)` → GET `/api/products/{productId}/batches` (pagination)
- [x] ✅ `getProductBatches(productId)` → GET `/api/products/{productId}/batches` (legacy wrapper)
- [x] ✅ `addProductBatch(batch)` → POST `/api/products/{productId}/batches`
- [x] ✅ `updateProductBatch(batch)` → PATCH `/api/products/{productId}/batches/{batchId}`
- [x] ✅ `deleteProductBatch(batchId)` → DELETE `/api/product-batches/{batchId}` (soft-delete)
- [x] ✅ `getAvailableStock(productId)` → GET `/api/products/{productId}/stock`
- [x] ✅ `getExpiringBatches({months})` → GET `/api/inventory/expiring-batches` (query `months`, fallback RPC)
- [x] ✅ `getLowStockProducts()` → GET `/api/inventory/low-stock`
- [x] ✅ `getProductBatchesPaginated({productId})` → GET `/api/products/{productId}/batches`
- [x] ✅ `quickAddBatch(payload)` → POST `/api/products/{productId}/quick-add-batch`
- [x] ✅ `quickSearchForPOS(query)` → GET `/api/products/pos-search?q=`
- [x] ✅ `scanProductBySKU(sku)` → GET `/api/products/scan?sku=`
- [x] ✅ `getProductById(productId)` → GET `/api/products/{productId}`
- [x] ✅ `createProduct(product)` → POST `/api/products`
- [x] ✅ `updateProduct(product)` → PUT `/api/products/{product.id}`
- [x] ✅ `deleteProduct(productId)` → DELETE `/api/products/{productId}` (soft-delete)
- [x] ✅ `getCurrentPrice(productId)` → GET `/api/products/{productId}/current-price`
- [x] ✅ `updateCurrentSellingPrice(productId, newPrice)` → PATCH `/api/products/{productId}/current-price`
- [x] ✅ `calculateAverageCostPrice(productId)` → POST `/api/rpc/get_average_cost_price`
- [x] ✅ `calculateGrossProfitPercentage(productId)` → POST `/api/rpc/get_gross_profit_percentage`
- [x] ✅ `getPriceHistory(productId, limit)` → GET `/api/products/{productId}/price-history?limit=`
- [x] ✅ `getSeasonalPrices(productId)` → GET `/api/products/{productId}/seasonal-prices`
- [x] ✅ `addSeasonalPrice(entry)` → POST `/api/products/{productId}/seasonal-prices`
- [x] ✅ `updateSeasonalPrice(entry)` → PATCH `/api/products/{productId}/seasonal-prices/{seasonalPriceId}`
- [x] ✅ `deleteSeasonalPrice(seasonalPriceId)` → DELETE `/api/products/{productId}/seasonal-prices/{seasonalPriceId}`
- [x] ✅ `getBannedSubstances()` → GET `/api/banned-substances`
- [x] ✅ `addBannedSubstance(substance)` → POST `/api/banned-substances`
- [x] ✅ `checkBannedSubstance(activeIngredient)` → POST `/api/banned-substances/check`
- [ ] `getCompanies()` → GET `/api/companies` (sẽ gom về CompanyService trên Next.js)
- [x] ✅ `getProductDashboardStats()` → GET `/api/products/dashboard`
- [x] ✅ `getTotalProductsCount()` → GET `/api/products/count`

## ProductUnitService (`lib/features/products/services/product_unit_service.dart`)
- [x] ✅ `getProductUnits(productId)` → GET `/api/products/{productId}/units`
- [x] ✅ `getDefaultUnit(productId)` → GET `/api/products/{productId}/units/default`
- [x] ✅ `createProductUnit(unit)` → POST `/api/products/{productId}/units`
- [x] ✅ `updateProductUnit(unit)` → PATCH `/api/product-units/{unitId}`
- [x] ✅ `deleteProductUnit(unitId)` → DELETE `/api/product-units/{unitId}`
- [x] ✅ `setDefaultUnit(productId, unitId)` → POST `/api/products/{productId}/units/{unitId}/set-default`
- [x] ✅ `checkStockAvailability(productId, quantity, unitId)` → POST `/api/rpc/check_stock_availability`
- [x] ✅ `getAvailableStockBaseUnit(productId)` → POST `/api/rpc/get_available_stock_base_unit`
- [ ] `convertToBaseUnit(...)` → *Helper, giữ client-side (không cần API)*
- [ ] `convertFromBaseUnit(...)` → *Helper, giữ client-side (không cần API)*

## InventoryAdjustmentService (`lib/features/products/services/inventory_adjustment_service.dart`)
- [x] ✅ `createAdjustment(payload)` → POST `/api/inventory/adjustments`
- [x] ✅ `voidBatch(batchId, reason)` → POST `/api/inventory/batches/{batchId}/void`
- [x] ✅ `canEditBatch(batchId)` → GET `/api/inventory/batches/{batchId}/permissions`
- [x] ✅ `canDeleteBatch(batchId)` → GET `/api/inventory/batches/{batchId}/permissions`
- [x] ✅ `getBatchAdjustmentHistory(batchId)` → GET `/api/inventory/batches/{batchId}/adjustments`
- [x] ✅ `getProductAdjustmentHistory(productId)` → GET `/api/inventory/products/{productId}/adjustments`
- [x] ✅ `incrementBatchSalesCount(batchId, increment)` → POST `/api/rpc/increment_batch_sales_count`

## PurchaseOrderService (`lib/features/products/services/purchase_order_service.dart`)
- [x] ✅ `getPurchaseOrders()` → GET `/api/purchase-orders`
- [x] ✅ `searchPurchaseOrders(filters)` → POST `/api/rpc/search_purchase_orders`
- [x] ✅ `getPurchaseOrderDetails(poId)` → GET `/api/purchase-orders/{poId}`
- [x] ✅ `createPurchaseOrder(order, items)` → POST `/api/purchase-orders`
- [x] ✅ `updatePurchaseOrderStatus(poId, status)` → PATCH `/api/purchase-orders/{poId}/status`
- [x] ✅ `receivePurchaseOrder(poId)` → POST `/api/purchase-orders/{poId}/receive`
- [x] ✅ `getBatchesFromPO(poId)` → GET `/api/purchase-orders/{poId}/batches`

## CompanyService (`lib/features/products/services/company_service.dart`)
- [x] ✅ `getCompanies()` → GET `/api/companies`
- [x] ✅ `createCompany(company)` → POST `/api/companies`
- [x] ✅ `updateCompany(company)` → PUT `/api/companies/{company.id}`
- [x] ✅ `deleteCompany(companyId)` → DELETE `/api/companies/{companyId}`
- [x] ✅ `getCompanyProducts(companyId)` → GET `/api/companies/{companyId}/products`
- [x] ✅ `existsCompanyName(name, excludeId?)` → GET `/api/companies/exists?name=...&excludeId=...`
- [x] ✅ `hasProducts(companyId)` → GET `/api/companies/{companyId}/has-products`
- [x] ✅ `hasPurchaseOrders(companyId)` → GET `/api/companies/{companyId}/has-purchase-orders`
- [x] ✅ `getCompaniesWithMetadata()` → GET `/api/companies/summary`

## CustomerService (`lib/features/customers/services/customer_service.dart`)
- [x] ✅ `getCustomers()` → GET `/api/customers`
- [x] ✅ `searchCustomers(query)` → GET `/api/customers/search?q=`
- [x] ✅ `createCustomer(customer)` → POST `/api/customers`
- [x] ✅ `updateCustomer(customer)` → PUT `/api/customers/{customer.id}`
- [x] ✅ `deleteCustomer(customerId)` → DELETE `/api/customers/{customerId}`
- [x] ✅ `getCustomerById(customerId)` → GET `/api/customers/{customerId}`
- [x] ✅ `getCustomersSorted(sortBy, ascending)` → GET `/api/customers?sortBy=&ascending=`
- [x] ✅ `getCustomerStatistics(customerId)` → POST `/api/rpc/get_customer_statistics`

## DebtService (`lib/features/debt/services/debt_service.dart`)
- [x] ✅ `createDebtFromTransaction(transaction, ...)` → POST `/api/debts/from-transaction`
- [x] ✅ `createManualDebt(customerId, amount, notes?)` → POST `/api/debts/manual`
- [x] ✅ `getCustomerDebts(customerId)` → GET `/api/customers/{customerId}/debts`
- [x] ✅ `getCustomerDebtSummary(customerId)` → POST `/api/rpc/get_customer_debt_summary`
- [x] ✅ `getAllDebts(status?, onlyOverdue?)` → GET `/api/debts`
- [x] ✅ `addPayment(customerId, amount, method, notes?)` → POST `/api/debts/payments`
- [x] ✅ `getDebtPayments(debtId)` → GET `/api/debts/{debtId}/payments`
- [x] ✅ `getCustomerPayments(customerId)` → GET `/api/customers/{customerId}/payments`
- [x] ✅ `adjustDebt(debtId, adjustment)` → POST `/api/debts/{debtId}/adjustments`
- [x] ✅ `getDebtAdjustments(debtId)` → GET `/api/debts/{debtId}/adjustments`
- [x] ✅ `calculateOverdueInterest(debtId, dailyRate?)` → POST `/api/rpc/calculate_overdue_interest`
- [x] ✅ `getDebtById(debtId)` → GET `/api/debts/{debtId}`
- [x] ✅ `cancelDebt(debtId, reason)` → POST `/api/debts/{debtId}/cancel`

## TransactionService (`lib/features/pos/services/transaction_service.dart`)
- [x] ✅ `createTransaction(payload)` → POST `/api/transactions`
- [x] ✅ `searchTransactions(filters)` → POST `/api/rpc/search_transactions_with_items`
- [x] ✅ `getTransactionHistoryPaginated(...)` → (Legacy) sử dụng cùng endpoint `searchTransactions`
- [x] ✅ `searchTransactionsPaginated(...)` → (Legacy) dùng `searchTransactions`
- [x] ✅ `getDebtTransactionsPaginated(...)` → (Legacy) dùng `searchTransactions` với `debtStatus=unpaid`
- [x] ✅ `getTodayTransactionsPaginated(...)` → (Legacy) dùng `searchTransactions` với `startDate/endDate` hôm nay
- [x] ✅ `getTransactionHistory(customerId?, limit)` → GET `/api/transactions/history` (legacy, cân nhắc thay thế bằng search)
- [x] ✅ `getTransactionItems(transactionId)` → GET `/api/transactions/{transactionId}/items`
- [x] ✅ `getTransactionWithItems(transactionId)` → GET `/api/transactions/{transactionId}?include=items`
- [x] ✅ `getTransactionById(transactionId)` → GET `/api/transactions/{transactionId}`
- [x] ✅ `getDebtTransactions(customerId?)` → GET `/api/transactions?isDebt=true&customerId=`
- [x] ✅ `getTodaySalesStats()` → GET `/api/transactions/today-summary`

## ReportService (`lib/features/reports/services/report_service.dart`)
- [x] ✅ `getRevenueSummaryWithComparison(start, end)` → POST `/api/rpc/get_revenue_summary_with_comparison`
- [x] ✅ `getRevenueTrend(start, end, interval)` → POST `/api/rpc/get_revenue_trend`
- [x] ✅ `getRevenueForWeek(startDate)` → *Client sử dụng `getRevenueTrend` (không cần endpoint mới)*
- [x] ✅ `getTopPerformingProducts(filters)` → POST `/api/rpc/get_top_performing_products`
- [x] ✅ `getInventoryAnalytics()` → POST `/api/rpc/get_inventory_summary` + `/api/rpc/get_inventory_alerts` (hoặc hợp nhất trong một API)
- [x] ✅ `getInventoryAnalyticsLists()` → POST `/api/rpc/get_inventory_analytics_lists`
- [x] ✅ `getLowStockProducts(threshold?)` → POST `/api/rpc/get_inventory_alerts` (tham số `p_low_stock_threshold`)
- [x] ✅ `getSlowMovingProducts(days?)` → POST `/api/rpc/get_inventory_alerts` (tham số `p_slow_moving_days`)
- [x] ✅ `getTaxSummaryDirect(start, end)` → GET `/api/reports/tax-summary`
- [x] ✅ `exportSalesLedger(start, end)` → POST `/api/rpc/export_sales_ledger`

## TaxService (`lib/features/reports/services/tax_service.dart`)
- [x] ✅ `getTaxSummary(start, end)` → POST `/api/rpc/get_tax_summary`
- [x] ✅ `getSalesLedgerForExport(start, end)` → POST `/api/rpc/get_sales_ledger_for_export`
- [x] ✅ `exportSalesLedgerToCSV(start, end)` → *Client TODO, tái sử dụng dữ liệu từ endpoint phía trên*

## CachedProductService (`lib/services/cached_product_service.dart`)
- [x] ✅ `getProductsPaginated(params)` → GET `/api/products` (áp dụng cache client nếu cần)
- [x] ✅ `getProductsByCategory(category)` → GET `/api/products?category=`
- [x] ✅ `searchProducts(query, filters)` → GET `/api/products/search`
- [x] ✅ `getLowStockProducts()` → GET `/api/inventory/low-stock`
- [x] ✅ `getDashboardStats()` → GET `/api/products/dashboard`
- [x] ✅ `refreshMaterializedViews()` → POST `/api/rpc/refresh_materialized_views` (nếu vẫn cần trên backend)
- [x] ✅ `invalidateProductCache()` → *Client-side cache clear (không cần API)*
- [x] ✅ `invalidateSearchCache()` → *Client-side cache clear*
- [x] ✅ `invalidateDashboardCache()` → *Client-side cache clear*

> Ghi chú:
> - Những hàm đánh dấu *helper/client-side* không yêu cầu API riêng, chỉ cần được xử lý ở tầng ViewModel/Service mới.
> - Với các hàm dùng `supabase.rpc(...)`, Next.js có thể tái sử dụng route `/api/rpc/[function_name]` (POST) đã tạo ở Giai đoạn 1.
> - Khi hiện thực, ưu tiên gom các endpoint trùng chức năng (ví dụ Product dashboard, low stock) để tránh nhân đôi logic giữa ProductService và CachedProductService.


Dưới đây là quy trình khái quát hoá để mày tái sử dụng cho mọi service khác, không chỉ riêng ProductService. Nó là khung chuẩn (template) cho toàn bộ quá trình chuyển đổi từ Flutter sang Next.js – Node.js theo kiến trúc MVVM-C.

⸻

⚙️ QUY TRÌNH CHUYỂN ĐỔI SERVICE → API GATEWAY (TEMPLATE CHUẨN)

⸻

1. Backend – Tạo API Route

Mục tiêu: Viết lại hàm RPC hoặc service cũ của Supabase thành endpoint Node.js (Next.js App Router).

Cấu trúc file:

app/api/<service-name>/[optional:id]/route.ts

Bước thực hiện:
	1.	Xác định loại request:
	•	Lấy dữ liệu → GET
	•	Tạo dữ liệu → POST
	•	Cập nhật → PUT hoặc PATCH
	•	Xoá → DELETE
	2.	Xây dựng route:
	•	Lấy token từ Authorization header.
	•	Xác thực user bằng supabaseServer.auth.getUser(token).
	•	Lấy store_id từ user.user_metadata.
	•	Thực thi query (hoặc RPC) tương ứng với bảng / view của service.
	•	Luôn kèm điều kiện .eq('store_id', storeId) để thay thế cho RLS.
	•	Trả về kết quả JSON.

Ví dụ mẫu:

import { NextRequest, NextResponse } from 'next/server';
import { supabaseServer } from '@/lib/supabase/server';

export async function GET(req: NextRequest) {
  const token = req.headers.get('authorization')?.split(' ')[1];
  if (!token) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const { data: { user }, error: userError } = await supabaseServer.auth.getUser(token);
  if (userError || !user) return NextResponse.json({ error: 'Invalid user' }, { status: 401 });

  const storeId = user.user_metadata?.store_id;
  const { data, error } = await supabaseServer
    .from('<table_or_view_name>')
    .select('*')
    .eq('store_id', storeId);

  if (error) return NextResponse.json({ error: error.message }, { status: 500 });
  return NextResponse.json(data);
}


⸻

2. Frontend – Service Layer

Mục tiêu: Trừu tượng hoá việc gọi API, tương đương với ProductService, CustomerService… bên Flutter.

Cấu trúc file:

lib/api/<service-name>.ts

Bước thực hiện:
	1.	Tạo hàm getAuthHeaders() dùng supabase.auth.getSession() để lấy token.
	2.	Tạo các hàm tương ứng với mỗi endpoint:
	•	getAll() → gọi GET /api/<service-name>
	•	getById(id) → gọi GET /api/<service-name>/${id}
	•	create(data) → POST /api/<service-name>
	•	update(id, data) → PUT /api/<service-name>/${id}
	•	delete(id) → DELETE /api/<service-name>/${id}

Ví dụ mẫu:

import { supabase } from '@/lib/supabase/client';

async function getAuthHeaders() {
  const { data: { session } } = await supabase.auth.getSession();
  return { 'Authorization': `Bearer ${session?.access_token}`, 'Content-Type': 'application/json' };
}

export const customerService = {
  getAll: async () => {
    const headers = await getAuthHeaders();
    const res = await fetch('/api/customers', { headers });
    return res.json();
  },

  getById: async (id: string) => {
    const headers = await getAuthHeaders();
    const res = await fetch(`/api/customers/${id}`, { headers });
    return res.json();
  },
};


⸻

3. ViewModel – Custom Hook

Mục tiêu: Quản lý state, lỗi, và luồng dữ liệu giữa UI và service.

Cấu trúc file:

hooks/use-<service-name>.ts

Bước thực hiện:
	•	Import service tương ứng.
	•	Dùng useState và useEffect để quản lý data, loading, error.
	•	Viết hàm refetch() để gọi lại API khi cần.

Ví dụ mẫu:

import { useState, useEffect, useCallback } from 'react';
import { customerService } from '@/lib/api/customers';

export function useCustomers() {
  const [customers, setCustomers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchCustomers = useCallback(async () => {
    try {
      setLoading(true);
      const data = await customerService.getAll();
      setCustomers(data);
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { fetchCustomers(); }, [fetchCustomers]);
  return { customers, loading, error, refetch: fetchCustomers };
}


⸻

4. View – Component

Mục tiêu: Hiển thị dữ liệu từ ViewModel.
Cấu trúc file:

app/(features)/<service-name>/page.tsx

Ví dụ mẫu:

'use client';
import { useCustomers } from '@/hooks/use-customers';

export default function CustomersPage() {
  const { customers, loading, error } = useCustomers();
  if (loading) return <p>Đang tải...</p>;
  if (error) return <p style={{ color: 'red' }}>Lỗi: {error}</p>;

  return (
    <ul>
      {customers.map((c: any) => (
        <li key={c.id}>{c.name}</li>
      ))}
    </ul>
  );
}


⸻

5. Kiểm Tra (Smoke Test)

Sau khi hoàn thiện:
	1.	Chạy npm run dev.
	2.	Đăng nhập và truy cập /service-name tương ứng.
	3.	Nếu dữ liệu hiển thị đúng và token được xác thực — nghĩa là pipeline (Backend → Service → Hook → View) đã hoạt động trơn tru.

⸻

✅ Tóm Tắt Mẫu Quy Trình Chuẩn

Tầng	Nhiệm vụ	File ví dụ
Backend (API Route)	Xử lý logic nghiệp vụ, xác thực, query DB	app/api/products/route.ts
Service (API Client)	Gọi API, quản lý token	lib/api/products.ts
ViewModel (Hook)	Quản lý state, xử lý dữ liệu	hooks/use-products.ts
View (Component)	Hiển thị UI, gọi hook	app/(features)/products/page.tsx



Từ nay, chỉ cần thay <service-name> và bảng tương ứng, mày có thể nhân quy trình này cho bất kỳ module nào: customers, orders, debts, suppliers, transactions, v.v.
