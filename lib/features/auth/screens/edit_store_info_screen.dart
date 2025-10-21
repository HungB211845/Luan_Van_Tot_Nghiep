import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/utils/responsive.dart';
import '../../../shared/utils/tax_code_validator.dart';
import '../providers/store_business_info_provider.dart';
import '../models/store_business_info.dart';
import '../../../shared/services/base_service.dart';

class EditStoreInfoScreen extends StatefulWidget {
  const EditStoreInfoScreen({super.key});

  @override
  State<EditStoreInfoScreen> createState() => _EditStoreInfoScreenState();
}

class _EditStoreInfoScreenState extends State<EditStoreInfoScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _taxCodeController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _taxAuthorityController = TextEditingController();
  final _businessAddressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _legalRepController = TextEditingController();

  bool _isAutoFilled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExistingData();
    });
  }

  @override
  void dispose() {
    _taxCodeController.dispose();
    _businessNameController.dispose();
    _taxAuthorityController.dispose();
    _businessAddressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _bankAccountController.dispose();
    _bankNameController.dispose();
    _legalRepController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingData() async {
    final provider = context.read<StoreBusinessInfoProvider>();
    await provider.loadStoreBusinessInfo();

    if (provider.storeBusinessInfo != null) {
      final info = provider.storeBusinessInfo!;
      _taxCodeController.text = TaxCodeValidator.format(info.taxCode);
      _businessNameController.text = info.businessName;
      _taxAuthorityController.text = info.taxAuthority ?? '';
      _businessAddressController.text = info.businessAddress ?? '';
      _phoneController.text = info.phoneNumber ?? '';
      _emailController.text = info.email ?? '';
      _bankAccountController.text = info.bankAccount ?? '';
      _bankNameController.text = info.bankName ?? '';
      _legalRepController.text = info.legalRepresentative ?? '';
    }
  }

  Future<void> _lookupTaxCode() async {
    final taxCode = _taxCodeController.text.trim();

    if (taxCode.isEmpty) {
      _showError('Vui lòng nhập mã số thuế');
      return;
    }

    final provider = context.read<StoreBusinessInfoProvider>();
    final success = await provider.validateAndFetchTaxCode(taxCode);

    if (success && provider.autoFilledData != null) {
      // Auto-fill fields
      setState(() {
        _isAutoFilled = true;
        _businessNameController.text = provider.autoFilledData!['business_name'] ?? '';
        _taxAuthorityController.text = provider.autoFilledData!['tax_authority'] ?? '';
        _businessAddressController.text = provider.autoFilledData!['address'] ?? '';
        _legalRepController.text = provider.autoFilledData!['legal_representative'] ?? '';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Đã tra cứu và điền thông tin tự động'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else if (provider.errorMessage != null) {
      _showError(provider.errorMessage!);
    }
  }

  Future<void> _saveInfo() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = context.read<StoreBusinessInfoProvider>();
    final cleanedTaxCode = TaxCodeValidator.clean(_taxCodeController.text.trim());

    final info = StoreBusinessInfo(
      id: provider.storeBusinessInfo?.id ?? '',
      storeId: BaseService.getDefaultStoreId(),
      taxCode: cleanedTaxCode,
      businessName: _businessNameController.text.trim(),
      taxAuthority: _taxAuthorityController.text.trim().isNotEmpty ? _taxAuthorityController.text.trim() : null,
      businessAddress: _businessAddressController.text.trim().isNotEmpty ? _businessAddressController.text.trim() : null,
      phoneNumber: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
      email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
      bankAccount: _bankAccountController.text.trim().isNotEmpty ? _bankAccountController.text.trim() : null,
      bankName: _bankNameController.text.trim().isNotEmpty ? _bankNameController.text.trim() : null,
      legalRepresentative: _legalRepController.text.trim().isNotEmpty ? _legalRepController.text.trim() : null,
      validatedAt: _isAutoFilled ? DateTime.now() : provider.storeBusinessInfo?.validatedAt,
      validationSource: _isAutoFilled ? 'API' : provider.storeBusinessInfo?.validationSource ?? 'MANUAL',
      createdAt: provider.storeBusinessInfo?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final success = await provider.saveStoreBusinessInfo(info);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Đã lưu thông tin hộ kinh doanh'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      } else {
        _showError(provider.errorMessage ?? 'Có lỗi xảy ra khi lưu thông tin');
      }
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
      title: 'Thông tin hộ kinh doanh',
      showBackButton: true,
      body: Consumer<StoreBusinessInfoProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.storeBusinessInfo == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(context.sectionPadding),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Section 1: Mã số thuế
                  _buildSectionHeader('MÃ SỐ THUẾ'),
                  SizedBox(height: context.cardSpacing),
                  _buildGroupedInput([
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _taxCodeController,
                            decoration: const InputDecoration(
                              labelText: 'Mã số thuế (MST)',
                              hintText: '10 hoặc 13 chữ số',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              return TaxCodeValidator.validateWithMessage(value ?? '');
                            },
                          ),
                        ),
                        SizedBox(width: context.cardSpacing),
                        ElevatedButton.icon(
                          onPressed: provider.isValidatingTaxCode ? null : _lookupTaxCode,
                          icon: provider.isValidatingTaxCode
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.search),
                          label: const Text('Tra cứu'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.all(context.sectionPadding),
                          ),
                        ),
                      ],
                    ),
                  ]),

                  SizedBox(height: context.sectionPadding),

                  // Section 2: Thông tin doanh nghiệp
                  _buildSectionHeader('THÔNG TIN DOANH NGHIỆP'),
                  SizedBox(height: context.cardSpacing),
                  _buildGroupedInput([
                    TextFormField(
                      controller: _businessNameController,
                      decoration: InputDecoration(
                        labelText: 'Tên doanh nghiệp / Hộ kinh doanh',
                        border: const OutlineInputBorder(),
                        suffixIcon: _isAutoFilled ? const Icon(Icons.check_circle, color: Colors.green) : null,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập tên doanh nghiệp';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: context.cardSpacing),
                    TextFormField(
                      controller: _taxAuthorityController,
                      decoration: const InputDecoration(
                        labelText: 'Cơ quan thuế quản lý',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: context.cardSpacing),
                    TextFormField(
                      controller: _businessAddressController,
                      decoration: const InputDecoration(
                        labelText: 'Địa chỉ kinh doanh',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    SizedBox(height: context.cardSpacing),
                    TextFormField(
                      controller: _legalRepController,
                      decoration: const InputDecoration(
                        labelText: 'Người đại diện pháp luật',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ]),

                  SizedBox(height: context.sectionPadding),

                  // Section 3: Thông tin liên hệ
                  _buildSectionHeader('THÔNG TIN LIÊN HỆ'),
                  SizedBox(height: context.cardSpacing),
                  _buildGroupedInput([
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Số điện thoại',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập số điện thoại';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: context.cardSpacing),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ]),

                  SizedBox(height: context.sectionPadding),

                  // Section 4: Thông tin ngân hàng (Optional)
                  _buildSectionHeader('THÔNG TIN NGÂN HÀNG (Tùy chọn)'),
                  SizedBox(height: context.cardSpacing),
                  _buildGroupedInput([
                    TextFormField(
                      controller: _bankAccountController,
                      decoration: const InputDecoration(
                        labelText: 'Số tài khoản',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: context.cardSpacing),
                    TextFormField(
                      controller: _bankNameController,
                      decoration: const InputDecoration(
                        labelText: 'Tên ngân hàng',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ]),

                  SizedBox(height: context.sectionPadding * 2),

                  // Save button
                  ElevatedButton(
                    onPressed: provider.isLoading ? null : _saveInfo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.all(context.sectionPadding),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: provider.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Lưu thông tin',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
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

  Widget _buildGroupedInput(List<Widget> children) {
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