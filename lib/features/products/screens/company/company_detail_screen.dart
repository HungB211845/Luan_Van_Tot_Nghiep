import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../shared/utils/formatter.dart';
import '../../models/company.dart';
import '../../models/product.dart';
import '../../providers/company_provider.dart';
import '../../providers/product_provider.dart';
import '../products/product_detail_screen.dart';
import 'company_transaction_history_screen.dart';

class CompanyDetailScreen extends StatefulWidget {
  final Company company;

  const CompanyDetailScreen({Key? key, required this.company}) : super(key: key);

  static const String routeName = '/company-detail';

  @override
  _CompanyDetailScreenState createState() => _CompanyDetailScreenState();
}

class _CompanyDetailScreenState extends State<CompanyDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  bool _showContactInfo = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);

    // Listen to scroll to hide/show contact info
    _scrollController.addListener(() {
      final shouldShow = _scrollController.offset < 50;
      if (shouldShow != _showContactInfo) {
        setState(() {
          _showContactInfo = shouldShow;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CompanyProvider>().loadCompanyProducts(widget.company.id);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    setState(() {}); // Rebuild to apply filter
  }

  Future<void> _makePhoneCall() async {
    final phone = widget.company.phone;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có số điện thoại'), backgroundColor: Colors.red),
      );
      return;
    }

    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể gọi điện thoại'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteCompany() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xác nhận xóa'),
          content: Text('Mày có chắc muốn xóa nhà cung cấp "${widget.company.name}" không?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Hủy'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Xóa'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final provider = context.read<CompanyProvider>();
      final success = await provider.deleteCompany(widget.company.id);

      if (mounted) {
        if (success) {
          Navigator.of(context).pop(); // Quay về danh sách
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa nhà cung cấp'), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: ${provider.errorMessage}'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _editCompany() {
    Navigator.of(context, rootNavigator: true).pushNamed(RouteNames.editCompany, arguments: widget.company);
  }

  void _viewTransactionHistory() {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) => CompanyTransactionHistoryScreen(company: widget.company),
      ),
    );
  }

  List<Product> _getFilteredProducts(List<Product> products) {
    ProductCategory? category;
    switch (_tabController.index) {
      case 0:
        return products; // Tất cả
      case 1:
        category = ProductCategory.PESTICIDE;
        break;
      case 2:
        category = ProductCategory.FERTILIZER;
        break;
      case 3:
        category = ProductCategory.SEED;
        break;
    }
    return products.where((p) => p.category == category).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.company.name),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Lịch sử Giao dịch',
            onPressed: _viewTransactionHistory,
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Sửa',
            onPressed: _editCompany,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          labelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'Tất Cả'),
            Tab(text: 'Thuốc BVTV'),
            Tab(text: 'Phân Bón'),
            Tab(text: 'Lúa Giống'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Contact info card (collapsible)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _showContactInfo ? null : 0,
            curve: Curves.easeInOut,
            child: _showContactInfo ? _buildContactInfoCard() : const SizedBox.shrink(),
          ),

          // Product list
          Expanded(
            child: Consumer<CompanyProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allProducts = provider.companyProducts;
                final filteredProducts = _getFilteredProducts(allProducts);

                if (filteredProducts.isEmpty) {
                  return _buildEmptyWidget();
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await provider.loadCompanyProducts(widget.company.id);
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      return _buildProductCard(context, product, provider);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfoCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (widget.company.contactPerson != null && widget.company.contactPerson!.isNotEmpty)
              _buildContactRow(Icons.person, widget.company.contactPerson!),
            if (widget.company.phone != null && widget.company.phone!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.phone, color: Colors.grey[600], size: 20),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(widget.company.phone!, style: const TextStyle(fontSize: 16)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.call, color: Colors.green),
                    onPressed: _makePhoneCall,
                    tooltip: 'Gọi điện',
                  ),
                ],
              ),
            ],
            if (widget.company.address != null && widget.company.address!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildContactRow(Icons.location_on, widget.company.address!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[600], size: 20),
        const SizedBox(width: 16),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
      ],
    );
  }

  Widget _buildProductCard(
    BuildContext context,
    Product product,
    CompanyProvider provider,
  ) {
    final stock = product.availableStock ?? 0;
    final currentPrice = product.currentPrice ?? 0;
    final isLowStock = stock <= 10;
    final isBanned = product.isBanned;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // Select product and navigate to detail (full-screen without bottom nav)
          context.read<ProductProvider>().selectProduct(product);
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (context) => const ProductDetailScreen(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Category icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(product.category).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getCategoryIcon(product.category),
                      color: _getCategoryColor(product.category),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Product info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                product.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isBanned)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'CẤM',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'SKU: ${product.sku}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          product.categoryDisplayName,
                          style: TextStyle(
                            fontSize: 12,
                            color: _getCategoryColor(product.category),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Quick add to cart button
                  IconButton(
                    onPressed: () {
                      if (!isBanned && stock > 0) {
                        context.read<ProductProvider>().addToCart(product, 1);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Đã thêm ${product.name} vào giỏ hàng'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    icon: Icon(
                      Icons.add_shopping_cart,
                      color: (!isBanned && stock > 0) ? Colors.green : Colors.grey[400],
                    ),
                    tooltip: 'Thêm vào giỏ',
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Price and stock row
              Row(
                children: [
                  // Price
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.attach_money,
                            color: Colors.green[700],
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            currentPrice > 0
                                ? AppFormatter.formatCurrency(currentPrice)
                                : 'Chưa có giá',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Stock
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isLowStock ? Colors.orange[50] : Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isLowStock ? Colors.orange[200]! : Colors.blue[200]!,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isLowStock ? Icons.warning : Icons.inventory_2,
                            color: isLowStock ? Colors.orange[700] : Colors.blue[700],
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'SL: $stock',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isLowStock ? Colors.orange[700] : Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Attributes preview
              if (product.attributes.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildAttributesPreview(product),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttributesPreview(Product product) {
    switch (product.category) {
      case ProductCategory.FERTILIZER:
        final attrs = product.fertilizerAttributes;
        if (attrs != null) {
          return Text(
            'NPK: ${attrs.npkRatio} • ${attrs.weight}${attrs.unit} • ${attrs.type}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }
        break;
      case ProductCategory.PESTICIDE:
        final attrs = product.pesticideAttributes;
        if (attrs != null) {
          return Text(
            'Hoạt chất: ${attrs.activeIngredient} • ${attrs.concentration}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }
        break;
      case ProductCategory.SEED:
        final attrs = product.seedAttributes;
        if (attrs != null) {
          return Text(
            'Giống: ${attrs.strain} • ${attrs.origin}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }
        break;
    }
    return const SizedBox.shrink();
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
            _getEmptyMessage(),
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  String _getEmptyMessage() {
    switch (_tabController.index) {
      case 1:
        return 'Không có thuốc BVTV nào từ nhà cung cấp này';
      case 2:
        return 'Không có phân bón nào từ nhà cung cấp này';
      case 3:
        return 'Không có lúa giống nào từ nhà cung cấp này';
      default:
        return 'Không có sản phẩm nào từ nhà cung cấp này';
    }
  }

  IconData _getCategoryIcon(ProductCategory category) {
    switch (category) {
      case ProductCategory.FERTILIZER:
        return Icons.eco;
      case ProductCategory.PESTICIDE:
        return Icons.bug_report;
      case ProductCategory.SEED:
        return Icons.grass;
    }
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
}