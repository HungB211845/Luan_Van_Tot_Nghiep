import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../models/fertilizer_attributes.dart';
import '../../models/pesticide_attributes.dart';
import '../../models/seed_attributes.dart';
import '../../providers/product_provider.dart';
import '../../../../shared/services/base_service.dart';

class AddProductStep3Screen extends StatefulWidget {
  final String productName;
  final String companyId;
  final String? imageUrl;
  final ProductCategory category;

  const AddProductStep3Screen({
    super.key,
    required this.productName,
    required this.companyId,
    this.imageUrl,
    required this.category,
  });

  @override
  State<AddProductStep3Screen> createState() => _AddProductStep3ScreenState();
}

class _AddProductStep3ScreenState extends State<AddProductStep3Screen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _productCreated = false; // Track if product has been created

  // Optional fields
  final _skuController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Category-specific controllers
  // Fertilizer
  final _npkRatioController = TextEditingController();
  final _fertilizerTypeController = TextEditingController();
  final _weightController = TextEditingController();
  String _weightUnit = 'kg';

  // Pesticide
  final _activeIngredientController = TextEditingController();
  final _concentrationController = TextEditingController();
  final _volumeController = TextEditingController();
  String _volumeUnit = 'ml';

  // Seed
  final _strainController = TextEditingController();
  final _originController = TextEditingController();
  final _germinationRateController = TextEditingController();
  final _purityController = TextEditingController();

  @override
  void dispose() {
    _skuController.dispose();
    _descriptionController.dispose();
    _npkRatioController.dispose();
    _fertilizerTypeController.dispose();
    _weightController.dispose();
    _activeIngredientController.dispose();
    _concentrationController.dispose();
    _volumeController.dispose();
    _strainController.dispose();
    _originController.dispose();
    _germinationRateController.dispose();
    _purityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Thêm Sản Phẩm Mới',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          // "Lưu" button - Always present escape hatch
          TextButton(
            onPressed: _saveWithCurrentInfo,
            child: const Text(
              'Lưu',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Step indicator
              Row(
                children: [
                  _buildStepIndicator(1, true),
                  _buildStepLine(true),
                  _buildStepIndicator(2, true),
                  _buildStepLine(true),
                  _buildStepIndicator(3, true),
                ],
              ),

              const SizedBox(height: 32),

              // Product context
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getCategoryColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getCategoryColor().withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getCategoryIcon(),
                      color: _getCategoryColor(),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.productName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _getCategoryColor(),
                            ),
                          ),
                          Text(
                            _getCategoryName(),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Title
              const Text(
                'Chi tiết bổ sung',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Thông tin này có thể để trống và bổ sung sau',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),

              const SizedBox(height: 32),

              // Optional fields
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // SKU
                      TextFormField(
                        controller: _skuController,
                        decoration: _buildInputDecoration(
                          label: 'Mã SKU/Barcode',
                          hint: 'Có thể để trống',
                          icon: Icons.qr_code,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Category-specific attributes
                      _buildCategorySpecificForm(),

                      const SizedBox(height: 20),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: _buildInputDecoration(
                          label: 'Mô tả',
                          hint: 'Mô tả chi tiết sản phẩm',
                          icon: Icons.description,
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Finish button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: (_isLoading || _productCreated) ? null : _saveComplete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Hoàn tất',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
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

  Widget _buildStepIndicator(int step, bool isActive) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isActive ? Colors.green : Colors.grey[300],
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$step',
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildStepLine(bool isCompleted) {
    return Expanded(
      child: Container(
        height: 2,
        color: isCompleted ? Colors.green : Colors.grey[300],
      ),
    );
  }

  Widget _buildCategorySpecificForm() {
    switch (widget.category) {
      case ProductCategory.FERTILIZER:
        return _buildFertilizerForm();
      case ProductCategory.PESTICIDE:
        return _buildPesticideForm();
      case ProductCategory.SEED:
        return _buildSeedForm();
    }
  }

  Widget _buildFertilizerForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thông số phân bón',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _getCategoryColor(),
          ),
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _npkRatioController,
          decoration: _buildInputDecoration(
            label: 'Tỷ lệ NPK',
            hint: 'Ví dụ: 16-16-8',
            icon: Icons.science,
          ),
        ),

        const SizedBox(height: 16),

        DropdownButtonFormField<String>(
          value: _fertilizerTypeController.text.isEmpty
              ? null
              : _fertilizerTypeController.text,
          decoration: _buildInputDecoration(
            label: 'Loại phân bón',
            hint: 'Chọn loại',
            icon: Icons.category,
          ),
          items: ['vô cơ', 'hữu cơ', 'hỗn hợp'].map((type) {
            return DropdownMenuItem<String>(value: type, child: Text(type));
          }).toList(),
          onChanged: (value) {
            _fertilizerTypeController.text = value ?? '';
          },
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _weightController,
                decoration: _buildInputDecoration(
                  label: 'Khối lượng',
                  hint: '0',
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _weightUnit,
                decoration: _buildInputDecoration(label: 'Đơn vị'),
                items: ['kg', 'tấn', 'bao'].map((unit) {
                  return DropdownMenuItem<String>(
                    value: unit,
                    child: Text(unit),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _weightUnit = value ?? 'kg';
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPesticideForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thông số thuốc BVTV',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _getCategoryColor(),
          ),
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _activeIngredientController,
          decoration: _buildInputDecoration(
            label: 'Hoạt chất chính',
            hint: 'Ví dụ: Imidacloprid',
            icon: Icons.biotech,
          ),
        ),

        const SizedBox(height: 16),

        TextFormField(
          controller: _concentrationController,
          decoration: _buildInputDecoration(
            label: 'Nồng độ',
            hint: 'Ví dụ: 4SC, 25EC',
          ),
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _volumeController,
                decoration: _buildInputDecoration(label: 'Thể tích', hint: '0'),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _volumeUnit,
                decoration: _buildInputDecoration(label: 'Đơn vị'),
                items: ['ml', 'lít', 'chai', 'gói', 'lọ'].map((unit) {
                  return DropdownMenuItem<String>(
                    value: unit,
                    child: Text(unit),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _volumeUnit = value ?? 'ml';
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSeedForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thông số lúa giống',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _getCategoryColor(),
          ),
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _strainController,
          decoration: _buildInputDecoration(
            label: 'Tên giống',
            hint: 'Ví dụ: OM18, ST24',
            icon: Icons.grass,
          ),
        ),

        const SizedBox(height: 16),

        TextFormField(
          controller: _originController,
          decoration: _buildInputDecoration(
            label: 'Nguồn gốc',
            hint: 'Ví dụ: Việt Nam, Nhật Bản',
            icon: Icons.place,
          ),
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _germinationRateController,
                decoration: _buildInputDecoration(
                  label: 'Tỷ lệ nảy mầm (%)',
                  hint: '0-100',
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _purityController,
                decoration: _buildInputDecoration(
                  label: 'Độ thuần chủng (%)',
                  hint: '0-100',
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration({
    required String label,
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: _getCategoryColor(), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Color _getCategoryColor() {
    switch (widget.category) {
      case ProductCategory.FERTILIZER:
        return Colors.green;
      case ProductCategory.PESTICIDE:
        return Colors.orange;
      case ProductCategory.SEED:
        return Colors.brown;
    }
  }

  IconData _getCategoryIcon() {
    switch (widget.category) {
      case ProductCategory.FERTILIZER:
        return Icons.eco;
      case ProductCategory.PESTICIDE:
        return Icons.bug_report;
      case ProductCategory.SEED:
        return Icons.grass;
    }
  }

  String _getCategoryName() {
    switch (widget.category) {
      case ProductCategory.FERTILIZER:
        return 'Phân Bón';
      case ProductCategory.PESTICIDE:
        return 'Thuốc BVTV';
      case ProductCategory.SEED:
        return 'Lúa Giống';
    }
  }

  Map<String, dynamic> _buildAttributes() {
    switch (widget.category) {
      case ProductCategory.FERTILIZER:
        return FertilizerAttributes(
          npkRatio: _npkRatioController.text.trim(),
          type: _fertilizerTypeController.text.trim(),
          weight: int.tryParse(_weightController.text.trim()) ?? 0,
          unit: _weightUnit,
        ).toJson();

      case ProductCategory.PESTICIDE:
        return PesticideAttributes(
          activeIngredient: _activeIngredientController.text.trim(),
          concentration: _concentrationController.text.trim(),
          volume: double.tryParse(_volumeController.text.trim()) ?? 0.0,
          unit: _volumeUnit,
          targetPests: [],
        ).toJson();

      case ProductCategory.SEED:
        return SeedAttributes(
          strain: _strainController.text.trim(),
          origin: _originController.text.trim(),
          germinationRate: _germinationRateController.text.trim(),
          purity: _purityController.text.trim(),
        ).toJson();
    }
  }

  Future<void> _saveProduct({bool isComplete = false}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final newProduct = Product(
        id: '',
        sku: _skuController.text.trim().isEmpty
            ? null
            : _skuController.text.trim(),
        name: widget.productName,
        category: widget.category,
        companyId: widget.companyId,
        imageUrl: widget.imageUrl,
        attributes: _buildAttributes(),
        isActive: true,
        isBanned: false,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        storeId: BaseService.getDefaultStoreId(),
      );

      final provider = context.read<ProductProvider>();
      final success = await provider.addProduct(newProduct);

      if (success) {
        if (mounted) {
          setState(() {
            _productCreated = true; // Mark as created to prevent duplicate
          });

          final message = isComplete
              ? 'Đã tạo sản phẩm với đầy đủ thông tin!'
              : 'Đã tạo sản phẩm thành công!';

          // Show success dialog
          await _showSuccessDialog(message);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                provider.errorMessage.isNotEmpty
                    ? provider.errorMessage
                    : 'Có lỗi xảy ra khi tạo sản phẩm',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi không mong muốn: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _saveWithCurrentInfo() {
    if (_productCreated) return; // Prevent duplicate creation
    _saveProduct(isComplete: false);
  }

  void _saveComplete() {
    if (_productCreated) return; // Prevent duplicate creation
    _saveProduct(isComplete: true);
  }

  Future<void> _showSuccessDialog(String message) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button to dismiss
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Thành công!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Sản phẩm đã được thêm vào danh sách và sẵn sàng sử dụng.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: <Widget>[
            Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog

                  // Pop all 3 wizard screens to return to product list
                  Navigator.of(context).pop(); // Pop step 3
                  Navigator.of(context).pop(); // Pop step 2
                  Navigator.of(context).pop(); // Pop step 1
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Quay về danh sách',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
