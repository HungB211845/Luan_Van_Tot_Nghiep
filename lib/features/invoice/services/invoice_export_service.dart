import 'dart:io';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../../shared/utils/formatter.dart';
import '../../../shared/utils/file_naming_helper.dart';
import '../../auth/screens/invoice_settings_screen.dart'; // For DateRangePreset
import '../models/invoice_data.dart';
import 'invoice_template_builder.dart';

/// Service for exporting invoices to PDF and Excel formats
/// Updated: 2025-10-22 - Using InvoiceTemplateBuilder for VAT-compliant invoices
class InvoiceExportService {
  /// Generate PDF invoice for transaction (VAT-compliant)
  ///
  /// Returns File object that can be shared or printed
  Future<File> generateTransactionPDF(InvoiceData data) async {
    // Use new template builder for VAT-compliant invoice
    final pdf = await InvoiceTemplateBuilder.buildVATInvoicePDF(data);

    // Generate accounting-compliant filename
    final businessName = data.storeInfo?.businessName ?? FileNamingHelper.getFallbackBusinessName();
    final invoiceNumber = data.invoiceNumber ?? 'INV${DateTime.now().millisecondsSinceEpoch}';
    final filename = FileNamingHelper.generateTransactionInvoiceFilename(
      businessName: businessName,
      invoiceNumber: invoiceNumber,
      format: 'pdf',
    );

    // Save to temp directory
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(await pdf.save());

    return file;
  }

  /// Generate Excel invoice for transaction
  Future<File> generateTransactionExcel(InvoiceData data) async {
    final excel = excel_pkg.Excel.createExcel();
    final sheet = excel['Hóa đơn'];

    _buildTransactionExcelContent(sheet, data);

    // Generate accounting-compliant filename
    final businessName = data.storeInfo?.businessName ?? FileNamingHelper.getFallbackBusinessName();
    final invoiceNumber = data.invoiceNumber ?? 'INV${DateTime.now().millisecondsSinceEpoch}';
    final filename = FileNamingHelper.generateTransactionInvoiceFilename(
      businessName: businessName,
      invoiceNumber: invoiceNumber,
      format: 'xlsx',
    );

    // Save to temp directory
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$filename');
    final bytes = excel.encode();
    if (bytes != null) {
      await file.writeAsBytes(bytes);
    }

    return file;
  }

  /// Generate PDF invoice for Purchase Order (VAT-compliant)
  Future<File> generatePOPDF(InvoiceData data) async {
    // Use new template builder for PO invoice
    final pdf = await InvoiceTemplateBuilder.buildPOInvoicePDF(data);

    // Generate accounting-compliant filename
    final businessName = data.storeInfo?.businessName ?? FileNamingHelper.getFallbackBusinessName();
    final poNumber = data.invoiceNumber ?? 'PO${DateTime.now().millisecondsSinceEpoch}';
    final filename = FileNamingHelper.generatePOInvoiceFilename(
      businessName: businessName,
      poNumber: poNumber,
      format: 'pdf',
    );

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(await pdf.save());

    return file;
  }

  /// Generate Excel invoice for Purchase Order
  Future<File> generatePOExcel(InvoiceData data) async {
    final excel = excel_pkg.Excel.createExcel();
    final sheet = excel['Đơn nhập hàng'];

    _buildPOExcelContent(sheet, data);

    // Generate accounting-compliant filename
    final businessName = data.storeInfo?.businessName ?? FileNamingHelper.getFallbackBusinessName();
    final poNumber = data.invoiceNumber ?? 'PO${DateTime.now().millisecondsSinceEpoch}';
    final filename = FileNamingHelper.generatePOInvoiceFilename(
      businessName: businessName,
      poNumber: poNumber,
      format: 'xlsx',
    );

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$filename');
    final bytes = excel.encode();
    if (bytes != null) {
      await file.writeAsBytes(bytes);
    }

    return file;
  }

  /// Export multiple transactions to Excel report (2 sheets: Summary + Detail)
  ///
  /// Sheet 1: "Tổng hợp theo ngày" - Grouped by date + product
  /// Sheet 2: "Chi tiết hóa đơn" - All transaction details
  Future<File> exportTransactionsReport({
    required List<Map<String, dynamic>> transactions,
    required DateTime startDate,
    required DateTime endDate,
    String? businessName,
    DateRangePreset? preset,
  }) async {
    final excel = excel_pkg.Excel.createExcel();

    // Remove default sheet
    excel.delete('Sheet1');

    // Create Sheet 1: Tổng hợp theo ngày (Summary)
    final summarySheet = excel['Tổng hợp theo ngày'];
    _buildSummarySheet(summarySheet, transactions, startDate, endDate);

    // Create Sheet 2: Chi tiết hóa đơn (Detail)
    final detailSheet = excel['Chi tiết hóa đơn'];
    _buildDetailSheet(detailSheet, transactions, startDate, endDate);

    // Generate accounting-compliant filename
    final name = businessName ?? FileNamingHelper.getFallbackBusinessName();
    final filename = FileNamingHelper.generateTransactionReportFilename(
      businessName: name,
      startDate: startDate,
      endDate: endDate,
      format: 'xlsx',
      preset: preset,
    );

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$filename');
    final bytes = excel.encode();
    if (bytes != null) {
      await file.writeAsBytes(bytes);
    }

    return file;
  }

  /// Export multiple transactions to PDF report (2 pages: Summary + Detail)
  ///
  /// Page 1: "Tổng hợp theo ngày" - Grouped by date + product
  /// Page 2: "Chi tiết hóa đơn" - All transaction details
  Future<File> exportTransactionsReportPDF({
    required List<Map<String, dynamic>> transactions,
    required DateTime startDate,
    required DateTime endDate,
    String? businessName,
    DateRangePreset? preset,
  }) async {
    // Ensure fonts are loaded
    await InvoiceTemplateBuilder.loadFonts();

    final pdf = await InvoiceTemplateBuilder.buildTransactionsReportPDF(
      transactions: transactions,
      startDate: startDate,
      endDate: endDate,
    );

    // Generate accounting-compliant filename
    final name = businessName ?? FileNamingHelper.getFallbackBusinessName();
    final filename = FileNamingHelper.generateTransactionReportFilename(
      businessName: name,
      startDate: startDate,
      endDate: endDate,
      format: 'pdf',
      preset: preset,
    );

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(await pdf.save());

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
  // EXCEL TEMPLATE BUILDERS (WITH VAT SUPPORT)
  // ======================================

  /// Build Transaction Excel content (with VAT columns)
  void _buildTransactionExcelContent(excel_pkg.Sheet sheet, InvoiceData data) {
    final storeInfo = data.storeInfo;
    final transaction = data.transaction!;
    final customer = data.customer;
    final hasVAT = (data.vatTotal ?? 0) > 0;

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

    // Table Header (with VAT if applicable)
    if (hasVAT) {
      _setCell(sheet, 0, row, 'STT', bold: true);
      _setCell(sheet, 1, row, 'Tên sản phẩm', bold: true);
      _setCell(sheet, 2, row, 'SL', bold: true);
      _setCell(sheet, 3, row, 'ĐVT', bold: true);
      _setCell(sheet, 4, row, 'Đơn giá', bold: true);
      _setCell(sheet, 5, row, 'Thành tiền', bold: true);
      _setCell(sheet, 6, row, 'Thuế %', bold: true);
      _setCell(sheet, 7, row, 'Tiền thuế', bold: true);
      _setCell(sheet, 8, row, 'Tổng cộng', bold: true);
    } else {
      _setCell(sheet, 0, row, 'STT', bold: true);
      _setCell(sheet, 1, row, 'Tên sản phẩm', bold: true);
      _setCell(sheet, 2, row, 'SL', bold: true);
      _setCell(sheet, 3, row, 'ĐVT', bold: true);
      _setCell(sheet, 4, row, 'Đơn giá', bold: true);
      _setCell(sheet, 5, row, 'Thành tiền', bold: true);
    }
    row++;

    // Items
    for (var i = 0; i < data.items.length; i++) {
      final item = data.items[i];
      if (hasVAT) {
        _setCell(sheet, 0, row, (i + 1).toString());
        _setCell(sheet, 1, row, item.productName);
        _setCell(sheet, 2, row, item.quantity.toString());
        _setCell(sheet, 3, row, item.unitName ?? 'đvt');
        _setCell(sheet, 4, row, AppFormatter.formatCurrency(item.pricePerUnit));
        _setCell(sheet, 5, row, AppFormatter.formatCurrency(item.subTotal));
        _setCell(sheet, 6, row, item.taxRate > 0 ? '${item.taxRate.toStringAsFixed(0)}%' : '-');
        _setCell(sheet, 7, row, item.taxAmount > 0 ? AppFormatter.formatCurrency(item.taxAmount) : '-');
        _setCell(sheet, 8, row, AppFormatter.formatCurrency(item.grossAmount));
      } else {
        _setCell(sheet, 0, row, (i + 1).toString());
        _setCell(sheet, 1, row, item.productName);
        _setCell(sheet, 2, row, item.quantity.toString());
        _setCell(sheet, 3, row, item.unitName ?? 'đvt');
        _setCell(sheet, 4, row, AppFormatter.formatCurrency(item.pricePerUnit));
        _setCell(sheet, 5, row, AppFormatter.formatCurrency(item.subTotal));
      }
      row++;
    }

    row++; // Empty row

    // Total
    final offset = hasVAT ? 7 : 4;
    _setCell(sheet, offset, row, 'Tổng cộng:', bold: true);
    _setCell(sheet, offset + 1, row, AppFormatter.formatCurrency(transaction.totalAmount), bold: true);
    row++;

    if (hasVAT && data.vatTotal != null && data.vatTotal! > 0) {
      _setCell(sheet, offset, row, 'Thuế GTGT:', bold: true);
      _setCell(sheet, offset + 1, row, AppFormatter.formatCurrency(data.vatTotal!), bold: true);
      row++;

      _setCell(sheet, offset, row, 'TỔNG THANH TOÁN:', bold: true);
      _setCell(sheet, offset + 1, row, AppFormatter.formatCurrency(data.totalWithVat), bold: true);
    }
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

  /// Build Summary Sheet (Grouped by date + product)
  void _buildSummarySheet(
    excel_pkg.Sheet sheet,
    List<Map<String, dynamic>> transactions,
    DateTime startDate,
    DateTime endDate,
  ) {
    int row = 0;

    // Title
    sheet.merge(excel_pkg.CellIndex.indexByString('A${row + 1}'), excel_pkg.CellIndex.indexByString('H${row + 1}'));
    _setCell(sheet, 0, row, 'BÁO CÁO TỔNG HỢP THEO NGÀY', bold: true, fontSize: 16);
    row++;
    _setCell(sheet, 0, row, 'Từ ${AppFormatter.formatDate(startDate)} đến ${AppFormatter.formatDate(endDate)}');
    row++;
    row++;

    // Header
    _setCell(sheet, 0, row, 'Ngày', bold: true);
    _setCell(sheet, 1, row, 'Tên hàng', bold: true);
    _setCell(sheet, 2, row, 'ĐVT', bold: true);
    _setCell(sheet, 3, row, 'Tổng SL', bold: true);
    _setCell(sheet, 4, row, 'Tổng tiền hàng', bold: true);
    _setCell(sheet, 5, row, 'Tổng thuế', bold: true);
    _setCell(sheet, 6, row, 'Tổng cộng', bold: true);
    _setCell(sheet, 7, row, 'Danh sách số HĐ', bold: true);
    row++;

    // Group transactions by (date, product)
    final Map<String, Map<String, dynamic>> grouped = {};

    for (var txData in transactions) {
      final tx = txData['transaction'] as Map<String, dynamic>;
      final items = txData['items'] as List<dynamic>? ?? [];
      final date = DateTime.parse(tx['transaction_date']).toIso8601String().split('T')[0];
      final invoiceNumber = tx['invoice_number'] ?? 'N/A';

      for (var itemData in items) {
        final item = itemData as Map<String, dynamic>;
        final productName = item['product_name'] ?? 'Unknown';
        final key = '$date|$productName';

        if (!grouped.containsKey(key)) {
          grouped[key] = {
            'date': date,
            'product_name': productName,
            'unit_name': item['unit_name'] ?? 'đvt',
            'total_quantity': 0,
            'total_subtotal': 0.0,
            'total_tax': 0.0,
            'total_gross': 0.0,
            'invoice_numbers': <String>{},
          };
        }

        grouped[key]!['total_quantity'] += item['quantity'] as int;
        grouped[key]!['total_subtotal'] += (item['sub_total'] as num).toDouble();
        grouped[key]!['total_tax'] += (item['tax_amount'] as num?)?.toDouble() ?? 0.0;
        grouped[key]!['total_gross'] += (item['gross_amount'] as num?)?.toDouble() ?? 0.0;
        (grouped[key]!['invoice_numbers'] as Set<String>).add(invoiceNumber);
      }
    }

    // Sort by date DESC
    final sortedEntries = grouped.entries.toList()
      ..sort((a, b) => b.value['date'].compareTo(a.value['date']));

    // Write grouped data
    for (var entry in sortedEntries) {
      final data = entry.value;
      _setCell(sheet, 0, row, data['date']);
      _setCell(sheet, 1, row, data['product_name']);
      _setCell(sheet, 2, row, data['unit_name']);
      _setCell(sheet, 3, row, data['total_quantity'].toString());
      _setCell(sheet, 4, row, AppFormatter.formatCurrency(data['total_subtotal']));
      _setCell(sheet, 5, row, AppFormatter.formatCurrency(data['total_tax']));
      _setCell(sheet, 6, row, AppFormatter.formatCurrency(data['total_gross']));
      _setCell(sheet, 7, row, (data['invoice_numbers'] as Set<String>).join('; '));
      row++;
    }
  }

  /// Build Detail Sheet (All transaction details)
  void _buildDetailSheet(
    excel_pkg.Sheet sheet,
    List<Map<String, dynamic>> transactions,
    DateTime startDate,
    DateTime endDate,
  ) {
    int row = 0;

    // Title
    sheet.merge(excel_pkg.CellIndex.indexByString('A${row + 1}'), excel_pkg.CellIndex.indexByString('J${row + 1}'));
    _setCell(sheet, 0, row, 'BÁO CÁO CHI TIẾT HÓA ĐƠN', bold: true, fontSize: 16);
    row++;
    _setCell(sheet, 0, row, 'Từ ${AppFormatter.formatDate(startDate)} đến ${AppFormatter.formatDate(endDate)}');
    row++;
    row++;

    // Header
    _setCell(sheet, 0, row, 'STT', bold: true);
    _setCell(sheet, 1, row, 'Ngày', bold: true);
    _setCell(sheet, 2, row, 'Số HĐ', bold: true);
    _setCell(sheet, 3, row, 'Khách hàng', bold: true);
    _setCell(sheet, 4, row, 'Sản phẩm', bold: true);
    _setCell(sheet, 5, row, 'Số lượng', bold: true);
    _setCell(sheet, 6, row, 'Đơn giá', bold: true);
    _setCell(sheet, 7, row, 'Thuế suất %', bold: true);
    _setCell(sheet, 8, row, 'Tiền thuế', bold: true);
    _setCell(sheet, 9, row, 'Thành tiền', bold: true);
    row++;

    // Data
    int stt = 1;
    for (var txData in transactions) {
      final tx = txData['transaction'] as Map<String, dynamic>;
      final customerName = txData['customer_name'] ?? 'Khách lẻ';
      final items = txData['items'] as List<dynamic>? ?? [];

      for (var itemData in items) {
        final item = itemData as Map<String, dynamic>;
        _setCell(sheet, 0, row, stt.toString());
        _setCell(sheet, 1, row, AppFormatter.formatDate(DateTime.parse(tx['transaction_date'])));
        _setCell(sheet, 2, row, tx['invoice_number'] ?? 'N/A');
        _setCell(sheet, 3, row, customerName);
        _setCell(sheet, 4, row, item['product_name'] ?? '');
        _setCell(sheet, 5, row, '${item['quantity']} ${item['unit_name'] ?? ''}');
        _setCell(sheet, 6, row, AppFormatter.formatCurrency((item['price_at_sale'] as num).toDouble()));
        _setCell(
          sheet,
          7,
          row,
          ((item['tax_rate'] as num?)?.toDouble() ?? 0) > 0
              ? '${((item['tax_rate'] as num).toDouble()).toStringAsFixed(0)}%'
              : '-',
        );
        _setCell(
          sheet,
          8,
          row,
          ((item['tax_amount'] as num?)?.toDouble() ?? 0) > 0
              ? AppFormatter.formatCurrency((item['tax_amount'] as num).toDouble())
              : '-',
        );
        _setCell(sheet, 9, row, AppFormatter.formatCurrency((item['gross_amount'] as num).toDouble()));
        row++;
        stt++;
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
