import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../models/fertilizer_attributes.dart';
import '../../models/pesticide_attributes.dart';
import '../../models/seed_attributes.dart';
import '../../providers/product_provider.dart';
import '../../providers/company_provider.dart'; // Thêm import CompanyProvider
import '../../../../shared/services/base_service.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers cho thông tin cơ bản
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Dropdown selections
  ProductCategory _selectedCategory = ProductCategory.FERTILIZER;
  String? _selectedCompanyId;

  // Controllers cho attributes động
  // Fertilizer
  final _npkRatioController = TextEditingController();
  final _fertilizerTypeController = TextEditingController();
  final _weightController = TextEditingController();
  final _weightUnitController = TextEditingController();

  // Pesticide
  final _activeIngredientController = TextEditingController();
  final _concentrationController = TextEditingController();
  final _volumeController = TextEditingController();
  final _volumeUnitController = TextEditingController();

  // Seed
  final _strainController = TextEditingController();
  final _originController = TextEditingController();
  final _germinationRateController = TextEditingController();
  final _purityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Yêu cầu CompanyProvider tải danh sách nhà cung cấp
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CompanyProvider>().loadCompanies();
    });
  }

  @override
  void dispose() {
    // Dispose tất cả controllers
    _nameController.dispose();
    _skuController.dispose();
    _descriptionController.dispose();
    _npkRatioController.dispose();
    _fertilizerTypeController.dispose();
    _weightController.dispose();
    _weightUnitController.dispose();
    _activeIngredientController.dispose();
    _concentrationController.dispose();
    _volumeController.dispose();
    _volumeUnitController.dispose();
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
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Section: Thông tin cơ bản
              _buildSectionTitle('Thông Tin Cơ Bản'),
              const SizedBox(height: 16),

              _buildBasicInfoForm(),

              const SizedBox(height: 24),

              // Section: Thuộc tính đặc thù
              _buildSectionTitle('Thuộc Tính Sản Phẩm'),
              const SizedBox(height: 16),

              _buildCategorySelector(),

              const SizedBox(height: 16),

              _buildDynamicAttributesForm(),

              const SizedBox(height: 32),

              // Action buttons
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildBasicInfoForm() {
    return Column(
      children: [
        // Tên sản phẩm
        TextFormField(
          controller: _nameController,
          decoration: _buildInputDecoration(
            label: 'Tên sản phẩm',
            hint: 'Ví dụ: Phân bón NPK 16-16-8',
            icon: Icons.inventory,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Vui lòng nhập tên sản phẩm';
            }
            if (value.trim().length < 2) {
              return 'Tên sản phẩm phải có ít nhất 2 ký tự';
            }
            return null;
          },
        ),

        const SizedBox(height: 16),

        // SKU/Barcode
        TextFormField(
          controller: _skuController,
          decoration: _buildInputDecoration(
            label: 'Mã SKU/Barcode (Tùy chọn)',
            hint: 'Để trống nếu chưa có - có thể cập nhật sau',
            icon: Icons.qr_code,
          ),
          validator: (value) {
            // SKU is now optional - only validate if provided
            if (value != null && value.trim().isNotEmpty && value.trim().length < 3) {
              return 'Mã SKU phải có ít nhất 3 ký tự';
            }
            return null;
          },
        ),

        const SizedBox(height: 16),

        // Nhà cung cấp
        Consumer<CompanyProvider>(
          builder: (context, provider, child) {
            // Nếu chưa có dữ liệu thì hiển thị dropdown bị vô hiệu hóa
            if (provider.isLoading && provider.companies.isEmpty) {
              return DropdownButtonFormField<String>(
                decoration: _buildInputDecoration(
                  label: 'Nhà cung cấp',
                  hint: 'Đang tải...',
                  icon: Icons.business,
                ),
                items: const [],
                onChanged: null, // Vô hiệu hóa
              );
            }

            // Nếu đã có dữ liệu thì xây dựng dropdown
            return DropdownButtonFormField<String>(
              value: _selectedCompanyId,
              decoration: _buildInputDecoration(
                label: 'Nhà cung cấp',
                hint: 'Chọn nhà cung cấp',
                icon: Icons.business,
              ),
              // Dùng danh sách thật từ provider
              items: provider.companies.map((company) {
                return DropdownMenuItem<String>(
                  value: company.id, // Value giờ là UUID thật
                  child: Text(company.name),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCompanyId = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng chọn nhà cung cấp';
                }
                return null;
              },
            );
          },
        ),

        const SizedBox(height: 16),

        // Mô tả (optional)
        TextFormField(
          controller: _descriptionController,
          decoration: _buildInputDecoration(
            label: 'Mô tả (tùy chọn)',
            hint: 'Mô tả chi tiết về sản phẩm',
            icon: Icons.description,
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    return DropdownButtonFormField<ProductCategory>(
      value: _selectedCategory,
      decoration: _buildInputDecoration(
        label: 'Loại sản phẩm',
        hint: 'Chọn loại sản phẩm',
        icon: Icons.category,
      ),
      items: ProductCategory.values.map((category) {
        return DropdownMenuItem<ProductCategory>(
          value: category,
          child: Text(_getCategoryDisplayName(category)),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedCategory = value;
            // Clear controllers khi đổi category
            _clearAttributeControllers();
          });
        }
      },
    );
  }

  Widget _buildDynamicAttributesForm() {
    switch (_selectedCategory) {
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
        const Text(
          'Thông số phân bón',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 12),

        // Tỷ lệ NPK
        TextFormField(
          controller: _npkRatioController,
          decoration: _buildInputDecoration(
            label: 'Tỷ lệ NPK (Tùy chọn)',
            hint: 'Để trống nếu chưa có - Ví dụ: 16-16-8',
            icon: Icons.science,
          ),
          validator: (value) {
            // NPK ratio is now optional
            return null;
          },
        ),

        const SizedBox(height: 16),

        // Loại phân bón
        DropdownButtonFormField<String>(
          value: _fertilizerTypeController.text.isEmpty ? null : _fertilizerTypeController.text,
          decoration: _buildInputDecoration(
            label: 'Loại (Tùy chọn)',
            hint: 'Chọn loại phân bón',
            icon: Icons.type_specimen,
          ),
          items: ['vô cơ', 'hữu cơ', 'hỗn hợp'].map((type) {
            return DropdownMenuItem<String>(
              value: type,
              child: Text(type),
            );
          }).toList(),
          onChanged: (value) {
            _fertilizerTypeController.text = value ?? '';
          },
          validator: (value) {
            // Fertilizer type is now optional
            return null;
          },
        ),

        const SizedBox(height: 16),

        // Khối lượng và Đơn vị
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _weightController,
                decoration: _buildInputDecoration(
                  label: 'Khối lượng (Tùy chọn)',
                  hint: 'Để trống nếu chưa có',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  // Weight is now optional - only validate if provided
                  if (value != null && value.trim().isNotEmpty && double.tryParse(value) == null) {
                    return 'Khối lượng phải là số';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _weightUnitController.text.isEmpty ? 'kg' : _weightUnitController.text,
                decoration: _buildInputDecoration(
                  label: 'Đơn vị',
                ),
                items: ['kg', 'tấn', 'bao'].map((unit) {
                  return DropdownMenuItem<String>(
                    value: unit,
                    child: Text(unit),
                  );
                }).toList(),
                onChanged: (value) {
                  _weightUnitController.text = value ?? 'kg';
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Chọn đơn vị';
                  }
                  return null;
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
        const Text(
          'Thông số thuốc BVTV',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.orange,
          ),
        ),
        const SizedBox(height: 12),

        // Hoạt chất chính
        TextFormField(
          controller: _activeIngredientController,
          decoration: _buildInputDecoration(
            label: 'Hoạt chất chính (Tùy chọn)',
            hint: 'Để trống nếu chưa có - Ví dụ: Imidacloprid',
            icon: Icons.biotech,
          ),
          validator: (value) {
            // Active ingredient is now optional
            return null;
          },
        ),

        const SizedBox(height: 16),

        // Nồng độ
        TextFormField(
          controller: _concentrationController,
          decoration: _buildInputDecoration(
            label: 'Nồng độ (Tùy chọn)',
            hint: 'Để trống nếu chưa có - Ví dụ: 4SC, 25EC',
          ),
          validator: (value) {
            // Concentration is now optional
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Thể tích và Đơn vị
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _volumeController,
                decoration: _buildInputDecoration(
                  label: 'Thể tích (Tùy chọn)',
                  hint: 'Để trống nếu chưa có',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  // Volume is now optional - only validate if provided
                  if (value != null && value.trim().isNotEmpty && double.tryParse(value) == null) {
                    return 'Thể tích phải là số';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _volumeUnitController.text.isEmpty ? 'ml' : _volumeUnitController.text,
                decoration: _buildInputDecoration(
                  label: 'Đơn vị',
                ),
                items: ['ml', 'lít', 'chai', 'gói', 'lọ'].map((unit) {
                  return DropdownMenuItem<String>(
                    value: unit,
                    child: Text(unit),
                  );
                }).toList(),
                onChanged: (value) {
                  _volumeUnitController.text = value ?? 'ml';
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Chọn đơn vị';
                  }
                  return null;
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
        const Text(
          'Thông số lúa giống',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.brown,
          ),
        ),
        const SizedBox(height: 12),

        // Tên giống
        TextFormField(
          controller: _strainController,
          decoration: _buildInputDecoration(
            label: 'Tên giống (Tùy chọn)',
            hint: 'Để trống nếu chưa có - Ví dụ: OM18, ST24',
            icon: Icons.grass,
          ),
          validator: (value) {
            // Seed strain is now optional
            return null;
          },
        ),

        const SizedBox(height: 16),

        // Nguồn gốc
        TextFormField(
          controller: _originController,
          decoration: _buildInputDecoration(
            label: 'Nguồn gốc (Tùy chọn)',
            hint: 'Để trống nếu chưa có - Ví dụ: Việt Nam, Nhật Bản',
            icon: Icons.place,
          ),
          validator: (value) {
            // Origin is now optional
            return null;
          },
        ),

        const SizedBox(height: 16),

        // Tỷ lệ nảy mầm và Độ thuần chủng
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _germinationRateController,
                decoration: _buildInputDecoration(
                  label: 'Tỷ lệ nảy mầm (%) - Tùy chọn',
                  hint: 'Để trống nếu chưa có',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  // Germination rate is now optional - only validate if provided
                  if (value != null && value.trim().isNotEmpty) {
                    final rate = double.tryParse(value);
                    if (rate == null || rate < 0 || rate > 100) {
                      return 'Tỷ lệ phải từ 0-100%';
                    }
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _purityController,
                decoration: _buildInputDecoration(
                  label: 'Độ thuần chủng (%) - Tùy chọn',
                  hint: 'Để trống nếu chưa có',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  // Purity is now optional - only validate if provided
                  if (value != null && value.trim().isNotEmpty) {
                    final purity = double.tryParse(value);
                    if (purity == null || purity < 0 || purity > 100) {
                      return 'Độ thuần chủng phải từ 0-100%';
                    }
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        // Nút Hủy
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading ? null : () {
              Navigator.pop(context);
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: Colors.grey[400]!),
            ),
            child: const Text(
              'Hủy',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),

        const SizedBox(width: 16),

        // Nút Lưu
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveProduct,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
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
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Lưu Sản Phẩm',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // Helper methods
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
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: Theme.of(context).primaryColor,
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
    );
  }

  String _getCategoryDisplayName(ProductCategory category) {
    switch (category) {
      case ProductCategory.FERTILIZER:
        return 'Phân Bón';
      case ProductCategory.PESTICIDE:
        return 'Thuốc BVTV';
      case ProductCategory.SEED:
        return 'Lúa Giống';
    }
  }

  void _clearAttributeControllers() {
    // Clear tất cả controllers của attributes
    _npkRatioController.clear();
    _fertilizerTypeController.clear();
    _weightController.clear();
    _weightUnitController.clear();
    _activeIngredientController.clear();
    _concentrationController.clear();
    _volumeController.clear();
    _volumeUnitController.clear();
    _strainController.clear();
    _originController.clear();
    _germinationRateController.clear();
    _purityController.clear();
  }

  Map<String, dynamic> _buildAttributes() {
    switch (_selectedCategory) {
      case ProductCategory.FERTILIZER:
        return FertilizerAttributes(
          npkRatio: _npkRatioController.text.trim(),
          type: _fertilizerTypeController.text.trim(),
          weight: int.tryParse(_weightController.text.trim()) ?? 0,
          unit: _weightUnitController.text.trim(),
        ).toJson();

      case ProductCategory.PESTICIDE:
        return PesticideAttributes(
          activeIngredient: _activeIngredientController.text.trim(),
          concentration: _concentrationController.text.trim(),
          volume: double.tryParse(_volumeController.text.trim()) ?? 0.0,
          unit: _volumeUnitController.text.trim(),
          targetPests: [], // Có thể mở rộng thêm field cho target pests
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

  Future<void> _saveProduct() async {
    // Kiểm tra validation
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Hiển thị loading
    setState(() {
      _isLoading = true;
    });

    try {
      // Tạo object Product
      final newProduct = Product(
        id: '', // Sẽ được tạo bởi database
        sku: _skuController.text.trim(),
        name: _nameController.text.trim(),
        category: _selectedCategory,
        companyId: _selectedCompanyId?.isEmpty == true ? null : _selectedCompanyId,
        attributes: _buildAttributes(),
        isActive: true,
        isBanned: false,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        storeId: BaseService.getDefaultStoreId() ?? '',
      );

      // Gọi ProductProvider để lưu
      final provider = context.read<ProductProvider>();
      final success = await provider.addProduct(newProduct);

      if (success) {
        // Thành công
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thêm sản phẩm thành công!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Thất bại
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(provider.errorMessage.isNotEmpty
                  ? provider.errorMessage
                  : 'Có lỗi xảy ra khi thêm sản phẩm'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      // Xử lý exception
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi không mong muốn: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      // Ẩn loading
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}