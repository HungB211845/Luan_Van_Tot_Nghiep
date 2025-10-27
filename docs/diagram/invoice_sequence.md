sequenceDiagram
    actor User
    participant Screen as UI (Screens)
    participant Provider as InvoiceProvider
    participant Service as InvoiceService
    participant Exporter as InvoiceExportService
    participant DB as Supabase (DB/RPC)

    %% === 1. Xuất hóa đơn bán hàng ===
    User->>Screen: Chọn giao dịch và nhấn "Xuất hóa đơn"
    Screen->>Provider: generateTransactionInvoice(txId, format)
    Provider->>Provider: isGenerating=true, progress=0
    Provider->>Screen: notifyListeners() (show loading)
    Note over Provider: Bước 1: Lấy dữ liệu invoice (30%)
    Provider->>Service: getTransactionInvoiceData(txId)
    Service->>DB: RPC get_invoice_data(p_transaction_id)
    DB-->>Service: JSON {store_info, transaction, items}
    Service-->>Provider: InvoiceData
    Provider->>Provider: progress=0.7
    Note over Provider: Bước 2: Render file PDF/Excel (70%)
    Provider->>Exporter: generateTransactionPDF/Excel(data)
    Exporter->>Exporter: buildVATInvoicePDF/Excel
    Exporter-->>Provider: PDF/Excel bytes
    Provider->>Provider: progress=1.0, isGenerating=false
    Provider->>Screen: notifyListeners() (hide loading)
    Provider->>Exporter: shareFile(file)
    Exporter-->>Provider: Completed (non-blocking)
    Screen-->>User: Hiển thị thông báo thành công

    %% === 2. Xuất hóa đơn nhập hàng (PO) ===
    User->>Screen: Chọn PO và nhấn "Xuất hóa đơn nhập hàng"
    Screen->>Provider: generatePOInvoice(poId, format)
    Provider->>Provider: isGenerating=true, progress=0
    Provider->>Screen: notifyListeners() (show loading)
    Note over Provider: Bước 1: Lấy dữ liệu PO (30%)
    Provider->>Service: getPOInvoiceData(poId)
    Service->>DB: RPC get_po_invoice_data(p_po_id)
    DB-->>Service: JSON {store_info, purchase_order, supplier, items}
    Service-->>Provider: InvoiceData
    Provider->>Provider: progress=0.7
    Note over Provider: Bước 2: Render file PDF/Excel (70%)
    Provider->>Exporter: generatePOPDF/Excel(data)
    Exporter->>Exporter: buildPOInvoicePDF/Excel
    Exporter-->>Provider: PDF/Excel bytes
    Provider->>Provider: progress=1.0, isGenerating=false
    Provider->>Screen: notifyListeners() (hide loading)
    Provider->>Exporter: shareFile(file)
    Exporter-->>Provider: Completed
    Screen-->>User: Hiển thị thông báo thành công

    %% === 3. Xuất báo cáo giao dịch ===
    User->>Screen: Chọn khoảng thời gian và nhấn "Xuất báo cáo"
    Screen->>Provider: exportCustomReport(startDate, endDate, format)
    Provider->>Provider: isGenerating=true, progress=0
    Provider->>Screen: notifyListeners() (show loading)
    Note over Provider: Bước 1: Lấy tên hộ kinh doanh (20%)
    Provider->>Service: getStoreBusinessName()
    Service->>DB: SELECT business_name FROM store_business_info WHERE store_id=?
    DB-->>Service: business_name
    Service-->>Provider: business_name
    Provider->>Provider: progress=0.5
    Note over Provider: Bước 2: Lấy dữ liệu giao dịch (50%)
    Provider->>Service: getTransactionsExportData(startDate, endDate)
    Service->>DB: RPC get_transactions_for_export(p_start_date, p_end_date)
    DB-->>Service: Danh sách giao dịch + items
    Service-->>Provider: List<Map>
    alt Không có giao dịch
        Provider->>Provider: isGenerating=false, error='Không có giao dịch'
        Provider->>Screen: notifyListeners() (show error)
        Screen-->>User: Hiển thị cảnh báo
    else Có dữ liệu
        Provider->>Provider: progress=0.8
        Note over Provider: Bước 3: Render báo cáo (80%)
        Provider->>Exporter: exportTransactionsReportPDF/Excel
        Exporter->>Exporter: buildTransactionsReportPDF/Excel
        Exporter-->>Provider: PDF/Excel bytes
        Provider->>Provider: progress=1.0, isGenerating=false
        Provider->>Screen: notifyListeners() (hide loading)
        Provider->>Exporter: shareFile(file)
        Exporter-->>Provider: Completed
        Screen-->>User: Hiển thị thông báo thành công
    end