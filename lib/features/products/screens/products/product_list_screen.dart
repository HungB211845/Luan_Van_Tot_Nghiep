// lib/screens/products/product_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../providers/product_provider.dart';
import '../../providers/product_edit_mode_provider.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/custom_button.dart';
import 'product_detail_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({Key? key}) : super(key: key);

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // Load products when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadProducts();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    if (query.isNotEmpty) {
      context.read<ProductProvider>().searchProducts(query);
    } else {
      context.read<ProductProvider>().clearSearch();
    }
  }

  void _onTabChanged() {
    ProductCategory? category;
    switch (_tabController.index) {
      case 0:
        category = null; // Tất cả
        break;
      case 1:
        category = ProductCategory.FERTILIZER;
        break;
      case 2:
        category = ProductCategory.PESTICIDE;
        break;
      case 3:
        category = ProductCategory.SEED;
        break;
    }
    context.read<ProductProvider>().filterByCategory(category);
  }

  void _showMoreActionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                ),
                title: const Text(
                  'Chọn Sản phẩm',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w400),
                ),
                onTap: () {
                  Navigator.pop(context);
                  context.read<ProductEditModeProvider>().enterEditMode();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProductEditModeProvider>(
      builder: (context, editModeProvider, child) {
        final isEditMode = editModeProvider.isEditMode;

        return GestureDetector(
          // Add swipe gesture for iOS-style back navigation
          onHorizontalDragEnd: (DragEndDetails details) {
            if (details.primaryVelocity != null &&
                details.primaryVelocity! > 300) {
              // Swipe right detected, navigate back to home
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          },
          child: Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              leading: isEditMode
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.more_horiz),
                      onPressed: _showMoreActionsMenu,
                      tooltip: 'Thêm hành động',
                    ),
              title: const Text('Quản Lý Sản Phẩm'),
              centerTitle: true,
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              actions: [
                if (isEditMode)
                  TextButton(
                    onPressed: () {
                      editModeProvider.exitEditMode();
                    },
                    child: const Text(
                      'Xong',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      Navigator.of(
                        context,
                        rootNavigator: true,
                      ).pushNamed('/add-product-step1');
                    },
                    tooltip: 'Thêm sản phẩm',
                  ),
              ],
              bottom: TabBar(
                controller: _tabController,
                onTap: (_) => _onTabChanged(),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                labelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(text: 'Tất Cả'),
                  Tab(text: 'Phân Bón'),
                  Tab(text: 'Thuốc BVTV'),
                  Tab(text: 'Lúa Giống'),
                ],
              ),
            ),
            body: Column(
              children: [
                // Search bar
                Material(
                  color: Colors.grey[50],
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm sản phẩm...',
                        hintStyle: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          size: 24,
                          color: Colors.grey[600],
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Theme.of(context).primaryColor,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),

                // Product list - Clean, focused content
                Expanded(
                  child: Consumer<ProductProvider>(
                    builder: (context, provider, child) {
                      if (provider.isLoading) {
                        return const LoadingWidget();
                      }

                      if (provider.hasError) {
                        return _buildErrorWidget(provider.errorMessage);
                      }

                      final products = provider.products;

                      if (products.isEmpty) {
                        return _buildEmptyWidget();
                      }

                      return RefreshIndicator(
                        onRefresh: () async {
                          await provider.refresh();
                        },
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            final product = products[index];
                            return _buildCleanProductCard(
                              context,
                              product,
                              provider,
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            bottomNavigationBar: editModeProvider.hasSelection
                ? _buildDeleteToolbar(editModeProvider)
                : null,
          ),
        );
      },
    );
  }

  Widget _buildDeleteToolbar(ProductEditModeProvider editModeProvider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!, width: 0.5)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      child: ElevatedButton(
        onPressed: () => _confirmDeleteSelected(editModeProvider),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(
          'Xóa (${editModeProvider.selectedCount})',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteSelected(
    ProductEditModeProvider editModeProvider,
  ) async {
    final selectedIds = editModeProvider.selectedProductIds.toList();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Bạn có chắc chắn muốn xóa ${selectedIds.length} sản phẩm này không?\n\nHành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = context.read<ProductProvider>();
      int successCount = 0;
      int failCount = 0;

      // Exit edit mode first
      editModeProvider.exitEditMode();

      // Show loading overlay
      final overlay = Overlay.of(context);
      final overlayEntry = OverlayEntry(
        builder: (context) => Container(
          color: Colors.black54,
          child: const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Đang xóa sản phẩm...'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      overlay.insert(overlayEntry);

      try {
        // Delete each product
        for (final productId in selectedIds) {
          final success = await provider.deleteProduct(productId);
          if (success) {
            successCount++;
          } else {
            failCount++;
          }
        }

        // Refresh list
        await provider.refresh();
      } finally {
        // Remove loading overlay
        overlayEntry.remove();
      }

      // Show result
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failCount == 0
                  ? 'Đã xóa $successCount sản phẩm thành công'
                  : 'Đã xóa $successCount sản phẩm, $failCount thất bại',
            ),
            backgroundColor: failCount == 0 ? Colors.green : Colors.orange,
          ),
        );
      }
    }
  }

  Widget _buildCleanProductCard(
    BuildContext context,
    Product product,
    ProductProvider provider,
  ) {
    return Consumer<ProductEditModeProvider>(
      builder: (context, editModeProvider, child) {
        final stock = provider.getProductStock(product.id);
        final currentPrice = provider.getCurrentPrice(product.id);
        final isLowStock = stock <= 10;
        final isBanned = product.isBanned;
        final isEditMode = editModeProvider.isEditMode;
        final isSelected = editModeProvider.isSelected(product.id);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey[200]!, width: 1),
          ),
          child: InkWell(
            onTap: () {
              if (isEditMode) {
                editModeProvider.toggleSelection(product.id);
              } else {
                provider.selectProduct(product);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProductDetailScreen(),
                  ),
                );
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Checkbox in edit mode
                  if (isEditMode) ...[
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.green : Colors.grey[400]!,
                          width: 2,
                        ),
                        color: isSelected ? Colors.green : Colors.transparent,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                  ],

                  // Simple category icon - small and minimal
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _getCategoryColor(product.category),
                      shape: BoxShape.circle,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Main content - Typography hierarchy
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product name - Largest, boldest
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                product.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                  height: 1.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isBanned)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: const Text(
                                  'CẤM',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 4),

                        // SKU and Category - Secondary info, lighter
                        Row(
                          children: [
                            Text(
                              'SKU: ${product.sku}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '•',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              product.categoryDisplayName,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Price and Stock - Same line, focused on stock
                        Row(
                          children: [
                            // Price - normal weight
                            Text(
                              currentPrice > 0
                                  ? _formatCurrency(currentPrice)
                                  : 'Chưa có giá',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            const SizedBox(width: 16),

                            // Separator
                            Text(
                              '•',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            const SizedBox(width: 16),

                            // Stock - Emphasized as primary info
                            Text(
                              'Tồn kho: ',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '$stock',
                              style: TextStyle(
                                fontSize: 16,
                                color: isLowStock
                                    ? Colors.red[600]
                                    : Colors.black,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (isLowStock) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.warning,
                                size: 16,
                                color: Colors.red[600],
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Chưa có sản phẩm nào',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bấm nút + để thêm sản phẩm đầu tiên',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          CustomButton(
            text: 'Thêm Sản Phẩm',
            onPressed: () {
              Navigator.of(
                context,
                rootNavigator: true,
              ).pushNamed('/add-product-step1');
            },
            icon: Icons.add,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String errorMessage) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
          const SizedBox(height: 16),
          Text(
            'Có lỗi xảy ra',
            style: TextStyle(
              fontSize: 18,
              color: Colors.red[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              errorMessage,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          CustomButton(
            text: 'Thử Lại',
            onPressed: () {
              context.read<ProductProvider>().refresh();
            },
            icon: Icons.refresh,
          ),
        ],
      ),
    );
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

  String _formatCurrency(double amount) {
    return '${amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}đ';
  }
}
