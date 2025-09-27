# Quy trình Đơn Nhập Hàng (PO) → Lô hàng → Tồn kho → POS

Tài liệu mô tả end-to-end workflow của Đơn Nhập Hàng trong AgriPOS theo mô hình 3 lớp: UI (Screens) → Provider (State) → Service (Business & API) → Supabase (Tables/Views/RPC).

## Kiến trúc tổng thể
- **Models**
  - `lib/features/products/models/purchase_order.dart`
  - `lib/features/products/models/purchase_order_item.dart`
  - `lib/features/products/models/product_batch.dart`
- **Services**
  - `lib/features/products/services/purchase_order_service.dart`
    - `getPurchaseOrders()`, `getPurchaseOrderDetails(...)`, `createPurchaseOrder(...)`, `updatePurchaseOrderStatus(...)`,
      `receivePurchaseOrder(poId)`, `getBatchesFromPO(poId)`, `searchPurchaseOrders(...)`
  - `lib/features/products/services/product_service.dart`
    - `getProductBatchesPaginated(...)`, `getProductBatches(...)`, `getAvailableStock(productId)`, `getCurrentPrice(productId)`, ...
- **Providers**
  - `lib/features/products/providers/purchase_order_provider.dart`
    - Danh sách PO, chi tiết, tạo PO, nhận hàng, tìm kiếm/lọc, phân trang client-side, filter theo NCC/ngày/giá, status.
  - `lib/features/products/providers/product_provider.dart`
    - Batches theo sản phẩm (phân trang), refresh tồn kho, current price, v.v.
  - `lib/features/products/providers/company_provider.dart`
    - Danh sách NCC để hiển thị filter (FilterChip).
- **Screens (UI)**
  - `lib/features/products/screens/purchase_order/po_list_screen.dart`: Lịch sử nhập hàng (PO)
    - Search, filter NCC, sort, phân trang cuộn, grouped-by-date.
  - `lib/features/products/screens/purchase_order/po_detail_screen.dart`: Chi tiết PO
    - Hiển thị supplier, items (tên sản phẩm), các lô sinh ra sau nhận hàng, nút “Xác Nhận Nhận Hàng”.
  - `lib/features/products/screens/purchase_order/po_receive_success_screen.dart`: Màn xác nhận thành công
  - `lib/features/products/screens/products/product_detail_screen.dart`: Tab “Tồn Kho & Lô Hàng”
    - Tìm theo ngày/mã lô, quick chips, filter bottom sheet (NCC, hạn dùng, khoảng ngày, khoảng giá nhập), phân trang cuộn, nhóm theo ngày.
  - `lib/features/products/screens/products/batch_history_screen.dart`: Màn tái sử dụng hiển thị lịch sử Lô hàng theo `productId`.
- **Views & RPC (Supabase)**
  - View: `products_with_details`
    - Trả về sản phẩm + `current_price`, `available_stock` (tính qua RPC), `company_name`, ...
  - RPC:
    - `create_batches_from_po(po_id uuid) returns integer`
      - Từ PO tạo các `product_batches` (quantity theo `coalesce(nullif(received_quantity,0), quantity)`).
    - `get_available_stock(product_uuid uuid) returns integer`
      - Tổng tồn từ `product_batches` còn hàng, quantity > 0, chưa hết hạn.
    - `get_current_price(product_uuid uuid) returns numeric`
      - Giá bán hiện tại từ `seasonal_prices` đang hiệu lực.
    - (Optional) `search_purchase_orders(...)` – hỗ trợ search/filter nhanh từ backend.

---

## Luồng dữ liệu chi tiết

### 1) Tạo PO (Draft / Sent)
- UI: `po_list_screen.dart` → `CreatePurchaseOrderScreen`
- Provider: `PurchaseOrderProvider.createPOFromCart(...)`
  - Nhận `supplierId`, danh sách item (product, quantity, unitCost, ...)
- Service: `PurchaseOrderService.createPurchaseOrder(order, items)` → insert `purchase_orders` + `purchase_order_items`
- Sau khi tạo thành công, điều hướng đến `po_detail_screen.dart` để theo dõi.

### 2) Xác nhận nhận hàng (DELIVERED)
- UI: `po_detail_screen.dart` nút “Xác Nhận Nhận Hàng”
- Provider: `PurchaseOrderProvider.receivePO(poId)`:
  - Update `purchase_orders.status = DELIVERED`, `delivery_date = now()`
  - Gọi RPC: `create_batches_from_po(po_id)` để sinh `product_batches` với `purchase_order_id` liên kết PO
  - Tải lại batches của PO và gọi `ProductProvider.refreshInventoryAfterGoodsReceipt(productIds)` để cập nhật tồn kho
- UI điều hướng: `po_receive_success_screen.dart` → quay về danh sách PO

### 3) Kho & Lô hàng theo Sản phẩm
- Provider: `ProductProvider`
  - `resetBatchesPagination(productId)`, `loadProductBatchesPaginated(productId)`, `loadMoreBatches(productId)`
  - `getAvailableStock(productId)` (RPC), `getCurrentPrice(productId)` (RPC)
- UI:
  - `product_detail_screen.dart` tab “Tồn Kho & Lô Hàng”
    - Tìm theo ngày (dd/mm/yyyy | dd.mm.yyyy | dd-mm-yyyy) hoặc batch number
    - Quick chips thời gian
    - Bottom Sheet bộ lọc: Từ/Đến ngày, khoảng giá nhập, Còn hạn/Đã hết hạn, NCC
    - Nhóm theo ngày nhận, hiển thị tổng số lô mỗi ngày
    - Phân trang 20 mục, load-more
    - Long-press copy mã lô
  - `batch_history_screen.dart`: màn độc lập (reuse) hiển thị lịch sử lô theo `productId`

### 4) POS lấy tồn kho & giá bán
- `products_with_details` chứa `available_stock` và `current_price` qua RPC nên UI/Provider có thể lấy trực tiếp.
- Khi giao dịch bán hàng, Provider sử dụng stock map và current price hiện hành.

---

## Mẫu RPC/SQL (STORE-AWARE VERSION)

```sql
-- 1) STORE-AWARE: Tạo batches từ PO với store validation
create or replace function create_batches_from_po(po_id uuid)
returns integer language plpgsql security definer as $$
declare 
  batch_count integer := 0; 
  current_store_id uuid;
begin
  -- SECURITY: Get current user's store_id
  select store_id into current_store_id 
  from user_profiles where id = auth.uid()::text;
  
  if current_store_id is null then
    raise exception 'User must belong to a store';
  end if;
  
  -- SECURITY: Verify PO belongs to user's store
  if not exists (
    select 1 from purchase_orders 
    where id = po_id and store_id = current_store_id
  ) then
    raise exception 'Purchase order access denied';
  end if;

  insert into product_batches (
    product_id, quantity, cost_price, received_date, batch_number,
    purchase_order_id, is_available, notes, created_at, updated_at, store_id
  )
  select poi.product_id,
         coalesce(nullif(poi.received_quantity, 0), poi.quantity) as quantity,
         poi.unit_cost,
         coalesce(po.delivery_date, current_date) as received_date,
         'BATCH-' || to_char(now(),'YYYYMMDD') || '-' || substr(gen_random_uuid()::text,1,8),
         po_id, true,
         'Auto-created from PO #' || po.po_number,
         now(), now(), current_store_id  -- CRITICAL: Set store_id
  from purchase_order_items poi
  join purchase_orders po on poi.purchase_order_id = po.id
  join products p on poi.product_id = p.id
  where po.id = po_id 
    and po.store_id = current_store_id    -- SECURITY: Store validation
    and p.store_id = current_store_id     -- SECURITY: Product validation
    and coalesce(nullif(poi.received_quantity,0), poi.quantity) > 0;

  get diagnostics batch_count = row_count;
  return batch_count;
end; $$;

-- 2) STORE-AWARE: Tồn kho hiện có với store isolation
create or replace function get_available_stock(product_uuid uuid)
returns integer language plpgsql security definer as $$
declare 
  total_stock integer := 0;
  current_store_id uuid;
begin
  select store_id into current_store_id 
  from user_profiles where id = auth.uid()::text;
  
  if current_store_id is null then return 0; end if;
  
  select coalesce(sum(quantity),0) into total_stock
  from product_batches pb
  join products p on pb.product_id = p.id
  where pb.product_id = product_uuid
    and pb.store_id = current_store_id      -- CRITICAL: Store filter
    and p.store_id = current_store_id       -- CRITICAL: Product validation
    and pb.is_available = true and pb.quantity > 0
    and (pb.expiry_date is null or pb.expiry_date > current_date);
  return total_stock;
end; $$;

-- 3) STORE-AWARE: Giá hiện tại với store isolation
create or replace function get_current_price(product_uuid uuid)
returns numeric language plpgsql security definer as $$
declare 
  current_price numeric := 0;
  current_store_id uuid;
begin
  select store_id into current_store_id 
  from user_profiles where id = auth.uid()::text;
  
  if current_store_id is null then return 0; end if;
  
  select coalesce(selling_price,0) into current_price
  from seasonal_prices sp
  join products p on sp.product_id = p.id
  where sp.product_id = product_uuid
    and sp.store_id = current_store_id      -- CRITICAL: Store filter  
    and p.store_id = current_store_id       -- CRITICAL: Product validation
    and sp.is_active = true
    and sp.start_date <= current_date and sp.end_date >= current_date
  order by sp.created_at desc limit 1;
  return current_price;
end; $$;
```

> Lưu ý: Khi đổi tham số RPC từ `product_id_param` → `product_uuid`, Service cũng phải gọi với key tương ứng:
> - `getAvailableStock`: `.rpc('get_available_stock', params: {'product_uuid': productId})`
> - `getCurrentPrice`: `.rpc('get_current_price', params: {'product_uuid': productId})`

---

## Gợi ý RLS/Policy
- Cho phép SELECT trên `products`, `product_batches`, `companies`, `seasonal_prices`, view `products_with_details` cho role app.
- GRANT EXECUTE các RPC cho role app.
- Lưu ý nested select trong `getBatchesFromPO()` (`products(name)`, `companies(name)`) yêu cầu quyền SELECT tương ứng.

---

## Checklist tái sử dụng nhanh
- **Providers cần**: `ProductProvider`, `PurchaseOrderProvider`, `CompanyProvider`
- **Service cần**: `ProductService`, `PurchaseOrderService`
- **Screen**: có thể tái sử dụng `BatchHistoryScreen(productId: ...)` để hiển thị lịch sử lô cho bất kỳ nơi nào.
- **Sau khi nhận hàng**: luôn gọi `refreshInventoryAfterGoodsReceipt(productIds)` + reload hiển thị.
