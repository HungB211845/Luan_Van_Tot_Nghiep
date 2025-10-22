import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../shared/utils/responsive.dart';
import '../../../shared/utils/formatter.dart';
import '../providers/store_business_info_provider.dart';
import '../../../features/invoice/providers/invoice_provider.dart';
import '../../../core/routing/route_names.dart';

class InvoiceSettingsScreen extends StatefulWidget {
  const InvoiceSettingsScreen({super.key});

  @override
  State<InvoiceSettingsScreen> createState() => _InvoiceSettingsScreenState();
}

class _InvoiceSettingsScreenState extends State<InvoiceSettingsScreen> {
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

  Future<void> _exportReport(String preset, String format) async {
    final invoiceProvider = context.read<InvoiceProvider>();

    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    switch (preset) {
      case 'month':
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0);
        break;
      case 'quarter':
        final currentQuarter = ((now.month - 1) ~/ 3) + 1;
        final quarterStartMonth = (currentQuarter - 1) * 3 + 1;
        startDate = DateTime(now.year, quarterStartMonth, 1);
        endDate = DateTime(now.year, quarterStartMonth + 3, 0);
        break;
      case 'year':
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year, 12, 31);
        break;
      case 'custom':
        if (_startDate == null || _endDate == null) {
          _showError('Vui lòng chọn khoảng thời gian');
          return;
        }
        startDate = _startDate!;
        endDate = _endDate!;
        break;
      default:
        return;
    }

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
              const Text(
                'Chọn khoảng thời gian:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: context.cardSpacing),

              // Preset buttons (3 columns: Month, Quarter, Year)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildPresetColumn('Tháng này', 'month'),
                  ),
                  SizedBox(width: context.cardSpacing),
                  Expanded(
                    child: _buildPresetColumn('Quý này', 'quarter'),
                  ),
                  SizedBox(width: context.cardSpacing),
                  Expanded(
                    child: _buildPresetColumn('Năm nay', 'year'),
                  ),
                ],
              ),

              SizedBox(height: context.sectionPadding),

              // Custom date range
              const Text(
                'Hoặc tùy chọn:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: context.cardSpacing),

              OutlinedButton.icon(
                onPressed: _selectDateRange,
                icon: const Icon(Icons.date_range),
                label: Text(
                  _startDate != null && _endDate != null
                      ? 'Từ ${DateFormat('dd/MM/yyyy').format(_startDate!)} đến ${DateFormat('dd/MM/yyyy').format(_endDate!)}'
                      : 'Chọn khoảng thời gian',
                ),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.all(context.sectionPadding),
                ),
              ),

              if (_startDate != null && _endDate != null) ...[
                SizedBox(height: context.cardSpacing),
                Consumer<InvoiceProvider>(
                  builder: (context, provider, child) {
                    return Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: provider.isGenerating ? null : () => _exportReport('custom', 'excel'),
                            icon: provider.isGenerating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.description),
                            label: const Text('Xuất Excel'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.all(context.cardSpacing),
                            ),
                          ),
                        ),
                        SizedBox(width: context.cardSpacing),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: provider.isGenerating ? null : () => _exportReport('custom', 'pdf'),
                            icon: provider.isGenerating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.picture_as_pdf),
                            label: const Text('Xuất PDF'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.all(context.cardSpacing),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
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

  Widget _buildPresetColumn(String label, String preset) {
    return Consumer<InvoiceProvider>(
      builder: (context, provider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.cardSpacing / 2),
            ElevatedButton.icon(
              onPressed: provider.isGenerating ? null : () => _exportReport(preset, 'excel'),
              icon: const Icon(Icons.description, size: 16),
              label: const Text('Excel', style: TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  vertical: context.cardSpacing / 2,
                  horizontal: context.cardSpacing / 2,
                ),
                elevation: 0,
              ),
            ),
            SizedBox(height: context.cardSpacing / 2),
            ElevatedButton.icon(
              onPressed: provider.isGenerating ? null : () => _exportReport(preset, 'pdf'),
              icon: const Icon(Icons.picture_as_pdf, size: 16),
              label: const Text('PDF', style: TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  vertical: context.cardSpacing / 2,
                  horizontal: context.cardSpacing / 2,
                ),
                elevation: 0,
              ),
            ),
          ],
        );
      },
    );
  }
}