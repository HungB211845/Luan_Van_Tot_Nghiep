import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../models/company.dart';
import '../../providers/product_provider.dart';
import '../../providers/purchase_order_provider.dart';
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

class _BulkProductSelectionScreenState
    extends State<BulkProductSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Map<String, POCartItem> _localCartItems = {}; // Local cart state
  ProductCategory? _selectedCategory;
  String _searchQuery = '';
  bool _isCartExpanded = false;

  @override
  void initState() {
    super.initState();

    // Initialize with existing cart items
    for (var item in widget.existingCartItems) {
      _localCartItems[item.product.id] = item;
    }

    // Load products for this supplier ONLY
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // FIXED: Load products filtered by supplier instead of all products
      context.read<ProductProvider>().loadProductsByCompany(widget.supplierId);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  void _onCategoryChanged(ProductCategory? category) {
    setState(() {
      _selectedCategory = category;
    });
    // FIXED: Reload products with both company and category filters
    context.read<ProductProvider>().loadProductsByCompany(
      widget.supplierId,
      category: category,
    );
  }

  void _showProductEntrySheet(
    Product product,
    int? existingQuantity,
    double? existingPrice,
    String? existingUnit,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProductEntryBottomSheet(
        product: product,
        existingQuantity: existingQuantity,
        existingPrice: existingPrice,
        existingUnit: existingUnit,
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
    // Update PurchaseOrderProvider with all selected items
    final poProvider = context.read<PurchaseOrderProvider>();

    // Clear only cart items, preserve supplier selection
    poProvider.clearPOCart();
    for (var item in _localCartItems.values) {
      poProvider.addPOCartItem(item);
    }

    // Return to previous screen (Create PO) with supplier preserved
    Navigator.pop(context);
  }

  List<Product> _getFilteredProducts(List<Product> products) {
    // NOTE: Company/supplier and category filtering are now done server-side
    // Only client-side search query filtering remains

    if (_searchQuery.isEmpty) {
      return products; // No search query, return all server-filtered products
    }

    // Filter by search query only
    return products.where((product) {
      final query = _searchQuery.toLowerCase();
      return product.name.toLowerCase().contains(query) ||
          (product.sku?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  double _getLocalCartTotal() {
    return _localCartItems.values.fold(0.0, (sum, item) {
      return sum + (item.quantity * item.unitCost);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header with supplier context
            ProductSelectionHeader(supplierName: widget.supplierName),

            // Live cart summary
            LiveCartSummary(
              cartItems: _localCartItems.values.toList(),
              isExpanded: _isCartExpanded,
              onToggleExpanded: () =>
                  setState(() => _isCartExpanded = !_isCartExpanded),
              onFinish: _localCartItems.isNotEmpty ? _finishSelection : null,
              onRemoveItem: _removeFromLocalCart,
              onUpdateQuantity: _updateLocalCartItem,
            ),

            // Search bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
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

            // Category filters
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

            // Product list
            Expanded(
              child: Consumer<ProductProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final products = _getFilteredProducts(provider.products);

                  if (products.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Không tìm thấy sản phẩm nào'
                                : 'Chưa có sản phẩm nào',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      final isInCart = _localCartItems.containsKey(product.id);
                      final cartItem = _localCartItems[product.id];

                      return SimpleProductCard(
                        product: product,
                        currentStock: provider.getProductStock(product.id),
                        lastPrice: provider.getCurrentPrice(product.id),
                        isInCart: isInCart,
                        cartQuantity: cartItem?.quantity ?? 0,
                        onTap: () => _showProductEntrySheet(
                          product,
                          cartItem?.quantity,
                          cartItem?.unitCost,
                          cartItem?.unit,
                        ),
                      );
                    },
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
