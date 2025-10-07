import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../shared/utils/responsive.dart';
import '../providers/debt_provider.dart';
import '../models/debt.dart';

/// Screen for adjusting debt amount
/// Supports increase, decrease, and write-off operations
class AdjustDebtScreen extends StatefulWidget {
  final String debtId;

  const AdjustDebtScreen({
    super.key,
    required this.debtId,
  });

  @override
  State<AdjustDebtScreen> createState() => _AdjustDebtScreenState();
}

class _AdjustDebtScreenState extends State<AdjustDebtScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();

  String _adjustmentType = 'decrease';
  Debt? _debt;
  bool _isLoading = false;

  final List<Map<String, String>> _adjustmentTypes = [
    {'value': 'decrease', 'label': 'Giảm nợ', 'icon': '⬇️'},
    {'value': 'increase', 'label': 'Tăng nợ', 'icon': '⬆️'},
    {'value': 'write_off', 'label': 'Xóa nợ', 'icon': '✖️'},
  ];

  @override
  void initState() {
    super.initState();
    _loadDebtData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadDebtData() async {
    setState(() => _isLoading = true);

    try {
      final provider = context.read<DebtProvider>();
      _debt = await provider.getDebtById(widget.debtId);

      if (_debt == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không tìm thấy khoản nợ'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải dữ liệu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitAdjustment() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Số tiền không hợp lệ'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập lý do điều chỉnh'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Confirm dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận điều chỉnh'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Loại: ${_adjustmentTypes.firstWhere((t) => t['value'] == _adjustmentType)['label']}',
            ),
            Text(
              'Số tiền: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(amount)}',
            ),
            Text('Lý do: $reason'),
            const SizedBox(height: 12),
            if (_adjustmentType == 'write_off')
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '⚠️ Xóa nợ sẽ xóa toàn bộ công nợ còn lại',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    final provider = context.read<DebtProvider>();
    final success = await provider.adjustDebt(
      debtId: widget.debtId,
      adjustmentAmount: amount,
      adjustmentType: _adjustmentType,
      reason: reason,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Điều chỉnh công nợ thành công'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      title: 'Điều Chỉnh Công Nợ',
      showBackButton: true,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(context.sectionPadding),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_debt != null) _buildDebtInfo(),
                    const SizedBox(height: 24),
                    _buildAdjustmentForm(),
                    const SizedBox(height: 32),
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDebtInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thông tin khoản nợ',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tổng nợ gốc',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      NumberFormat.currency(locale: 'vi_VN', symbol: '₫')
                          .format(_debt!.originalAmount),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Còn nợ',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      NumberFormat.currency(locale: 'vi_VN', symbol: '₫')
                          .format(_debt!.remainingAmount),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (_debt!.dueDate != null) ...[
              const SizedBox(height: 8),
              Text(
                'Hạn: ${DateFormat('dd/MM/yyyy').format(_debt!.dueDate!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: _debt!.isOverdue ? Colors.red : Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAdjustmentForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Adjustment type selector
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Loại điều chỉnh *',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              ..._adjustmentTypes.map((type) {
                return RadioListTile<String>(
                  value: type['value']!,
                  groupValue: _adjustmentType,
                  title: Row(
                    children: [
                      Text(type['icon']!),
                      const SizedBox(width: 8),
                      Text(type['label']!),
                    ],
                  ),
                  onChanged: (value) {
                    setState(() {
                      _adjustmentType = value!;
                      // Auto-fill amount for write-off
                      if (value == 'write_off' && _debt != null) {
                        _amountController.text = NumberFormat('#,###')
                            .format(_debt!.remainingAmount);
                      }
                    });
                  },
                  dense: true,
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _amountController,
          decoration: InputDecoration(
            labelText: 'Số tiền điều chỉnh *',
            hintText: 'Nhập số tiền',
            prefixText: '₫ ',
            border: const OutlineInputBorder(),
            helperText: _adjustmentType == 'write_off'
                ? 'Số tiền sẽ tự động điền bằng số nợ còn lại'
                : null,
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            _ThousandsSeparatorInputFormatter(),
          ],
          enabled: _adjustmentType != 'write_off',
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Vui lòng nhập số tiền';
            }
            final amount = double.tryParse(value.replaceAll(',', ''));
            if (amount == null || amount <= 0) {
              return 'Số tiền phải lớn hơn 0';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _reasonController,
          decoration: const InputDecoration(
            labelText: 'Lý do điều chỉnh *',
            hintText: 'Nhập lý do điều chỉnh công nợ',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Vui lòng nhập lý do điều chỉnh';
            }
            if (value.trim().length < 10) {
              return 'Lý do phải có ít nhất 10 ký tự';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info, size: 16, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Text(
                    'Lưu ý:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '• Điều chỉnh sẽ thay đổi số nợ còn lại\n'
                '• Lý do điều chỉnh sẽ được lưu lại để kiểm tra\n'
                '• Không thể hoàn tác sau khi điều chỉnh',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _submitAdjustment,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: _isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          : const Text(
              'Xác nhận điều chỉnh',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
    );
  }
}

/// Input formatter to add thousands separators
class _ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final number = int.tryParse(newValue.text.replaceAll(',', ''));
    if (number == null) {
      return oldValue;
    }

    final formatted = NumberFormat('#,###').format(number);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
