import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../providers/product_provider.dart';
import '../../widgets/product_image_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/utils/formatter.dart';
import '../../../../shared/utils/responsive.dart';
import '../../utils/unit_display_formatter.dart';
import '../../../../core/config/cache_config.dart';
import '../../../../core/tools/performance_benchmark.dart';
import 'add_product_dialog.dart';
import 'product_detail_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({Key? key}) : super(key: key);

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

enum ProductSortOption {
  nameAsc,
  nameDesc,
  priceHighToLow,
  priceLowToHigh,
  stockHighToLow,
  stockLowToHigh,
}

extension ProductSortOptionExtension on ProductSortOption {
  String get displayName {
    switch (this) {
      case ProductSortOption.nameAsc:
        return 'Tên A → Z';
      case ProductSortOption.nameDesc:
        return 'Tên Z → A';
      case ProductSortOption.priceHighToLow:
        return 'Giá cao → thấp';
      case ProductSortOption.priceLowToHigh:
        return 'Giá thấp → cao';
      case ProductSortOption.stockHighToLow:
        return 'Tồn kho nhiều → ít';
      case ProductSortOption.stockLowToHigh:
        return 'Tồn kho ít → nhiều';
    }
  }
}

enum StockFilterOption {
  all,
  inStock,
  lowStock,
  outOfStock,
}

extension StockFilterOptionExtension on StockFilterOption {
  String get displayName {
    switch (this) {
      case StockFilterOption.all:
        return 'Tất cả';
      case StockFilterOption.inStock:
        return 'Còn hàng';
      case StockFilterOption.lowStock:
        return 'Sắp hết hàng';
      case StockFilterOption.outOfStock:
        return 'Hết hàng';
    }
  }
}

class _ProductListScreenState extends State<ProductListScreen> {
  final TextEditingController _searchController = TextEditingController();
  ProductCategory? _selectedCategory;
  bool _isSelectionMode = false;
  final Set<String> _selectedProductIds = {};
  ProductSortOption _sortOption = ProductSortOption.nameAsc;
  StockFilterOption _stockFilter = StockFilterOption.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ProductProvider>();
      if (provider.status == ProductStatus.idle) {
        // 🎯 FIXED: Use cached paginated version for faster initial load
        provider.loadProductsPaginated(useCache: true);
      }
    });
    _searchController.addListener(_onSearchChanged);
  }

  // 🎯 FIXED: Debounced search handler to prevent excessive API calls
  Timer? _searchDebounce;
  
  void _onSearchChanged() {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      final query = _searchController.text.trim();
      final provider = context.read<ProductProvider>();
      
      if (query.isEmpty) {
        // 🔥 CRITICAL FIX: Only clear search UI state, don't call provider
        // This prevents the "sort/filter reset" behavior user complained about
        provider.clearSearch(); // Ensure provider state is cleared
        setState(() {
          // Update UI state to refresh empty state message
        });
      } else if (query.length >= 2) {
        // 🔥 UX FIX: Only search when query has at least 2 characters
        // This prevents "không có sản phẩm" flash when typing first character
        provider.searchProductsPaginated(query: query, useCache: true);
        setState(() {
          // Update UI to show search state
        });
      } else {
        // For 1-character queries, show all products (no search)
        setState(() {
          // Update UI to show that we're not in search mode
        });
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelectionMode({String? initialProductId}) {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedProductIds.clear();
      if (_isSelectionMode && initialProductId != null) {
        _selectedProductIds.add(initialProductId);
      }
    });
  }

  void _toggleProductSelection(String productId) {
    setState(() {
      if (_selectedProductIds.contains(productId)) {
        _selectedProductIds.remove(productId);
        if (_selectedProductIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedProductIds.add(productId);
      }
    });
  }

  Future<void> _deleteSelectedProducts() async {
    if (_selectedProductIds.isEmpty) return;

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa ${_selectedProductIds.length} sản phẩm đã chọn?'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = context.read<ProductProvider>();
      for (final productId in _selectedProductIds) {
        await provider.deleteProduct(productId);
      }

      setState(() {
        _selectedProductIds.clear();
        _isSelectionMode = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa sản phẩm thành công'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return context.adaptiveWidget(
      mobile: _buildMobileLayout(),
      tablet: _buildDesktopLayout(), // Tablet uses desktop layout
      desktop: _buildDesktopLayout(),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSegmentedControl(),
          Expanded(child: _buildProductList(isMasterDetail: false)),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: Colors.grey[100], // Light background for separation
      body: Column(
        children: [
          _buildDesktopToolbar(),
          _buildSegmentedControl(),
          Expanded(
            child: Row(
              children: [
                // Master pane - Product list (wider for better readability)
                Expanded(
                  flex: 4, // Increased from 3 to 4 for better proportion
                  child: Container(
                    color: Colors.white, // White background for master pane
                    child: _buildProductList(isMasterDetail: true),
                  ),
                ),
                // Prominent divider
                Container(
                  width: 1,
                  color: Colors.grey[300],
                  margin: const EdgeInsets.symmetric(vertical: 8),
                ),
                // Detail pane - Product details (narrower, more focused)
                Expanded(
                  flex: 6, // Reduced from 7 to 6 for better balance
                  child: Container(
                    color: Colors.grey[50], // Subtle background for detail pane
                    child: Consumer<ProductProvider>(
                      builder: (context, provider, child) {
                        if (provider.selectedProduct == null) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 80,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'Chọn một sản phẩm để xem chi tiết',
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
                        return ProductDetailScreen(key: ValueKey(provider.selectedProduct!.id));
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Text(_isSelectionMode ? '${_selectedProductIds.length} đã chọn' : 'Quản Lý Sản Phẩm'),
      backgroundColor: Colors.green,
      foregroundColor: Colors.white,
      leading: _isSelectionMode
          ? IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => _toggleSelectionMode(),
              tooltip: 'Hủy chọn',
            )
          : null,
      actions: [
        if (_isSelectionMode)
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _selectedProductIds.isEmpty ? null : _deleteSelectedProducts,
            tooltip: 'Xóa',
          )
        else ...[
          // 🔥 REMOVED: Performance button causing confusion and errors
          // Debug cache stats removed to avoid null safety issues
          PopupMenuButton<dynamic>(
            icon: const Icon(CupertinoIcons.line_horizontal_3_decrease, color: Colors.white),
            tooltip: 'Lọc và Sắp xếp',
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            color: Colors.white.withOpacity(0.95),
            onSelected: (value) {
              if (value is ProductSortOption) {
                _applySortOption(value);
              } else if (value is StockFilterOption) {
                setState(() => _stockFilter = value);
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<dynamic>>[
              PopupMenuItem(
                enabled: false,
                child: Text(
                  'SẮP XẾP THEO',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
              ...ProductSortOption.values.map((option) => PopupMenuItem<ProductSortOption>(
                value: option,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(option.displayName),
                    if (_sortOption == option) const Icon(Icons.check, color: Colors.green, size: 20),
                  ],
                ),
              )),
              const PopupMenuDivider(height: 1),
              PopupMenuItem(
                enabled: false,
                child: Text(
                  'LỌC THEO TRẠNG THÁI',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
              ...StockFilterOption.values.map((option) => PopupMenuItem<StockFilterOption>(
                value: option,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(option.displayName),
                    if (_stockFilter == option) const Icon(Icons.check, color: Colors.green, size: 20),
                  ],
                ),
              )),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddProductDialog,
            tooltip: 'Thêm sản phẩm',
          ),
        ],
      ],
    );
  }

  Widget _buildDesktopToolbar() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          SizedBox(width: context.sectionPadding),
          Text(
            _isSelectionMode ? '${_selectedProductIds.length} đã chọn' : 'Quản Lý Sản Phẩm',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          if (_isSelectionMode) ...[
            const SizedBox(width: 16),
            TextButton.icon(
              onPressed: () => _toggleSelectionMode(),
              icon: const Icon(Icons.close),
              label: const Text('Hủy chọn'),
            ),
          ],
          const Spacer(),
          if (_isSelectionMode)
            ElevatedButton.icon(
              onPressed: _selectedProductIds.isEmpty ? null : _deleteSelectedProducts,
              icon: const Icon(Icons.delete),
              label: const Text('Xóa'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            )
          else ...[
            // 🔥 REMOVED: Duplicate PopupMenuButton causing search conflicts
            // This was identical to the AppBar PopupMenuButton and caused conflicts
            // Keep only the AppBar version for consistency
            ElevatedButton.icon(
              onPressed: _showAddProductDialog,
              icon: const Icon(Icons.add),
              label: const Text('Thêm sản phẩm'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
          SizedBox(width: context.sectionPadding),
        ],
      ),
    );
  }

  void _applySortOption(ProductSortOption option) {
    setState(() {
      _sortOption = option;
    });
  }

  void _showAddProductDialog() {
    if (context.isDesktop) {
      showDialog(
        context: context,
        builder: (context) => const AddProductDialog(),
      ).then((success) {
        if (success == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Thêm sản phẩm thành công!'), backgroundColor: Colors.green),
          );
          // Force refresh with fresh data after product creation
          context.read<ProductProvider>().refreshAllCache();
        }
      });
    } else {
      Navigator.of(context, rootNavigator: true).pushNamed('/add-product-step1');
    }
  }

  List<Product> _filterAndSortProducts(List<Product> products, ProductProvider provider) {
    // 🔥 CRITICAL FIX: Use consistent search logic with POS Screen
    final searchQuery = _searchController.text.trim();
    final isSearching = searchQuery.isNotEmpty && searchQuery.length >= 2;
    
    var filteredList = List<Product>.from(products);

    if (_selectedCategory != null) {
      filteredList = filteredList
          .where((product) => product.category == _selectedCategory)
          .toList();
    }

    // ⚠️ CHỈ APPLY STOCK FILTER KHI KHÔNG ĐANG SEARCH
    // Khi search, products đã được filter bởi search query rồi
    if (_stockFilter != StockFilterOption.all && !isSearching) {
      filteredList = filteredList.where((product) {
        final baseStock = provider.getProductStock(product.id); // Use base stock for filtering logic
        switch (_stockFilter) {
          case StockFilterOption.inStock:
            return baseStock > (product.minStockLevel ?? 0);
          case StockFilterOption.lowStock:
            final minStock = product.minStockLevel ?? 0;
            return baseStock > 0 && baseStock <= minStock;
          case StockFilterOption.outOfStock:
            return baseStock == 0;
          default:
            return true;
        }
      }).toList();
    }

    switch (_sortOption) {
      case ProductSortOption.nameAsc:
        filteredList.sort((a, b) => a.name.compareTo(b.name));
        break;
      case ProductSortOption.nameDesc:
        filteredList.sort((a, b) => b.name.compareTo(a.name));
        break;
      case ProductSortOption.priceHighToLow:
        filteredList.sort((a, b) {
          final priceA = provider.getCurrentPrice(a.id);
          final priceB = provider.getCurrentPrice(b.id);
          return priceB.compareTo(priceA);
        });
        break;
      case ProductSortOption.priceLowToHigh:
        filteredList.sort((a, b) {
          final priceA = provider.getCurrentPrice(a.id);
          final priceB = provider.getCurrentPrice(b.id);
          return priceA.compareTo(priceB);
        });
        break;
      case ProductSortOption.stockHighToLow:
        filteredList.sort((a, b) {
          final baseStockA = provider.getProductStock(a.id); // Use base stock for sorting
          final baseStockB = provider.getProductStock(b.id);
          return baseStockB.compareTo(baseStockA);
        });
        break;
      case ProductSortOption.stockLowToHigh:
        filteredList.sort((a, b) {
          final baseStockA = provider.getProductStock(a.id); // Use base stock for sorting  
          final baseStockB = provider.getProductStock(b.id);
          return baseStockA.compareTo(baseStockB);
        });
        break;
    }

    return filteredList;
  }

  Widget _buildSegmentedControl() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: context.sectionPadding, vertical: 12),
      child: CupertinoSlidingSegmentedControl<int>(
        groupValue: _selectedCategory == null ? 0 : (_selectedCategory!.index + 1),
        backgroundColor: CupertinoColors.systemGrey6,
        thumbColor: Colors.green,
        padding: const EdgeInsets.all(4),
        children: {
          0: _buildSegmentItem('Tất cả', _selectedCategory == null),
          1: _buildSegmentItem('Phân Bón', _selectedCategory == ProductCategory.FERTILIZER),
          2: _buildSegmentItem('Thuốc BVTV', _selectedCategory == ProductCategory.PESTICIDE),
          3: _buildSegmentItem('Lúa Giống', _selectedCategory == ProductCategory.SEED),
        },
        onValueChanged: (index) {
          if (index == null) return;
          if (index == 0) {
            _updateCategoryFilter(null);
          } else {
            _updateCategoryFilter(ProductCategory.values[index - 1]);
          }
        },
      ),
    );
  }

  Widget _buildSegmentItem(String text, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        text,
        style: TextStyle(
          color: isSelected ? Colors.white : CupertinoColors.black,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
        maxLines: 2,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  void _updateCategoryFilter(ProductCategory? category) {
    final provider = context.read<ProductProvider>();
    setState(() => _selectedCategory = category);

    if (_searchController.text.isNotEmpty) {
      _searchController.clear();
      provider.clearSearch();
    }

    if (category == null) {
      provider.resetSelectedCategory();
    }
  }

  Widget _buildProductList({required bool isMasterDetail}) {
    return Consumer<ProductProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.products.isEmpty) {
          return const Center(child: LoadingWidget());
        }
        
        final baseProducts = provider.getProductsForCategory(null);
        final filteredAndSortedProducts = _filterAndSortProducts(baseProducts, provider);

        if (filteredAndSortedProducts.isEmpty) {
          final isSearching = _searchController.text.trim().isNotEmpty && _searchController.text.trim().length >= 2;
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSearching ? Icons.search_off : Icons.inventory_2_outlined,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 24),
                Text(
                  isSearching 
                      ? 'Không tìm thấy sản phẩm nào\nvới từ khóa "${_searchController.text}"'
                      : 'Không có sản phẩm nào khớp với bộ lọc.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isSearching) ...[
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      _searchController.clear();
                      // Clear search will automatically trigger _onSearchChanged via listener
                    },
                    icon: const Icon(Icons.clear),
                    label: const Text('Xóa tìm kiếm'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        return CustomScrollView(
          slivers: [
            CupertinoSliverRefreshControl(
              onRefresh: () async {
                // Force refresh bypasses cache for fresh data
                final provider = context.read<ProductProvider>();
                await provider.refreshAllCache();
                return Future.value();
              },
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(context.sectionPadding, 8, context.sectionPadding, 8),
                child: CupertinoSearchTextField(
                  controller: _searchController,
                  placeholder: 'Tìm theo tên, SKU, nhà cung cấp...',
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final product = filteredAndSortedProducts[index];
                  return _buildProductListItem(product, provider, isMasterDetail);
                },
                childCount: filteredAndSortedProducts.length,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProductListItem(Product product, ProductProvider provider, bool isMasterDetail) {
    final baseStock = provider.getProductStock(product.id);
    final price = provider.getCurrentPrice(product.id);
    final isSelected = isMasterDetail && provider.selectedProduct?.id == product.id;
    final isChecked = _selectedProductIds.contains(product.id);

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? Colors.green.withOpacity(0.12) : Colors.transparent,
        border: isSelected ? Border(
          left: BorderSide(color: Colors.green, width: 3),
        ) : null,
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (_isSelectionMode) {
                  _toggleProductSelection(product.id);
                } else {
                  provider.selectProduct(product);
                  if (!isMasterDetail) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProductDetailScreen()),
                    );
                  }
                }
              },
              onLongPress: () {
                if (!_isSelectionMode && !isMasterDetail) {
                  _toggleSelectionMode(initialProductId: product.id);
                }
              },
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMasterDetail ? 16 : context.sectionPadding,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    if (_isSelectionMode)
                      Container(
                        width: 50,
                        height: 50,
                        alignment: Alignment.center,
                        child: Icon(
                          isChecked ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.circle,
                          color: isChecked ? Colors.green : CupertinoColors.systemGrey3,
                          size: 28,
                        ),
                      )
                    else
                      ProductImageWidget(
                        imageUrl: product.imageUrl,
                        size: ProductImageSize.list,
                        width: 50,
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: CupertinoColors.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          // 🔥 FIXED: Display stock in selling units instead of base units
                          FutureBuilder<String>(
                            future: _getStockDisplayString(product, baseStock, provider),
                            builder: (context, snapshot) {
                              final stockDisplay = snapshot.data ?? '$baseStock ${product.unit}';
                              return Text(
                                'Tồn kho: $stockDisplay • ${AppFormatter.formatCurrency(price)}',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: isSelected 
                                    ? CupertinoColors.systemGrey.withOpacity(1.0)
                                    : CupertinoColors.systemGrey.withOpacity(0.9),
                                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    // Apple HIG: Only show chevron for navigation, not selection
                    if (!_isSelectionMode && !isMasterDetail)
                      const Icon(
                        CupertinoIcons.chevron_right,
                        color: CupertinoColors.systemGrey3,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Apple HIG: Separator line (inset from left)
          Container(
            margin: EdgeInsets.only(
              left: isMasterDetail ? 78 : (context.responsive.isMobile ? 78 : 16),
            ),
            height: 0.5,
            color: CupertinoColors.separator,
          ),
        ],
      ),
    );
  }

  /// 🔥 NEW: Convert base stock to selling units for display
  Future<String> _getStockDisplayString(Product product, int baseStock, ProductProvider provider) async {
    try {
      final units = await provider.getProductUnits(product.id);
      
      if (units.isEmpty) {
        // No units configured, use base unit
        final baseUnitName = product.effectiveBaseUnit == 'đơn vị'
            ? ''
            : product.effectiveBaseUnit;
        return baseUnitName.isEmpty
            ? AppFormatter.formatNumber(baseStock)
            : '$baseStock ${_normalizeBaseUnit(baseUnitName)}';
      }
      
      // Find default selling unit
      final defaultUnit = UnitDisplayFormatter.defaultUnit(units) ?? units.first;
      final baseUnitName = UnitDisplayFormatter.resolveBaseUnitName(
        units: units,
        fallback: product.effectiveBaseUnit,
      );
      final defaultLabel = UnitDisplayFormatter.label(
        unit: defaultUnit,
        units: units,
        baseUnitName: baseUnitName,
      );
      final displayLabel = _simplifyUnitLabel(defaultLabel, baseUnitName);

      if (defaultUnit.conversionFactor <= 0) {
        // Invalid conversion factor, fallback
        return baseUnitName.isNotEmpty
            ? '$baseStock ${_normalizeBaseUnit(baseUnitName)}'
            : AppFormatter.formatNumber(baseStock);
      }
      
      // Convert base stock to selling units
      final conversion = defaultUnit.conversionFactor;
      final sellingUnitStock = baseStock / conversion;
      final wholeParts = sellingUnitStock.floor();

      if (wholeParts == 0) {
        // Less than one selling unit
        return baseUnitName.isNotEmpty
            ? '$baseStock ${_normalizeBaseUnit(baseUnitName)}'
            : AppFormatter.formatNumber(baseStock);
      }

      final remainder = baseStock - (wholeParts * conversion).round();
      final normalizedRemainder = remainder < 0 ? 0 : remainder;
      final hasMeaningfulBase = baseUnitName.isNotEmpty && baseUnitName.toLowerCase() != 'đơn vị';
      final hideRemainder = _shouldHideRemainder(defaultLabel, baseUnitName);
      
      if (!hideRemainder && normalizedRemainder > 0 && hasMeaningfulBase) {
        // Mixed display: "53 Bao và 32 kg"
        return '${AppFormatter.formatNumber(wholeParts)} $displayLabel và ${AppFormatter.formatNumber(normalizedRemainder)} ${_normalizeBaseUnit(baseUnitName)}';
      }
      
      // Exact match: "50 Bao"
      return '${AppFormatter.formatNumber(wholeParts)} $displayLabel';
    } catch (e) {
      // Error loading units, fallback to base display
      final baseUnitName = product.effectiveBaseUnit == 'đơn vị'
          ? ''
          : product.effectiveBaseUnit;
      return baseUnitName.isEmpty
          ? AppFormatter.formatNumber(baseStock)
          : '$baseStock ${_normalizeBaseUnit(baseUnitName)}';
    }
  }


  String _normalizeBaseUnit(String baseUnitName) {
    if (baseUnitName.isEmpty || baseUnitName.toLowerCase() == 'đơn vị') {
      return '';
    }
    return baseUnitName;
  }

  bool _shouldHideRemainder(String defaultLabel, String baseUnitName) {
    if (baseUnitName.isEmpty || baseUnitName.toLowerCase() == 'đơn vị') {
      return false;
    }
    final lowerBase = baseUnitName.toLowerCase();
    final lowerLabel = defaultLabel.toLowerCase();
    return lowerLabel.contains(lowerBase);
  }

  String _simplifyUnitLabel(String label, String baseUnitName) {
    if (baseUnitName.isEmpty || baseUnitName.toLowerCase() == 'đơn vị') {
      return label;
    }

    final lowerBase = baseUnitName.toLowerCase();
    var result = label;

    final pattern = RegExp(r'\s*\d+(?:[\.,]\d+)?\s*' + RegExp.escape(lowerBase), caseSensitive: false);
    result = result.replaceAll(pattern, '');
    result = result.replaceAll(RegExp(r'\b' + RegExp.escape(lowerBase) + r'\b', caseSensitive: false), '');
    result = result.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    if (result.isEmpty) {
      return label;
    }
    return result;
  }
  // 🔥 REMOVED: Unused performance methods since performance button was removed
}
