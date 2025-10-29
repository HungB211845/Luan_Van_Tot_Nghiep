/// BatchHistoryScreen
/// ---------------------------------------------
/// Mục đích: Màn hình tái sử dụng để hiển thị lịch sử Lô hàng (product_batches)
/// cho 1 sản phẩm (productId) với đầy đủ tính năng lọc, tìm kiếm, phân trang,
/// nhóm theo ngày giống như PO History.
///
/// Yêu cầu wiring trong MultiProvider (ở cấp app):
/// - ProductProvider: quản lý batches + phân trang
///   + Các hàm được dùng:
///     - resetBatchesPagination({required String productId, int pageSize = 20})
///     - loadProductBatchesPaginated({required String productId, int pageSize = 20})
///     - loadMoreBatches(String productId)
///     - hasMoreBatches (getter)
///     - productBatches (getter)
/// - CompanyProvider: để hiển thị FilterChip theo Nhà cung cấp
///   + Các hàm được dùng:
///     - loadCompanies()
///     - companies (getter)
///
/// Services tương ứng:
/// - ProductService.getProductBatchesPaginated(...) (đã trả newest first)
///
/// State cục bộ của màn hình này:
/// - Tìm kiếm theo ngày (dd/mm/yyyy | dd.mm.yyyy | dd-mm-yyyy) hoặc theo mã lô
/// - Quick chips: Hôm nay / 7 ngày / 30 ngày / Xóa ngày
/// - Bộ lọc khoảng ngày cụ thể (DatePicker From/To)
/// - Bộ lọc khoảng giá nhập (min/max)
/// - Lọc theo NCC (FilterChip)
/// - Lọc theo trạng thái hạn dùng: Còn hạn / Đã hết hạn
/// - Phân trang: 20/lần, load-more khi kéo gần cuối
/// - Nhóm header theo ngày + hiển thị tổng số lô của ngày đó
/// - Long-press copy mã lô
///
/// Ví dụ wiring MultiProvider (app_providers.dart):
/// ```dart
/// return MultiProvider(
///   providers: [
///     ChangeNotifierProvider(create: (_) => ProductProvider()),
///     ChangeNotifierProvider(create: (_) => CompanyProvider()),
///     ChangeNotifierProvider(create: (_) => PurchaseOrderProvider(ProductProvider())), // nếu cần dùng chung
///   ],
///   child: const AppWidget(),
/// );
/// ```
///
/// Ví dụ điều hướng mở màn hình:
/// ```dart
/// Navigator.of(context).push(
///   MaterialPageRoute(
///     builder: (_) => BatchHistoryScreen(
///       productId: product.id,
///       title: 'Lịch sử Lô hàng',
///     ),
///   ),
/// );
/// ```

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../models/product_batch.dart';
import '../../models/product_unit.dart';
import '../../providers/product_provider.dart';
import '../../providers/company_provider.dart';
import '../../models/company.dart';
import '../../../../shared/utils/formatter.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/services/base_service.dart';
import '../../notification/providers/notification_provider.dart';
import '../../notification/utils/inventory_threshold_helper.dart';
import 'batch_detail_screen.dart';

class BatchHistoryScreen extends StatefulWidget {
  final String productId;
  final String? title;

  const BatchHistoryScreen({super.key, required this.productId, this.title});

  @override
  State<BatchHistoryScreen> createState() => _BatchHistoryScreenState();
}

class _BatchHistoryScreenState extends State<BatchHistoryScreen> {
  // Search & filters
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  DateTime? _fromDate;
  DateTime? _toDate;
  final Set<String> _supplierFilters = {};
  bool _showNonExpired = false;
  bool _showExpired = false;
  double? _minCost;
  double? _maxCost;
  String _selectedFilter = 'all';
  Product? _product;
  List<ProductUnit> _productUnits = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeProductContext();
      // NCC for filter
      await context.read<CompanyProvider>().loadCompanies();
      await _reloadBatches();
    });

    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() {});
    });
  }

  void _onScroll() {
    final provider = context.read<ProductProvider>();
    if (provider.hasMoreBatches &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      provider.loadMoreBatches(widget.productId);
    }
  }

  Future<void> _initializeProductContext() async {
    try {
      final productProvider = context.read<ProductProvider>();
      final Product? product =
          await productProvider.fetchProductById(widget.productId);
      final List<ProductUnit> units =
          await productProvider.getProductUnits(widget.productId);

      if (!mounted) return;

      _product = product;
      _productUnits = units;

      if (product != null && mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('BatchHistoryScreen: failed to init product context: $e');
    }
  }

  Future<void> _reloadBatches() async {
    final productProvider = context.read<ProductProvider>();
    await productProvider.resetBatchesPagination(
      productId: widget.productId,
      pageSize: 20,
    );
    await productProvider.loadProductBatchesPaginated(
      productId: widget.productId,
      pageSize: 20,
    );
    final notificationProvider = context.read<NotificationProvider>();
    await notificationProvider.refresh();
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title ?? 'Lịch sử Lô hàng';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Consumer3<ProductProvider, CompanyProvider, NotificationProvider>(
        builder: (context, productProvider, companyProvider, notificationProvider, child) {
          if (productProvider.isLoading && productProvider.productBatches.isEmpty) {
            return const Center(child: LoadingWidget());
          }

          final filtered = _applyFilters(
            productProvider.productBatches,
            notificationProvider,
          );
          final grouped = _groupByDateWithCount(filtered);
          final showFooter = productProvider.hasMoreBatches;

          return Column(
            children: [
              _buildSearchBar(),
              _buildQuickChips(),
              _buildRangePickers(),
              _buildFilterChips(companyProvider),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _reloadBatches,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: grouped.length + (showFooter ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (showFooter && index == grouped.length) {
                        return _buildLoadingFooter();
                      }
                      final item = grouped[index];
                      if (item.isHeader) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 4),
                          child: Text(
                            '${item.headerText!}  •  ${item.count ?? 0} lô',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
                          ),
                        );
                      }
                      return _buildBatchCard(context, item.batch!);
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Tìm theo ngày (dd/mm/yyyy) hoặc mã lô...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey[200],
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildQuickChips() {
    final hasDateFilter = _fromDate != null || _toDate != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          ActionChip(
            label: const Text('Hôm nay'),
            onPressed: () {
              final now = DateTime.now();
              setState(() {
                _fromDate = DateTime(now.year, now.month, now.day);
                _toDate = DateTime(now.year, now.month, now.day);
              });
            },
          ),
          const SizedBox(width: 8),
          ActionChip(
            label: const Text('7 ngày'),
            onPressed: () {
              final now = DateTime.now();
              setState(() {
                _fromDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
                _toDate = DateTime(now.year, now.month, now.day);
              });
            },
          ),
          const SizedBox(width: 8),
          ActionChip(
            label: const Text('30 ngày'),
            onPressed: () {
              final now = DateTime.now();
              setState(() {
                _fromDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
                _toDate = DateTime(now.year, now.month, now.day);
              });
            },
          ),
          const SizedBox(width: 8),
          if (hasDateFilter)
            ActionChip(
              avatar: const Icon(Icons.clear, size: 16),
              label: const Text('Xóa ngày'),
              onPressed: () {
                setState(() {
                  _fromDate = null;
                  _toDate = null;
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRangePickers() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(_fromDate == null ? 'Từ ngày' : AppFormatter.formatDate(_fromDate!)),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _fromDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _fromDate = picked);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(_toDate == null ? 'Đến ngày' : AppFormatter.formatDate(_toDate!)),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _toDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _toDate = picked);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Giá nhập tối thiểu',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    setState(() => _minCost = double.tryParse(val.replaceAll(',', '')));
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Giá nhập tối đa',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    setState(() => _maxCost = double.tryParse(val.replaceAll(',', '')));
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(CompanyProvider companyProvider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: -8,
            children: [
              FilterChip(
                label: const Text('Còn hạn'),
                selected: _showNonExpired,
                onSelected: (val) => setState(() => _showNonExpired = val),
              ),
              FilterChip(
                label: const Text('Đã hết hạn'),
                selected: _showExpired,
                onSelected: (val) => setState(() => _showExpired = val),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (companyProvider.companies.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: companyProvider.companies.map((c) {
                  final selected = _supplierFilters.contains(c.id);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(c.name),
                      selected: selected,
                      onSelected: (val) => setState(() {
                        if (val) {
                          _supplierFilters.add(c.id);
                        } else {
                          _supplierFilters.remove(c.id);
                        }
                      }),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  List<_GroupedItem> _groupByDateWithCount(List<ProductBatch> batches) {
    final List<_GroupedItem> result = [];
    String? currentDateStr;
    int currentCount = 0;
    void pushHeader() {
      if (currentDateStr != null) {
        result.add(_GroupedItem.header(currentDateStr!, currentCount));
        currentCount = 0;
      }
    }
    for (final b in batches) {
      final ds = AppFormatter.formatDate(b.receivedDate);
      if (currentDateStr != ds) {
        pushHeader();
        currentDateStr = ds;
      }
      result.add(_GroupedItem.item(b));
      currentCount += 1;
    }
    pushHeader();
    return result;
  }

  List<ProductBatch> _applyFilters(
    List<ProductBatch> batches,
    NotificationProvider notificationProvider,
  ) {
    final notifications = notificationProvider.notifications;
    final q = _searchController.text.trim().toLowerCase();
    DateTime? dateQuery;
    if (q.isNotEmpty) {
      final reg = RegExp(r'^(\d{1,2})[\/\.\-](\d{1,2})[\/\.\-](\d{4})$');
      final m = reg.firstMatch(q);
      if (m != null) {
        final d = int.tryParse(m.group(1)!);
        final mo = int.tryParse(m.group(2)!);
        final y = int.tryParse(m.group(3)!);
        if (d != null && mo != null && y != null) {
          dateQuery = DateTime(y, mo, d);
        }
      }
    }

    final relevantNotifications = notifications
        .where((n) => n.productId == widget.productId)
        .toList();

    final expiryNotifications = relevantNotifications.where((n) {
      if (n.topic == NotificationTopic.batchExpiry) return true;
      return n.expiryDays != null;
    }).toList();

    final lowStockNotifications = relevantNotifications.where((n) {
      if (n.topic == NotificationTopic.batchLowStock) return true;
      return n.topic == NotificationTopic.general &&
          n.id.startsWith('lowstock-batch-');
    }).toList();

    final Map<String, int> expiryDaysMap = {
      for (final n in expiryNotifications)
        if (n.batchNumber != null && n.expiryDays != null)
          n.batchNumber!: n.expiryDays!,
    };

    final Set<String> expiringBatchNumbers = expiryNotifications
        .where((n) => (n.expiryDays ?? 0) >= 0 && n.batchNumber != null)
        .map((n) => n.batchNumber!)
        .toSet();
    final Set<String> expiredBatchNumbers = expiryNotifications
        .where((n) => (n.expiryDays ?? 0) < 0 && n.batchNumber != null)
        .map((n) => n.batchNumber!)
        .toSet();
    final Set<String> lowStockBatchIds = {
      for (final n in lowStockNotifications)
        if (n.batchId != null) n.batchId!,
    };
    final Set<String> lowStockBatchNumbers = {
      for (final n in lowStockNotifications)
        if (n.batchNumber != null) n.batchNumber!,
    };

    final now = DateTime.now();

    bool isExpiringSoon(ProductBatch batch) {
      if (expiringBatchNumbers.contains(batch.batchNumber)) return true;
      if (batch.expiryDate == null) return false;
      final diff = batch.expiryDate!.difference(now).inDays;
      return diff >= 0 && diff <= 90;
    }

    var results = batches;

    if (_supplierFilters.isNotEmpty) {
      results = results
          .where((b) => b.supplierId != null && _supplierFilters.contains(b.supplierId))
          .toList();
    }

    if (dateQuery != null) {
      results = results.where((b) {
        final bd = DateTime(b.receivedDate.year, b.receivedDate.month, b.receivedDate.day);
        final dq = DateTime(dateQuery!.year, dateQuery!.month, dateQuery!.day);
        return bd == dq;
      }).toList();
    }

    if (q.isNotEmpty && dateQuery == null) {
      results = results
          .where((b) => (b.batchNumber ?? '').toLowerCase().contains(q))
          .toList();
    }

    if (_fromDate != null) {
      final start = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
      results = results.where((b) {
        final bd = DateTime(b.receivedDate.year, b.receivedDate.month, b.receivedDate.day);
        return bd.isAtSameMomentAs(start) || bd.isAfter(start);
      }).toList();
    }
    if (_toDate != null) {
      final end = DateTime(_toDate!.year, _toDate!.month, _toDate!.day);
      results = results.where((b) {
        final bd = DateTime(b.receivedDate.year, b.receivedDate.month, b.receivedDate.day);
        return bd.isAtSameMomentAs(end) || bd.isBefore(end);
      }).toList();
    }

    if (_showExpired || _showNonExpired) {
      results = results.where((b) {
        final isExpired = expiredBatchNumbers.contains(b.batchNumber) || b.isExpired;
        final isNonExpired = !isExpired;
        if (_showExpired && _showNonExpired) return true;
        if (_showExpired) return isExpired;
        if (_showNonExpired) return isNonExpired;
        return true;
      }).toList();
    }

    if (_minCost != null) {
      results = results.where((b) => (b.costPrice ?? 0) >= _minCost!).toList();
    }
    if (_maxCost != null) {
      results = results.where((b) => (b.costPrice ?? 0) <= _maxCost!).toList();
    }

    final lowStockThreshold = _product != null
        ? notificationProvider.resolveLowStockThreshold(
            product: _product!,
            units: _productUnits,
          )
        : 10;

    switch (_selectedFilter) {
      case 'active':
        results = results.where((b) => b.quantity > 0 && !b.isExpired).toList();
        break;
      case 'low_stock':
        results = results.where((b) {
          final quantity = b.quantity.toDouble();
          final matchesNotification =
              lowStockBatchIds.contains(b.id) ||
                  lowStockBatchNumbers.contains(b.batchNumber);

          if (quantity <= 0) {
            return false;
          }

          if (matchesNotification) {
            return true;
          }

          return quantity <= lowStockThreshold;
        }).toList();
        break;
      case 'out_of_stock':
        results = results.where((b) => b.quantity <= 0).toList();
        break;
      case 'expiring':
        results = results.where((b) => isExpiringSoon(b) && !b.isExpired).toList();
        break;
      case 'expired':
        results = results
            .where((b) => b.isExpired || expiredBatchNumbers.contains(b.batchNumber))
            .toList();
        break;
      default:
        break;
    }

    if (_selectedFilter == 'expiring' || _selectedFilter == 'expired') {
      results.sort((a, b) {
        final da = expiryDaysMap[a.batchNumber] ??
            (a.expiryDate != null ? a.expiryDate!.difference(now).inDays : 9999);
        final db = expiryDaysMap[b.batchNumber] ??
            (b.expiryDate != null ? b.expiryDate!.difference(now).inDays : 9999);
        return da.compareTo(db);
      });
    } else {
      results.sort((a, b) => b.receivedDate.compareTo(a.receivedDate));
    }

    return results;
  }

  Widget _buildBatchCard(BuildContext context, ProductBatch batch) {
    final companyProvider = context.watch<CompanyProvider>();
    final supplier = companyProvider.companies.firstWhere(
      (c) => c.id == batch.supplierId,
      orElse: () => Company(id: '', name: 'Không xác định', createdAt: DateTime.now(), updatedAt: DateTime.now(), storeId: BaseService.getDefaultStoreId()),
    );

    final quantityLabel = _formatBatchQuantity(batch);
    final costLabel = _formatUnitCost(batch);
    final secondaryLabel = _formatSecondaryInfo(batch);
    final statusColor = _getChipColor(batch);

    return InkWell(
      onTap: () async {
        final updated = await Navigator.of(context).push<ProductBatch>(
          MaterialPageRoute(
            builder: (context) => BatchDetailScreen(batch: batch),
          ),
        );

        if (updated != null && mounted) {
          await _reloadBatches();
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onLongPress: () async {
                        final text = batch.batchNumber ?? '';
                        if (text.isNotEmpty) {
                          await Clipboard.setData(ClipboardData(text: text));
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Đã sao chép mã Lô: $text')),
                            );
                          }
                        }
                      },
                      child: Text(
                        _shortenBatchCode(batch.batchNumber),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      quantityLabel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                costLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                secondaryLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              if (batch.supplierId != null && supplier.name.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'NCC: ${supplier.name}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _shortenBatchCode(String? code) {
    if (code == null || code.isEmpty) return 'Không rõ mã';
    if (code.length <= 12) return code;
    final prefix = code.substring(0, 4);
    final suffix = code.substring(code.length - 4);
    return '$prefix...$suffix';
  }

  String _formatUnitCost(ProductBatch batch) {
    final units = _productUnits;
    if (units.isEmpty) {
      return 'Giá vốn: ${AppFormatter.formatCurrencyWithSymbol(batch.costPrice, symbol: 'đ')}/${_product?.unit.toLowerCase() ?? 'đơn vị'}';
    }

    final defaultUnit = UnitDisplayFormatter.defaultUnit(units) ?? units.first;
    final unitLabel = UnitDisplayFormatter.simpleUnitName(defaultUnit).toLowerCase();
    final costPerDefault = batch.costPrice * (defaultUnit.conversionFactor <= 0 ? 1 : defaultUnit.conversionFactor);

    return 'Giá vốn: ${AppFormatter.formatCurrencyWithSymbol(costPerDefault, symbol: 'đ')}/$unitLabel';
  }

  String _formatSecondaryInfo(ProductBatch batch) {
    final received = AppFormatter.formatDate(batch.receivedDate);
    final expiry = batch.expiryDate != null ? AppFormatter.formatDate(batch.expiryDate!) : null;
    if (expiry == null || expiry.isEmpty) {
      return 'Nhập: $received';
    }
    return 'Nhập: $received • HSD: $expiry';
  }

  Color _getChipColor(ProductBatch batch) {
    if (batch.quantity <= 0) {
      return Colors.red[600]!;
    }
    final notificationProvider = context.read<NotificationProvider>();
    final threshold = (_product != null)
        ? notificationProvider.resolveLowStockThreshold(
            product: _product!,
            units: _productUnits,
          )
        : InventoryThresholdHelper.fallbackThreshold;
    if (batch.quantity.toDouble() <= threshold) {
      return Colors.orange[600]!;
    }
    return Colors.green[600]!;
  }

  Widget _buildLoadingFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 12),
          Text('Đang tải thêm...'),
        ],
      ),
    );
  }
}

class _GroupedItem {
  final bool isHeader;
  final String? headerText;
  final int? count;
  final ProductBatch? batch;

  _GroupedItem._(this.isHeader, this.headerText, this.count, this.batch);
  factory _GroupedItem.header(String text, int count) => _GroupedItem._(true, text, count, null);
  factory _GroupedItem.item(ProductBatch b) => _GroupedItem._(false, null, null, b);
}
