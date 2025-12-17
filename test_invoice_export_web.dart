/// Simple test script to verify invoice export works on web
/// Run with: flutter run -d chrome test_invoice_export_web.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'lib/features/invoice/models/invoice_data.dart';
import 'lib/features/invoice/models/invoice_item.dart';
import 'lib/features/invoice/services/invoice_export_service.dart';
import 'lib/shared/utils/file_naming_helper.dart';

void main() {
  runApp(const TestApp());
}

class TestApp extends StatelessWidget {
  const TestApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Invoice Export Test',
      home: const TestScreen(),
    );
  }
}

class TestScreen extends StatefulWidget {
  const TestScreen({Key? key}) : super(key: key);

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  final _exportService = InvoiceExportService();
  String _status = 'Ready to test';
  bool _isLoading = false;

  InvoiceData _createSampleInvoiceData() {
    return InvoiceData(
      invoiceNumber: 'TEST001',
      invoiceDate: DateTime.now(),
      items: [
        InvoiceItem(
          productId: '1',
          productName: 'Phân bón NPK',
          quantity: 10,
          unitName: 'bao',
          pricePerUnit: 50000,
        ),
        InvoiceItem(
          productId: '2',
          productName: 'Thuốc trừ sâu',
          quantity: 5,
          unitName: 'chai',
          pricePerUnit: 25000,
        ),
      ],
      totalAmount: 625000,
    );
  }

  Future<void> _testPDFExport() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing PDF export...';
    });

    try {
      final invoiceData = _createSampleInvoiceData();
      final result = await _exportService.generateTransactionPDF(invoiceData);

      setState(() {
        _isLoading = false;
        if (kIsWeb) {
          _status = result == null 
              ? '✅ PDF export successful! Download should have started automatically.'
              : '❌ PDF export failed: Expected null on web, got file.';
        } else {
          _status = result != null 
              ? '✅ PDF export successful! File saved locally.'
              : '❌ PDF export failed: No file returned.';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = '❌ PDF export failed: $e';
      });
    }
  }

  Future<void> _testExcelExport() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing Excel export...';
    });

    try {
      final invoiceData = _createSampleInvoiceData();
      final result = await _exportService.generateTransactionExcel(invoiceData);

      setState(() {
        _isLoading = false;
        if (kIsWeb) {
          _status = result == null 
              ? '✅ Excel export successful! Download should have started automatically.'
              : '❌ Excel export failed: Expected null on web, got file.';
        } else {
          _status = result != null 
              ? '✅ Excel export successful! File saved locally.'
              : '❌ Excel export failed: No file returned.';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = '❌ Excel export failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Invoice Export Test - ${kIsWeb ? 'Web' : 'Mobile'}'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Platform: ${kIsWeb ? 'Web Browser' : 'Native'}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Web Behavior: Downloads triggered automatically via FileSaver',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      'Mobile Behavior: Files saved locally and can be shared',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _status,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (_isLoading) ...[
                      const SizedBox(height: 8),
                      const CircularProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _testPDFExport,
                    child: const Text('Test PDF Export'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _testExcelExport,
                    child: const Text('Test Excel Export'),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            const Card(
              color: Colors.blue,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test Instructions:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. Click "Test PDF Export" or "Test Excel Export"\n'
                      '2. On Web: Check if download started automatically\n'
                      '3. On Mobile: Check if success message appears\n'
                      '4. Verify no MissingPluginException errors',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}