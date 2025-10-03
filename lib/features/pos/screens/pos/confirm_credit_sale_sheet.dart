import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../customers/models/customer.dart';
import '../../../../shared/utils/formatter.dart';

class ConfirmCreditSaleSheet extends StatefulWidget {
  final Customer customer;
  final double baseAmount; // Tổng tiền hàng (không bao gồm phụ phí)
  final VoidCallback? onCancel;
  final Function(double surchargeAmount)? onConfirm;

  const ConfirmCreditSaleSheet({
    Key? key,
    required this.customer,
    required this.baseAmount,
    this.onCancel,
    this.onConfirm,
  }) : super(key: key);

  @override
  State<ConfirmCreditSaleSheet> createState() => _ConfirmCreditSaleSheetState();
}

class _ConfirmCreditSaleSheetState extends State<ConfirmCreditSaleSheet> {
  final TextEditingController _surchargeController = TextEditingController(text: '0');
  double _surchargeAmount = 0.0;
  double get _finalDebtAmount => widget.baseAmount + _surchargeAmount;

  @override
  void initState() {
    super.initState();
    _surchargeController.addListener(_onSurchargeChanged);
  }

  @override
  void dispose() {
    _surchargeController.removeListener(_onSurchargeChanged);
    _surchargeController.dispose();
    super.dispose();
  }

  void _onSurchargeChanged() {
    final text = _surchargeController.text;
    final value = double.tryParse(text) ?? 0.0;
    if (value >= 0) {
      setState(() {
        _surchargeAmount = value;
      });
    }
  }

  void _handleConfirm() {
    final surcharge = double.tryParse(_surchargeController.text) ?? 0.0;
    if (surcharge < 0) {
      _showError('Phụ phí không thể âm');
      return;
    }
    widget.onConfirm?.call(surcharge);
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
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                'Xác nhận Ghi nợ cho ${widget.customer.name}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 24),

              // Base amount section
              _buildAmountRow(
                label: 'Tổng tiền hàng:',
                amount: widget.baseAmount,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              // Surcharge input section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Phụ phí (tùy chọn):',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _surchargeController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: InputDecoration(
                      hintText: '0',
                      suffixText: 'VND',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.green, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Divider
              Container(
                height: 1,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),

              // Final total (prominently displayed)
              _buildAmountRow(
                label: 'TỔNG NỢ GHI NHẬN:',
                amount: _finalDebtAmount,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
                labelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 32),

              // Action button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _handleConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Xác nhận Ghi nợ ${AppFormatter.formatCurrency(_finalDebtAmount)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Cancel button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: widget.onCancel ?? () => Navigator.pop(context),
                  child: const Text(
                    'Hủy',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountRow({
    required String label,
    required double amount,
    required TextStyle style,
    TextStyle? labelStyle,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: labelStyle ?? const TextStyle(
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        Text(
          AppFormatter.formatCurrency(amount),
          style: style,
        ),
      ],
    );
  }
}