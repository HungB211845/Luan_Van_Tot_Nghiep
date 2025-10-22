import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../shared/utils/formatter.dart';
import '../../../shared/utils/number_to_words.dart';
import '../models/invoice_data.dart';

/// PDF Template Builder for Vietnamese VAT Invoices
/// Compliant with NĐ 123/2020, NĐ 70/2025, TT 32/2025
///
/// Generates professional PDF invoices with:
/// - Unicode font support (Roboto)
/// - VAT calculations per legal requirements
/// - Proper invoice symbol & template code display
/// - Vietnamese number-to-words conversion
class InvoiceTemplateBuilder {
  // Cached fonts for performance
  static pw.Font? _fontRegular;
  static pw.Font? _fontBold;
  static pw.Font? _fontItalic;

  /// Load Roboto fonts (call once at app startup or lazy load)
  static Future<void> loadFonts() async {
    if (_fontRegular != null) return; // Already loaded

    final regularData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    final italicData = await rootBundle.load('assets/fonts/Roboto-Italic.ttf');

    _fontRegular = pw.Font.ttf(regularData);
    _fontBold = pw.Font.ttf(boldData);
    _fontItalic = pw.Font.ttf(italicData);
  }

  /// Build VAT Invoice PDF for Transaction
  ///
  /// Layout follows Vietnamese invoice standard (mẫu hóa đơn GTGT):
  /// 1. Header: Store info + Invoice symbol/number (right aligned)
  /// 2. Title: "HÓA ĐƠN GIÁ TRỊ GIA TĂNG"
  /// 3. Two-column info: Seller / Buyer
  /// 4. 9-column table: STT - Tên HH - ĐVT - SL - Đơn giá - Thành tiền - Thuế % - Tiền thuế - Tổng cộng
  /// 5. Summary: Subtotal, VAT (hidden if 0%), Total, Amount in words
  /// 6. Footer: Signature blocks
  static Future<pw.Document> buildVATInvoicePDF(InvoiceData data) async {
    // Ensure fonts are loaded
    await loadFonts();

    final pdf = pw.Document();
    final storeInfo = data.storeInfo;
    final transaction = data.transaction;
    final customer = data.customer;
    final hasVAT = (data.vatTotal ?? 0) > 0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ===== HEADER SECTION =====
            _buildHeader(storeInfo, data.invoiceSymbol, data.invoiceNumber),
            pw.SizedBox(height: 16),
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 16),

            // ===== TITLE SECTION =====
            _buildTitle(data.invoiceDate),
            pw.SizedBox(height: 16),

            // ===== SELLER/BUYER INFO =====
            _buildTwoColumnInfo(storeInfo, customer, transaction),
            pw.SizedBox(height: 16),

            // ===== ITEMS TABLE =====
            _buildItemsTable(data.items, hasVAT),
            pw.SizedBox(height: 12),

            // ===== SUMMARY SECTION =====
            _buildSummary(data.totalAmount, data.vatTotal, data.totalWithVat, hasVAT),

            pw.Spacer(),

            // ===== SIGNATURE SECTION =====
            _buildSignatures(data.invoiceDate),
          ],
        ),
      ),
    );

    return pdf;
  }

  /// Build Purchase Order Invoice PDF (similar structure, different labels)
  static Future<pw.Document> buildPOInvoicePDF(InvoiceData data) async {
    await loadFonts();

    final pdf = pw.Document();
    final storeInfo = data.storeInfo;
    final po = data.purchaseOrder;
    final supplier = data.supplier;
    final hasVAT = (data.vatTotal ?? 0) > 0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(storeInfo, data.invoiceSymbol, po?.poNumber),
            pw.SizedBox(height: 16),
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 16),

            // Title (Purchase Order)
            pw.Center(
              child: pw.Column(
                children: [
                  _text('ĐƠN NHẬP HÀNG', fontSize: 18, fontWeight: pw.FontWeight.bold),
                  pw.SizedBox(height: 6),
                  _text('Số: ${po?.poNumber ?? 'N/A'}', fontSize: 11),
                  _text('Ngày: ${AppFormatter.formatDate(po?.orderDate ?? DateTime.now())}', fontSize: 11),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Buyer/Supplier Info
            _buildPOInfo(storeInfo, supplier),
            pw.SizedBox(height: 16),

            // Items Table
            _buildItemsTable(data.items, hasVAT),
            pw.SizedBox(height: 12),

            // Summary
            _buildSummary(data.totalAmount, data.vatTotal, data.totalWithVat, hasVAT),

            pw.Spacer(),

            // Signatures (different labels for PO)
            _buildPOSignatures(po?.orderDate ?? DateTime.now()),
          ],
        ),
      ),
    );

    return pdf;
  }

  // ===== PRIVATE BUILDERS =====

  /// Build header with store info (left) and invoice symbol/number (right)
  static pw.Widget _buildHeader(dynamic storeInfo, String? invoiceSymbol, String? invoiceNumber) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Left: Store info
        pw.Expanded(
          flex: 3,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _text(
                storeInfo?.businessName ?? 'TÊN DOANH NGHIỆP',
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
              if (storeInfo?.businessAddress != null) ...[
                pw.SizedBox(height: 4),
                _text('Địa chỉ: ${storeInfo.businessAddress}', fontSize: 9),
              ],
              if (storeInfo?.taxCode != null) ...[
                pw.SizedBox(height: 2),
                _text('MST: ${storeInfo.taxCode}', fontSize: 9),
              ],
              if (storeInfo?.phoneNumber != null || storeInfo?.email != null) ...[
                pw.SizedBox(height: 2),
                _text(
                  '${storeInfo?.phoneNumber ?? ''} ${storeInfo?.email ?? ''}'.trim(),
                  fontSize: 9,
                ),
              ],
              if (storeInfo?.bankAccount != null && storeInfo?.bankName != null) ...[
                pw.SizedBox(height: 2),
                _text('STK: ${storeInfo.bankAccount} - ${storeInfo.bankName}', fontSize: 9),
                if (storeInfo?.bankBranch != null)
                  _text('Chi nhánh: ${storeInfo.bankBranch}', fontSize: 9),
              ],
            ],
          ),
        ),

        // Right: Invoice symbol & number
        pw.Expanded(
          flex: 2,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              if (invoiceSymbol != null) _text('Ký hiệu: $invoiceSymbol', fontSize: 10),
              if (invoiceNumber != null) ...[
                pw.SizedBox(height: 2),
                _text('Số: $invoiceNumber', fontSize: 10, fontWeight: pw.FontWeight.bold),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Build title section
  static pw.Widget _buildTitle(DateTime invoiceDate) {
    return pw.Center(
      child: pw.Column(
        children: [
          _text(
            'HÓA ĐƠN GIÁ TRỊ GIA TĂNG',
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
          pw.SizedBox(height: 4),
          _text(
            'Ngày ${invoiceDate.day} tháng ${invoiceDate.month} năm ${invoiceDate.year}',
            fontSize: 10,
            fontStyle: pw.FontStyle.italic,
          ),
        ],
      ),
    );
  }

  /// Build two-column info (Seller / Buyer)
  static pw.Widget _buildTwoColumnInfo(dynamic storeInfo, dynamic customer, dynamic transaction) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Left column: Seller
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _text('Đơn vị bán hàng:', fontSize: 10, fontWeight: pw.FontWeight.bold),
              _text('Tên: ${storeInfo?.businessName ?? '...'}', fontSize: 9),
              if (storeInfo?.businessAddress != null)
                _text('Địa chỉ: ${storeInfo.businessAddress}', fontSize: 9),
              if (storeInfo?.taxCode != null) _text('MST: ${storeInfo.taxCode}', fontSize: 9),
            ],
          ),
        ),

        pw.SizedBox(width: 16),

        // Right column: Buyer
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _text('Họ tên người mua hàng:', fontSize: 10, fontWeight: pw.FontWeight.bold),
              _text('Tên: ${customer?.name ?? 'Khách lẻ'}', fontSize: 9),
              if (customer?.address != null) _text('Địa chỉ: ${customer.address}', fontSize: 9),
              if (customer?.phone != null) _text('SĐT: ${customer.phone}', fontSize: 9),
              _text(
                'Hình thức thanh toán: ${_getPaymentMethodLabel(transaction?.paymentMethod.value)}',
                fontSize: 9,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build PO-specific info (Buyer / Supplier)
  static pw.Widget _buildPOInfo(dynamic storeInfo, dynamic supplier) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _text('Đơn vị mua hàng: ${storeInfo?.businessName ?? '...'}', fontSize: 10),
        pw.SizedBox(height: 8),
        _text('Nhà cung cấp:', fontSize: 10, fontWeight: pw.FontWeight.bold),
        _text('Tên: ${supplier?.name ?? 'N/A'}', fontSize: 9),
        if (supplier?.address != null) _text('Địa chỉ: ${supplier.address}', fontSize: 9),
        if (supplier?.phone != null) _text('SĐT: ${supplier.phone}', fontSize: 9),
        // NOTE: taxCode removed - Company model doesn't have this field
      ],
    );
  }

  /// Build items table (9 columns with VAT, or 6 columns without VAT)
  static pw.Widget _buildItemsTable(List<dynamic> items, bool hasVAT) {
    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: hasVAT
          ? {
              0: const pw.FixedColumnWidth(25), // STT
              1: const pw.FlexColumnWidth(3), // Tên hàng
              2: const pw.FixedColumnWidth(35), // ĐVT
              3: const pw.FixedColumnWidth(30), // SL
              4: const pw.FlexColumnWidth(2), // Đơn giá
              5: const pw.FlexColumnWidth(2), // Thành tiền
              6: const pw.FixedColumnWidth(35), // Thuế %
              7: const pw.FlexColumnWidth(2), // Tiền thuế
              8: const pw.FlexColumnWidth(2), // Tổng cộng
            }
          : {
              0: const pw.FixedColumnWidth(25),
              1: const pw.FlexColumnWidth(4),
              2: const pw.FixedColumnWidth(40),
              3: const pw.FixedColumnWidth(35),
              4: const pw.FlexColumnWidth(2),
              5: const pw.FlexColumnWidth(2),
            },
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: hasVAT
              ? [
                  _tableCell('STT', bold: true, center: true),
                  _tableCell('Tên hàng hóa, dịch vụ', bold: true),
                  _tableCell('ĐVT', bold: true, center: true),
                  _tableCell('SL', bold: true, center: true),
                  _tableCell('Đơn giá', bold: true, right: true),
                  _tableCell('Thành tiền', bold: true, right: true),
                  _tableCell('Thuế suất', bold: true, center: true),
                  _tableCell('Tiền thuế', bold: true, right: true),
                  _tableCell('Tổng cộng', bold: true, right: true),
                ]
              : [
                  _tableCell('STT', bold: true, center: true),
                  _tableCell('Tên hàng hóa, dịch vụ', bold: true),
                  _tableCell('ĐVT', bold: true, center: true),
                  _tableCell('SL', bold: true, center: true),
                  _tableCell('Đơn giá', bold: true, right: true),
                  _tableCell('Thành tiền', bold: true, right: true),
                ],
        ),

        // Data rows
        ...items.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final item = entry.value;

          return pw.TableRow(
            children: hasVAT
                ? [
                    _tableCell(index.toString(), center: true),
                    _tableCell(item.productName),
                    _tableCell(item.unitName ?? 'đvt', center: true),
                    _tableCell(item.quantity.toString(), center: true),
                    _tableCell(AppFormatter.formatCurrency(item.pricePerUnit), right: true),
                    _tableCell(AppFormatter.formatCurrency(item.subTotal), right: true),
                    _tableCell(item.taxRate > 0 ? '${item.taxRate.toStringAsFixed(0)}%' : '-', center: true),
                    _tableCell(
                      item.taxAmount > 0 ? AppFormatter.formatCurrency(item.taxAmount) : '-',
                      right: true,
                    ),
                    _tableCell(AppFormatter.formatCurrency(item.grossAmount), right: true),
                  ]
                : [
                    _tableCell(index.toString(), center: true),
                    _tableCell(item.productName),
                    _tableCell(item.unitName ?? 'đvt', center: true),
                    _tableCell(item.quantity.toString(), center: true),
                    _tableCell(AppFormatter.formatCurrency(item.pricePerUnit), right: true),
                    _tableCell(AppFormatter.formatCurrency(item.subTotal), right: true),
                  ],
          );
        }),
      ],
    );
  }

  /// Build summary section (Subtotal, VAT, Total, Words)
  static pw.Widget _buildSummary(double subtotal, double? vatAmount, double total, bool hasVAT) {
    final amountInWords = NumberToVietnameseWords.convertToVietnameseWords(total);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        // Subtotal (always show)
        _summaryRow('Cộng tiền hàng:', subtotal),

        // VAT (conditional - hidden if 0%)
        if (hasVAT && vatAmount != null && vatAmount > 0) ...[
          pw.SizedBox(height: 4),
          _summaryRow('Thuế GTGT:', vatAmount),
        ],

        pw.SizedBox(height: 4),
        pw.Divider(thickness: 0.5),
        pw.SizedBox(height: 4),

        // Total (bold)
        _summaryRow('TỔNG CỘNG THANH TOÁN:', total, bold: true),

        pw.SizedBox(height: 8),

        // Amount in words
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(width: 0.5),
            color: PdfColors.grey100,
          ),
          child: pw.Row(
            children: [
              _text('Số tiền viết bằng chữ: ', fontSize: 9, fontStyle: pw.FontStyle.italic),
              pw.Expanded(
                child: _text(
                  amountInWords,
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build signature section
  static pw.Widget _buildSignatures(DateTime date) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Buyer signature
        pw.Column(
          children: [
            _text('Người mua hàng', fontSize: 9, fontWeight: pw.FontWeight.bold),
            _text('(Ký, ghi rõ họ tên)', fontSize: 8, fontStyle: pw.FontStyle.italic),
            pw.SizedBox(height: 50), // Space for signature
          ],
        ),

        // Seller signature
        pw.Column(
          children: [
            _text('Người bán hàng', fontSize: 9, fontWeight: pw.FontWeight.bold),
            _text('(Ký, ghi rõ họ tên)', fontSize: 8, fontStyle: pw.FontStyle.italic),
            pw.SizedBox(height: 50),
          ],
        ),
      ],
    );
  }

  /// Build PO-specific signatures
  static pw.Widget _buildPOSignatures(DateTime date) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
      children: [
        pw.Column(
          children: [
            _text('Người lập', fontSize: 9, fontWeight: pw.FontWeight.bold),
            _text('(Ký, họ tên)', fontSize: 8, fontStyle: pw.FontStyle.italic),
            pw.SizedBox(height: 50),
          ],
        ),
        pw.Column(
          children: [
            _text('Người duyệt', fontSize: 9, fontWeight: pw.FontWeight.bold),
            _text('(Ký, họ tên)', fontSize: 8, fontStyle: pw.FontStyle.italic),
            pw.SizedBox(height: 50),
          ],
        ),
      ],
    );
  }

  // ===== HELPER WIDGETS =====

  /// Create text widget with Roboto font
  static pw.Widget _text(
    String text, {
    double fontSize = 10,
    pw.FontWeight? fontWeight,
    pw.FontStyle? fontStyle,
    pw.TextAlign? textAlign,
  }) {
    pw.Font? font = _fontRegular;

    if (fontWeight == pw.FontWeight.bold && fontStyle == pw.FontStyle.italic) {
      font = _fontBold; // Use bold for bold+italic (no bold-italic variant)
    } else if (fontWeight == pw.FontWeight.bold) {
      font = _fontBold;
    } else if (fontStyle == pw.FontStyle.italic) {
      font = _fontItalic;
    }

    return pw.Text(
      text,
      style: pw.TextStyle(
        font: font,
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
      ),
      textAlign: textAlign,
    );
  }

  /// Create table cell
  static pw.Widget _tableCell(
    String text, {
    bool bold = false,
    bool center = false,
    bool right = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: _text(
        text,
        fontSize: 8,
        fontWeight: bold ? pw.FontWeight.bold : null,
        textAlign: center
            ? pw.TextAlign.center
            : right
                ? pw.TextAlign.right
                : pw.TextAlign.left,
      ),
    );
  }

  /// Create summary row
  static pw.Widget _summaryRow(String label, double amount, {bool bold = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        _text(label, fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : null),
        pw.SizedBox(width: 16),
        pw.Container(
          width: 120,
          alignment: pw.Alignment.centerRight,
          child: _text(
            AppFormatter.formatCurrency(amount),
            fontSize: 10,
            fontWeight: bold ? pw.FontWeight.bold : null,
          ),
        ),
      ],
    );
  }

  /// Get payment method label
  static String _getPaymentMethodLabel(String? method) {
    switch (method?.toUpperCase()) {
      case 'CASH':
        return 'Tiền mặt (TM)';
      case 'BANK_TRANSFER':
        return 'Chuyển khoản (CK)';
      case 'DEBT':
        return 'Ghi nợ';
      default:
        return 'N/A';
    }
  }

  /// Build Transactions Report PDF (2 pages: Summary + Detail)
  ///
  /// Page 1: Grouped summary by date + product
  /// Page 2: Detail table of all transactions
  static Future<pw.Document> buildTransactionsReportPDF({
    required List<Map<String, dynamic>> transactions,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    await loadFonts();

    final pdf = pw.Document();

    // Page 1: Summary Report
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Title
              pw.Center(
                child: _text(
                  'BÁO CÁO TỔNG HỢP THEO NGÀY',
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Center(
                child: _text(
                  'Từ ${AppFormatter.formatDate(startDate)} đến ${AppFormatter.formatDate(endDate)}',
                  fontSize: 10,
                ),
              ),
              pw.SizedBox(height: 16),

              // Summary Table
              _buildSummaryPDFTable(transactions),
            ],
          );
        },
      ),
    );

    // Page 2: Detail Report
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return [
            // Title
            pw.Center(
              child: _text(
                'BÁO CÁO CHI TIẾT HÓA ĐƠN',
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Center(
              child: _text(
                'Từ ${AppFormatter.formatDate(startDate)} đến ${AppFormatter.formatDate(endDate)}',
                fontSize: 10,
              ),
            ),
            pw.SizedBox(height: 16),

            // Detail Table
            _buildDetailPDFTable(transactions),
          ];
        },
      ),
    );

    return pdf;
  }

  /// Build Summary PDF Table (grouped by date + product)
  static pw.Widget _buildSummaryPDFTable(List<Map<String, dynamic>> transactions) {
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

    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.5),  // Ngày
        1: const pw.FlexColumnWidth(2),    // Tên hàng
        2: const pw.FlexColumnWidth(0.8),  // ĐVT
        3: const pw.FlexColumnWidth(0.8),  // Tổng SL
        4: const pw.FlexColumnWidth(1.5),  // Tổng tiền hàng
        5: const pw.FlexColumnWidth(1.2),  // Tổng thuế
        6: const pw.FlexColumnWidth(1.5),  // Tổng cộng
        7: const pw.FlexColumnWidth(2),    // Danh sách số HĐ
      },
      children: [
        // Header
        pw.TableRow(
          children: [
            _tableCell('Ngày', bold: true, center: true),
            _tableCell('Tên hàng', bold: true, center: true),
            _tableCell('ĐVT', bold: true, center: true),
            _tableCell('Tổng SL', bold: true, center: true),
            _tableCell('Tổng tiền hàng', bold: true, right: true),
            _tableCell('Tổng thuế', bold: true, right: true),
            _tableCell('Tổng cộng', bold: true, right: true),
            _tableCell('Danh sách số HĐ', bold: true, center: true),
          ],
        ),

        // Data rows
        ...sortedEntries.map((entry) {
          final data = entry.value;
          return pw.TableRow(
            children: [
              _tableCell(AppFormatter.formatDate(DateTime.parse(data['date']))),
              _tableCell(data['product_name']),
              _tableCell(data['unit_name'], center: true),
              _tableCell(data['total_quantity'].toString(), center: true),
              _tableCell(AppFormatter.formatCurrency(data['total_subtotal']), right: true),
              _tableCell(AppFormatter.formatCurrency(data['total_tax']), right: true),
              _tableCell(AppFormatter.formatCurrency(data['total_gross']), right: true),
              _tableCell((data['invoice_numbers'] as Set<String>).join(', '), center: true),
            ],
          );
        }),
      ],
    );
  }

  /// Build Detail PDF Table (all transaction line items)
  static pw.Widget _buildDetailPDFTable(List<Map<String, dynamic>> transactions) {
    final List<pw.TableRow> rows = [];

    // Header
    rows.add(
      pw.TableRow(
        children: [
          _tableCell('STT', bold: true, center: true),
          _tableCell('Ngày', bold: true, center: true),
          _tableCell('Số HĐ', bold: true, center: true),
          _tableCell('Khách hàng', bold: true, center: true),
          _tableCell('Sản phẩm', bold: true, center: true),
          _tableCell('Số lượng', bold: true, center: true),
          _tableCell('Đơn giá', bold: true, right: true),
          _tableCell('Thuế suất %', bold: true, center: true),
          _tableCell('Tiền thuế', bold: true, right: true),
          _tableCell('Thành tiền', bold: true, right: true),
        ],
      ),
    );

    // Data rows
    int stt = 1;
    for (var txData in transactions) {
      final tx = txData['transaction'] as Map<String, dynamic>;
      final customerName = txData['customer_name'] ?? 'Khách lẻ';
      final items = txData['items'] as List<dynamic>? ?? [];

      for (var itemData in items) {
        final item = itemData as Map<String, dynamic>;
        rows.add(
          pw.TableRow(
            children: [
              _tableCell(stt.toString(), center: true),
              _tableCell(AppFormatter.formatDate(DateTime.parse(tx['transaction_date']))),
              _tableCell(tx['invoice_number'] ?? 'N/A', center: true),
              _tableCell(customerName),
              _tableCell(item['product_name'] ?? ''),
              _tableCell('${item['quantity']} ${item['unit_name'] ?? ''}', center: true),
              _tableCell(AppFormatter.formatCurrency((item['price_at_sale'] as num).toDouble()), right: true),
              _tableCell(
                ((item['tax_rate'] as num?)?.toDouble() ?? 0) > 0
                    ? '${((item['tax_rate'] as num).toDouble()).toStringAsFixed(0)}%'
                    : '-',
                center: true,
              ),
              _tableCell(
                ((item['tax_amount'] as num?)?.toDouble() ?? 0) > 0
                    ? AppFormatter.formatCurrency((item['tax_amount'] as num).toDouble())
                    : '-',
                right: true,
              ),
              _tableCell(AppFormatter.formatCurrency((item['gross_amount'] as num).toDouble()), right: true),
            ],
          ),
        );
        stt++;
      }
    }

    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(30),   // STT
        1: const pw.FlexColumnWidth(1.2),   // Ngày
        2: const pw.FlexColumnWidth(1),     // Số HĐ
        3: const pw.FlexColumnWidth(1.5),   // Khách hàng
        4: const pw.FlexColumnWidth(2),     // Sản phẩm
        5: const pw.FlexColumnWidth(1),     // Số lượng
        6: const pw.FlexColumnWidth(1.2),   // Đơn giá
        7: const pw.FlexColumnWidth(0.8),   // Thuế suất %
        8: const pw.FlexColumnWidth(1),     // Tiền thuế
        9: const pw.FlexColumnWidth(1.2),   // Thành tiền
      },
      children: rows,
    );
  }
}
