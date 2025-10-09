import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../../../shared/utils/formatter.dart';
import '../../../../shared/utils/input_formatters.dart';
import '../../../../shared/utils/responsive.dart';
import '../../models/product.dart';
import '../../providers/product_provider.dart';
import '../../widgets/key_metrics_widget.dart';
import '../../widgets/quick_actions_widget.dart';
import '../../widgets/inventory_batches_widget.dart';
import '../../widgets/price_history_widget.dart';
import 'edit_product_screen.dart';
import 'inventory_history_screen.dart';
import 'price_history_screen.dart';
import 'batch_detail_screen.dart';
import '../../../../shared/widgets/loading_widget.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  bool _isLoading = true;
  bool _isEditMode = false;
  double _totalStock = 0;
  double _averageCostPrice = 0;
  double _grossProfitPercentage = 0;
  List<PriceHistoryItem> _priceHistory = [];

  // Edit mode controllers
  final TextEditingController _priceController = TextEditingController();
  double _originalPrice = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    final provider = context.read<ProductProvider>();
    final product = provider.selectedProduct;
    if (product == null) return;

    setState(() => _isLoading = true);

    try {
      await provider.loadProductBatches(product.id);

      _totalStock = provider.getProductStock(product.id).toDouble();

      // Load dashboard metrics
      _averageCostPrice = await provider.calculateAverageCostPrice(product.id);
      _grossProfitPercentage = await provider.calculateGrossProfitPercentage(product.id);

      // Load price history from service
      _priceHistory = await provider.getPriceHistory(product.id);

      // 🔄 DISABLED: Auto price sync to prevent infinite loops
      // Use manual sync instead: provider.syncProductPriceFromHistory(product.id)
      // await _syncPriceFromHistoryIfNeeded(provider, product);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải dữ liệu dashboard: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _syncPriceFromHistoryIfNeeded(ProductProvider provider, Product product) async {
    // 🔥 CRITICAL FIX: DISABLE AUTO PRICE SYNC to prevent infinite loops
    // Price sync should be handled by database migration, not by UI screens
    // Commenting out the sync logic to prevent cache invalidation loops
    
    /*
    // Only sync if current selling price is 0 and we have price history
    if (product.currentSellingPrice == 0 && _priceHistory.isNotEmpty) {
      // Get the latest price from history (sorted by date desc in getPriceHistory)
      final latestPrice = _priceHistory.first.newPrice;

      if (latestPrice > 0) {
        try {
          // Update the product's current selling price to match latest history
          await provider.updateCurrentSellingPrice(
            product.id,
            latestPrice,
            reason: 'Auto-sync from price history'
          );
        } catch (e) {
          // Don't rethrow - this is a non-critical operation
          // Silent fail for price sync
        }
      }
    }
    */
    
    // Price sync is now handled by database migration sync_prices_from_history.sql
    // No need to do manual sync in UI to prevent cache invalidation loops
    print('🚫 Auto price sync disabled to prevent infinite loops');
  }

  void _enterEditMode() {
    final product = context.read<ProductProvider>().selectedProduct;
    if (product != null) {
      setState(() {
        _isEditMode = true;
        _originalPrice = product.currentSellingPrice;
        _priceController.text = AppFormatter.formatNumber(product.currentSellingPrice);
      });
    }
  }

  void _exitEditMode() {
    setState(() {
      _isEditMode = false;
      _priceController.clear();
    });
  }

  Future<void> _savePrice() async {
    final newPrice = InputFormatterHelper.extractNumber(_priceController.text);
    if (newPrice == null || newPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Giá bán phải là số dương'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final provider = context.read<ProductProvider>();
      final product = provider.selectedProduct;
      if (product != null) {
        final success = await provider.updateCurrentSellingPrice(
          product.id,
          newPrice,
          reason: 'Cập nhật từ giao diện quản lý sản phẩm',
        );

        if (success) {
          _exitEditMode();
          _loadDashboardData();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cập nhật giá bán thành công'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(provider.errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildInventoryExpansionTile() {
    return Consumer<ProductProvider>(
      builder: (context, provider, child) {
        final batches = provider.productBatches;
        final totalBatches = batches.length;
        final activeBatches = batches.where((b) => b.quantity > 0).length;
        final totalStock = batches.fold<int>(0, (sum, batch) => sum + batch.quantity);

        return Card(
          margin: EdgeInsets.zero,
          child: ExpansionTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.green[600]!.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.inventory_2,
                color: Colors.green[600],
                size: 20,
              ),
            ),
            title: Text(
              'Lịch Sử Nhập Hàng',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
            subtitle: Text(
              '$totalBatches lô | Tổng: $totalStock đơn vị',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (activeBatches > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$activeBatches còn hàng',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                const Icon(Icons.expand_more),
              ],
            ),
            children: [
              if (batches.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Chưa có lô hàng nào',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else ...[
                // Show top 3 most recent batches
                ...batches.take(3).map((batch) => _buildBatchPreviewItem(batch)),
                // "View all" button
                ListTile(
                  leading: const Icon(Icons.list, color: Colors.green),
                  title: const Text('Xem tất cả lô hàng'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    final product = provider.selectedProduct;
                    if (product != null) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => InventoryHistoryScreen(product: product),
                        ),
                      );
                    }
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPriceHistoryExpansionTile() {
    final currentPrice = context.watch<ProductProvider>().selectedProduct?.currentSellingPrice ?? 0;

    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        title: Text(
          'Lịch Sử Giá',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.green[700],
          ),
        ),
        subtitle: Text(
          'Hiện tại: ${AppFormatter.formatCompactCurrency(currentPrice)}${_priceHistory.isNotEmpty ? ' • ${_priceHistory.length} thay đổi' : ''}',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 13,
          ),
        ),
        trailing: GestureDetector(
          onTap: () => _navigateToPriceHistory(),
          child: Icon(
            Icons.chevron_right,
            color: Colors.blue[600],
          ),
        ),
        children: [
          if (_priceHistory.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Chưa có thay đổi giá nào',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else ...[
            // Show top 3 most recent price changes
            ..._priceHistory.take(3).map((item) => _buildPriceHistoryItem(item)),
            if (_priceHistory.length > 3) ...[
              Divider(height: 1, color: Colors.grey[300]),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: TextButton.icon(
                    onPressed: _navigateToPriceHistory,
                    icon: const Icon(Icons.history, size: 16),
                    label: Text(
                      'Xem tất cả ${_priceHistory.length} thay đổi',
                      style: const TextStyle(fontSize: 14),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue[600],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildBatchPreviewItem(batch) {
    return ListTile(
      dense: true,
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: _getBatchColor(batch).withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          _getBatchIcon(batch),
          color: _getBatchColor(batch),
          size: 16,
        ),
      ),
      title: Text(
        batch.batchNumber,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        'SL: ${batch.quantity} | Giá vốn: ${AppFormatter.formatCompactCurrency(batch.costPrice)}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Text(
        _formatDate(batch.receivedDate),
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey[500],
        ),
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => BatchDetailScreen(batch: batch),
          ),
        );
      },
    );
  }

  Widget _buildPriceHistoryItem(PriceHistoryItem item) {
    final isIncrease = item.oldPrice != null && item.newPrice > item.oldPrice!;
    final isDecrease = item.oldPrice != null && item.newPrice < item.oldPrice!;

    // User-friendly reason mapping
    String displayReason = _getDisplayReason(item.reason);

    // Calculate change amount for visual indicator
    String? changeIndicator;
    Color? changeColor;
    if (item.oldPrice != null) {
      final change = item.newPrice - item.oldPrice!;
      if (change > 0) {
        changeIndicator = '↑ ${AppFormatter.formatCompactCurrency(change)}';
        changeColor = Colors.green[600];
      } else if (change < 0) {
        changeIndicator = '↓ ${AppFormatter.formatCompactCurrency(change.abs())}';
        changeColor = Colors.red[600];
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      AppFormatter.formatCompactCurrency(item.newPrice),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (changeIndicator != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: changeColor!.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          changeIndicator,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: changeColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  displayReason,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            _formatDate(item.changedAt),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  String _getDisplayReason(String? reason) {
    if (reason == null || reason.isEmpty) return 'Cập nhật giá';

    final lowerReason = reason.toLowerCase();

    // Map developer language to user-friendly language
    if (lowerReason.contains('auto-sync') || lowerReason.contains('price history')) {
      return 'Đồng bộ từ lịch sử giá';
    }
    if (lowerReason.contains('manual') || lowerReason.contains('giao diện quản lý')) {
      return 'Điều chỉnh thủ công';
    }
    if (lowerReason.contains('batch') || lowerReason.contains('lô')) {
      // Extract batch number if possible
      final batchMatch = RegExp(r'LOT[A-Z0-9]+', caseSensitive: false).firstMatch(reason);
      if (batchMatch != null) {
        return 'Từ Lô hàng ${batchMatch.group(0)}';
      }
      return 'Cập nhật từ lô hàng';
    }
    if (lowerReason.contains('khuyến mãi') || lowerReason.contains('promotion')) {
      return 'Áp dụng khuyến mãi';
    }
    if (lowerReason.contains('import') || lowerReason.contains('nhập')) {
      return 'Cập nhật khi nhập hàng';
    }

    // For other cases, return original but clean it up
    return reason.length > 30 ? '${reason.substring(0, 30)}...' : reason;
  }

  void _navigateToPriceHistory() {
    final product = context.read<ProductProvider>().selectedProduct;
    if (product == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PriceHistoryScreen(product: product),
      ),
    );
  }

  Color _getBatchColor(batch) {
    if (batch.quantity <= 0) return Colors.red[600]!;
    if (batch.isExpired) return Colors.red[600]!;
    if (batch.isExpiringSoon) return Colors.orange[600]!;
    if (batch.quantity <= 10) return Colors.orange[600]!;
    return Colors.green[600]!;
  }

  IconData _getBatchIcon(batch) {
    if (batch.quantity <= 0) return Icons.error;
    if (batch.isExpired) return Icons.event_busy;
    if (batch.isExpiringSoon || batch.quantity <= 10) return Icons.warning;
    return Icons.check_circle;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final product = context.watch<ProductProvider>().selectedProduct;
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive: Desktop layout only for wide screens (web or large tablets)
    final useDesktopLayout = screenWidth >= 1024;
    
    if (product == null) {
      return useDesktopLayout 
          ? _buildDesktopNotFound() 
          : _buildMobileNotFound();
    }

    if (_isLoading) {
      return useDesktopLayout 
          ? _buildDesktopLoading(product) 
          : _buildMobileLoading(product);
    }

    return useDesktopLayout 
        ? _buildDesktopLayout(product) 
        : _buildMobileLayout(product);
  }

  // Mobile layout (traditional single column)
  Widget _buildMobileLayout(Product product) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Text(
            product.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: _buildAppBarActions(product),
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: _buildMainContent(product),
        ),
      ),
    );
  }

  // Tablet layout (optimized spacing)
  Widget _buildTabletLayout(Product product) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          product.name,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: _buildAppBarActions(product),
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              child: _buildMainContent(product),
            ),
          ),
        ),
      ),
    );
  }

  // Desktop layout (optimized two-column with proper spacing)
  Widget _buildDesktopLayout(Product product) {
    return Scaffold(
      backgroundColor: Colors.grey[100], // Light background for better separation
      body: Column(
        children: [
          // Desktop header toolbar
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 24),
                Expanded(
                  child: Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ..._buildDesktopAppBarActions(product),
                const SizedBox(width: 24),
              ],
            ),
          ),
          // Main content area with proper layout
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 1400),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top section: Key Metrics (full width)
                        KeyMetricsWidget(
                          product: product,
                          totalStock: _totalStock,
                          averageCostPrice: _averageCostPrice,
                          grossProfitPercentage: _grossProfitPercentage,
                          isEditMode: _isEditMode,
                          priceController: _priceController,
                          onPriceTap: _enterEditMode,
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Bottom section: Two-column layout (responsive)
                        LayoutBuilder(
                          builder: (context, constraints) {
                            // If too narrow, stack vertically instead of horizontal
                            final isTooNarrow = constraints.maxWidth < 800;
                            
                            if (isTooNarrow) {
                              return Column(
                                children: [
                                  QuickActionsWidget(
                                    product: product,
                                    onBatchAdded: _loadDashboardData,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildInventoryExpansionTile(),
                                  const SizedBox(height: 16),
                                  _buildPriceHistoryExpansionTile(),
                                ],
                              );
                            }
                            
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left column: Inventory & History (wider)
                                Expanded(
                                  flex: 6,
                                  child: Column(
                                    children: [
                                      _buildInventoryExpansionTile(),
                                      const SizedBox(height: 16),
                                      _buildPriceHistoryExpansionTile(),
                                    ],
                                  ),
                                ),
                                
                                const SizedBox(width: 24),
                                
                                // Right column: Quick Actions (narrower, flexible)
                                Expanded(
                                  flex: 4,
                                  child: QuickActionsWidget(
                                    product: product,
                                    onBatchAdded: _loadDashboardData,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDesktopAppBarActions(Product product) {
    if (_isEditMode) {
      return [
        TextButton(
          onPressed: _exitEditMode,
          child: const Text(
            'Hủy',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        TextButton(
          onPressed: _savePrice,
          child: const Text(
            'Xong',
            style: TextStyle(
              color: Colors.green,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ];
    } else {
      return [
        IconButton(
          icon: const Icon(Icons.settings, size: 24, color: Colors.grey),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => EditProductScreen(product: product),
              ),
            );
          },
          tooltip: 'Cài đặt sản phẩm',
        ),
        IconButton(
          icon: const Icon(Icons.edit, size: 24, color: Colors.green),
          onPressed: _enterEditMode,
          tooltip: 'Chỉnh sửa giá bán',
        ),
      ];
    }
  }

  // Shared content builder
  Widget _buildMainContent(Product product) {
    return Column(
      children: [
        KeyMetricsWidget(
          product: product,
          totalStock: _totalStock,
          averageCostPrice: _averageCostPrice,
          grossProfitPercentage: _grossProfitPercentage,
          isEditMode: _isEditMode,
          priceController: _priceController,
          onPriceTap: _enterEditMode,
        ),
        const SizedBox(height: 16),
        QuickActionsWidget(
          product: product,
          onBatchAdded: _loadDashboardData,
        ),
        const SizedBox(height: 16),
        _buildInventoryExpansionTile(),
        const SizedBox(height: 16),
        _buildPriceHistoryExpansionTile(),
        const SizedBox(height: 16),
      ],
    );
  }

  // Shared AppBar actions
  List<Widget> _buildAppBarActions(Product product) {
    if (_isEditMode) {
      return [
        TextButton(
          onPressed: _exitEditMode,
          child: const Text(
            'Hủy',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        TextButton(
          onPressed: _savePrice,
          child: const Text(
            'Xong',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ];
    } else {
      return [
        IconButton(
          icon: const Icon(Icons.settings, size: 24),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => EditProductScreen(product: product),
              ),
            );
          },
          tooltip: 'Cài đặt sản phẩm',
        ),
        IconButton(
          icon: const Icon(Icons.edit, size: 24),
          onPressed: _enterEditMode,
          tooltip: 'Chỉnh sửa giá bán',
        ),
      ];
    }
  }

  // Error state layouts
  Widget _buildMobileNotFound() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi Tiết Sản Phẩm'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: const Center(child: Text('Không tìm thấy sản phẩm')),
    );
  }

  Widget _buildTabletNotFound() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi Tiết Sản Phẩm'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: context.contentWidth),
          padding: EdgeInsets.all(context.sectionPadding),
          child: const Text(
            'Không tìm thấy sản phẩm',
            style: TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopNotFound() {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Row(
              children: [
                SizedBox(width: 24),
                Text(
                  'Chi Tiết Sản Phẩm',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Không tìm thấy sản phẩm',
                style: TextStyle(fontSize: 20, color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Loading state layouts
  Widget _buildMobileLoading(Product product) {
    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: const Center(child: LoadingWidget()),
    );
  }

  Widget _buildTabletLoading(Product product) {
    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: context.contentWidth),
          child: const LoadingWidget(),
        ),
      ),
    );
  }

  Widget _buildDesktopLoading(Product product) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 24),
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const Expanded(
            child: Center(child: LoadingWidget()),
          ),
        ],
      ),
    );
  }
}