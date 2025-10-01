import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../shared/utils/formatter.dart';
import '../../providers/company_provider.dart';
import '../../providers/purchase_order_provider.dart';
import '../../providers/product_provider.dart';
import '../../models/company.dart';
import '../../models/product.dart';
import '../../models/purchase_order.dart';
import '../../models/purchase_order_status.dart';
import '../../../../core/routing/route_names.dart';
import '../company/company_picker_screen.dart';
import 'bulk_product_selection_screen.dart';

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
      // Don't clear PO cart here - preserve existing state
      // Only clear if this is a truly fresh start (no supplier selected)
      final poProvider = context.read<PurchaseOrderProvider>();
      if (poProvider.selectedSupplierId == null) {
        poProvider.clearPOCart();
      }
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _showQuickConfirmDialog(BuildContext context, PurchaseOrder po) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.flash_on, color: Colors.orange[600], size: 28),
            const SizedBox(width: 8),
            const Text(
              'Xác Nhận Nhanh',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bạn có muốn xác nhận nhận hàng ngay cho đơn hàng này không?',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Đơn hàng: ${po.poNumber}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Để sau', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.check_circle, size: 20),
            label: const Text('XÁC NHẬN NGAY'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              // Capture dependencies before closing dialog
              final poProvider = context.read<PurchaseOrderProvider>();
              final productProvider = context.read<ProductProvider>();
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              // Close dialog first
              navigator.pop();

              // Show loading indicator
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('Đang xác nhận nhận hàng...'),
                    ],
                  ),
                  backgroundColor: Colors.blue,
                  duration: const Duration(seconds: 3),
                  behavior: SnackBarBehavior.floating,
                ),
              );

              final success = await poProvider.receivePO(po.id);

              if (success) {
                // Refresh inventory
                final productIds = poProvider.getProductIdsFromPO(po.id);
                await productProvider.refreshInventoryAfterGoodsReceipt(
                  productIds,
                );
                await productProvider.refreshAllInventoryData();
                await productProvider.loadProductsPaginated();

                // Show success message
                scaffoldMessenger.hideCurrentSnackBar();
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '✅ Đã xác nhận nhận hàng ${po.poNumber} thành công!',
                        ),
                      ],
                    ),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 4),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );

                // Navigate to success screen
                navigator.pushNamed(
                  RouteNames.purchaseOrderReceiveSuccess,
                  arguments: po.poNumber,
                );
              } else {
                // Show error
                scaffoldMessenger.hideCurrentSnackBar();
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.error, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            poProvider.errorMessage.isNotEmpty
                                ? poProvider.errorMessage
                                : 'Có lỗi xảy ra khi xác nhận nhận hàng',
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 4),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _navigateToProductSelection(BuildContext context) {
    final poProvider = context.read<PurchaseOrderProvider>();
    final companyProvider = context.read<CompanyProvider>();

    if (poProvider.selectedSupplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn nhà cung cấp trước')),
      );
      return;
    }

    // Find supplier name from company provider
    final supplier = companyProvider.companies.firstWhere(
      (company) => company.id == poProvider.selectedSupplierId,
      orElse: () => Company(
        id: poProvider.selectedSupplierId!,
        name: 'Unknown Supplier',
        phone: '',
        address: '',
        storeId: '', // Empty store ID for fallback
      ),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BulkProductSelectionScreen(
          supplierId: supplier.id,
          supplierName: supplier.name,
          existingCartItems: poProvider.poCartItems,
        ),
      ),
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final companyProvider = context.watch<CompanyProvider>();
    final poProvider = context.watch<PurchaseOrderProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo Đơn Nhập Hàng'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSupplierDropdown(companyProvider, poProvider),
            const SizedBox(height: 32),
            _buildPOCart(poProvider),
            const SizedBox(height: 32),
            _buildSummary(poProvider),
            const SizedBox(height: 40),
            _buildActionButtons(poProvider),
            // Extra bottom padding to ensure content doesn't get cut off
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierDropdown(
    CompanyProvider companyProvider,
    PurchaseOrderProvider poProvider,
  ) {
    if (companyProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Find selected company name
    String? selectedCompanyName;
    if (poProvider.selectedSupplierId != null) {
      final company = companyProvider.companies.firstWhere(
        (c) => c.id == poProvider.selectedSupplierId,
        orElse: () => Company(
          id: '',
          name: 'Unknown',
          phone: '',
          address: '',
          storeId: '',
        ),
      );
      selectedCompanyName = company.name;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Nhà cung cấp',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
        ),
        // Navigation Row
        InkWell(
          onTap: () async {
            final selectedId = await Navigator.of(context).push<String>(
              MaterialPageRoute(
                builder: (context) => CompanyPickerScreen(
                  selectedCompanyId: poProvider.selectedSupplierId,
                ),
              ),
            );

            if (selectedId != null && mounted) {
              poProvider.setSupplierForCart(selectedId);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.business, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nhà cung cấp',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selectedCompanyName ?? 'Chọn nhà cung cấp',
                        style: TextStyle(
                          fontSize: 16,
                          color: selectedCompanyName != null
                              ? Colors.black
                              : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPOCart(PurchaseOrderProvider poProvider) {
    final isEmpty = poProvider.poCartItems.isEmpty;
    final hasSupplier = poProvider.selectedSupplierId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 16),
            child: Text(
              'Sản phẩm nhập hàng',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ),
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
        ],

        // Hero Add Product Button
        Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: isEmpty ? 140 : 60),
          decoration: BoxDecoration(
            color: hasSupplier ? Colors.green[50] : Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasSupplier ? Colors.green[200]! : Colors.grey[300]!,
              width: 2,
              style: hasSupplier ? BorderStyle.solid : BorderStyle.none,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: hasSupplier
                  ? () => _navigateToProductSelection(context)
                  : null,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_circle,
                      size: isEmpty ? 48 : 28,
                      color: hasSupplier ? Colors.green : Colors.grey[400],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isEmpty ? 'Thêm sản phẩm đầu tiên' : 'Thêm sản phẩm khác',
                      style: TextStyle(
                        fontSize: isEmpty ? 18 : 16,
                        fontWeight: isEmpty ? FontWeight.w600 : FontWeight.w500,
                        color: hasSupplier
                            ? Colors.green[700]
                            : Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (isEmpty && !hasSupplier) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Chọn nhà cung cấp trước',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
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
                  onPressed: () =>
                      _showRemoveItemDialog(context, item.product.name, () {
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
                      return DropdownMenuItem<String>(
                        value: unit,
                        child: Text(unit),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      poProvider.updatePOCartItem(
                        item.product.id,
                        newUnit: newValue,
                      );
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
                    Icon(
                      Icons.warning_amber,
                      color: Colors.orange.shade700,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Số lượng = 0. Sản phẩm sẽ không được thêm vào đơn hàng.',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 12,
                        ),
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
                const Text(
                  'Thành tiền:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
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

  Widget _buildSmartQuantityField(
    POCartItem item,
    PurchaseOrderProvider poProvider,
  ) {
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
        item.quantityController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: item.quantityController.text.length,
        );
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
          item.quantityController.selection = TextSelection.fromPosition(
            TextPosition(offset: item.quantityController.text.length),
          );
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

  Widget _buildSmartPriceField(
    POCartItem item,
    PurchaseOrderProvider poProvider,
  ) {
    return TextFormField(
      controller: item.unitCostController,
      decoration: InputDecoration(
        labelText: 'Giá nhập / đơn vị',
        hintText: 'Nhập giá nhập (ví dụ: 25,000 hoặc 25,000.5)',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.attach_money),
        suffixText: 'VND',
      ),
      keyboardType: TextInputType.number,
      onTap: () {
        // Select all text on tap for easy editing
        item.unitCostController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: item.unitCostController.text.length,
        );
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
          item.unitCostController.selection = TextSelection.fromPosition(
            TextPosition(offset: item.unitCostController.text.length),
          );
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

  void _showRemoveItemDialog(
    BuildContext context,
    String productName,
    VoidCallback onConfirm,
  ) {
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
    final hasItems = poProvider.poCartItems.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Notes Field - only show if has items
        if (hasItems) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Ghi chú (tùy chọn)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ),
          TextFormField(
            controller: _notesController,
            decoration: InputDecoration(
              hintText: 'Thêm ghi chú cho đơn hàng...',
              hintStyle: TextStyle(color: Colors.grey[500]),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.green, width: 2),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            maxLines: 3,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
        ],

        // Total - only show if has items
        if (hasItems) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green[100]!, width: 1),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tổng cộng:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    Text(
                      AppFormatter.formatCurrency(poProvider.poCartTotal),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${poProvider.poCartItems.length} sản phẩm',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons(PurchaseOrderProvider poProvider) {
    final hasSupplier = poProvider.selectedSupplierId != null;
    final hasItems = poProvider.poCartItems.isNotEmpty;
    final canSend =
        hasSupplier && hasItems; // Only disable if truly can't proceed

    return Column(
      children: [
        // Primary Action - Gửi Đơn Hàng
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: canSend
                ? () async {
                    final newPO = await poProvider.createPOFromCart(
                      notes: _notesController.text,
                      status: PurchaseOrderStatus.sent,
                    );
                    if (newPO != null) {
                      // Clear everything after successful PO creation
                      poProvider.clearPOCartAndSupplier();
                      Navigator.of(context).pop();
                      Navigator.of(context).pushNamed(
                        RouteNames.purchaseOrderDetail,
                        arguments: newPO,
                      );
                      // Show success with quick confirm action
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Đã gửi đơn nhập hàng thành công',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          action: SnackBarAction(
                            label: 'XÁC NHẬN NHANH',
                            textColor: Colors.white,
                            backgroundColor: Colors.green[700],
                            onPressed: () {
                              _showQuickConfirmDialog(context, newPO);
                            },
                          ),
                        ),
                      );
                    }
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canSend ? Colors.green : Colors.grey[300],
              foregroundColor: canSend ? Colors.white : Colors.grey[500],
              elevation: canSend ? 3 : 0,
              shadowColor: canSend ? Colors.green.withOpacity(0.3) : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.send,
                  size: 20,
                  color: canSend ? Colors.white : Colors.grey[500],
                ),
                const SizedBox(width: 8),
                Text(
                  canSend
                      ? 'Gửi Đơn Hàng'
                      : (!hasSupplier
                            ? 'Chọn nhà cung cấp trước'
                            : 'Thêm sản phẩm trước'),
                  style: TextStyle(
                    fontSize: canSend ? 18 : 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Secondary Action - Lưu Nháp (subtle text button)
        if (hasItems) // Only show save draft if there's something to save
          TextButton(
            onPressed: () async {
              final newPO = await poProvider.createPOFromCart(
                notes: _notesController.text,
                status: PurchaseOrderStatus.draft,
              );
              if (newPO != null) {
                // Clear everything after successful draft save
                poProvider.clearPOCartAndSupplier();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Đã lưu đơn hàng nháp'),
                    backgroundColor: Colors.grey[600],
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.save_outlined, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                const Text('Lưu nháp', style: TextStyle(fontSize: 14)),
              ],
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
          .where(
            (product) =>
                product.name.toLowerCase().contains(query.toLowerCase()) ||
                (product.sku?.toLowerCase().contains(query.toLowerCase()) ??
                    false),
          )
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
    if (_filteredProducts != poProvider.filteredProducts &&
        _searchController.text.isEmpty) {
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
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
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
                        if (product.category == ProductCategory.FERTILIZER)
                          defaultUnit = 'kg';
                        if (product.category == ProductCategory.PESTICIDE)
                          defaultUnit = 'chai';
                        if (product.category == ProductCategory.SEED)
                          defaultUnit = 'kg';

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
