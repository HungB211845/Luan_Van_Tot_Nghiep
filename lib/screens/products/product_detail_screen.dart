import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../models/product_batch.dart';
import '../../models/seasonal_price.dart';
import '../../providers/product_provider.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/custom_button.dart';
import 'edit_product_screen.dart';
// import 'add_batch_screen.dart'; // TODO: Sẽ được tạo ở bước sau
// import 'add_seasonal_price_screen.dart'; // TODO: Sẽ được tạo ở bước sau

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
      case 1: // Inventory Tab
        provider.loadProductBatches(product.id);
        break;
      case 2: // Price History Tab
        provider.loadSeasonalPrices(product.id);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dùng Watch ở đây để rebuild toàn bộ màn hình khi selectedProduct thay đổi
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
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
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
          unselectedLabelColor: Colors.white70,
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
    return Consumer<ProductProvider>(
      builder: (context, provider, child) {
         switch (_tabController.index) {
          case 1:
            return FloatingActionButton.extended(
              onPressed: () {
                // TODO: Điều hướng đến AddBatchScreen sau khi được tạo
                // Navigator.push(context, MaterialPageRoute(builder: (context) => const AddBatchScreen()));
              },
              icon: const Icon(Icons.add),
              label: const Text('Thêm Lô Hàng'),
            );
          case 2:
            return FloatingActionButton.extended(
              onPressed: () {
                // TODO: Điều hướng đến AddSeasonalPriceScreen sau khi được tạo
                // Navigator.push(context, MaterialPageRoute(builder: (context) => const AddSeasonalPriceScreen()));
              },
              icon: const Icon(Icons.add),
              label: const Text('Thêm Giá'),
            );
          default:
            return const SizedBox.shrink();
        }
      },
    );
  }

  Widget _buildGeneralInfoTab(Product product) {
    // Dùng Consumer để chỉ build lại những widget cần thiết khi provider thay đổi
    return Consumer<ProductProvider>(
      builder: (context, provider, child) {
        final stock = provider.getProductStock(product.id);
        final currentPrice = provider.getCurrentPrice(product.id);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoCard(product),
              const SizedBox(height: 16),
              _buildStockPriceCard(stock, currentPrice),
              const SizedBox(height: 16),
              _buildCategoryAttributesCard(product),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInventoryTab(Product product) {
    return Consumer<ProductProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.productBatches.isEmpty) {
          return const Center(child: LoadingWidget());
        }
        if (provider.hasError && provider.productBatches.isEmpty) {
          return Center(child: Text('Lỗi: ${provider.errorMessage}'));
        }
        if (provider.productBatches.isEmpty) {
          return const Center(child: Text('Chưa có lô hàng nào.'));
        }
        return RefreshIndicator(
          onRefresh: () => provider.loadProductBatches(product.id),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.productBatches.length,
            itemBuilder: (context, index) {
              final batch = provider.productBatches[index];
              return _buildBatchCard(batch);
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
        if (provider.hasError && provider.seasonalPrices.isEmpty) {
          return Center(child: Text('Lỗi: ${provider.errorMessage}'));
        }
        if (provider.seasonalPrices.isEmpty) {
          return const Center(child: Text('Chưa có lịch sử giá.'));
        }
        return RefreshIndicator(
          onRefresh: () => provider.loadSeasonalPrices(product.id),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.seasonalPrices.length,
            itemBuilder: (context, index) {
              final price = provider.seasonalPrices[index];
              return _buildPriceCard(price);
            },
          ),
        );
      },
    );
  }

  // --- Helper Widgets --- 

  Widget _buildInfoCard(Product product) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Thông Tin Cơ Bản', style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            _buildInfoRow('Mã SKU', product.sku),
            _buildInfoRow('Tên sản phẩm', product.name),
            _buildInfoRow('Danh mục', product.categoryDisplayName),
            _buildInfoRow('Trạng thái', product.isActive ? 'Hoạt động' : 'Không hoạt động'),
            if (product.isBanned) _buildInfoRow('Cảnh báo', 'Sản phẩm bị cấm', isWarning: true),
            if (product.description != null) _buildInfoRow('Mô tả', product.description!),
          ],
        ),
      ),
    );
  }

  Widget _buildStockPriceCard(int stock, double currentPrice) {
    return Card(
       child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                Text('Tồn kho', style: Theme.of(context).textTheme.titleMedium),
                Text('$stock', style: Theme.of(context).textTheme.headlineMedium),
              ],
            ),
            Column(
              children: [
                Text('Giá hiện tại', style: Theme.of(context).textTheme.titleMedium),
                Text(_formatCurrency(currentPrice), style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.green)),
              ],
            ),
          ],
        ),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            attributesWidget,
          ],
        ),
      ),
    );
  }

  Widget _buildBatchCard(ProductBatch batch) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lô: ${batch.batchNumber}', style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            _buildInfoRow('Số lượng', '${batch.quantity}'),
            _buildInfoRow('Giá nhập', _formatCurrency(batch.costPrice)),
            _buildInfoRow('Ngày nhập', _formatDate(batch.receivedDate)),
            if (batch.expiryDate != null) _buildInfoRow('Hạn sử dụng', _formatDate(batch.expiryDate!)),
            if (batch.supplierBatchId != null) _buildInfoRow('Mã lô NCC', batch.supplierBatchId!),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceCard(SeasonalPrice price) {
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
            _buildInfoRow('Trạng thái', price.isCurrentlyActive ? 'Đang áp dụng' : 'Không hoạt động'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isWarning = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value, style: TextStyle(color: isWarning ? Colors.red : null))),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    return '${amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}₫';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}