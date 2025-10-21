import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' as excel_pkg;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../../shared/utils/formatter.dart';
import '../models/invoice_data.dart';

/// Service for exporting invoices to PDF and Excel formats
class InvoiceExportService {
  /// Generate PDF invoice for transaction
  ///
  /// Returns File object that can be shared or printed
  Future<File> generateTransactionPDF(InvoiceData data) async {
    final pdf = pw.Document();

    // Build PDF pages
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => _buildTransactionPDFContent(data),
      ),
    );

    // Save to temp directory
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/invoice_${data.invoiceNumber ?? DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());

    return file;
  }

  /// Generate Excel invoice for transaction
  Future<File> generateTransactionExcel(InvoiceData data) async {
    final excel = excel_pkg.Excel.createExcel();
    final sheet = excel['Hóa đơn'];

    _buildTransactionExcelContent(sheet, data);

    // Save to temp directory
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/invoice_${data.invoiceNumber ?? DateTime.now().millisecondsSinceEpoch}.xlsx');
    final bytes = excel.encode();
    if (bytes != null) {
      await file.writeAsBytes(bytes);
    }

    return file;
  }

  /// Generate PDF invoice for Purchase Order
  Future<File> generatePOPDF(InvoiceData data) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => _buildPOPDFContent(data),
      ),
    );

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/po_invoice_${data.invoiceNumber ?? DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());

    return file;
  }

  /// Generate Excel invoice for Purchase Order
  Future<File> generatePOExcel(InvoiceData data) async {
    final excel = excel_pkg.Excel.createExcel();
    final sheet = excel['Đơn nhập hàng'];

    _buildPOExcelContent(sheet, data);

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/po_invoice_${data.invoiceNumber ?? DateTime.now().millisecondsSinceEpoch}.xlsx');
    final bytes = excel.encode();
    if (bytes != null) {
      await file.writeAsBytes(bytes);
    }

    return file;
  }

  /// Export multiple transactions to Excel report
  Future<File> exportTransactionsReport({
    required List<Map<String, dynamic>> transactions,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final excel = excel_pkg.Excel.createExcel();
    final sheet = excel['Báo cáo giao dịch'];

    _buildTransactionsReportExcel(sheet, transactions, startDate, endDate);

    final directory = await getTemporaryDirectory();
    final filename = 'transactions_${startDate.toString().split(' ')[0]}_to_${endDate.toString().split(' ')[0]}.xlsx';
    final file = File('${directory.path}/$filename');
    final bytes = excel.encode();
    if (bytes != null) {
      await file.writeAsBytes(bytes);
    }

    return file;
  }

  /// Share file via system share sheet
  Future<void> shareFile(File file) async {
    await Share.shareXFiles([XFile(file.path)]);
  }

  /// Print PDF file
  Future<void> printPDF(File pdfFile) async {
    final bytes = await pdfFile.readAsBytes();
    await Printing.layoutPdf(onLayout: (format) async => bytes);
  }

  // ======================================
  // PDF TEMPLATE BUILDERS
  // ======================================

  /// Build Transaction PDF content
  pw.Widget _buildTransactionPDFContent(InvoiceData data) {
    final storeInfo = data.storeInfo;
    final transaction = data.transaction!;
    final customer = data.customer;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header - Store Info
        pw.Center(
          child: pw.Column(
            children: [
              pw.Text(
                storeInfo?.businessName ?? 'TÊN CỬA HÀNG',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              if (storeInfo?.businessAddress != null)
                pw.Text(storeInfo!.businessAddress!, style: const pw.TextStyle(fontSize: 10)),
              if (storeInfo?.phoneNumber != null || storeInfo?.email != null)
                pw.Text(
                  '${storeInfo?.phoneNumber ?? ''} ${storeInfo?.email ?? ''}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              if (storeInfo?.taxCode != null)
                pw.Text(
                  'MST: ${storeInfo!.taxCode}${storeInfo.taxAuthority != null ? ' - ${storeInfo.taxAuthority}' : ''}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
            ],
          ),
        ),
        pw.SizedBox(height: 20),
        pw.Divider(),

        // Title
        pw.Center(
          child: pw.Column(
            children: [
              pw.Text(
                'HÓA ĐƠN BÁN HÀNG',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 5),
              pw.Text('Số: ${transaction.invoiceNumber ?? 'N/A'}', style: const pw.TextStyle(fontSize: 11)),
              pw.Text('Ngày: ${AppFormatter.formatDate(transaction.transactionDate)}', style: const pw.TextStyle(fontSize: 11)),
            ],
          ),
        ),
        pw.SizedBox(height: 15),

        // Customer Info
        pw.Text('Khách hàng: ${customer?.name ?? 'Khách lẻ'}', style: const pw.TextStyle(fontSize: 11)),
        if (customer?.address != null)
          pw.Text('Địa chỉ: ${customer!.address}', style: const pw.TextStyle(fontSize: 10)),
        if (customer?.phone != null)
          pw.Text('SĐT: ${customer!.phone}', style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 15),

        // Items Table
        pw.Table(
          border: pw.TableBorder.all(),
          columnWidths: {
            0: const pw.FixedColumnWidth(30),
            1: const pw.FlexColumnWidth(3),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(1),
            4: const pw.FlexColumnWidth(1.5),
            5: const pw.FlexColumnWidth(1.5),
          },
          children: [
            // Header
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _pdfCell('STT', bold: true, center: true),
                _pdfCell('Tên sản phẩm', bold: true),
                _pdfCell('SL', bold: true, center: true),
                _pdfCell('ĐVT', bold: true, center: true),
                _pdfCell('Đơn giá', bold: true, right: true),
                _pdfCell('Thành tiền', bold: true, right: true),
              ],
            ),
            // Items
            ...data.items.asMap().entries.map((entry) {
              final index = entry.key + 1;
              final item = entry.value;
              return pw.TableRow(
                children: [
                  _pdfCell(index.toString(), center: true),
                  _pdfCell(item.productName),
                  _pdfCell(item.quantity.toString(), center: true),
                  _pdfCell(item.unitName ?? 'đvt', center: true),
                  _pdfCell(AppFormatter.formatCurrency(item.pricePerUnit), right: true),
                  _pdfCell(AppFormatter.formatCurrency(item.subTotal), right: true),
                ],
              );
            }),
          ],
        ),
        pw.SizedBox(height: 10),

        // Total
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text('Tổng cộng: ', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.Text(
              AppFormatter.formatCurrency(transaction.totalAmount),
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        if (transaction.surchargeAmount > 0) ...[
          pw.SizedBox(height: 5),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text('Phụ phí: '),
              pw.Text(AppFormatter.formatCurrency(transaction.surchargeAmount)),
            ],
          ),
        ],
        if (transaction.notes != null) ...[
          pw.SizedBox(height: 10),
          pw.Text('Ghi chú: ${transaction.notes}', style: const pw.TextStyle(fontSize: 10)),
        ],

        pw.Spacer(),

        // Signatures
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
          children: [
            pw.Column(
              children: [
                pw.Text('Người mua hàng', style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 40),
                pw.Text('(Ký, họ tên)', style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
            pw.Column(
              children: [
                pw.Text('Người bán hàng', style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 40),
                pw.Text('(Ký, họ tên)', style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// Build PO PDF content
  pw.Widget _buildPOPDFContent(InvoiceData data) {
    final storeInfo = data.storeInfo;
    final po = data.purchaseOrder!;
    final supplier = data.supplier;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header
        pw.Center(
          child: pw.Column(
            children: [
              pw.Text(
                storeInfo?.businessName ?? 'TÊN CỬA HÀNG',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              if (storeInfo?.businessAddress != null)
                pw.Text(storeInfo!.businessAddress!),
            ],
          ),
        ),
        pw.SizedBox(height: 20),
        pw.Divider(),

        // Title
        pw.Center(
          child: pw.Column(
            children: [
              pw.Text(
                'ĐƠN NHẬP HÀNG',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 5),
              pw.Text('Số: ${po.poNumber ?? 'N/A'}'),
              pw.Text('Ngày: ${AppFormatter.formatDate(po.orderDate)}'),
            ],
          ),
        ),
        pw.SizedBox(height: 15),

        // Supplier Info
        pw.Text('Nhà cung cấp: ${supplier?.name ?? 'N/A'}'),
        if (supplier?.address != null) pw.Text('Địa chỉ: ${supplier!.address}'),
        if (supplier?.phone != null) pw.Text('SĐT: ${supplier!.phone}'),
        pw.SizedBox(height: 15),

        // Items Table
        pw.Table(
          border: pw.TableBorder.all(),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _pdfCell('STT', bold: true, center: true),
                _pdfCell('Tên sản phẩm', bold: true),
                _pdfCell('SL', bold: true, center: true),
                _pdfCell('Đơn giá', bold: true, right: true),
                _pdfCell('Thành tiền', bold: true, right: true),
              ],
            ),
            ...data.items.asMap().entries.map((entry) {
              final index = entry.key + 1;
              final item = entry.value;
              return pw.TableRow(
                children: [
                  _pdfCell(index.toString(), center: true),
                  _pdfCell(item.productName),
                  _pdfCell(item.quantityDisplay, center: true),
                  _pdfCell(AppFormatter.formatCurrency(item.pricePerUnit), right: true),
                  _pdfCell(AppFormatter.formatCurrency(item.subTotal), right: true),
                ],
              );
            }),
          ],
        ),
        pw.SizedBox(height: 10),

        // Total
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text('Tổng cộng: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(
              AppFormatter.formatCurrency(po.totalAmount),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),

        pw.Spacer(),

        // Signatures
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
          children: [
            pw.Column(
              children: [
                pw.Text('Người lập'),
                pw.SizedBox(height: 40),
                pw.Text('(Ký, họ tên)'),
              ],
            ),
            pw.Column(
              children: [
                pw.Text('Người duyệt'),
                pw.SizedBox(height: 40),
                pw.Text('(Ký, họ tên)'),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // PDF Helper: Create table cell
  pw.Widget _pdfCell(String text, {bool bold = false, bool center = false, bool right = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
        textAlign: center
            ? pw.TextAlign.center
            : right
                ? pw.TextAlign.right
                : pw.TextAlign.left,
      ),
    );
  }

  // ======================================
  // EXCEL TEMPLATE BUILDERS
  // ======================================

  /// Build Transaction Excel content
  void _buildTransactionExcelContent(excel_pkg.Sheet sheet, InvoiceData data) {
    final storeInfo = data.storeInfo;
    final transaction = data.transaction!;
    final customer = data.customer;

    int row = 0;

    // Header
    sheet.merge(excel_pkg.CellIndex.indexByString('A${row + 1}'), excel_pkg.CellIndex.indexByString('F${row + 1}'));
    _setCell(sheet, 0, row, storeInfo?.businessName ?? 'TÊN CỬA HÀNG', bold: true, fontSize: 16);
    row++;

    if (storeInfo?.businessAddress != null) {
      sheet.merge(excel_pkg.CellIndex.indexByString('A${row + 1}'), excel_pkg.CellIndex.indexByString('F${row + 1}'));
      _setCell(sheet, 0, row, storeInfo!.businessAddress!);
      row++;
    }

    if (storeInfo?.taxCode != null) {
      sheet.merge(excel_pkg.CellIndex.indexByString('A${row + 1}'), excel_pkg.CellIndex.indexByString('F${row + 1}'));
      _setCell(sheet, 0, row, 'MST: ${storeInfo!.taxCode}');
      row++;
    }

    row++; // Empty row

    // Title
    sheet.merge(excel_pkg.CellIndex.indexByString('A${row + 1}'), excel_pkg.CellIndex.indexByString('F${row + 1}'));
    _setCell(sheet, 0, row, 'HÓA ĐƠN BÁN HÀNG', bold: true, fontSize: 14);
    row++;

    _setCell(sheet, 0, row, 'Số: ${transaction.invoiceNumber ?? 'N/A'}');
    row++;
    _setCell(sheet, 0, row, 'Ngày: ${AppFormatter.formatDate(transaction.transactionDate)}');
    row++;
    row++; // Empty row

    // Customer
    _setCell(sheet, 0, row, 'Khách hàng: ${customer?.name ?? 'Khách lẻ'}');
    row++;
    if (customer?.phone != null) {
      _setCell(sheet, 0, row, 'SĐT: ${customer!.phone}');
      row++;
    }
    row++; // Empty row

    // Table Header
    _setCell(sheet, 0, row, 'STT', bold: true);
    _setCell(sheet, 1, row, 'Tên sản phẩm', bold: true);
    _setCell(sheet, 2, row, 'SL', bold: true);
    _setCell(sheet, 3, row, 'ĐVT', bold: true);
    _setCell(sheet, 4, row, 'Đơn giá', bold: true);
    _setCell(sheet, 5, row, 'Thành tiền', bold: true);
    row++;

    // Items
    for (var i = 0; i < data.items.length; i++) {
      final item = data.items[i];
      _setCell(sheet, 0, row, (i + 1).toString());
      _setCell(sheet, 1, row, item.productName);
      _setCell(sheet, 2, row, item.quantity.toString());
      _setCell(sheet, 3, row, item.unitName ?? 'đvt');
      _setCell(sheet, 4, row, AppFormatter.formatCurrency(item.pricePerUnit));
      _setCell(sheet, 5, row, AppFormatter.formatCurrency(item.subTotal));
      row++;
    }

    row++; // Empty row

    // Total
    _setCell(sheet, 4, row, 'Tổng cộng:', bold: true);
    _setCell(sheet, 5, row, AppFormatter.formatCurrency(transaction.totalAmount), bold: true);
  }

  /// Build PO Excel content
  void _buildPOExcelContent(excel_pkg.Sheet sheet, InvoiceData data) {
    final storeInfo = data.storeInfo;
    final po = data.purchaseOrder!;
    final supplier = data.supplier;

    int row = 0;

    // Header
    sheet.merge(excel_pkg.CellIndex.indexByString('A${row + 1}'), excel_pkg.CellIndex.indexByString('E${row + 1}'));
    _setCell(sheet, 0, row, storeInfo?.businessName ?? 'TÊN CỬA HÀNG', bold: true, fontSize: 16);
    row++;
    row++;

    // Title
    sheet.merge(excel_pkg.CellIndex.indexByString('A${row + 1}'), excel_pkg.CellIndex.indexByString('E${row + 1}'));
    _setCell(sheet, 0, row, 'ĐƠN NHẬP HÀNG', bold: true, fontSize: 14);
    row++;
    _setCell(sheet, 0, row, 'Số: ${po.poNumber ?? 'N/A'}');
    row++;
    _setCell(sheet, 0, row, 'Ngày: ${AppFormatter.formatDate(po.orderDate)}');
    row++;
    row++;

    // Supplier
    _setCell(sheet, 0, row, 'Nhà cung cấp: ${supplier?.name ?? 'N/A'}');
    row++;
    row++;

    // Table Header
    _setCell(sheet, 0, row, 'STT', bold: true);
    _setCell(sheet, 1, row, 'Tên sản phẩm', bold: true);
    _setCell(sheet, 2, row, 'SL', bold: true);
    _setCell(sheet, 3, row, 'Đơn giá', bold: true);
    _setCell(sheet, 4, row, 'Thành tiền', bold: true);
    row++;

    // Items
    for (var i = 0; i < data.items.length; i++) {
      final item = data.items[i];
      _setCell(sheet, 0, row, (i + 1).toString());
      _setCell(sheet, 1, row, item.productName);
      _setCell(sheet, 2, row, item.quantityDisplay);
      _setCell(sheet, 3, row, AppFormatter.formatCurrency(item.pricePerUnit));
      _setCell(sheet, 4, row, AppFormatter.formatCurrency(item.subTotal));
      row++;
    }

    row++;

    // Total
    _setCell(sheet, 3, row, 'Tổng cộng:', bold: true);
    _setCell(sheet, 4, row, AppFormatter.formatCurrency(po.totalAmount), bold: true);
  }

  /// Build Transactions Report Excel
  void _buildTransactionsReportExcel(
    excel_pkg.Sheet sheet,
    List<Map<String, dynamic>> transactions,
    DateTime startDate,
    DateTime endDate,
  ) {
    int row = 0;

    // Title
    sheet.merge(excel_pkg.CellIndex.indexByString('A${row + 1}'), excel_pkg.CellIndex.indexByString('G${row + 1}'));
    _setCell(sheet, 0, row, 'BÁO CÁO GIAO DỊCH', bold: true, fontSize: 16);
    row++;
    _setCell(sheet, 0, row, 'Từ ${AppFormatter.formatDate(startDate)} đến ${AppFormatter.formatDate(endDate)}');
    row++;
    row++;

    // Header
    _setCell(sheet, 0, row, 'STT', bold: true);
    _setCell(sheet, 1, row, 'Ngày', bold: true);
    _setCell(sheet, 2, row, 'Mã hóa đơn', bold: true);
    _setCell(sheet, 3, row, 'Khách hàng', bold: true);
    _setCell(sheet, 4, row, 'Sản phẩm', bold: true);
    _setCell(sheet, 5, row, 'Số lượng', bold: true);
    _setCell(sheet, 6, row, 'Tổng tiền', bold: true);
    row++;

    // Data
    for (var i = 0; i < transactions.length; i++) {
      final txData = transactions[i];
      final tx = txData['transaction'] as Map<String, dynamic>;
      final customerName = txData['customer_name'] ?? 'Khách lẻ';
      final items = txData['items'] as List<dynamic>? ?? [];

      // First item row
      if (items.isNotEmpty) {
        final firstItem = items[0] as Map<String, dynamic>;
        _setCell(sheet, 0, row, (i + 1).toString());
        _setCell(sheet, 1, row, AppFormatter.formatDate(DateTime.parse(tx['transaction_date'])));
        _setCell(sheet, 2, row, tx['invoice_number'] ?? 'N/A');
        _setCell(sheet, 3, row, customerName);
        _setCell(sheet, 4, row, firstItem['product_name'] ?? '');
        _setCell(sheet, 5, row, '${firstItem['quantity']} ${firstItem['unit_name'] ?? ''}');
        _setCell(sheet, 6, row, AppFormatter.formatCurrency((tx['total_amount'] as num).toDouble()));
        row++;

        // Additional items
        for (var j = 1; j < items.length; j++) {
          final item = items[j] as Map<String, dynamic>;
          _setCell(sheet, 4, row, item['product_name'] ?? '');
          _setCell(sheet, 5, row, '${item['quantity']} ${item['unit_name'] ?? ''}');
          row++;
        }
      } else {
        _setCell(sheet, 0, row, (i + 1).toString());
        _setCell(sheet, 1, row, AppFormatter.formatDate(DateTime.parse(tx['transaction_date'])));
        _setCell(sheet, 2, row, tx['invoice_number'] ?? 'N/A');
        _setCell(sheet, 3, row, customerName);
        _setCell(sheet, 6, row, AppFormatter.formatCurrency((tx['total_amount'] as num).toDouble()));
        row++;
      }
    }
  }

  // Excel Helper: Set cell value with formatting
  void _setCell(excel_pkg.Sheet sheet, int col, int row, String value, {bool bold = false, int? fontSize}) {
    final cell = sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = excel_pkg.TextCellValue(value);

    if (bold || fontSize != null) {
      cell.cellStyle = excel_pkg.CellStyle(
        bold: bold,
        fontSize: fontSize,
      );
    }
  }
}
