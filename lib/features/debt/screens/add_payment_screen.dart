import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../shared/utils/responsive.dart';
import '../providers/debt_provider.dart';
import '../../customers/services/customer_service.dart';
import '../../customers/models/customer.dart';

/// Screen for adding payment to customer debt
/// Includes overpayment prevention validation
class AddPaymentScreen extends StatefulWidget {
  final String customerId;

  const AddPaymentScreen({
    super.key,
    required this.customerId,
  });

  @override
  State<AddPaymentScreen> createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends State<AddPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final CustomerService _customerService = CustomerService();

  String _paymentMethod = 'CASH';
  Customer? _customer;
  double _totalDebt = 0.0;
  bool _isLoading = false;

  final List<Map<String, String>> _paymentMethods = [
    {'value': 'CASH', 'label': 'Tiền mặt'},
    {'value': 'BANK_TRANSFER', 'label': 'Chuyển khoản'},
    {'value': 'CARD', 'label': 'Thẻ'},
    {'value': 'MOMO', 'label': 'MoMo'},
    {'value': 'ZALOPAY', 'label': 'ZaloPay'},
    {'value': 'OTHER', 'label': 'Khác'},
  ];

  @override
  void initState() {
    super.initState();
    _loadCustomerData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomerData() async {
    setState(() => _isLoading = true);

    try {
      // Load customer info
      _customer = await _customerService.getCustomerById(widget.customerId);

      // Load debt summary to get total remaining debt
      final provider = context.read<DebtProvider>();
      await provider.loadCustomerDebtSummary(widget.customerId);

      if (provider.debtSummary != null) {
        final remaining = provider.debtSummary!['remaining_debt'] ?? 0.0;
        setState(() {
          _totalDebt = (remaining as num).toDouble();
        });
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

  Future<void> _submitPayment() async {
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

    setState(() => _isLoading = true);

    final provider = context.read<DebtProvider>();
    provider.clearPaymentError(); // Clear previous errors

    final success = await provider.addPayment(
      customerId: widget.customerId,
      paymentAmount: amount,
      paymentMethod: _paymentMethod,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thanh toán thành công'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      // Check if it's overpayment error
      if (provider.paymentError.isNotEmpty) {
        _showOverpaymentDialog(provider.paymentError);
      } else if (provider.errorMessage.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showOverpaymentDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange[700]),
            const SizedBox(width: 8),
            const Text('Cảnh báo quá số'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(errorMessage),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tổng công nợ hiện tại:',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    NumberFormat.currency(locale: 'vi_VN', symbol: '₫')
                        .format(_totalDebt),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Auto-fill with exact debt amount
              _amountController.text = NumberFormat('#,###').format(_totalDebt);
            },
            child: const Text('Thanh toán đúng số nợ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      title: 'Thanh Toán Công Nợ',
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
                    _buildCustomerInfo(),
                    const SizedBox(height: 24),
                    _buildDebtSummary(),
                    const SizedBox(height: 24),
                    _buildPaymentForm(),
                    const SizedBox(height: 32),
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCustomerInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thông tin khách hàng',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            if (_customer != null) ...[
              Text(
                _customer!.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_customer!.phone != null) ...[
                const SizedBox(height: 4),
                Text(
                  _customer!.phone!,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ] else
              Text(
                'KH: ${widget.customerId.substring(0, 8)}...',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebtSummary() {
    return Card(
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tổng công nợ hiện tại',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              NumberFormat.currency(locale: 'vi_VN', symbol: '₫')
                  .format(_totalDebt),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '⚠️ Không được thanh toán vượt quá số nợ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.orange,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _amountController,
          decoration: const InputDecoration(
            labelText: 'Số tiền thanh toán *',
            hintText: 'Nhập số tiền',
            prefixText: '₫ ',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            _ThousandsSeparatorInputFormatter(),
          ],
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
        DropdownButtonFormField<String>(
          value: _paymentMethod,
          decoration: const InputDecoration(
            labelText: 'Phương thức thanh toán *',
            border: OutlineInputBorder(),
          ),
          items: _paymentMethods.map((method) {
            return DropdownMenuItem(
              value: method['value'],
              child: Text(method['label']!),
            );
          }).toList(),
          onChanged: (value) {
            setState(() => _paymentMethod = value!);
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _notesController,
          decoration: const InputDecoration(
            labelText: 'Ghi chú',
            hintText: 'Ghi chú về thanh toán (tùy chọn)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _submitPayment,
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
              'Xác nhận thanh toán',
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
