import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../shared/utils/formatter.dart';
import '../../providers/company_provider.dart';
import '../../providers/purchase_order_provider.dart';
import '../../models/company.dart';
import '../../models/product.dart';
import '../../models/purchase_order.dart';
import '../../models/purchase_order_status.dart';
import '../../../../core/routing/route_names.dart';

class CreatePurchaseOrderScreen extends StatefulWidget {
  const CreatePurchaseOrderScreen({Key? key}) : super(key: key);

  static const String routeName = '/create-po';

  @override
  _CreatePurchaseOrderScreenState createState() =>
      _CreatePurchaseOrderScreenState();
}

class _CreatePurchaseOrderScreenState extends State<CreatePurchaseOrderScreen> {
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CompanyProvider>().loadCompanies();
      context.read<PurchaseOrderProvider>().clearPOCart();
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _showProductPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Chọn Sản Phẩm'),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.6,
            child: ProductPickerDialog(),
          ),
          actions: [
            TextButton(
              child: const Text('Đóng'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        );
      },
    );
  }

  List<String> _getUnitListForCategory(ProductCategory category) {
    switch (category) {
      case ProductCategory.FERTILIZER:
        return ['kg', 'tấn', 'bao'];
      case ProductCategory.PESTICIDE:
        return ['ml', 'lít', 'chai', 'gói', 'lọ'];
      case ProductCategory.SEED:
        return ['kg', 'bao'];
      default:
        return ['cái'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final companyProvider = context.watch<CompanyProvider>();
    final poProvider = context.watch<PurchaseOrderProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo Đơn Nhập Hàng'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSupplierDropdown(companyProvider, poProvider),
            const SizedBox(height: 24),
            _buildPOCart(poProvider),
            const SizedBox(height: 24),
            _buildSummary(poProvider),
            const SizedBox(height: 32),
            _buildActionButtons(poProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierDropdown(
      CompanyProvider companyProvider, PurchaseOrderProvider poProvider) {
    if (companyProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return DropdownButtonFormField<String>(
      value: poProvider.selectedSupplierId,
      hint: const Text('Chọn nhà cung cấp'),
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Nhà cung cấp'),
      items: companyProvider.companies.map((Company company) {
        return DropdownMenuItem<String>(
          value: company.id,
          child: Text(company.name),
        );
      }).toList(),
      onChanged: (String? newValue) {
        if (newValue != null) {
          poProvider.setSupplierForCart(newValue);
        }
      },
      validator: (value) => value == null ? 'Vui lòng chọn nhà cung cấp' : null,
    );
  }

  Widget _buildPOCart(PurchaseOrderProvider poProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Giỏ hàng nhập', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (poProvider.poCartItems.isEmpty)
          const Text('Chưa có sản phẩm nào.')
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: poProvider.poCartItems.length,
            itemBuilder: (context, index) {
              final item = poProvider.poCartItems[index];
              return _buildCartItem(item, poProvider);
            },
          ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Thêm Sản Phẩm'),
          onPressed: poProvider.selectedSupplierId == null
              ? null
              : () => _showProductPicker(context),
        ),
      ],
    );
  }

  Widget _buildCartItem(POCartItem item, PurchaseOrderProvider poProvider) {
    final unitList = _getUnitListForCategory(item.product.category);
    final isZeroQuantity = item.quantity == 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.product.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isZeroQuantity ? Colors.grey : Colors.black,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _showRemoveItemDialog(context, item.product.name, () {
                    poProvider.removeFromPOCart(item.product.id);
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _buildSmartQuantityField(item, poProvider),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: item.unit,
                    decoration: const InputDecoration(
                      labelText: 'Đơn vị',
                      border: OutlineInputBorder(),
                    ),
                    items: unitList.map((String unit) {
                      return DropdownMenuItem<String>(value: unit, child: Text(unit));
                    }).toList(),
                    onChanged: (String? newValue) {
                      poProvider.updatePOCartItem(item.product.id, newUnit: newValue);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSmartPriceField(item, poProvider),
            if (isZeroQuantity)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Số lượng = 0. Sản phẩm sẽ không được thêm vào đơn hàng.',
                        style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            // Total row
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Thành tiền:', style: TextStyle(fontWeight: FontWeight.w500)),
                Text(
                  AppFormatter.formatCurrency(item.quantity * item.unitCost),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isZeroQuantity ? Colors.grey : Colors.green.shade700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartQuantityField(POCartItem item, PurchaseOrderProvider poProvider) {
    return TextFormField(
      controller: item.quantityController,
      decoration: InputDecoration(
        labelText: 'Số lượng',
        hintText: 'Nhập số lượng (ví dụ: 10)',
        border: const OutlineInputBorder(),
        suffixIcon: item.quantity == 0
          ? Icon(Icons.warning, color: Colors.orange.shade600, size: 20)
          : null,
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly, // Only allow digits
      ],
      onTap: () {
        // Select all text on tap for easy editing
        item.quantityController.selection = TextSelection(baseOffset: 0, extentOffset: item.quantityController.text.length);
      },
      onChanged: (value) {
        // Handle empty string or invalid input gracefully
        if (value.isEmpty) {
          poProvider.updatePOCartItem(item.product.id, newQuantity: 0);
          return;
        }

        final qty = int.tryParse(value);
        if (qty != null && qty >= 0 && qty <= 999999) {
          poProvider.updatePOCartItem(item.product.id, newQuantity: qty);
        } else if (qty == null) {
          // If input is invalid, revert controller text to previous valid value
          item.quantityController.text = item.quantity.toString();
          item.quantityController.selection = TextSelection.fromPosition(TextPosition(offset: item.quantityController.text.length));
        }
      },
      validator: (value) {
        // Allow empty (will be treated as 0)
        if (value == null || value.isEmpty) {
          return null; // Valid - will be 0
        }

        final qty = int.tryParse(value);
        if (qty == null) {
          return 'Vui lòng nhập số hợp lệ';
        }
        if (qty < 0) {
          return 'Số lượng không được âm';
        }
        if (qty > 999999) {
          return 'Số lượng quá lớn (tối đa 999,999)';
        }
        return null; // Valid
      },
    );
  }

  Widget _buildSmartPriceField(POCartItem item, PurchaseOrderProvider poProvider) {
    return TextFormField(
      controller: item.unitCostController,
      decoration: InputDecoration(
        labelText: 'Giá nhập / đơn vị',
        hintText: 'Nhập giá nhập (ví dụ: 25000)',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.attach_money),
        suffixText: 'VND',
      ),
      keyboardType: TextInputType.number,
      onTap: () {
        // Select all text on tap for easy editing
        item.unitCostController.selection = TextSelection(baseOffset: 0, extentOffset: item.unitCostController.text.length);
      },
      onChanged: (value) {
        // Handle empty string gracefully
        if (value.isEmpty) {
          poProvider.updatePOCartItem(item.product.id, newUnitCost: 0.0);
          return;
        }

        final cost = double.tryParse(value);
        if (cost != null && cost >= 0) {
          poProvider.updatePOCartItem(item.product.id, newUnitCost: cost);
        } else if (cost == null) {
          // If input is invalid, revert controller text to previous valid value
          item.unitCostController.text = item.unitCost.toStringAsFixed(0);
          item.unitCostController.selection = TextSelection.fromPosition(TextPosition(offset: item.unitCostController.text.length));
        }
      },
      validator: (value) {
        // Allow empty (will be treated as 0)
        if (value == null || value.isEmpty) {
          return null; // Valid - will be 0
        }

        final cost = double.tryParse(value);
        if (cost == null) {
          return 'Vui lòng nhập số hợp lệ';
        }
        if (cost < 0) {
          return 'Giá không được âm';
        }
        return null; // Valid
      },
    );
  }

  void _showRemoveItemDialog(BuildContext context, String productName, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xác nhận xóa'),
          content: Text('Bạn có chắc muốn xóa "$productName" khỏi giỏ hàng?'),
          actions: [
            TextButton(
              child: const Text('Hủy'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Xóa', style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummary(PurchaseOrderProvider poProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _notesController,
          decoration: const InputDecoration(labelText: 'Ghi chú', border: OutlineInputBorder()),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Tổng cộng:', style: Theme.of(context).textTheme.titleLarge),
            Text(
              AppFormatter.formatCurrency(poProvider.poCartTotal),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.green, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons(PurchaseOrderProvider poProvider) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            child: const Text('Lưu Nháp'),
            onPressed: poProvider.poCartItems.isEmpty ? null : () async {
              final newPO = await poProvider.createPOFromCart(
                notes: _notesController.text,
                status: PurchaseOrderStatus.draft,
              );
              if (newPO != null) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã lưu đơn hàng nháp')),
                );
              }
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            child: const Text('Gửi Đơn Hàng'),
            onPressed: poProvider.poCartItems.isEmpty ? null : () async {
               final newPO = await poProvider.createPOFromCart(
                notes: _notesController.text,
                status: PurchaseOrderStatus.sent,
              );
              if (newPO != null) {
                Navigator.of(context).pop(); // Pop current screen
                Navigator.of(context).pushNamed(
                  RouteNames.purchaseOrderDetail,
                  arguments: newPO,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã gửi đơn nhập hàng')),
                );
              }
            },
          ),
        ),
      ],
    );
  }
}

// Widget con cho Product Picker Dialog
class ProductPickerDialog extends StatefulWidget {
  @override
  _ProductPickerDialogState createState() => _ProductPickerDialogState();
}

class _ProductPickerDialogState extends State<ProductPickerDialog> {
  final _searchController = TextEditingController();
  List<Product> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    final poProvider = context.read<PurchaseOrderProvider>();
    _filteredProducts = poProvider.filteredProducts;

    _searchController.addListener(() {
      _filterProducts(_searchController.text);
    });
  }

  void _filterProducts(String query) {
    final poProvider = context.read<PurchaseOrderProvider>();
    if (query.isEmpty) {
      _filteredProducts = poProvider.filteredProducts;
    } else {
      _filteredProducts = poProvider.filteredProducts
          .where((product) =>
              product.name.toLowerCase().contains(query.toLowerCase()) ||
              (product.sku?.toLowerCase().contains(query.toLowerCase()) ?? false))
          .toList();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final poProvider = context.watch<PurchaseOrderProvider>();

    // Update filtered products when company changes
    if (_filteredProducts != poProvider.filteredProducts && _searchController.text.isEmpty) {
      _filteredProducts = poProvider.filteredProducts;
    }

    return Column(
      children: [
        if (poProvider.selectedSupplierId == null)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Vui lòng chọn nhà cung cấp trước',
              style: TextStyle(color: Colors.orange, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          )
        else ...[
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Tìm kiếm sản phẩm của nhà cung cấp...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Builder(
              builder: (context) {
                if (poProvider.loadingProducts) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Đang tải sản phẩm...'),
                      ],
                    ),
                  );
                }

                if (_filteredProducts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline, size: 48, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isEmpty
                              ? 'Nhà cung cấp này chưa có sản phẩm nào'
                              : 'Không tìm thấy sản phẩm phù hợp',
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final products = _filteredProducts;

                return ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return ListTile(
                      title: Text(product.name),
                      subtitle: Text(product.sku ?? 'Chưa có SKU'),
                      onTap: () {
                        // Set default unit based on category
                        String? defaultUnit;
                        if (product.category == ProductCategory.FERTILIZER) defaultUnit = 'kg';
                        if (product.category == ProductCategory.PESTICIDE) defaultUnit = 'chai';
                        if (product.category == ProductCategory.SEED) defaultUnit = 'kg';

                        poProvider.addToPOCart(product, unit: defaultUnit);
                        Navigator.of(context).pop(); // Đóng dialog sau khi chọn
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
