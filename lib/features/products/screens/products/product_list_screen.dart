import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../providers/product_provider.dart';
import '../../providers/product_edit_mode_provider.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/utils/formatter.dart';
import 'add_product_dialog.dart';
import 'product_detail_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({Key? key}) : super(key: key);

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final TextEditingController _searchController = TextEditingController();
  ProductCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadProducts();
    });
    _searchController.addListener(() {
      context.read<ProductProvider>().searchProducts(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double tabletBreakpoint = 768;
        if (constraints.maxWidth >= tabletBreakpoint) {
          return _buildDesktopLayout();
        }
        return _buildMobileLayout();
      },
    );
  }

  // MASTER-DETAIL LAYOUT FOR TABLET/DESKTOP
  Widget _buildDesktopLayout() {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Row(
        children: [
          // Master Pane (List)
          Expanded(
            flex: 4,
            child: Column(
              children: [
                _buildSearchBar(),
                _buildCategoryFilters(),
                Expanded(child: _buildProductList(isMasterDetail: true)),
              ],
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          // Detail Pane
          Expanded(
            flex: 6,
            child: Consumer<ProductProvider>(
              builder: (context, provider, child) {
                if (provider.selectedProduct == null) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Chọn một sản phẩm để xem chi tiết', style: TextStyle(fontSize: 16, color: Colors.grey)),
                      ],
                    ),
                  );
                }
                // Reuse the existing detail screen widget
                return const ProductDetailScreen();
              },
            ),
          ),
        ],
      ),
    );
  }

  // STANDARD LAYOUT FOR MOBILE
  Widget _buildMobileLayout() {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildCategoryFilters(),
          Expanded(child: _buildProductList(isMasterDetail: false)),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('Quản Lý Sản Phẩm'),
      backgroundColor: Colors.green,
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () {
            const double tabletBreakpoint = 768;
            final screenWidth = MediaQuery.of(context).size.width;

            if (screenWidth >= tabletBreakpoint) {
              showDialog(
                context: context,
                builder: (context) => const AddProductDialog(),
              ).then((success) {
                if (success == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Thêm sản phẩm thành công!'), backgroundColor: Colors.green),
                  );
                  context.read<ProductProvider>().loadProducts();
                }
              });
            } else {
              Navigator.of(context, rootNavigator: true).pushNamed('/add-product-step1');
            }
          },
          tooltip: 'Thêm sản phẩm',
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Tìm kiếm sản phẩm...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildCategoryFilters() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          FilterChip(label: const Text('Tất cả'), selected: _selectedCategory == null, onSelected: (s) => _updateCategoryFilter(null)),
          const SizedBox(width: 8),
          ...ProductCategory.values.map((cat) => Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(label: Text(cat.displayName), selected: _selectedCategory == cat, onSelected: (s) => _updateCategoryFilter(s ? cat : null)),
          )),
        ],
      ),
    );
  }

  void _updateCategoryFilter(ProductCategory? category) {
    setState(() => _selectedCategory = category);
    context.read<ProductProvider>().loadProducts(category: category);
  }

  Widget _buildProductList({required bool isMasterDetail}) {
    return Consumer<ProductProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.products.isEmpty) {
          return const Center(child: LoadingWidget());
        }
        if (provider.products.isEmpty) {
          return const Center(child: Text('Không có sản phẩm nào.'));
        }
        return RefreshIndicator(
          onRefresh: () => provider.loadProducts(category: _selectedCategory),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.products.length,
            itemBuilder: (context, index) {
              final product = provider.products[index];
              return _buildProductListItem(product, provider, isMasterDetail);
            },
          ),
        );
      },
    );
  }

  Widget _buildProductListItem(Product product, ProductProvider provider, bool isMasterDetail) {
    final stock = provider.getProductStock(product.id);
    final price = provider.getCurrentPrice(product.id);
    final isSelected = isMasterDetail && provider.selectedProduct?.id == product.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isSelected ? Colors.green.withOpacity(0.1) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isSelected ? Colors.green : Colors.grey[200]!, width: 1.5),
      ),
      child: ListTile(
        title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Tồn kho: $stock • Giá: ${AppFormatter.formatCurrency(price)}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          provider.selectProduct(product);
          if (!isMasterDetail) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProductDetailScreen()),
            );
          }
        },
      ),
    );
  }
}