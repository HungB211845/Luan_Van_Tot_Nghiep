sequenceDiagram
actor User
participant Screen as ReportsScreen
participant Provider as ReportProvider
participant Service as ReportService
participant DB as Supabase DB/RPC
participant Device as Thiết bị (Share/FileSaver)

    User->>Screen: Mở tab "Doanh thu"
    Screen->>Provider: loadRevenueData(forceRefresh?)
    Provider->>Provider: Kiểm tra cờ _revenueLoaded/_isLoadingRevenue
    Note over Provider: Nếu lần đầu hoặc forceRefresh=true thì tiếp tục\\nNếu đã load thì bỏ qua
    Provider->>Provider: set _isLoadingRevenue=true, _isLoading=true, clear error
    Provider--)Screen: notifyListeners() (hiển thị loading)
    Note over Provider: Bước 1: gọi RPC tóm tắt & so sánh doanh thu (30%)\\nBước 2: gọi RPC xu hướng doanh thu (30%)\\nBước 3: gọi RPC top sản phẩm (40%)

    Provider->>Service: getRevenueSummaryWithComparison(start,end)
    Service->>DB: RPC get_revenue_summary_with_comparison
    DB-->>Service: {current_period, previous_period,...}
    Service-->>Provider: Map

    Provider->>Service: getRevenueTrend(start,end)
    Service->>DB: RPC get_revenue_trend
    DB-->>Service: List<RevenueTrendPoint>
    Service-->>Provider: List

    Provider->>Service: getTopPerformingProducts(start,end)
    Service->>DB: RPC get_top_performing_products
    DB-->>Service: List<TopProduct>
    Service-->>Provider: List

    Provider->>Provider: Gán _revenueSummary/_revenueTrend/_topProducts, _revenueLoaded=true
    Provider->>Provider: set _isLoadingRevenue=false, _isLoading=false
    Provider--)Screen: notifyListeners() (render dữ liệu)
    Screen-->>User: Hiển thị biểu đồ & top sản phẩm

    User->>Screen: Mở tab "Hàng tồn kho"
    Screen->>Provider: loadInventoryData(forceRefresh?)
    Provider->>Provider: Kiểm tra _inventoryLoaded/_isLoadingInventory
    Note over Provider: Nếu chưa tải hoặc forceRefresh thì tiếp tục
    Provider->>Provider: set _isLoadingInventory=true, _isLoading=true, clear error
    Provider--)Screen: notifyListeners() (loading badge)

    Provider->>Service: getInventoryAnalytics()
    Service->>DB: RPC get_inventory_summary & get_inventory_alerts (Future.wait)
    DB-->>Service: {summary, alerts}
    Service-->>Provider: InventoryAnalytics

    Provider->>Service: getInventoryAnalyticsLists()
    Service->>DB: RPC get_inventory_analytics_lists
    DB-->>Service: Map{top_value,fast_turnover,slow_turnover}
    Service-->>Provider: Map<String,List<InventoryProduct>>

    Provider->>Provider: Cập nhật _inventoryAnalytics và các list, _inventoryLoaded=true
    Provider->>Provider: set _isLoadingInventory=false, _isLoading=false
    Provider--)Screen: notifyListeners()
    Screen-->>User: Hiển thị KPI tồn kho & cảnh báo

    User->>Screen: Mở tab "Thuế"
    Screen->>Provider: loadTaxData(forceRefresh?)
    Provider->>Provider: Kiểm tra _taxLoaded/_isLoadingTax
    Provider->>Provider: set _isLoadingTax=true, _isLoading=true, clear error
    Provider--)Screen: notifyListeners()
    Note over Provider: Bước 1: ReportService chạy 2 truy vấn song song (transactions,purchase_orders)\\nBước 2: Tổng hợp doanh thu, chi phí, số giao dịch, ước tính thuế

    Provider->>Service: getTaxSummaryDirect(start,end)
    Service->>Service: Lấy store_id từ Supabase.auth
    Service->>DB: SELECT total_amount FROM transactions WHERE store_id=? AND created_at BETWEEN start&end
    DB-->>Service: List
    Service->>DB: SELECT total_amount FROM purchase_orders WHERE status='DELIVERED' AND store_id=? AND delivery_date BETWEEN start&end
    DB-->>Service: List
    Service->>Service: Tính totalRevenue, totalExpenses, estimatedTax=totalRevenue*1.5%
    Service-->>Provider: TaxSummary
    Provider->>Provider: Gán _taxSummary, _taxLoaded=true, đặt flags false
    Provider--)Screen: notifyListeners()
    Screen-->>User: Hiển thị bảng tóm tắt thuế

    User->>Screen: Nhấn "Xuất bảng kê bán hàng"
    Screen->>Provider: exportSalesLedgerAction()
    Provider->>Provider: Nếu _isExporting=true thì bỏ qua, ngược lại set _isExporting=true
    Provider--)Screen: notifyListeners() (hiển thị progress)
    Provider->>Service: exportSalesLedger(startDate,endDate)
    Service->>DB: RPC export_sales_ledger(p_start_date,p_end_date)
    DB-->>Service: List<Map<String,dynamic>>

    alt Có dữ liệu
        Service->>Service: Chuyển JSON -> CSV, đặt tên file theo ngày
        Note over Service: Sử dụng ListToCsvConverter để encode dữ liệu
        Service->>Device: Chia sẻ/lưu file (SharePlus/FileSaver tùy nền tảng)
        Device-->>Service: Success
        Service-->>Provider: Hoàn tất
        Provider->>Provider: set _isExporting=false, _exportError=null
        Provider--)Screen: notifyListeners() (ẩn progress)
        Screen-->>User: Hiển thị thông báo/Share sheet
    else Không có dữ liệu
        Service-->>Provider: throw Exception("Không có dữ liệu")
        Provider->>Provider: set _isExporting=false, _exportError=message
        Provider--)Screen: notifyListeners()
        Screen-->>User: Hiển thị cảnh báo
    end
