import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product_batch.dart';
import '../../models/purchase_order.dart';
import '../../models/company.dart';
import '../../models/product.dart';
import '../../models/seasonal_price.dart';
import '../../providers/product_provider.dart';
import '../../providers/purchase_order_provider.dart';
import '../../providers/company_provider.dart';
import '../../../../shared/utils/formatter.dart';

class AddBatchScreen extends StatefulWidget {
  const AddBatchScreen({Key? key}) : super(key: key);

  @override
  State<AddBatchScreen> createState() => _AddBatchScreenState();
}

class _AddBatchScreenState extends State<AddBatchScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers for form fields
  final _batchNumberController = TextEditingController();
  final _quantityController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _sellingPriceController = TextEditingController(); // For suggested price
  final _supplierBatchIdController = TextEditingController();
  final _notesController = TextEditingController();

  // Date fields
  DateTime _receivedDate = DateTime.now();
  DateTime? _expiryDate;

  // New state for PO integration
  PurchaseOrder? _selectedPurchaseOrder;
  Company? _selectedSupplier;
  List<PurchaseOrder> _purchaseOrders = [];
  List<Company> _suppliers = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await context.read<PurchaseOrderProvider>().loadPurchaseOrders();
      _purchaseOrders = context.read<PurchaseOrderProvider>().purchaseOrders;
      await context.read<CompanyProvider>().loadCompanies();
      _suppliers = context.read<CompanyProvider>().companies;
    } catch (e) {
      // Handle error if needed
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _batchNumberController.dispose();
    _quantityController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _supplierBatchIdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onPOSelected(PurchaseOrder? po) async {
    if (po == null) return;

    await context.read<PurchaseOrderProvider>().loadPODetails(po.id);
    final poItems = context.read<PurchaseOrderProvider>().selectedPOItems;

    setState(() {
      _selectedPurchaseOrder = po;
      _selectedSupplier = _suppliers.firstWhere((s) => s.id == po.supplierId);

      final poItem = poItems.firstWhere(
        (item) => item.productId == context.read<ProductProvider>().selectedProduct?.id,
        orElse: () => poItems.first,
      );

      _quantityController.text = poItem.quantity.toString();
      _costPriceController.text = poItem.unitCost.toString();
      _supplierBatchIdController.text = po.poNumber ?? '';

      // Auto-suggest selling price (e.g., 20% markup)
      final costPrice = poItem.unitCost;
      if (costPrice > 0) {
        final suggestedPrice = costPrice * 1.2;
        _sellingPriceController.text = suggestedPrice.toStringAsFixed(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProductProvider>(
      builder: (context, provider, child) {
        final selectedProduct = provider.selectedProduct;

        if (selectedProduct == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Thêm Lô Hàng'),
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            body: const Center(
              child: Text(
                'Không tìm thấy sản phẩm được chọn',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Thêm Lô Hàng',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                  _buildProductInfo(selectedProduct),
                  const SizedBox(height: 24),
                  _buildPOSelection(),
                  const SizedBox(height: 24),
                  _buildBatchForm(),
                  const SizedBox(height: 32),
                  _buildSaveButton(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPOSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tùy chọn: Nhập từ đơn hàng',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<PurchaseOrder>(
          value: _selectedPurchaseOrder,
          hint: const Text('Chọn đơn nhập hàng (PO)'),
          isExpanded: true,
          items: _purchaseOrders.map((po) {
            return DropdownMenuItem(
              value: po,
              child: Text(po.poNumber ?? 'PO không có mã'),
            );
          }).toList(),
          onChanged: _onPOSelected,
          decoration: _buildInputDecoration(label: 'Đơn nhập hàng'),
        ),
        if (_selectedSupplier != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text('Nhà cung cấp: ${_selectedSupplier!.name}', style: const TextStyle(fontStyle: FontStyle.italic)),
          ),
      ],
    );
  }

  Widget _buildProductInfo(dynamic selectedProduct) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.inventory,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Sản phẩm được chọn',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              selectedProduct.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'SKU: ${selectedProduct.sku}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Thông tin lô hàng',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _batchNumberController,
          decoration: _buildInputDecoration(
            label: 'Mã lô *',
            hint: 'Ví dụ: LOT001, B2024001',
            icon: Icons.qr_code,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Vui lòng nhập mã lô';
            }
            if (value.trim().length < 2) {
              return 'Mã lô phải có ít nhất 2 ký tự';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _quantityController,
                decoration: _buildInputDecoration(
                  label: 'Số lượng *',
                  hint: '100',
                  icon: Icons.inventory_2,
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập số lượng';
                  }
                  final quantity = int.tryParse(value);
                  if (quantity == null || quantity <= 0) {
                    return 'Số lượng phải là số dương';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _costPriceController,
                decoration: _buildInputDecoration(
                  label: 'Giá vốn *',
                  hint: '50000',
                  icon: Icons.attach_money,
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập giá vốn';
                  }
                  final price = double.tryParse(value);
                  if (price == null || price <= 0) {
                    return 'Giá vốn phải là số dương';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildPriceSuggestion(),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _selectReceivedDate(context),
                child: InputDecorator(
                  decoration: _buildInputDecoration(
                    label: 'Ngày nhập *',
                    icon: Icons.calendar_today,
                  ),
                  child: Text(
                    AppFormatter.formatDate(_receivedDate),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: InkWell(
                onTap: () => _selectExpiryDate(context),
                child: InputDecorator(
                  decoration: _buildInputDecoration(
                    label: 'Hạn sử dụng',
                    icon: Icons.event_busy,
                  ),
                  child: Text(
                    _expiryDate != null ? AppFormatter.formatDate(_expiryDate!) : 'Chọn ngày',
                    style: TextStyle(
                      fontSize: 16,
                      color: _expiryDate != null ? Colors.black : Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _supplierBatchIdController,
          decoration: _buildInputDecoration(
            label: 'Mã lô nhà cung cấp',
            hint: 'Mã lô từ nhà cung cấp (tùy chọn)',
            icon: Icons.business,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _notesController,
          decoration: _buildInputDecoration(
            label: 'Ghi chú',
            hint: 'Ghi chú thêm về lô hàng này (tùy chọn)',
            icon: Icons.note,
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildPriceSuggestion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _sellingPriceController,
          decoration: _buildInputDecoration(
            label: 'Giá bán đề xuất',
            hint: 'Giá bán cho khách hàng',
            icon: Icons.price_change,
          ),
          keyboardType: TextInputType.number,
        ),
        const Padding(
          padding: EdgeInsets.only(top: 4, left: 12),
          child: Text(
            'Gợi ý: Lợi nhuận 20% trên giá vốn.', 
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _saveBatch,
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
              'Lưu Lô Hàng',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
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

  Future<void> _selectReceivedDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _receivedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('vi', 'VN'),
    );
    if (picked != null && picked != _receivedDate) {
      setState(() {
        _receivedDate = picked;
      });
    }
  }

  Future<void> _selectExpiryDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? _receivedDate.add(const Duration(days: 365)),
      firstDate: _receivedDate,
      lastDate: DateTime(2030),
      locale: const Locale('vi', 'VN'),
    );
    if (picked != null) {
      setState(() {
        _expiryDate = picked;
      });
    }
  }

  Future<void> _saveBatch() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<ProductProvider>();
      final selectedProduct = provider.selectedProduct;

      if (selectedProduct == null) {
        throw Exception('Không tìm thấy sản phẩm được chọn');
      }

      DateTime? finalExpiryDate = _expiryDate;
      if (_expiryDate == null &&
          (selectedProduct.category == ProductCategory.FERTILIZER ||
              selectedProduct.category == ProductCategory.PESTICIDE)) {
        finalExpiryDate = _receivedDate.add(const Duration(days: 365 * 2));
      }

      final newBatch = ProductBatch(
        id: '', 
        productId: selectedProduct.id,
        batchNumber: _batchNumberController.text.trim(),
        quantity: int.parse(_quantityController.text.trim()),
        costPrice: double.parse(_costPriceController.text.trim()),
        sellingPrice: _sellingPriceController.text.isNotEmpty ? double.parse(_sellingPriceController.text) : null,
        receivedDate: _receivedDate,
        expiryDate: finalExpiryDate,
        supplierBatchId: _supplierBatchIdController.text.trim().isNotEmpty
            ? _supplierBatchIdController.text.trim()
            : null,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        isAvailable: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        purchaseOrderId: _selectedPurchaseOrder?.id,
        supplierId: _selectedSupplier?.id,
      );

      final success = await provider.addProductBatch(newBatch);

      if (success) {
        // Auto-create a seasonal price entry
        if (_sellingPriceController.text.isNotEmpty) {
          final newPrice = SeasonalPrice(
            id: '',
            productId: selectedProduct.id,
            sellingPrice: double.parse(_sellingPriceController.text),
            seasonName: 'Giá từ lô hàng ${_batchNumberController.text.trim()}',
            startDate: _receivedDate,
            endDate: _expiryDate ?? _receivedDate.add(const Duration(days: 365)),
            isActive: true, // Automatically activate the new price
            notes: 'Tự động tạo từ việc thêm lô hàng mới',
            createdAt: DateTime.now(),
          );
          await provider.addSeasonalPrice(newPrice);
        }

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thêm lô hàng và giá bán thành công'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                provider.errorMessage.isNotEmpty
                    ? provider.errorMessage
                    : 'Có lỗi xảy ra khi thêm lô hàng',
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
            duration: const Duration(seconds: 3),
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
}