import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/customer_provider.dart';
import '../../models/customer.dart';

class EditCustomerScreen extends StatefulWidget {
  final Customer customer;

  const EditCustomerScreen({Key? key, required this.customer}) : super(key: key);

  @override
  _EditCustomerScreenState createState() => _EditCustomerScreenState();
}

class _EditCustomerScreenState extends State<EditCustomerScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form controllers - pre-filled with existing data
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _debtLimitController;
  late TextEditingController _interestRateController;
  late TextEditingController _noteController;

  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing customer data
    _nameController = TextEditingController(text: widget.customer.name);
    _phoneController = TextEditingController(text: widget.customer.phone ?? '');
    _addressController = TextEditingController(text: widget.customer.address ?? '');
    _debtLimitController = TextEditingController(text: widget.customer.debtLimit.toString());
    _interestRateController = TextEditingController(text: widget.customer.interestRate.toString());
    _noteController = TextEditingController(text: widget.customer.note ?? '');

    // Add listeners to detect changes
    _nameController.addListener(_onTextChanged);
    _phoneController.addListener(_onTextChanged);
    _addressController.addListener(_onTextChanged);
    _debtLimitController.addListener(_onTextChanged);
    _interestRateController.addListener(_onTextChanged);
    _noteController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _debtLimitController.dispose();
    _interestRateController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _updateCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedCustomer = widget.customer.copyWith(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        debtLimit: double.tryParse(_debtLimitController.text) ?? widget.customer.debtLimit,
        interestRate: double.tryParse(_interestRateController.text) ?? widget.customer.interestRate,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );

      final success = await Provider.of<CustomerProvider>(context, listen: false)
          .updateCustomer(updatedCustomer);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Cập nhật thông tin thành công!'),
            backgroundColor: Colors.green,
          ),
        );

        // Quay về màn hình trước
        Navigator.pop(context, true); // Return true to indicate success
      } else {
        final error = Provider.of<CustomerProvider>(context, listen: false).errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Lỗi: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Lỗi không xác định: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    return await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Có Thay Đổi Chưa Lưu'),
          content: Text(
            'Bạn có thay đổi chưa được lưu. Bạn có muốn thoát mà không lưu?',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('Ở Lại'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Thoát', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text(
            'Chỉnh Sửa Khách Hàng',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          backgroundColor: Colors.green,
          elevation: 0,
          actions: [
            if (_isLoading)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              ),
            if (_hasChanges && !_isLoading)
              Container(
                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: ElevatedButton(
                  onPressed: _updateCustomer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.green,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text('Lưu', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header card with customer info
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.blue.shade400, Colors.blue.shade600],
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.edit, color: Colors.white, size: 24),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Chỉnh Sửa Thông Tin',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'ID: ${widget.customer.id.substring(0, 8)}...',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_hasChanges)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Có thay đổi',
                              style: TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 16),

                // Form fields
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Tên khách hàng (required)
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Tên Khách Hàng *',
                            hintText: 'VD: Ông Năm Nông Dân',
                            prefixIcon: Icon(Icons.person, color: Colors.green),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.green, width: 2),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Tên khách hàng không được để trống';
                            }
                            if (value.trim().length < 2) {
                              return 'Tên phải có ít nhất 2 ký tự';
                            }
                            return null;
                          },
                          textCapitalization: TextCapitalization.words,
                        ),

                        SizedBox(height: 16),

                        // Số điện thoại (optional)
                        TextFormField(
                          controller: _phoneController,
                          decoration: InputDecoration(
                            labelText: 'Số Điện Thoại',
                            hintText: 'VD: 0123456789',
                            prefixIcon: Icon(Icons.phone, color: Colors.blue),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.green, width: 2),
                            ),
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value != null && value.trim().isNotEmpty) {
                              if (!RegExp(r'^[0-9]{10,11}$').hasMatch(value.trim())) {
                                return 'Số điện thoại không hợp lệ (10-11 số)';
                              }
                            }
                            return null;
                          },
                        ),

                        SizedBox(height: 16),

                        // Địa chỉ (optional)
                        TextFormField(
                          controller: _addressController,
                          decoration: InputDecoration(
                            labelText: 'Địa Chỉ',
                            hintText: 'VD: Ấp 3, Xã Tân Phú, Huyện Cờ Đỏ',
                            prefixIcon: Icon(Icons.location_on, color: Colors.red),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.green, width: 2),
                            ),
                          ),
                          maxLines: 2,
                          textCapitalization: TextCapitalization.words,
                        ),

                        SizedBox(height: 16),

                        // Row cho debt limit và interest rate
                        Row(
                          children: [
                            // Hạn mức nợ
                            Expanded(
                              child: TextFormField(
                                controller: _debtLimitController,
                                decoration: InputDecoration(
                                  labelText: 'Hạn Mức Nợ (VNĐ)',
                                  hintText: '0',
                                  prefixIcon: Icon(Icons.money, color: Colors.orange),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.green, width: 2),
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value != null && value.trim().isNotEmpty) {
                                    final amount = double.tryParse(value);
                                    if (amount == null || amount < 0) {
                                      return 'Số tiền không hợp lệ';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ),

                            SizedBox(width: 12),

                            // Lãi suất
                            Expanded(
                              child: TextFormField(
                                controller: _interestRateController,
                                decoration: InputDecoration(
                                  labelText: 'Lãi Suất (%/tháng)',
                                  hintText: '0.5',
                                  prefixIcon: Icon(Icons.percent, color: Colors.purple),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.green, width: 2),
                                  ),
                                ),
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                validator: (value) {
                                  if (value != null && value.trim().isNotEmpty) {
                                    final rate = double.tryParse(value);
                                    if (rate == null || rate < 0 || rate > 100) {
                                      return 'Lãi suất 0-100%';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 16),

                        // Ghi chú (optional)
                        TextFormField(
                          controller: _noteController,
                          decoration: InputDecoration(
                            labelText: 'Ghi Chú',
                            hintText: 'VD: Khách hàng VIP, mua nhiều phân bón...',
                            prefixIcon: Icon(Icons.note, color: Colors.grey),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.green, width: 2),
                            ),
                          ),
                          maxLines: 3,
                          textCapitalization: TextCapitalization.sentences,
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 24),

                // Update button
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: (_isLoading || !_hasChanges) ? null : _updateCustomer,
                    icon: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                          )
                        : Icon(Icons.update, color: Colors.white),
                    label: Text(
                      _isLoading ? 'Đang Cập Nhật...' : _hasChanges ? 'Cập Nhật Thông Tin' : 'Không Có Thay Đổi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _hasChanges ? Colors.green : Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      elevation: 3,
                    ),
                  ),
                ),

                SizedBox(height: 12),

                // Cancel button
                SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    icon: Icon(Icons.cancel, color: Colors.grey[600]),
                    label: Text(
                      'Hủy Bỏ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}