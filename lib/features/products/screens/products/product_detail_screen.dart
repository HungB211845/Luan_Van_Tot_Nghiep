import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../shared/utils/formatter.dart';
import '../../../../shared/utils/input_formatters.dart';
import '../../models/product.dart';
import '../../providers/product_provider.dart';
import '../../widgets/key_metrics_widget.dart';
import '../../widgets/quick_actions_widget.dart';
import '../../widgets/inventory_batches_widget.dart';
import '../../widgets/price_history_widget.dart';
import 'edit_product_screen.dart';
import '../../../../shared/widgets/loading_widget.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({Key? key}) : super(key: key);

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  bool _isLoading = true;
  double _totalStock = 0;
  double _averageCostPrice = 0;
  double _grossProfitPercentage = 0;
  List<PriceHistoryItem> _priceHistory = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
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

      // FIXED: Sync price from history if current price is 0
      await _syncPriceFromHistoryIfNeeded(provider, product);

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

  /// FIXED: Sync price from price history if current selling price is 0
  Future<void> _syncPriceFromHistoryIfNeeded(ProductProvider provider, Product product) async {
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
            reason: 'Auto-sync from price history on app restart'
          );
          
          // Log for debugging (remove in production)
          print('DEBUG: Synced price ${latestPrice} from history for product ${product.name}');
        } catch (e) {
          print('Warning: Failed to sync price from history: $e');
          // Don't rethrow - this is a non-critical operation
        }
      } else {
        print('DEBUG: Latest price in history is 0, skipping sync for ${product.name}');
      }
    }
  }

  void _showEditPriceDialog() {
    final product = context.read<ProductProvider>().selectedProduct;
    if (product == null) return;

    // FIXED: Initialize with formatted price (1.000 instead of 1000)
    final controller = TextEditingController(
      text: AppFormatter.formatNumber(product.currentSellingPrice),
    );
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cập Nhật Giá Bán'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              // FIXED: Use numeric keyboard on mobile devices
              keyboardType: InputFormatterHelper.getNumericKeyboard(allowDecimal: false),
              // FIXED: Add currency input formatter for thousands separator
              inputFormatters: [
                CurrencyInputFormatter(maxValue: 999999999), // Max 999M
              ],
              decoration: const InputDecoration(
                labelText: 'Giá bán mới *',
                suffixText: 'VNĐ',
                border: OutlineInputBorder(),
                helperText: 'Ví dụ: 25.000',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Lý do thay đổi (tùy chọn)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              // FIXED: Extract number from formatted text
              final newPrice = InputFormatterHelper.extractNumber(controller.text);
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
                final reason = reasonController.text.trim().isEmpty
                    ? 'Cập nhật giá từ giao diện quản lý sản phẩm'
                    : reasonController.text.trim();

                final success = await provider.updateCurrentSellingPrice(
                  product.id,
                  newPrice,
                  reason: reason,
                );

                if (context.mounted) {
                  Navigator.pop(context);
                  if (success) {
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
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lỗi: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Cập nhật'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
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

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(product.name),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: LoadingWidget()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(product.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, size: 24),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => EditProductScreen(product: product),
                ),
              );
            },
            tooltip: 'Chỉnh sửa sản phẩm',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 24),
            tooltip: 'Làm mới dữ liệu',
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              KeyMetricsWidget(
                product: product,
                totalStock: _totalStock,
                averageCostPrice: _averageCostPrice,
                grossProfitPercentage: _grossProfitPercentage,
              ),
              const SizedBox(height: 8),
              QuickActionsWidget(
                product: product,
                onBatchAdded: _loadDashboardData,
              ),
              const SizedBox(height: 8),
              Consumer<ProductProvider>(
                builder: (context, provider, child) {
                  return InventoryBatchesWidget(
                    batches: provider.productBatches,
                    onBatchUpdated: _loadDashboardData,
                  );
                },
              ),
              const SizedBox(height: 8),
              PriceHistoryWidget(
                product: product,
                priceHistory: _priceHistory,
                onEditPrice: _showEditPriceDialog,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }


}