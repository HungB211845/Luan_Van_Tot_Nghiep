import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../../models/purchase_order.dart';
import '../../models/purchase_order_status.dart';
import '../../models/purchase_order_item.dart';
import '../../models/product_batch.dart';
import '../../models/company.dart';
import '../../providers/purchase_order_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/company_provider.dart';
import '../../../../shared/utils/formatter.dart';
import '../../../../shared/services/base_service.dart';

/// Custom TextInputFormatter for VND currency
/// Formats: 1000000 → 1.000.000
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Remove all non-digit characters
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    if (digitsOnly.isEmpty) {
      return const TextEditingValue();
    }

    // Format with thousand separators (dot)
    String formatted = _formatWithDots(digitsOnly);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatWithDots(String number) {
    if (number.isEmpty) return '';

    // Reverse the string to add dots from right to left
    String reversed = number.split('').reversed.join();
    String result = '';

    for (int i = 0; i < reversed.length; i++) {
      if (i > 0 && i % 3 == 0) {
        result += '.';
      }
      result += reversed[i];
    }

    return result.split('').reversed.join();
  }
}

/// Màn hình xác nhận nhận hàng từ PO
/// Tự động điền thông tin từ PO, chỉ cần xác nhận và bổ sung
class ReceivePOItemsScreen extends StatefulWidget {
  final PurchaseOrder purchaseOrder;

  const ReceivePOItemsScreen({
    Key? key,
    required this.purchaseOrder,
  }) : super(key: key);

  @override
  State<ReceivePOItemsScreen> createState() => _ReceivePOItemsScreenState();
}

class _ReceivePOItemsScreenState extends State<ReceivePOItemsScreen> {
  bool _isLoading = false;
  bool _isSaving = false;

  // Map to store editable data for each PO item
  final Map<String, _ItemReceiveData> _itemDataMap = {};

  @override
  void initState() {
    super.initState();
    _initializeItemData();
  }

  @override
  void dispose() {
    // Dispose all controllers
    for (var data in _itemDataMap.values) {
      data.dispose();
    }
    super.dispose();
  }

  void _initializeItemData() {
    final poItems = context.read<PurchaseOrderProvider>().selectedPOItems;

    for (final item in poItems) {
      // Generate batch code
      final batchCode = _generateBatchCode();

      _itemDataMap[item.id] = _ItemReceiveData(
        poItem: item,
        batchNumber: batchCode,
        receivedQuantity: item.quantity, // Auto-fill with ordered quantity
        costPrice: item.unitCost, // Auto-fill with PO unit cost
        expiryDate: null,
      );
    }
  }

  String _generateBatchCode() {
    final now = DateTime.now();
    final random = Random();
    final randomNum = random.nextInt(9999).toString().padLeft(4, '0');
    return 'LOT${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-$randomNum';
  }

  Future<void> _confirmReceiveAll() async {
    // Validate all items
    for (final data in _itemDataMap.values) {
      if (data.batchNumber.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng nhập mã lô cho tất cả sản phẩm'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (data.receivedQuantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Số lượng nhận phải lớn hơn 0'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final productProvider = context.read<ProductProvider>();
      final poProvider = context.read<PurchaseOrderProvider>();

      // Create batches for all items
      final batches = <ProductBatch>[];

      for (final data in _itemDataMap.values) {
        final batch = ProductBatch(
          id: '', // Will be generated
          productId: data.poItem.productId,
          batchNumber: data.batchNumber,
          quantity: data.receivedQuantity,
          costPrice: data.costPrice,
          receivedDate: DateTime.now(),
          expiryDate: data.expiryDate,
          supplierId: widget.purchaseOrder.supplierId,
          purchaseOrderId: widget.purchaseOrder.id,
          notes: 'Nhập từ ${widget.purchaseOrder.poNumber}',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          storeId: BaseService.getDefaultStoreId() ?? '',
        );

        batches.add(batch);
      }

      // Save all batches
      bool allSuccess = true;
      for (final batch in batches) {
        final success = await productProvider.addProductBatch(batch);
        if (!success) {
          allSuccess = false;
          break;
        }
      }

      if (allSuccess) {
        // Update PO status to delivered
        await poProvider.updatePOStatus(
          widget.purchaseOrder.id,
          PurchaseOrderStatus.delivered,
        );

        if (mounted) {
          // Pop all screens and return to product detail
          Navigator.of(context).pop(); // Close this screen
          Navigator.of(context).pop(); // Close PO selection screen
          Navigator.of(context).pop(); // Close method selection screen

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã nhận hàng thành công!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          // Refresh product batches
          final selectedProduct = productProvider.selectedProduct;
          if (selectedProduct != null) {
            await productProvider.loadProductBatches(selectedProduct.id);
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(productProvider.errorMessage.isEmpty
                ? 'Có lỗi xảy ra khi nhận hàng'
                : productProvider.errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final companyProvider = context.watch<CompanyProvider>();
    final supplier = companyProvider.companies.firstWhere(
      (c) => c.id == widget.purchaseOrder.supplierId,
      orElse: () => Company(
        id: '',
        name: 'Không xác định',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        storeId: BaseService.getDefaultStoreId(),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Xác Nhận Nhận Hàng',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // PO Info banner
          Container(
            width: double.infinity,
            color: Colors.green.withOpacity(0.1),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.purchaseOrder.poNumber ?? 'PO-không có mã',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.business, size: 16, color: Colors.grey[700]),
                    const SizedBox(width: 6),
                    Text(
                      supplier.name,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey[700]),
                    const SizedBox(width: 6),
                    Text(
                      'Ngày đặt: ${AppFormatter.formatDate(widget.purchaseOrder.orderDate)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Instructions
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.blue.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Kiểm tra số lượng thực nhận, nhập mã lô và hạn sử dụng cho từng sản phẩm',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue[900],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Items list
          Expanded(
            child: Consumer2<PurchaseOrderProvider, ProductProvider>(
              builder: (context, poProvider, productProvider, _) {
                if (poProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final selectedProduct = productProvider.selectedProduct;
                final allItems = poProvider.selectedPOItems;

                // CRITICAL FILTER: Only show items for the currently selected product
                // This ensures we only receive batches for the product we're working on
                final items = selectedProduct != null
                    ? allItems.where((item) => item.productId == selectedProduct.id).toList()
                    : allItems;

                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          selectedProduct != null
                              ? 'Đơn hàng này không chứa sản phẩm\n"${selectedProduct.name}"'
                              : 'Không có sản phẩm nào trong đơn hàng này',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final data = _itemDataMap[item.id];

                    if (data == null) return const SizedBox.shrink();

                    return _buildItemCard(item, data);
                  },
                );
              },
            ),
          ),
        ],
      ),

      // Floating action button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _confirmReceiveAll,
        backgroundColor: Colors.green,
        icon: _isSaving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : const Icon(Icons.check_circle, color: Colors.white),
        label: Text(
          _isSaving ? 'Đang lưu...' : 'Xác Nhận Nhận Hàng',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildItemCard(PurchaseOrderItem item, _ItemReceiveData data) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product name
            Text(
              item.productName ?? 'Sản phẩm',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 12),

            // Ordered quantity (read-only)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Số lượng đặt:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    '${item.quantity}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Received quantity (editable)
            TextFormField(
              initialValue: data.receivedQuantity.toString(),
              decoration: _buildInputDecoration(
                label: 'Số lượng thực nhận *',
                icon: Icons.inventory_2,
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                final qty = int.tryParse(value) ?? 0;
                setState(() {
                  data.receivedQuantity = qty;
                });
              },
            ),

            const SizedBox(height: 12),

            // Cost price (editable but pre-filled)
            TextFormField(
              controller: data.costPriceController,
              decoration: _buildInputDecoration(
                label: 'Giá vốn *',
                icon: Icons.attach_money,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                CurrencyInputFormatter(),
              ],
              onChanged: (value) {
                // Remove dots before parsing (1.000.000 → 1000000)
                final cleanedValue = value.replaceAll('.', '');
                final price = double.tryParse(cleanedValue) ?? 0;
                setState(() {
                  data.costPrice = price;
                });
              },
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nhập giá vốn';
                }
                final cleanedValue = value.replaceAll('.', '');
                final price = double.tryParse(cleanedValue);
                if (price == null || price < 0) {
                  return 'Giá ≥ 0';
                }
                return null;
              },
            ),

            const SizedBox(height: 12),

            // Batch number with random button
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: data.batchNumber,
                    decoration: _buildInputDecoration(
                      label: 'Mã lô *',
                      icon: Icons.qr_code_2,
                    ),
                    onChanged: (value) {
                      setState(() {
                        data.batchNumber = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Tạo mã mới',
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          data.batchNumber = _generateBatchCode();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Icon(Icons.casino, size: 20),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Expiry date
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: data.expiryDate ?? DateTime.now().add(const Duration(days: 365)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  setState(() {
                    data.expiryDate = picked;
                  });
                }
              },
              child: InputDecorator(
                decoration: _buildInputDecoration(
                  label: 'Hạn sử dụng',
                  icon: Icons.event_available,
                ),
                child: Text(
                  data.expiryDate == null
                    ? 'Chọn ngày (tùy chọn)'
                    : AppFormatter.formatDate(data.expiryDate!),
                  style: TextStyle(
                    fontSize: 16,
                    color: data.expiryDate == null ? Colors.grey : Colors.black87,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String label,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, size: 20) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.green, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

/// Helper class to store editable receive data for each PO item
class _ItemReceiveData {
  final PurchaseOrderItem poItem;
  String batchNumber;
  int receivedQuantity;
  double costPrice;
  DateTime? expiryDate;
  final TextEditingController costPriceController;

  _ItemReceiveData({
    required this.poItem,
    required this.batchNumber,
    required this.receivedQuantity,
    required this.costPrice,
    this.expiryDate,
  }) : costPriceController = TextEditingController(
    text: _formatCurrency(costPrice),
  );

  // Format initial value with dots
  static String _formatCurrency(double price) {
    final priceStr = price.toStringAsFixed(0);
    final reversed = priceStr.split('').reversed.join();
    String result = '';
    for (int i = 0; i < reversed.length; i++) {
      if (i > 0 && i % 3 == 0) {
        result += '.';
      }
      result += reversed[i];
    }
    return result.split('').reversed.join();
  }

  void dispose() {
    costPriceController.dispose();
  }
}