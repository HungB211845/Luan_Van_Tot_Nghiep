import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../shared/utils/input_formatters.dart';
import 'package:provider/provider.dart';
import '../../../../shared/utils/responsive.dart';
import '../../models/product.dart';
import '../../models/company.dart';
import '../../providers/product_provider.dart';
import '../../providers/company_provider.dart';
import '../../../../shared/widgets/loading_overlay.dart';

import 'package:flutter/cupertino.dart';

import '../../models/bulk_product_entry.dart';

class BulkProductAddScreen extends StatefulWidget {
  final Company company;

  const BulkProductAddScreen({
    super.key,
    required this.company,
  });

  static const String routeName = '/bulk-product-add';

  @override
  State<BulkProductAddScreen> createState() => _BulkProductAddScreenState();
}

class _BulkProductAddScreenState extends State<BulkProductAddScreen> {
  final List<ProductEntry> _productEntries = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Add a default entry
    _addNewEntry();
  }

  void _addNewEntry() {
    setState(() {
      final newEntry = ProductEntry();
      // Add listener to update button text when user types
      newEntry.nameController.addListener(() {
        setState(() {}); // Trigger rebuild to update button text
      });
      // Add listener to rebuild UOM config when category changes
      newEntry.categoryNotifier.addListener(() {
        setState(() {});
      });
      _productEntries.add(newEntry);
    });
  }

  void _removeEntry(int index) {
    if (_productEntries.length > 1) {
      setState(() {
        // Dispose all controllers and notifiers in the entry
        _productEntries[index].dispose();
        _productEntries.removeAt(index);
      });
    }
  }

  Future<void> _saveProducts() async {
    // 1. Validate entries
    final validEntries = _productEntries
        .where((entry) => entry.nameController.text.trim().isNotEmpty)
        .toList();

    if (validEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập ít nhất một sản phẩm'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 2. Get contexts before async gap
    final productProvider = context.read<ProductProvider>();
    final companyProvider = context.read<CompanyProvider>();
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // 3. Show confirmation
    final confirmed = await _showConfirmationDialog(validEntries.length);
    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      // 4. Map UI state to DTOs
      final List<ProductEntryData> entriesData = validEntries.map((entry) {
        double? pesticideVolume;
        int? pesticideQuantity;

        if (entry.categoryNotifier.value == ProductCategory.PESTICIDE) {
          pesticideVolume =
              double.tryParse(entry.pesticideVolumeController.text.trim());
          pesticideQuantity =
              int.tryParse(entry.pesticideQuantityController.text.trim());
        }

        final price = double.tryParse(entry.priceController.text.replaceAll('.', ''));

        return ProductEntryData(
          name: entry.nameController.text.trim(),
          category: entry.categoryNotifier.value,
          pesticidePackagingType: entry.pesticidePackagingType,
          pesticideBaseUnit: entry.pesticideBaseUnit,
          pesticideVolume: pesticideVolume,
          pesticideQuantityPerBox: pesticideQuantity,
          price: price,
        );
      }).toList();

      // 5. Call the new provider method
      final result = await productProvider.addBulkProducts(entriesData, widget.company.id);
      final successCount = result['success'] ?? 0;
      final errorCount = result['error'] ?? 0;

      // 6. Handle result
      if (mounted) {
        await companyProvider.loadCompanyProducts(widget.company.id);

        navigator.pop();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              'Đã thêm $successCount sản phẩm thành công'
              '${errorCount > 0 ? '. Có $errorCount lỗi.' : '.'}',
            ),
            backgroundColor: errorCount > 0 ? Colors.orange : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Lỗi không mong muốn: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _showConfirmationDialog(int productCount) async {
    final navigator = Navigator.of(context);
    
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Xác nhận thêm sản phẩm'),
          content: Text(
            'Bạn có chắc chắn muốn thêm $productCount sản phẩm cho nhà cung cấp "${widget.company.name}" không?',
          ),
          actions: [
            TextButton(
              onPressed: () => navigator.pop(false),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => navigator.pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Xác nhận'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      title: 'Thêm sản phẩm cho ${widget.company.name}',
      showBackButton: true,
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: Column(
          children: [
            // Header info
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(context.sectionPadding),
              color: Colors.green.shade50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nhà cung cấp: ${widget.company.name}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Nhập tên, chọn loại. Đơn vị sẽ được tự động cấu hình.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // Product entries list
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(context.sectionPadding),
                itemCount: _productEntries.length,
                itemBuilder: (context, index) {
                  return _buildProductEntry(index);
                },
              ),
            ),

            // Action buttons
            Container(
              padding: EdgeInsets.all(context.sectionPadding),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    offset: const Offset(0, -2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Add more product button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _addNewEntry,
                      icon: const Icon(Icons.add),
                      label: const Text('Thêm sản phẩm khác'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Colors.green),
                        foregroundColor: Colors.green,
                      ),
                    ),
                  ),
                  
                  SizedBox(height: context.cardSpacing),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveProducts,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Lưu ${_productEntries.where((e) => e.nameController.text.trim().isNotEmpty).length} sản phẩm',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductEntry(int index) {
    final entry = _productEntries[index];
    
    return Card(
      margin: EdgeInsets.only(bottom: context.cardSpacing),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(context.sectionPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with index and remove button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                if (_productEntries.length > 1)
                  IconButton(
                    onPressed: () => _removeEntry(index),
                    icon: const Icon(Icons.close, color: Colors.red, size: 20),
                    tooltip: 'Xóa sản phẩm này',
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
              ],
            ),

            SizedBox(height: context.cardSpacing),

            // Product Name
            TextField(
              controller: entry.nameController,
              decoration: const InputDecoration(
                labelText: 'Tên sản phẩm *',
                hintText: 'Nhập tên sản phẩm...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.inventory_2),
              ),
              textInputAction: TextInputAction.next,
            ),

            SizedBox(height: context.sectionPadding),

            // Product Category
            DropdownButtonFormField<ProductCategory>(
              value: entry.categoryNotifier.value,
              decoration: const InputDecoration(
                labelText: 'Loại sản phẩm *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: ProductCategory.values.map((category) {
                return DropdownMenuItem<ProductCategory>(
                  value: category,
                  child: Row(
                    children: [
                      Icon(
                        _getCategoryIcon(category),
                        color: _getCategoryColor(category),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(category.displayName),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  entry.categoryNotifier.value = value;
                }
              },
            ),

            // Dynamic UOM Config UI
            ValueListenableBuilder<ProductCategory>(
              valueListenable: entry.categoryNotifier,
              builder: (context, category, child) {
                if (category == ProductCategory.PESTICIDE) {
                  return _buildUomConfigUI(entry);
                }
                return const SizedBox.shrink();
              },
            ),

            SizedBox(height: context.sectionPadding),

            // Selling Price
            TextFormField(
              controller: entry.priceController,
              decoration: const InputDecoration(
                labelText: 'Giá bán',
                hintText: 'Nhập giá bán...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                CurrencyInputFormatter(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // New UI for Pesticide UOM Configuration
  Widget _buildUomConfigUI(ProductEntry entry) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quy cách đóng gói (Thuốc BVTV)',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<PesticidePackagingType>(
              groupValue: entry.pesticidePackagingType,
              backgroundColor: Colors.grey.shade200,
              thumbColor: _getCategoryColor(ProductCategory.PESTICIDE),
              onValueChanged: (value) {
                if (value != null) {
                  setState(() {
                    entry.pesticidePackagingType = value;
                    entry.pesticideBaseUnit = packagingDefaults[value]!.defaultBaseUnit;
                  });
                }
              },
              children: {
                for (var type in PesticidePackagingType.values)
                  type: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      packagingDefaults[type]!.displayName,
                      style: TextStyle(
                        color: entry.pesticidePackagingType == type
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                  ),
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: entry.pesticideVolumeController,
                  decoration: const InputDecoration(
                    labelText: 'Dung tích/KL',
                    hintText: 'ví dụ: 500',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<String>(
                  value: entry.pesticideBaseUnit,
                  decoration: const InputDecoration(
                    labelText: 'Đơn vị',
                    border: OutlineInputBorder(),
                  ),
                  items: packagingDefaults[entry.pesticidePackagingType]!
                      .baseUnits
                      .map((unit) => DropdownMenuItem(
                            value: unit,
                            child: Text(unit),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        entry.pesticideBaseUnit = value;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: entry.pesticideQuantityController,
            decoration: const InputDecoration(
              labelText: 'Số lượng/thùng',
              hintText: 'ví dụ: 20',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.inventory),
            ),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(ProductCategory category) {
    switch (category) {
      case ProductCategory.FERTILIZER:
        return Icons.eco;
      case ProductCategory.PESTICIDE:
        return Icons.bug_report;
      case ProductCategory.SEED:
        return Icons.grass;
    }
  }

  Color _getCategoryColor(ProductCategory category) {
    switch (category) {
      case ProductCategory.FERTILIZER:
        return Colors.green;
      case ProductCategory.PESTICIDE:
        return Colors.orange;
      case ProductCategory.SEED:
        return Colors.brown;
    }
  }

  @override
  void dispose() {
    // Dispose all controllers
    for (final entry in _productEntries) {
      entry.dispose();
    }
    super.dispose();
  }
}

class ProductEntry {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  // Use ValueNotifier to easily rebuild widgets that depend on the category
  final ValueNotifier<ProductCategory> categoryNotifier =
      ValueNotifier(ProductCategory.FERTILIZER);

  // State for Pesticide UOM configuration
  PesticidePackagingType pesticidePackagingType = PesticidePackagingType.bottle;
  String pesticideBaseUnit = 'ml';
  final TextEditingController pesticideVolumeController =
      TextEditingController();
  final TextEditingController pesticideQuantityController =
      TextEditingController();

  ProductEntry() {
    // Set default base unit when category changes to pesticide
    categoryNotifier.addListener(() {
      if (categoryNotifier.value == ProductCategory.PESTICIDE) {
        pesticideBaseUnit =
            packagingDefaults[pesticidePackagingType]!.defaultBaseUnit;
      }
    });
  }

  void dispose() {
    nameController.dispose();
    priceController.dispose();
    categoryNotifier.dispose();
    pesticideVolumeController.dispose();
    pesticideQuantityController.dispose();
  }
}
