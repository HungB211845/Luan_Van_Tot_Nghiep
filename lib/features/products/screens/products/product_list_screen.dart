import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../providers/product_provider.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/utils/formatter.dart';
import '../../../../shared/utils/responsive.dart';
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
        // Use cache-enabled version for faster initial load
        provider.loadProducts();
      }
    });
    _searchController.addListener(() {
      final query = _searchController.text;
      final provider = context.read<ProductProvider>();
      
      if (query.isEmpty) {
        // Clear search results and show all products
        provider.clearSearch();
      } else {
        // Use cache-enabled search for better performance
        provider.searchProducts(query, useCache: true);
      }
    });
  }

  @override
  void dispose() {
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
          // Debug cache info in development
          if (kDebugMode && CacheConfig.enableCacheLogging)
            IconButton(
              icon: const Icon(Icons.speed, color: Colors.white),
              onPressed: _showCacheStats,
              tooltip: 'Cache Stats',
            ),
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
            PopupMenuButton<dynamic>(
              icon: const Icon(CupertinoIcons.line_horizontal_3_decrease),
              tooltip: 'Lọc và Sắp xếp',
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
            const SizedBox(width: 8),
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
    var filteredList = List<Product>.from(products);

    // ⚠️ CHỈ APPLY STOCK FILTER KHI KHÔNG ĐANG SEARCH
    // Khi search, products đã được filter bởi search query rồi
    if (_stockFilter != StockFilterOption.all && provider.searchQuery.isEmpty) {
      filteredList = filteredList.where((product) {
        final stock = provider.getProductStock(product.id);
        switch (_stockFilter) {
          case StockFilterOption.inStock:
            return stock > (product.minStockLevel ?? 0);
          case StockFilterOption.lowStock:
            final minStock = product.minStockLevel ?? 0;
            return stock > 0 && stock <= minStock;
          case StockFilterOption.outOfStock:
            return stock == 0;
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
          final stockA = provider.getProductStock(a.id);
          final stockB = provider.getProductStock(b.id);
          return stockB.compareTo(stockA);
        });
        break;
      case ProductSortOption.stockLowToHigh:
        filteredList.sort((a, b) {
          final stockA = provider.getProductStock(a.id);
          final stockB = provider.getProductStock(b.id);
          return stockA.compareTo(stockB);
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        text,
        style: TextStyle(
          color: isSelected ? Colors.white : CupertinoColors.black,
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  void _updateCategoryFilter(ProductCategory? category) {
    setState(() => _selectedCategory = category);
    // Cache will be automatically used if available
    context.read<ProductProvider>().loadProducts(category: category);
  }

  Widget _buildProductList({required bool isMasterDetail}) {
    return Consumer<ProductProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.products.isEmpty) {
          return const Center(child: LoadingWidget());
        }
        
        final filteredAndSortedProducts = _filterAndSortProducts(provider.products, provider);

        if (filteredAndSortedProducts.isEmpty) {
          return const Center(child: Text('Không có sản phẩm nào khớp với bộ lọc.'));
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
    final stock = provider.getProductStock(product.id);
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
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.green.withOpacity(0.2) : Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  product.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Icon(
                                    Icons.inventory_2,
                                    color: isSelected ? Colors.green[700] : Colors.green,
                                    size: 28,
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.inventory_2,
                                color: isSelected ? Colors.green[700] : Colors.green,
                                size: 28,
                              ),
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
                          Text(
                            'Tồn kho: $stock • ${AppFormatter.formatCurrency(price)}',
                            style: TextStyle(
                              fontSize: 15,
                              color: isSelected 
                                ? CupertinoColors.systemGrey.withOpacity(1.0)
                                : CupertinoColors.systemGrey.withOpacity(0.9),
                              fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                            ),
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

  /// Show enhanced cache performance statistics and run benchmarks
  void _showCacheStats() {
    final provider = context.read<ProductProvider>();
    final stats = provider.getCacheStats();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.speed, color: Colors.blue),
            SizedBox(width: 8),
            Text('Cache Performance Dashboard'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Current Performance Stats
              _buildStatsSection('Current Performance', [
                'Hit Rate: ${(stats['cache_performance']['hit_rate'] * 100).toStringAsFixed(1)}%',
                'Total Operations: ${stats['cache_performance']['total_operations']}',
                'Cache Hits: ${stats['cache_performance']['total_hits']}',
                'Cache Misses: ${stats['cache_performance']['total_misses']}',
              ]),
              
              const SizedBox(height: 16),
              
              // Search Performance
              if (stats['cache_performance']['search_performance']['count'] > 0)
                _buildStatsSection('Search Performance', [
                  'Average: ${stats['cache_performance']['search_performance']['avg']}ms',
                  'Recent: ${stats['cache_performance']['search_performance']['recent_avg']}ms',
                  'Range: ${stats['cache_performance']['search_performance']['min']}-${stats['cache_performance']['search_performance']['max']}ms',
                  'Samples: ${stats['cache_performance']['search_performance']['count']}',
                ]),
              
              const SizedBox(height: 16),
              
              // Dashboard Performance  
              if (stats['cache_performance']['dashboard_performance']['count'] > 0)
                _buildStatsSection('Dashboard Performance', [
                  'Average: ${stats['cache_performance']['dashboard_performance']['avg']}ms',
                  'Recent: ${stats['cache_performance']['dashboard_performance']['recent_avg']}ms',
                  'Samples: ${stats['cache_performance']['dashboard_performance']['count']}',
                ]),
              
              const SizedBox(height: 16),
              
              // Cache Configuration
              _buildStatsSection('Configuration', [
                'Search Cache: ${stats['cache_config']['search_enabled'] ? 'ON' : 'OFF'}',
                'Stats Cache: ${stats['cache_config']['stats_enabled'] ? 'ON' : 'OFF'}',
                'Debug Logging: ${stats['cache_config']['logging_enabled'] ? 'ON' : 'OFF'}',
              ]),
              
              const SizedBox(height: 16),
              
              // Memory Usage
              _buildStatsSection('Memory Usage', [
                'Total Items: ${stats['provider_memory']['total_items']}',
                'Auto Cleanup: ${stats['provider_memory']['memory_managed'] ? 'Active' : 'Inactive'}',
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _runPerformanceBenchmark();
            },
            child: const Text('Run Benchmark'),
          ),
          TextButton(
            onPressed: () {
              provider.refreshAllCache();
              CacheMetrics.reset();
              Navigator.pop(context);
            },
            child: const Text('Reset Cache'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatsSection(String title, List<String> stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        ...stats.map((stat) => Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 4),
          child: Text(stat, style: const TextStyle(fontFamily: 'monospace')),
        )),
      ],
    );
  }
  
  /// Run comprehensive performance benchmarks
  Future<void> _runPerformanceBenchmark() async {
    final provider = context.read<ProductProvider>();
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text('Running Performance Benchmark...'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Testing cache performance\nThis may take a few moments'),
          ],
        ),
      ),
    );
    
    try {
      // Run comprehensive benchmarks
      final results = await PerformanceBenchmark.runBenchmarks(provider);
      
      // Also run workflow simulation
      final workflowResults = await PerformanceBenchmark.simulateUserWorkflow(provider);
      
      // Close loading dialog
      Navigator.pop(context);
      
      // Show results
      _showBenchmarkResults(results, workflowResults);
      
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Benchmark failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  /// Show detailed benchmark results
  void _showBenchmarkResults(Map<String, dynamic> results, Map<String, dynamic> workflow) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.analytics, color: Colors.green),
            SizedBox(width: 8),
            Text('Performance Benchmark Results'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search Benchmark
              if (results['search_benchmark'] != null)
                _buildBenchmarkSection(
                  '🔍 Search Performance',
                  results['search_benchmark'] as Map<String, dynamic>,
                ),
              
              // Dashboard Benchmark
              if (results['dashboard_benchmark'] != null)
                _buildBenchmarkSection(
                  '📊 Dashboard Performance',
                  results['dashboard_benchmark'] as Map<String, dynamic>,
                ),
              
              // Workflow Simulation
              _buildWorkflowSection('👤 User Workflow', workflow),
              
              // Overall Analysis
              _buildAnalysisSection('📈 Analysis', results['cache_analysis'] as Map<String, dynamic>),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Show full performance report in console
              if (kDebugMode) {
                print(CacheMetrics.generatePerformanceReport());
              }
            },
            child: const Text('View Report'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBenchmarkSection(String title, Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Cached: ${data['cached_avg']}ms average'),
        Text('Direct: ${data['direct_avg']}ms average'),
        Text('Improvement: ${data['improvement_percent']}%', 
             style: TextStyle(
               color: (data['improvement_percent'] as int) > 0 ? Colors.green : Colors.red,
               fontWeight: FontWeight.bold,
             )),
        Text('Tests: ${data['queries_tested'] ?? data['loads_tested']}'),
        const SizedBox(height: 16),
      ],
    );
  }
  
  Widget _buildWorkflowSection(String title, Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Total Time: ${data['total_time']}ms'),
        Text('Rating: ${data['workflow_rating']}', 
             style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Breakdown:', style: TextStyle(fontWeight: FontWeight.w500)),
        ...((data['breakdown'] as Map<String, int>).entries.map((entry) =>
            Text('  ${entry.key}: ${entry.value}ms'))),
        const SizedBox(height: 16),
      ],
    );
  }
  
  Widget _buildAnalysisSection(String title, Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Hit Rate: ${(data['hit_rate'] * 100).toStringAsFixed(1)}%'),
        Text('Effectiveness: ${data['is_effective'] ? 'YES' : 'NO'}'),
        Text('Recommendation:', style: const TextStyle(fontWeight: FontWeight.w500)),
        Text('  ${data['recommendation']}'),
      ],
    );
  }
}