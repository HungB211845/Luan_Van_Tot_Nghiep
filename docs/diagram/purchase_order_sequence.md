sequenceDiagram
    actor User
    participant ListUI as POListScreen
    participant CreateUI as CreatePurchaseOrderScreen
    participant BulkUI as BulkProductSelectionScreen
    participant DetailUI as PODetailScreen
    participant Provider as PurchaseOrderProvider
    participant ProductProv as ProductProvider
    participant UnitProv as ProductUnitProvider
    participant Service as PurchaseOrderService
    participant ProductSvc as ProductService
    participant UnitSvc as ProductUnitService
    participant DB as Supabase DB/RPC

    User->>+ListUI: Mở POListScreen
    ListUI->>+Provider: searchPurchaseOrders()
    Provider->>Provider: Kết hợp searchText, bộ lọc, phân trang
    Provider->>+Service: searchPurchaseOrders(filters)
    Service->>+DB: RPC search_purchase_orders hoặc SELECT view
    DB-->>-Service: List<PurchaseOrder>
    Service-->>-Provider: PurchaseOrders
    Provider->>Provider: Cập nhật _purchaseOrders và paging
    Provider-->>ListUI: notifyListeners()
    ListUI-->>-User: Hiển thị danh sách đơn nhập

    User->>+CreateUI: Mở CreatePurchaseOrderScreen
    CreateUI->>Provider: setSupplierForCart(supplierId)
    User->>+BulkUI: Chọn "Thêm sản phẩm"
    BulkUI->>+ProductSvc: getProductsByCompany(supplierId)
    ProductSvc->>+DB: SELECT products_by_company
    DB-->>-ProductSvc: List<Product>
    ProductSvc-->>-BulkUI: Sản phẩm NCC
    loop Đối với từng sản phẩm
        BulkUI->>+UnitProv: getUnitsForProduct(productId, forceRefresh=true)
        UnitProv->>+UnitSvc: SELECT product_units
        UnitSvc-->>-UnitProv: Units
        UnitProv-->>-BulkUI: Units cache
        BulkUI->>Provider: addPOCartItem(POCartItem)
        Provider->>Provider: Cập nhật _poCartItems
        Provider-->>CreateUI: notifyListeners()
    end

    User->>CreateUI: Nhấn "Gửi đơn hàng"
    CreateUI->>+Provider: createPOFromCart(notes,status=sent)
    Provider->>Provider: Validate supplier & items
    Provider->>+UnitProv: getUnitsForProduct(productIds)
    UnitProv->>+UnitSvc: SELECT product_units
    UnitSvc-->>-UnitProv: Units
    UnitProv-->>-Provider: Map đơn vị
    loop Với mỗi item
        Provider->>UnitProv: convertQuantityToBaseFromUnits(...)
        Provider->>UnitProv: convertPriceToBaseFromUnits(...)
        alt Giá bán mới khác giá hiện tại
            Provider->>+ProductSvc: updateCurrentSellingPrice(productId, displayPrice)
            ProductSvc->>+DB: RPC update_product_selling_price
            DB-->>-ProductSvc: OK
            ProductSvc-->>-Provider: Success
        end
    end
    Provider->>+Service: createPurchaseOrder(order, items)
    Service->>+DB: INSERT purchase_orders + purchase_order_items
    DB-->>-Service: Row mới (id, số đơn)
    Service-->>-Provider: PurchaseOrder
    Provider->>ProductProv: refreshProductsByIds(affectedProductIds)
    ProductProv->>+ProductSvc: getProductById(productId)
    ProductSvc->>+DB: SELECT products_with_details
    DB-->>-ProductSvc: Product
    ProductSvc-->>-ProductProv: Product
    ProductProv->>ProductProv: Cập nhật cache & notifyListeners()
    Provider->>Provider: clear cart, supplier, filters
    Provider->>Provider: searchPurchaseOrders() (refresh list)
    Provider-->>CreateUI: notifyListeners()
    CreateUI-->>-User: Điều hướng sang PODetailScreen(newPO)

    User->>+DetailUI: Mở PODetailScreen
    DetailUI->>+Provider: loadPODetails(poId)
    Provider->>Provider: reset _selectedPO/_selectedPOItems/_batches
    Provider->>+Service: getPurchaseOrderDetails(poId)
    Service->>+DB: SELECT purchase_orders_with_details
    DB-->>-Service: Order row
    Service->>+DB: SELECT purchase_order_items JOIN products
    DB-->>-Service: Items
    Service-->>-Provider: {order, items}
    Provider->>+UnitProv: getUnitsForProduct(productIds)
    UnitProv->>+UnitSvc: SELECT product_units
    UnitSvc-->>-UnitProv: Units
    UnitProv-->>-Provider: Units cache
    Provider->>+Service: getBatchesFromPO(poId)
    Service->>+DB: SELECT product_batches WHERE purchase_order_id=?
    DB-->>-Service: Batches
    Service-->>-Provider: List<ProductBatch>
    Provider->>Provider: cập nhật _selectedPO, items, batches, status=success
    Provider-->>DetailUI: notifyListeners()
    DetailUI-->>-User: Hiển thị chi tiết PO

    User->>+DetailUI: Nhấn "Nhận hàng"
    DetailUI->>+Provider: receivePO(poId)
    Provider->>Provider: _setStatus(loading)
    alt PO đang ở trạng thái SENT
        Provider->>+Service: updatePurchaseOrderStatus(poId, CONFIRMED)
        Service->>+DB: UPDATE purchase_orders SET status='confirmed'
        DB-->>-Service: Updated PO
        Service-->>-Provider: PurchaseOrder
        Provider->>Provider: update _selectedPO và danh sách
    end
    Provider->>+Service: receivePurchaseOrder(poId)
    Service->>+DB: RPC create_batches_from_po(po_id)
    DB-->>-Service: OK
    Service->>+DB: UPDATE purchase_orders SET status='delivered'
    DB-->>-Service: OK
    Service->>+DB: SELECT purchase_orders_with_details WHERE id=poId
    DB-->>-Service: Updated order
    Service->>+DB: SELECT purchase_order_items WHERE purchase_order_id=poId
    DB-->>-Service: Items (product_ids)
    loop Mỗi sản phẩm cập nhật
        Service->>+ProductSvc: getProductById(productId)
        ProductSvc->>+DB: SELECT products_with_details
        DB-->>-ProductSvc: Product
        ProductSvc-->>-Service: Product
        Service->>+UnitSvc: getProductUnits(productId)
        UnitSvc->>+DB: SELECT product_units
        DB-->>-UnitSvc: Units
        UnitSvc-->>-Service: Units list
    end
    Service-->>-Provider: {po, products, units}
    Provider->>Provider: update _selectedPO và _purchaseOrders
    loop Cập nhật cache sản phẩm
        Provider->>ProductProv: refreshProductSummary(productId)
        ProductProv->>+ProductSvc: getProductById(productId)
        ProductSvc->>+DB: SELECT products_with_details
        DB-->>-ProductSvc: Product
        ProductSvc-->>-ProductProv: Product
        ProductProv->>ProductProv: update cache
        Provider->>UnitProv: clearCache(productId)
        Provider->>+UnitProv: getUnitsForProduct(productId, forceRefresh=true)
        UnitProv->>+UnitSvc: SELECT product_units
        UnitSvc-->>-UnitProv: Units
        UnitProv-->>-Provider: Units map
    end
    Provider->>ProductProv: refreshInventoryAfterGoodsReceipt(productIds)
    ProductProv->>ProductProv: update tồn kho, batches, notifyListeners()
    Provider->>Provider: loadPODetails(poId) để refresh UI
    Provider-->>DetailUI: notifyListeners()
    DetailUI-->>User: PO hiển thị trạng thái "ĐÃ NHẬN" với tồn kho mới 