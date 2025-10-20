import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../models/product_unit.dart'; // 🔥 NEW: Import ProductUnit model
import '../../providers/product_unit_provider.dart';
import '../../providers/purchase_order_provider.dart';
import '../../services/product_service.dart'; // Import service
import '../../utils/unit_display_formatter.dart';
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
  final Map<String, List<ProductUnit>> _productUnits = {}; // 🔥 NEW: Cache units per product
  final Map<String, _PriceDisplay> _lastPrices = {};
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

      final unitProvider = context.read<ProductUnitProvider>();
      // 🔥 NEW: Load units for each product via provider (with caching)
      for (final product in products) {
        try {
          final units = await unitProvider.getUnitsForProduct(
            product.id,
            forceRefresh: true, // Ensure latest config when opening selector
          );
          _productUnits[product.id] = units;
        } catch (e) {
          debugPrint('Failed to load units for ${product.name}: $e');
          _productUnits[product.id] = []; // Empty list on error
        }
      }

      Map<String, double> latestCosts = {};
      if (products.isNotEmpty) {
        latestCosts = await _productService.getLatestCostsForSupplier(
          supplierId: widget.supplierId,
          productIds: products.map((p) => p.id).toList(),
        );
      }

      if (mounted) {
        setState(() {
          _supplierProducts = products;
          _lastPrices
            ..clear()
            ..addAll({
              for (final entry in latestCosts.entries)
                entry.key: _convertCostForDisplay(
                  entry.value,
                  _productUnits[entry.key] ?? [],
                )
            });
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
        existingPrice:
            cartItem?.unitCost ?? _lastPrices[product.id]?.amount,
        existingSellingPrice:
            cartItem?.sellingPrice ?? product.currentSellingPrice,
        existingUnit: cartItem?.unit,
        onAdd: (
          quantity,
          price,
          unit,
          unitId,
          sellingPrice,
          defaultUnitId,
          defaultUnitName,
          selectedUnitFactor,
          defaultUnitFactor,
          displaySellingPrice,
          defaultUnitCost,
          allowsPricingToggle,
          pricingSelection,
        ) {
          setState(() {
            final normalizedDefaultCost =
                defaultUnitCost ?? price;
            _localCartItems[product.id] = POCartItem(
              product: product,
              quantity: quantity,
              unitCost: price,
              sellingPrice: sellingPrice,
              unit: unit,
              unitId: unitId,
              defaultUnitId: defaultUnitId,
              defaultUnitName: defaultUnitName,
              selectedUnitFactor: selectedUnitFactor,
              defaultUnitFactor: defaultUnitFactor,
              displaySellingPrice: displaySellingPrice,
              baseSellingPrice: (displaySellingPrice != null &&
                      defaultUnitFactor != null &&
                      defaultUnitFactor! > 0)
                  ? displaySellingPrice! / defaultUnitFactor!
                  : null,
              defaultUnitCost: normalizedDefaultCost,
              allowsPricingToggle: allowsPricingToggle,
              pricingSelection: pricingSelection,
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

                            // 🔥 NEW: Calculate display stock in default selling unit
                            final units = _productUnits[product.id] ?? [];
                            final stockDisplay = _formatStockDisplay(product, units);
                            final bool isLowStock = _isLowStock(product, units);
                            final priceDisplay = _lastPrices[product.id];

                            return SimpleProductCard(
                              product: product,
                              stockDisplay: stockDisplay,
                              lastPrice: priceDisplay?.amount,
                              lastPriceUnit: priceDisplay?.unitLabel,
                              isLowStock: isLowStock,
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

  String _formatStockDisplay(Product product, List<ProductUnit> units) {
    final baseStock = (product.availableStock ?? 0).toDouble();
    if (baseStock <= 0) {
      return '0 ${product.effectiveBaseUnit}';
    }

    if (units.isNotEmpty) {
      final displayUnit =
          UnitDisplayFormatter.preferredDisplayUnit(units) ?? units.first;

      if (displayUnit.conversionFactor > 0) {
        final quantity = baseStock / displayUnit.conversionFactor;
        if (quantity >= 1) {
          final rounded = quantity.round();
          final unitName = UnitDisplayFormatter.simpleUnitName(displayUnit);
          return '$rounded $unitName';
        }
      }

      final defaultQuantity = product.getStockInDefaultUnit(units);
      final defaultUnitName = product.getDefaultUnitName(units);
      return '${_formatQuantity(defaultQuantity)} $defaultUnitName';
    }

    return '${_formatQuantity(baseStock)} ${product.effectiveBaseUnit}';
  }

  bool _isLowStock(Product product, List<ProductUnit> units) {
    final converted = product.getStockInDefaultUnit(units);
    final threshold =
        product.minStockLevel > 0 ? product.minStockLevel.toDouble() : 10.0;
    return converted <= threshold;
  }

  _PriceDisplay _convertCostForDisplay(double baseCost, List<ProductUnit> units) {
    if (units.isEmpty) {
      return _PriceDisplay(amount: baseCost, unitLabel: '');
    }

    final defaultUnit = units.firstWhere(
      (u) => u.isDefaultSellingUnit,
      orElse: () => units.first,
    );
    final factor = defaultUnit.conversionFactor <= 0
        ? 1.0
        : defaultUnit.conversionFactor;
    final converted = baseCost * factor;
    debugPrint(
        'Latest cost conversion -> base: $baseCost, unit: ${defaultUnit.unitName}, factor: $factor, converted: $converted');
    return _PriceDisplay(
      amount: converted,
      unitLabel: UnitDisplayFormatter.simpleUnitName(defaultUnit),
    );
  }

  String _formatQuantity(double value) {
    if (value <= 0) return '0';
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    final formatted = value.toStringAsFixed(2);
    return formatted.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
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

class _PriceDisplay {
  final double amount;
  final String unitLabel;

  const _PriceDisplay({required this.amount, required this.unitLabel});
}
