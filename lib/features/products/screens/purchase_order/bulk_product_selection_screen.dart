import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../providers/purchase_order_provider.dart';
import '../../services/product_service.dart'; // Import service
import 'widgets/product_selection_header.dart';
import 'widgets/live_cart_summary.dart';
import 'widgets/simple_product_card.dart';
import 'widgets/product_entry_bottom_sheet.dart';

class BulkProductSelectionScreen extends StatefulWidget {
  final String supplierId;
  final String supplierName;
  final List<POCartItem> existingCartItems;

  const BulkProductSelectionScreen({
    Key? key,
    required this.supplierId,
    required this.supplierName,
    this.existingCartItems = const [],
  }) : super(key: key);

  @override
  State<BulkProductSelectionScreen> createState() =>
      _BulkProductSelectionScreenState();
}

class _BulkProductSelectionScreenState extends State<BulkProductSelectionScreen> {
  final ProductService _productService = ProductService(); // Instantiate service
  final TextEditingController _searchController = TextEditingController();

  // Local state for this screen
  List<Product> _supplierProducts = [];
  bool _isLoading = true;
  final Map<String, POCartItem> _localCartItems = {};
  ProductCategory? _selectedCategory;
  String _searchQuery = '';
  bool _isCartExpanded = false;

  @override
  void initState() {
    super.initState();
    for (var item in widget.existingCartItems) {
      _localCartItems[item.product.id] = item;
    }
    _fetchProductsForSupplier();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchProductsForSupplier() async {
    setState(() => _isLoading = true);
    try {
      final products = await _productService.getProductsByCompany(widget.supplierId);
      if (mounted) {
        setState(() {
          _supplierProducts = products;
        });
      }
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onCategoryChanged(ProductCategory? category) {
    setState(() {
      _selectedCategory = category;
    });
  }

  void _showProductEntrySheet(Product product, POCartItem? cartItem) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProductEntryBottomSheet(
        product: product,
        existingQuantity: cartItem?.quantity,
        existingPrice: cartItem?.unitCost,
        existingUnit: cartItem?.unit,
        onAdd: (quantity, price, unit) {
          setState(() {
            _localCartItems[product.id] = POCartItem(
              product: product,
              quantity: quantity,
              unitCost: price,
              unit: unit,
            );
          });
        },
      ),
    );
  }

  void _removeFromLocalCart(String productId) {
    setState(() {
      _localCartItems.remove(productId);
    });
  }

  void _updateLocalCartItem(String productId, int newQuantity, String unit) {
    setState(() {
      final item = _localCartItems[productId];
      if (item != null) {
        if (newQuantity <= 0) {
          _localCartItems.remove(productId);
        } else {
          _localCartItems[productId] = item.copyWith(
            quantity: newQuantity,
            unit: unit,
          );
        }
      }
    });
  }

  void _finishSelection() {
    final poProvider = context.read<PurchaseOrderProvider>();
    poProvider.clearPOCart();
    for (var item in _localCartItems.values) {
      poProvider.addPOCartItem(item);
    }
    Navigator.pop(context);
  }

  List<Product> _getDisplayedProducts() {
    List<Product> products = _supplierProducts;
    if (_selectedCategory != null) {
      products = products.where((p) => p.category == _selectedCategory).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      products = products.where((product) {
        return product.name.toLowerCase().contains(query) ||
            (product.sku?.toLowerCase().contains(query) ?? false);
      }).toList();
    }
    return products;
  }

  @override
  Widget build(BuildContext context) {
    final displayedProducts = _getDisplayedProducts();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ProductSelectionHeader(supplierName: widget.supplierName),
            LiveCartSummary(
              cartItems: _localCartItems.values.toList(),
              isExpanded: _isCartExpanded,
              onToggleExpanded: () =>
                  setState(() => _isCartExpanded = !_isCartExpanded),
              onFinish: _localCartItems.isNotEmpty ? _finishSelection : null,
              onRemoveItem: _removeFromLocalCart,
              onUpdateQuantity: _updateLocalCartItem,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Tìm sản phẩm của ${widget.supplierName}...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildCategoryChip('Tất cả', null),
                  const SizedBox(width: 8),
                  _buildCategoryChip('Phân bón', ProductCategory.FERTILIZER),
                  const SizedBox(width: 8),
                  _buildCategoryChip('Thuốc BVTV', ProductCategory.PESTICIDE),
                  const SizedBox(width: 8),
                  _buildCategoryChip('Lúa giống', ProductCategory.SEED),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : displayedProducts.isEmpty
                      ? const Center(child: Text('Không có sản phẩm nào.'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: displayedProducts.length,
                          itemBuilder: (context, index) {
                            final product = displayedProducts[index];
                            final cartItem = _localCartItems[product.id];
                            final bool isInCart = cartItem != null && cartItem.quantity > 0;

                            return SimpleProductCard(
                              product: product,
                              currentStock: product.availableStock ?? 0,
                              isInCart: isInCart,
                              cartQuantity: cartItem?.quantity ?? 0,
                              onTap: () => _showProductEntrySheet(product, cartItem),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, ProductCategory? category) {
    final isSelected = _selectedCategory == category;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) => _onCategoryChanged(selected ? category : null),
      backgroundColor: Colors.grey[100],
      selectedColor: Colors.green[100],
      checkmarkColor: Colors.green[700],
      labelStyle: TextStyle(
        color: isSelected ? Colors.green[700] : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}