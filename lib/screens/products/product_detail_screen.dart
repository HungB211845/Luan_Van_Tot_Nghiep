// lib/screens/products/product_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../models/product_batch.dart';
import '../../models/seasonal_price.dart';
import '../../providers/product_provider.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/custom_button.dart';
import 'edit_product_screen.dart';
import 'add_batch_screen.dart';
import 'add_seasonal_price_screen.dart';
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

    // Load initial data cho tab đầu tiên
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadInitialData() {
    final provider = context.read<ProductProvider>();
    final product = provider.selectedProduct;
    if (product != null) {
      // Load batches mặc định cho tab inventory
      provider.loadProductBatches(product.id);
    }
  }

  void _onTabChanged() {
    final provider = context.read<ProductProvider>();
    final product = provider.selectedProduct;
    if (product == null) return;

    // Load data theo tab được chọn
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
    return Consumer<ProductProvider>(
      builder: (context, provider, child) {
        final product = provider.selectedProduct;

        if (product == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Chi Tiết Sản Phẩm'),
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            body: const Center(
              child: Text(
                'Không tìm thấy sản phẩm',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(
              product.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            elevation: 2,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit, size: 24),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EditProductScreen(),
                    ),
                  );
                },
                tooltip: 'Chỉnh sửa',
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
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
              _buildGeneralInfoTab(product, provider),
              _buildInventoryTab(product, provider),
              _buildPriceHistoryTab(product, provider),
            ],
          ),
          floatingActionButton: _buildFAB(),
        );
      },
    );
  }

  Widget? _buildFAB() {
    switch (_tabController.index) {
      case 1:
        return FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddBatchScreen()),
            ).then((_) {
              // Reload batches sau khi thêm
              final provider = context.read<ProductProvider>();
              final product = provider.selectedProduct;
              if (product != null) {
                provider.loadProductBatches(product.id);
              }
            });
          },
          icon: const Icon(Icons.add),
          label: const Text('Thêm Lô Hàng'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        );
      case 2:
        return FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AddSeasonalPriceScreen(),
              ),
            ).then((_) {
              // Reload prices sau khi thêm
              final provider = context.read<ProductProvider>();
              final product = provider.selectedProduct;
              if (product != null) {
                provider.loadSeasonalPrices(product.id);
              }
            });
          },
          icon: const Icon(Icons.add),
          label: const Text('Thêm Giá'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        );
      default:
        return null;
    }
  }

  Widget _buildGeneralInfoTab(Product product, ProductProvider provider) {
    final stock = provider.getProductStock(product.id);
    final currentPrice = provider.getCurrentPrice(product.id);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic Info Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _getCategoryIcon(product.category),
                        color: _getCategoryColor(product.category),
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Thông Tin Cơ Bản',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow('Mã SKU', product.sku),
                  _buildInfoRow('Tên sản phẩm', product.name),
                  _buildInfoRow('Danh mục', product.categoryDisplayName),
                  _buildInfoRow(
                    'Trạng thái',
                    product.isActive ? 'Hoạt động' : 'Không hoạt động',
                  ),
                  if (product.isBanned)
                    _buildInfoRow(
                      'Cảnh báo',
                      'Sản phẩm bị cấm',
                      isWarning: true,
                    ),
                  if (product.description != null)
                    _buildInfoRow('Mô tả', product.description!),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Stock and Price Card
          _buildStockPriceCard(stock, currentPrice),

          const SizedBox(height: 16),

          // Category Specific Attributes Card
          _buildCategoryAttributesCard(product),
        ],
      ),
    );
  }

  Widget _buildInventoryTab(Product product, ProductProvider provider) {
    // Lấy data và state TRỰC TIẾP từ Provider
    final batches = provider.productBatches;
    final isLoading = provider.isLoading;
    final hasError = provider.hasError;
    final errorMessage = provider.errorMessage;

    if (isLoading) {
      return const Center(child: LoadingWidget());
    }

    if (hasError && errorMessage.isNotEmpty) {
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
            Text(errorMessage, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            CustomButton(
              text: 'Thử lại',
              onPressed: () => provider.loadProductBatches(product.id),
              icon: Icons.refresh,
            ),
          ],
        ),
      );
    }

    if (batches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Chưa có lô hàng nào',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bấm nút + để thêm lô hàng đầu tiên',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await provider.loadProductBatches(product.id);
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: batches.length,
        itemBuilder: (context, index) {
          final batch = batches[index];
          return _buildBatchCard(batch, provider);
        },
      ),
    );
  }

  Widget _buildPriceHistoryTab(Product product, ProductProvider provider) {
    // Lấy data và state TRỰC TIẾP từ Provider
    final prices = provider.seasonalPrices;
    final isLoading = provider.isLoading;
    final hasError = provider.hasError;
    final errorMessage = provider.errorMessage;

    if (isLoading) {
      return const Center(child: LoadingWidget());
    }

    if (hasError && errorMessage.isNotEmpty) {
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
            Text(errorMessage, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            CustomButton(
              text: 'Thử lại',
              onPressed: () => provider.loadSeasonalPrices(product.id),
              icon: Icons.refresh,
            ),
          ],
        ),
      );
    }

    if (prices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.trending_up_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Chưa có lịch sử giá',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bấm nút + để thêm mức giá đầu tiên',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await provider.loadSeasonalPrices(product.id);
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: prices.length,
        itemBuilder: (context, index) {
          final price = prices[index];
          return _buildPriceCard(price, provider);
        },
      ),
    );
  }

  Widget _buildStockPriceCard(int stock, double currentPrice) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.inventory_2, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Tồn Kho & Giá Bán',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: stock <= 10 ? Colors.orange[50] : Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: stock <= 10
                            ? Colors.orange[200]!
                            : Colors.blue[200]!,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          stock <= 10 ? Icons.warning : Icons.inventory_2,
                          color: stock <= 10
                              ? Colors.orange[700]
                              : Colors.blue[700],
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$stock',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: stock <= 10
                                ? Colors.orange[700]
                                : Colors.blue[700],
                          ),
                        ),
                        Text(
                          'Tồn kho',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.attach_money,
                          color: Colors.green[700],
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currentPrice > 0
                              ? _formatCurrency(currentPrice)
                              : 'N/A',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                        Text(
                          'Giá hiện tại',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
              if (attrs.nitrogen != null)
                _buildInfoRow('Nitơ (N)', '${attrs.nitrogen}%'),
              if (attrs.phosphorus != null)
                _buildInfoRow('Phốt pho (P)', '${attrs.phosphorus}%'),
              if (attrs.potassium != null)
                _buildInfoRow('Kali (K)', '${attrs.potassium}%'),
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
              if (attrs.targetPests.isNotEmpty)
                _buildInfoRow(
                  'Đối tượng sử dụng',
                  attrs.targetPests.join(', '),
                ),
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
              if (attrs.growthPeriod != null)
                _buildInfoRow('Thời gian sinh trưởng', attrs.growthPeriod!),
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
            Row(
              children: [
                Icon(
                  _getCategoryIcon(product.category),
                  color: _getCategoryColor(product.category),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            attributesWidget,
          ],
        ),
      ),
    );
  }

  Widget _buildBatchCard(ProductBatch batch, ProductProvider provider) {
    final isExpired = batch.isExpired;
    final isExpiringSoon = batch.isExpiringSoon;

    Color statusColor = Colors.green;
    String statusText = 'Tốt';
    IconData statusIcon = Icons.check_circle;

    if (isExpired) {
      statusColor = Colors.red;
      statusText = 'Hết hạn';
      statusIcon = Icons.error;
    } else if (isExpiringSoon) {
      statusColor = Colors.orange;
      statusText = 'Sắp hết hạn';
      statusIcon = Icons.warning;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Lô: ${batch.batchNumber}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildBatchInfo('Số lượng', '${batch.quantity}')),
                Expanded(child: _buildBatchInfo('Giá nhập', _formatCurrency(batch.costPrice))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildBatchInfo('Ngày nhập', _formatDate(batch.receivedDate))),
                if (batch.expiryDate != null)
                  Expanded(child: _buildBatchInfo('Hạn sử dụng', _formatDate(batch.expiryDate!))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.blue[700]),
                  // Vô hiệu hóa nút khi đang loading để tránh bấm nhiều lần
                  onPressed: provider.isLoading
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditBatchScreen(batch: batch),
                            ),
                          );
                        },
                  tooltip: 'Chỉnh sửa lô hàng',
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red[700]),
                  onPressed: provider.isLoading
                      ? null
                      : () {
                          _showDeleteBatchConfirmation(context, provider, batch);
                        },
                  tooltip: 'Xóa lô hàng',
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPriceCard(SeasonalPrice price, ProductProvider provider) {
    final isCurrentlyActive = price.isCurrentlyActive;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCurrentlyActive ? Icons.check_circle : Icons.circle_outlined,
                  color: isCurrentlyActive ? Colors.green : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _formatCurrency(price.sellingPrice),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const Spacer(),
                if (isCurrentlyActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Đang áp dụng',
                      style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              price.seasonName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildBatchInfo('Từ ngày', _formatDate(price.startDate))),
                Expanded(child: _buildBatchInfo('Đến ngày', _formatDate(price.endDate))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.blue[700]),
                  onPressed: provider.isLoading
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditSeasonalPriceScreen(price: price),
                            ),
                          );
                        },
                  tooltip: 'Chỉnh sửa giá',
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red[700]),
                  onPressed: provider.isLoading
                      ? null
                      : () {
                          _showDeletePriceConfirmation(context, provider, price);
                        },
                  tooltip: 'Xóa giá',
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isWarning = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: isWarning ? Colors.red[600] : Colors.grey[800],
                fontWeight: isWarning ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
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

  String _formatCurrency(double amount) {
    return '${amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}đ';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showDeleteBatchConfirmation(
    BuildContext context,
    ProductProvider provider,
    ProductBatch batch,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận xóa lô hàng'),
        content: Text('Bạn có chắc muốn xóa lô hàng "${batch.batchNumber}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final success = await provider.deleteProductBatch(batch.id, batch.productId);
              if (!mounted) return;
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Xóa lô hàng thành công'), backgroundColor: Colors.green),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Lỗi: ${provider.errorMessage}'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  void _showDeletePriceConfirmation(
    BuildContext context,
    ProductProvider provider,
    SeasonalPrice price,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận xóa mức giá'),
        content: Text('Bạn có chắc muốn xóa mức giá "${price.seasonName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final success = await provider.deleteSeasonalPrice(price.id, price.productId);
              if (!mounted) return;
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Xóa giá thành công'), backgroundColor: Colors.green),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Lỗi: ${provider.errorMessage}'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
}
