import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/utils/responsive.dart';
import '../../models/product.dart';
import '../../models/company.dart';
import '../../providers/product_provider.dart';
import '../../providers/company_provider.dart';
import '../../../../shared/widgets/loading_overlay.dart';

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
    // Thêm một entry mặc định
    _addNewEntry();
  }

  void _addNewEntry() {
    setState(() {
      final newEntry = ProductEntry();
      // Add listener to update button text when user types
      newEntry.nameController.addListener(() {
        setState(() {}); // Trigger rebuild to update button text
      });
      _productEntries.add(newEntry);
    });
  }

  void _removeEntry(int index) {
    if (_productEntries.length > 1) {
      setState(() {
        // Remove listener before removing entry
        _productEntries[index].nameController.removeListener(() {});
        _productEntries.removeAt(index);
      });
    }
  }

  Future<void> _saveProducts() async {
    // Validate tất cả entries
    final validEntries = _productEntries.where((entry) {
      return entry.nameController.text.trim().isNotEmpty;
    }).toList();

    if (validEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập ít nhất một sản phẩm'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Store context references before any await calls
    final productProvider = context.read<ProductProvider>();
    final companyProvider = context.read<CompanyProvider>();
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Hiển thị confirmation dialog
    final confirmed = await _showConfirmationDialog(validEntries.length);
    if (!confirmed) return;

    setState(() => _isLoading = true);

    int successCount = 0;
    int errorCount = 0;

    try {
      for (final entry in validEntries) {
        final product = Product(
          id: '', // Sẽ được generate bởi database
          name: entry.nameController.text.trim(),
          category: entry.selectedCategory,
          companyId: widget.company.id,
          attributes: {},
          isActive: true,
          isBanned: false,
          storeId: '', // Sẽ được set bởi service
          minStockLevel: 0,
          currentSellingPrice: 0.0,
          unit: 'kg',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final success = await productProvider.addProduct(product);
        if (success) {
          successCount++;
        } else {
          errorCount++;
        }
      }

      // Refresh company products
      if (mounted) {
        await companyProvider.loadCompanyProducts(widget.company.id);

        navigator.pop();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              'Đã thêm $successCount sản phẩm thành công'
              '${errorCount > 0 ? ', $errorCount lỗi' : ''}',
            ),
            backgroundColor: errorCount > 0 ? Colors.orange : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
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
                    'Chỉ cần nhập tên sản phẩm và chọn loại. Các thông tin khác có thể cập nhật sau.',
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
                    color: Colors.black.withValues(alpha: 0.1),
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
            // Header với số thứ tự và nút xóa
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

            // Tên sản phẩm
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

            // Loại sản phẩm
            DropdownButtonFormField<ProductCategory>(
              initialValue: entry.selectedCategory,
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
                setState(() {
                  entry.selectedCategory = value!;
                });
              },
            ),
          ],
        ),
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
    // Dispose tất cả controllers
    for (final entry in _productEntries) {
      entry.dispose();
    }
    super.dispose();
  }
}

class ProductEntry {
  final TextEditingController nameController = TextEditingController();
  ProductCategory selectedCategory = ProductCategory.FERTILIZER;

  void dispose() {
    nameController.dispose();
  }
}