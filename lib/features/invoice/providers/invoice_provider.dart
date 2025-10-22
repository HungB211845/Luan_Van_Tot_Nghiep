import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/invoice_data.dart';
import '../services/invoice_service.dart';
import '../services/invoice_export_service.dart';

/// Provider for managing invoice generation and export
///
/// Handles:
/// - Generating PDF/Excel invoices for transactions and purchase orders
/// - Exporting transaction reports
/// - Sharing and printing invoices
class InvoiceProvider extends ChangeNotifier {
  final InvoiceService _invoiceService = InvoiceService();
  final InvoiceExportService _exportService = InvoiceExportService();

  // State
  bool _isGenerating = false;
  String? _errorMessage;
  File? _generatedFile;
  double? _progress;

  // Getters
  bool get isGenerating => _isGenerating;
  String? get errorMessage => _errorMessage;
  File? get generatedFile => _generatedFile;
  double? get progress => _progress;

  /// Generate invoice for a transaction (with auto-share)
  ///
  /// Format: 'pdf' or 'excel'
  /// Returns File if successful, null otherwise
  /// Automatically shares file via system share sheet after generation
  Future<File?> generateTransactionInvoice(
    String transactionId,
    String format,
  ) async {
    _isGenerating = true;
    _errorMessage = null;
    _generatedFile = null;
    _progress = 0.0;
    notifyListeners();

    try {
      // Step 1: Fetch invoice data (30%)
      _progress = 0.3;
      notifyListeners();

      final invoiceData = await _invoiceService.getTransactionInvoiceData(transactionId);

      // Step 2: Generate file (70%)
      _progress = 0.7;
      notifyListeners();

      final File file;
      if (format == 'pdf') {
        file = await _exportService.generateTransactionPDF(invoiceData);
      } else if (format == 'excel') {
        file = await _exportService.generateTransactionExcel(invoiceData);
      } else {
        throw Exception('Invalid format: $format. Must be "pdf" or "excel".');
      }

      // Step 3: Done (100%)
      _progress = 1.0;
      _generatedFile = file;
      _isGenerating = false;
      notifyListeners();

      // Step 4: Auto-share (non-blocking)
      await shareInvoice(file);

      return file;
    } catch (e) {
      _isGenerating = false;
      _errorMessage = e.toString();
      _progress = null;
      notifyListeners();
      return null;
    }
  }

  /// Generate invoice for a purchase order (with auto-share)
  ///
  /// Format: 'pdf' or 'excel'
  /// Returns File if successful, null otherwise
  /// Automatically shares file via system share sheet after generation
  Future<File?> generatePOInvoice(
    String poId,
    String format,
  ) async {
    _isGenerating = true;
    _errorMessage = null;
    _generatedFile = null;
    _progress = 0.0;
    notifyListeners();

    try {
      // Step 1: Fetch PO data
      _progress = 0.3;
      notifyListeners();

      final invoiceData = await _invoiceService.getPOInvoiceData(poId);

      // Step 2: Generate file
      _progress = 0.7;
      notifyListeners();

      final File file;
      if (format == 'pdf') {
        file = await _exportService.generatePOPDF(invoiceData);
      } else if (format == 'excel') {
        file = await _exportService.generatePOExcel(invoiceData);
      } else {
        throw Exception('Invalid format: $format. Must be "pdf" or "excel".');
      }

      // Step 3: Done
      _progress = 1.0;
      _generatedFile = file;
      _isGenerating = false;
      notifyListeners();

      // Step 4: Auto-share (non-blocking)
      await shareInvoice(file);

      return file;
    } catch (e) {
      _isGenerating = false;
      _errorMessage = e.toString();
      _progress = null;
      notifyListeners();
      return null;
    }
  }

  /// Export monthly transactions report to Excel
  ///
  /// Returns File if successful, null otherwise
  Future<File?> exportMonthlyReport(int month, int year) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0); // Last day of month

    return await _exportTransactionsReport(startDate, endDate);
  }

  /// Export quarterly transactions report to Excel
  ///
  /// Quarter: 1-4
  /// Returns File if successful, null otherwise
  Future<File?> exportQuarterlyReport(int quarter, int year) async {
    if (quarter < 1 || quarter > 4) {
      _errorMessage = 'Invalid quarter: $quarter. Must be 1-4.';
      notifyListeners();
      return null;
    }

    final startMonth = (quarter - 1) * 3 + 1;
    final startDate = DateTime(year, startMonth, 1);
    final endDate = DateTime(year, startMonth + 3, 0); // Last day of quarter

    return await _exportTransactionsReport(startDate, endDate);
  }

  /// Export yearly transactions report to Excel
  ///
  /// Returns File if successful, null otherwise
  Future<File?> exportYearlyReport(int year) async {
    final startDate = DateTime(year, 1, 1);
    final endDate = DateTime(year, 12, 31);

    return await _exportTransactionsReport(startDate, endDate);
  }

  /// Export custom date range transactions report to Excel (with auto-share)
  ///
  /// Returns File if successful, null otherwise
  /// Automatically shares file via system share sheet after generation
  Future<File?> exportCustomReport(DateTime startDate, DateTime endDate) async {
    return await _exportTransactionsReport(startDate, endDate);
  }

  /// Internal method to export transactions report (with auto-share)
  Future<File?> _exportTransactionsReport(DateTime startDate, DateTime endDate) async {
    _isGenerating = true;
    _errorMessage = null;
    _generatedFile = null;
    _progress = 0.0;
    notifyListeners();

    try {
      // Step 1: Fetch transactions data
      _progress = 0.4;
      notifyListeners();

      final transactions = await _invoiceService.getTransactionsExportData(
        startDate: startDate,
        endDate: endDate,
      );

      if (transactions.isEmpty) {
        _isGenerating = false;
        _errorMessage = 'Không có giao dịch nào trong khoảng thời gian này.';
        _progress = null;
        notifyListeners();
        return null;
      }

      // Step 2: Generate Excel file
      _progress = 0.8;
      notifyListeners();

      final file = await _exportService.exportTransactionsReport(
        transactions: transactions,
        startDate: startDate,
        endDate: endDate,
      );

      // Step 3: Done
      _progress = 1.0;
      _generatedFile = file;
      _isGenerating = false;
      notifyListeners();

      // Step 4: Auto-share (non-blocking)
      await shareInvoice(file);

      return file;
    } catch (e) {
      _isGenerating = false;
      _errorMessage = e.toString();
      _progress = null;
      notifyListeners();
      return null;
    }
  }

  /// Share invoice file via system share sheet
  Future<void> shareInvoice(File file) async {
    try {
      await _exportService.shareFile(file);
    } catch (e) {
      _errorMessage = 'Lỗi chia sẻ file: $e';
      notifyListeners();
    }
  }

  /// Print PDF invoice
  ///
  /// Only works for PDF files
  Future<void> printInvoice(File pdfFile) async {
    try {
      if (!pdfFile.path.endsWith('.pdf')) {
        throw Exception('Chỉ có thể in file PDF');
      }

      await _exportService.printPDF(pdfFile);
    } catch (e) {
      _errorMessage = 'Lỗi in hóa đơn: $e';
      notifyListeners();
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Clear generated file
  void clearGeneratedFile() {
    _generatedFile = null;
    _progress = null;
    notifyListeners();
  }

  /// Reset all state
  void reset() {
    _isGenerating = false;
    _errorMessage = null;
    _generatedFile = null;
    _progress = null;
    notifyListeners();
  }
}
