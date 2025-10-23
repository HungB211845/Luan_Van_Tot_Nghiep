import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../shared/utils/responsive.dart';
import '../providers/store_business_info_provider.dart';
import '../../../features/invoice/providers/invoice_provider.dart';
import '../../../core/routing/route_names.dart';

/// Date range presets for report export
enum DateRangePreset {
  thisMonth,
  thisQuarter,
  thisYear,
  custom,
}

/// Export format options
enum ExportFormat {
  excel,
  pdf,
}

class InvoiceSettingsScreen extends StatefulWidget {
  const InvoiceSettingsScreen({super.key});

  @override
  State<InvoiceSettingsScreen> createState() => _InvoiceSettingsScreenState();
}

class _InvoiceSettingsScreenState extends State<InvoiceSettingsScreen> {
  DateRangePreset _selectedPreset = DateRangePreset.thisMonth;
  ExportFormat _selectedFormat = ExportFormat.excel;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StoreBusinessInfoProvider>().loadStoreBusinessInfo();
    });
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.green,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _exportReport() async {
    final invoiceProvider = context.read<InvoiceProvider>();

    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    switch (_selectedPreset) {
      case DateRangePreset.thisMonth:
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0);
        break;
      case DateRangePreset.thisQuarter:
        final currentQuarter = ((now.month - 1) ~/ 3) + 1;
        final quarterStartMonth = (currentQuarter - 1) * 3 + 1;
        startDate = DateTime(now.year, quarterStartMonth, 1);
        endDate = DateTime(now.year, quarterStartMonth + 3, 0);
        break;
      case DateRangePreset.thisYear:
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year, 12, 31);
        break;
      case DateRangePreset.custom:
        if (_startDate == null || _endDate == null) {
          _showError('Vui lòng chọn khoảng thời gian');
          return;
        }
        startDate = _startDate!;
        endDate = _endDate!;
        break;
    }

    final format = _selectedFormat == ExportFormat.excel ? 'excel' : 'pdf';

    final file = await invoiceProvider.exportCustomReport(
      startDate,
      endDate,
      format: format,
    );

    // Only show error snackbar if export failed (auto-share will handle success)
    if (mounted && file == null && invoiceProvider.errorMessage != null) {
      _showError(invoiceProvider.errorMessage!);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      title: 'Cài đặt hóa đơn & Thuế',
      showBackButton: true,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(context.sectionPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section 1: Store Business Info Preview
            _buildSectionHeader('THÔNG TIN HÓA ĐƠN'),
            SizedBox(height: context.cardSpacing),
            Consumer<StoreBusinessInfoProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return _buildCard([
                    const Center(child: CircularProgressIndicator()),
                  ]);
                }

                if (provider.storeBusinessInfo == null) {
                  return _buildCard([
                    const Icon(Icons.info_outline, size: 48, color: Colors.orange),
                    SizedBox(height: context.cardSpacing),
                    const Text(
                      'Chưa cấu hình thông tin hộ kinh doanh',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: context.cardSpacing),
                    const Text(
                      'Vui lòng nhập thông tin MST và hộ kinh doanh để sử dụng tính năng in hóa đơn',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: context.sectionPadding),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context, rootNavigator: true).pushNamed(RouteNames.editStoreInfo),
                      icon: const Icon(Icons.add),
                      label: const Text('Nhập thông tin'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ]);
                }

                final info = provider.storeBusinessInfo!;
                return _buildCard([
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              info.businessName,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: context.cardSpacing / 2),
                            Text('MST: ${info.taxCode}', style: const TextStyle(color: Colors.grey)),
                            if (info.taxAuthority != null)
                              Text('Cơ quan thuế: ${info.taxAuthority}', style: const TextStyle(color: Colors.grey)),
                            if (info.phoneNumber != null)
                              Text('SĐT: ${info.phoneNumber}', style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                      if (info.isApiValidated)
                        const Tooltip(
                          message: 'Đã xác thực qua API',
                          child: Icon(Icons.verified, color: Colors.green),
                        ),
                    ],
                  ),
                  SizedBox(height: context.sectionPadding),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context, rootNavigator: true).pushNamed(RouteNames.editStoreInfo),
                    icon: const Icon(Icons.edit),
                    label: const Text('Sửa thông tin'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                    ),
                  ),
                ]);
              },
            ),

            SizedBox(height: context.sectionPadding * 2),

            // Section 2: Export Reports
            _buildSectionHeader('XUẤT BÁO CÁO GIAO DỊCH'),
            SizedBox(height: context.cardSpacing),
            _buildCard([
              // Step 1: Date Range Selection
              const Text(
                '1. Chọn khoảng thời gian:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: context.cardSpacing),
              SegmentedButton<DateRangePreset>(
                segments: const [
                  ButtonSegment(
                    value: DateRangePreset.thisMonth,
                    label: Text('Tháng này'),
                  ),
                  ButtonSegment(
                    value: DateRangePreset.thisQuarter,
                    label: Text('Quý này'),
                  ),
                  ButtonSegment(
                    value: DateRangePreset.thisYear,
                    label: Text('Năm nay'),
                  ),
                  ButtonSegment(
                    value: DateRangePreset.custom,
                    label: Text('Tuỳ chọn'),
                  ),
                ],
                selected: {_selectedPreset},
                onSelectionChanged: (newSelection) {
                  setState(() {
                    _selectedPreset = newSelection.first;
                  });
                },
                style: SegmentedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  selectedBackgroundColor: Colors.green,
                  selectedForegroundColor: Colors.white,
                ),
              ),

              // Custom date picker (only show when "Tuỳ chọn" selected)
              if (_selectedPreset == DateRangePreset.custom) ...[
                SizedBox(height: context.cardSpacing),
                OutlinedButton.icon(
                  onPressed: _selectDateRange,
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    _startDate != null && _endDate != null
                        ? 'Từ ${DateFormat('dd/MM/yyyy').format(_startDate!)} đến ${DateFormat('dd/MM/yyyy').format(_endDate!)}'
                        : 'Chọn khoảng thời gian',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.all(context.cardSpacing),
                  ),
                ),
              ],

              SizedBox(height: context.sectionPadding),

              // Step 2: Format Selection
              const Text(
                '2. Chọn định dạng:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: context.cardSpacing),
              SegmentedButton<ExportFormat>(
                segments: const [
                  ButtonSegment(
                    value: ExportFormat.excel,
                    label: Text('Excel'),
                    icon: Icon(Icons.description, size: 16),
                  ),
                  ButtonSegment(
                    value: ExportFormat.pdf,
                    label: Text('PDF'),
                    icon: Icon(Icons.picture_as_pdf, size: 16),
                  ),
                ],
                selected: {_selectedFormat},
                onSelectionChanged: (newSelection) {
                  setState(() {
                    _selectedFormat = newSelection.first;
                  });
                },
                style: SegmentedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  selectedBackgroundColor: Colors.green,
                  selectedForegroundColor: Colors.white,
                ),
              ),

              SizedBox(height: context.sectionPadding),

              // Step 3: Primary Action
              Consumer<InvoiceProvider>(
                builder: (context, provider, child) {
                  return ElevatedButton.icon(
                    onPressed: provider.isGenerating ? null : _exportReport,
                    icon: provider.isGenerating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.file_download),
                    label: Text(
                      provider.isGenerating ? 'Đang xuất...' : 'Xuất báo cáo',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.all(context.sectionPadding),
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  );
                },
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: EdgeInsets.all(context.sectionPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

}