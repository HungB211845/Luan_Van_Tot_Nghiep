import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../models/product_batch.dart';
import '../../models/seasonal_price.dart';
import '../../providers/product_provider.dart';
import '../../../../shared/widgets/loading_widget.dart';
import 'add_batch_screen.dart';
import 'add_seasonal_price_screen.dart';
import 'edit_product_screen.dart';
import 'edit_batch_screen.dart';
import 'edit_seasonal_price_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({Key? key}) : super(key: key);

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _loadInitialData() {
    final provider = context.read<ProductProvider>();
    final product = provider.selectedProduct;
    if (product != null) {
      provider.loadProductBatches(product.id);
    }
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;
    final provider = context.read<ProductProvider>();
    final product = provider.selectedProduct;
    if (product == null) return;

    switch (_tabController.index) {
      case 1:
        provider.loadProductBatches(product.id);
        break;
      case 2:
        provider.loadSeasonalPrices(product.id);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = context.watch<ProductProvider>().selectedProduct;

    if (product == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi Tiết Sản Phẩm')),
        body: const Center(child: Text('Không tìm thấy sản phẩm')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(product.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green, // Theme màu xanh lá
        foregroundColor: Colors.white, // Chữ trắng
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, size: 24),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => EditProductScreen(product: product)));
            },
            tooltip: 'Chỉnh sửa',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7), // Sửa lỗi màu chữ tab
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Thông Tin Chung'),
            Tab(text: 'Tồn Kho & Lô Hàng'),
            Tab(text: 'Lịch Sử Giá Bán'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGeneralInfoTab(product),
          _buildInventoryTab(product),
          _buildPriceHistoryTab(product),
        ],
      ),
      floatingActionButton: _buildFAB(context, product),
    );
  }

  Widget? _buildFAB(BuildContext context, Product product) {
    switch (_tabController.index) {
      case 1:
        return FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => AddBatchScreen()));
          },
          icon: const Icon(Icons.add),
          label: const Text('Thêm Lô Hàng'),
        );
      case 2:
        return FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => AddSeasonalPriceScreen()));
          },
          icon: const Icon(Icons.add),
          label: const Text('Thêm Giá'),
        );
      default:
        return null;
    }
  }

  Widget _buildInventoryTab(Product product) {
    return Consumer<ProductProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.productBatches.isEmpty) {
          return const Center(child: LoadingWidget());
        }
        return RefreshIndicator(
          onRefresh: () => provider.loadProductBatches(product.id),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.productBatches.length,
            itemBuilder: (context, index) {
              final batch = provider.productBatches[index];
              return _buildBatchCard(context, batch);
            },
          ),
        );
      },
    );
  }

  Widget _buildPriceHistoryTab(Product product) {
    return Consumer<ProductProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.seasonalPrices.isEmpty) {
          return const Center(child: LoadingWidget());
        }
        return RefreshIndicator(
          onRefresh: () => provider.loadSeasonalPrices(product.id),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.seasonalPrices.length,
            itemBuilder: (context, index) {
              final price = provider.seasonalPrices[index];
              return _buildPriceCard(context, price);
            },
          ),
        );
      },
    );
  }

  // =====================================================
  // CÁC HÀM HELPER VẼ GIAO DIỆN (ĐÃ SỬA LẠI)
  // =====================================================

  Widget _buildGeneralInfoTab(Product product) {
    final provider = context.read<ProductProvider>();
    final stock = provider.getProductStock(product.id);
    final currentPrice = provider.getCurrentPrice(product.id);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(
                    icon: _getCategoryIcon(product.category),
                    color: _getCategoryColor(product.category),
                    title: 'Thông Tin Cơ Bản',
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow('Mã SKU', product.sku),
                  _buildInfoRow('Tên sản phẩm', product.name),
                  _buildInfoRow('Danh mục', product.categoryDisplayName),
                  _buildInfoRow('Trạng thái', product.isActive ? 'Hoạt động' : 'Không hoạt động'),
                  if (product.description != null && product.description!.isNotEmpty)
                    _buildInfoRow('Mô tả', product.description!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildSectionHeader(
                    icon: Icons.inventory_2,
                    color: Colors.blue,
                    title: 'Tồn Kho & Giá Bán',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildStatBox('Tồn kho', '$stock', Icons.inventory_2, Colors.blue)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildStatBox('Giá hiện tại', _formatCurrency(currentPrice), Icons.attach_money, Colors.green)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildCategoryAttributesCard(product),
        ],
      ),
    );
  }

  Widget _buildCategoryAttributesCard(Product product) {
    Widget? attributesWidget;
    String title = '';

    switch (product.category) {
      case ProductCategory.FERTILIZER:
        title = 'Thông Tin Phân Bón';
        final attrs = product.fertilizerAttributes;
        if (attrs != null) {
          attributesWidget = Column(
            children: [
              _buildInfoRow('Tỷ lệ NPK', attrs.npkRatio),
              _buildInfoRow('Loại phân', attrs.type),
              _buildInfoRow('Khối lượng', '${attrs.weight} ${attrs.unit}'),
            ],
          );
        }
        break;
      case ProductCategory.PESTICIDE:
        title = 'Thông Tin Thuốc BVTV';
        final attrs = product.pesticideAttributes;
        if (attrs != null) {
          attributesWidget = Column(
            children: [
              _buildInfoRow('Hoạt chất', attrs.activeIngredient),
              _buildInfoRow('Nồng độ', attrs.concentration),
              _buildInfoRow('Thể tích', '${attrs.volume} ${attrs.unit}'),
              if (attrs.targetPests.isNotEmpty) _buildInfoRow('Sâu bệnh mục tiêu', attrs.targetPests.join(', ')),
            ],
          );
        }
        break;
      case ProductCategory.SEED:
        title = 'Thông Tin Lúa Giống';
        final attrs = product.seedAttributes;
        if (attrs != null) {
          attributesWidget = Column(
            children: [
              _buildInfoRow('Giống', attrs.strain),
              _buildInfoRow('Xuất xứ', attrs.origin),
              _buildInfoRow('Tỷ lệ nảy mầm', attrs.germinationRate),
              _buildInfoRow('Độ thuần chủng', attrs.purity),
              if (attrs.growthPeriod != null) _buildInfoRow('TG sinh trưởng', attrs.growthPeriod!),
              if (attrs.yield != null) _buildInfoRow('Năng suất', attrs.yield!),
            ],
          );
        }
        break;
    }

    if (attributesWidget == null) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(icon: _getCategoryIcon(product.category), color: _getCategoryColor(product.category), title: title),
            const SizedBox(height: 16),
            attributesWidget,
          ],
        ),
      ),
    );
  }

  Widget _buildBatchCard(BuildContext context, ProductBatch batch) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lô: ${batch.batchNumber}', style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            _buildInfoRow('Số lượng', batch.quantity.toString()),
            _buildInfoRow('Giá nhập', _formatCurrency(batch.costPrice)),
            _buildInfoRow('Ngày nhập', _formatDate(batch.receivedDate)),
            if (batch.expiryDate != null) _buildInfoRow('Hạn sử dụng', _formatDate(batch.expiryDate!)),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.blue[700]),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => EditBatchScreen(batch: batch)));
                  },
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPriceCard(BuildContext context, SeasonalPrice price) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(price.seasonName, style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            _buildInfoRow('Giá bán', _formatCurrency(price.sellingPrice)),
            _buildInfoRow('Từ ngày', _formatDate(price.startDate)),
            _buildInfoRow('Đến ngày', _formatDate(price.endDate)),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.blue[700]),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => EditSeasonalPriceScreen(price: price)));
                  },
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({required IconData icon, required Color color, required String title}) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14, color: Colors.grey[800], fontWeight: FontWeight.normal),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color.shade700, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color.shade700),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(ProductCategory category) {
    switch (category) {
      case ProductCategory.FERTILIZER: return Icons.eco;
      case ProductCategory.PESTICIDE: return Icons.bug_report;
      case ProductCategory.SEED: return Icons.grass;
    }
  }

  Color _getCategoryColor(ProductCategory category) {
    switch (category) {
      case ProductCategory.FERTILIZER: return Colors.green;
      case ProductCategory.PESTICIDE: return Colors.orange;
      case ProductCategory.SEED: return Colors.brown;
    }
  }

  String _formatCurrency(double amount) {
    if (amount <= 0) return 'N/A';
    return '${amount.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}đ';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}