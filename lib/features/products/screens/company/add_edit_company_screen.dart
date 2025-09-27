import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/company.dart';
import '../../providers/company_provider.dart';
import '../../../../shared/services/base_service.dart';

class AddEditCompanyScreen extends StatefulWidget {
  final Company? company;

  const AddEditCompanyScreen({Key? key, this.company}) : super(key: key);

  static const String addRouteName = '/add-company';
  static const String editRouteName = '/edit-company';

  @override
  _AddEditCompanyScreenState createState() => _AddEditCompanyScreenState();
}

class _AddEditCompanyScreenState extends State<AddEditCompanyScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _contactPersonController;

  bool get _isEditMode => widget.company != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.company?.name ?? '');
    _phoneController = TextEditingController(text: widget.company?.phone ?? '');
    _addressController = TextEditingController(text: widget.company?.address ?? '');
    _contactPersonController = TextEditingController(text: widget.company?.contactPerson ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _contactPersonController.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    if (_formKey.currentState!.validate()) {
      final provider = context.read<CompanyProvider>();
      
      final company = Company(
        id: widget.company?.id ?? '', // ID is empty for new company
        name: _nameController.text,
        phone: _phoneController.text,
        address: _addressController.text,
        contactPerson: _contactPersonController.text,
        createdAt: widget.company?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        storeId: BaseService.getDefaultStoreId(),
      );

      bool success = false;
      if (_isEditMode) {
        success = await provider.updateCompany(company);
      } else {
        success = await provider.addCompany(company);
      }

      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã lưu nhà cung cấp thành công')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: ${provider.errorMessage}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Sửa Nhà Cung Cấp' : 'Thêm Nhà Cung Cấp'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveForm,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Tên nhà cung cấp'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập tên nhà cung cấp';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contactPersonController,
                decoration: const InputDecoration(labelText: 'Người liên hệ'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Số điện thoại'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Địa chỉ'),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
