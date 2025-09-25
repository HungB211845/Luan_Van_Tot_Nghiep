import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../models/product_batch.dart';
import '../../models/seasonal_price.dart';
import '../../models/purchase_order.dart'; // Thêm import
import '../../models/company.dart'; // Thêm import
import '../../providers/product_provider.dart';
import '../../providers/company_provider.dart'; // Thêm import
import '../../providers/purchase_order_provider.dart'; // Thêm import
import '../../../../shared/utils/formatter.dart'; // Thêm import
import '../../../../core/routing/route_names.dart'; // Thêm import
import '../../../../shared/widgets/loading_widget.dart';
import 'add_batch_screen.dart';
import 'add_seasonal_price_screen.dart';
import 'edit_product_screen.dart';
import 'seasonal_price_list_widget.dart';
import 'edit_batch_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({Key? key}) : super(key: key);

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

// Helper model for grouped list rendering in Inventory tab
class _InvItem {
  final bool isHeader;
  final String? headerText;
  final int? count;
  final ProductBatch? batch;

  _InvItem._(this.isHeader, this.headerText, this.count, this.batch);
  factory _InvItem.header(String text, [int count = 0]) => _InvItem._(true, text, count, null);
  factory _InvItem.item(ProductBatch b) => _InvItem._(false, null, null, b);
}

class _ProductDetailScreenState extends State<ProductDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _invScrollController = ScrollController();
  final TextEditingController _invSearchController = TextEditingController();
  Timer? _invDebounce;
  DateTime? _invFromDate;
  DateTime? _invToDate;
  final Set<String> _invSupplierFilters = {};
  bool _invShowNonExpired = false;
  bool _invShowExpired = false;
  double? _invMinCost;
  double? _invMaxCost;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });

    _invSearchController.addListener(_onInvSearchChanged);
    _invScrollController.addListener(_onInvScroll);
  }

  void _showBatchFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final companyProvider = context.read<CompanyProvider>();
        // Local editable copies
        DateTime? from = _invFromDate;
        DateTime? to = _invToDate;
        bool showNonExpired = _invShowNonExpired;
        bool showExpired = _invShowExpired;
        double? minCost = _invMinCost;
        double? maxCost = _invMaxCost;
        final Set<String> supplierSet = {..._invSupplierFilters};

        final minCtrl = TextEditingController(text: minCost?.toStringAsFixed(0) ?? '');
        final maxCtrl = TextEditingController(text: maxCost?.toStringAsFixed(0) ?? '');

        Future<void> pickFrom() async {
          final picked = await showDatePicker(
            context: ctx,
            initialDate: from ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (picked != null) {
            from = picked;
            // Force rebuild bottom sheet
            (ctx as Element).markNeedsBuild();
          }
        }

        Future<void> pickTo() async {
          final picked = await showDatePicker(
            context: ctx,
            initialDate: to ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (picked != null) {
            to = picked;
            (ctx as Element).markNeedsBuild();
          }
        }

        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Bộ lọc Lô hàng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.date_range, size: 18),
                        label: Text(from == null ? 'Từ ngày' : AppFormatter.formatDate(from!)),
                        onPressed: pickFrom,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.date_range, size: 18),
                        label: Text(to == null ? 'Đến ngày' : AppFormatter.formatDate(to!)),
                        onPressed: pickTo,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: minCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Giá nhập tối thiểu',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: maxCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Giá nhập tối đa',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Trạng thái hạn dùng', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('Còn hạn'),
                      selected: showNonExpired,
                      onSelected: (v) { showNonExpired = v; (ctx as Element).markNeedsBuild(); },
                    ),
                    FilterChip(
                      label: const Text('Đã hết hạn'),
                      selected: showExpired,
                      onSelected: (v) { showExpired = v; (ctx as Element).markNeedsBuild(); },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Lọc theo Nhà cung cấp', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (companyProvider.companies.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: companyProvider.companies.map((c) {
                        final selected = supplierSet.contains(c.id);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            label: Text(c.name),
                            selected: selected,
                            onSelected: (v) {
                              if (v) { supplierSet.add(c.id); } else { supplierSet.remove(c.id); }
                              (ctx as Element).markNeedsBuild();
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _invFromDate = null;
                            _invToDate = null;
                            _invMinCost = null;
                            _invMaxCost = null;
                            _invShowNonExpired = false;
                            _invShowExpired = false;
                            _invSupplierFilters.clear();
                          });
                          Navigator.of(ctx).pop();
                        },
                        child: const Text('Xóa bộ lọc'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _invFromDate = from;
                            _invToDate = to;
                            _invMinCost = double.tryParse(minCtrl.text.replaceAll(',', ''));
                            _invMaxCost = double.tryParse(maxCtrl.text.replaceAll(',', ''));
                            _invShowNonExpired = showNonExpired;
                            _invShowExpired = showExpired;
                            _invSupplierFilters
                              ..clear()
                              ..addAll(supplierSet);
                          });
                          Navigator.of(ctx).pop();
                        },
                        child: const Text('Áp dụng'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInventoryFilterChips() {
    return Consumer<CompanyProvider>(
      builder: (context, companyProvider, _) {
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
                    selected: _invShowNonExpired,
                    onSelected: (val) => setState(() => _invShowNonExpired = val),
                  ),
                  FilterChip(
                    label: const Text('Đã hết hạn'),
                    selected: _invShowExpired,
                    onSelected: (val) => setState(() => _invShowExpired = val),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (companyProvider.companies.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: companyProvider.companies.map((c) {
                      final selected = _invSupplierFilters.contains(c.id);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          label: Text(c.name),
                          selected: selected,
                          onSelected: (val) => setState(() {
                            if (val) {
                              _invSupplierFilters.add(c.id);
                            } else {
                              _invSupplierFilters.remove(c.id);
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
      },
    );
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _invSearchController.removeListener(_onInvSearchChanged);
    _invSearchController.dispose();
    _invDebounce?.cancel();
    _invScrollController.removeListener(_onInvScroll);
    _invScrollController.dispose();
    super.dispose();
  }

  void _loadInitialData() {
    final provider = context.read<ProductProvider>();
    final product = provider.selectedProduct;
    if (product != null) {
      provider.resetBatchesPagination(productId: product.id, pageSize: 20);
      provider.loadProductBatchesPaginated(productId: product.id, pageSize: 20);
    }
    // Ensure companies are loaded for supplier filter chips
    context.read<CompanyProvider>().loadCompanies();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;
    final provider = context.read<ProductProvider>();
    final product = provider.selectedProduct;
    if (product == null) return;

    switch (_tabController.index) {
      case 1:
        provider.resetBatchesPagination(productId: product.id, pageSize: 20);
        provider.loadProductBatchesPaginated(productId: product.id);
        break;
      case 2:
        provider.loadSeasonalPrices(product.id);
        break;
    }
  }

  void _onInvSearchChanged() {
    if (_invDebounce?.isActive ?? false) _invDebounce!.cancel();
    _invDebounce = Timer(const Duration(milliseconds: 400), () {
      setState(() {});
    });
  }

  void _onInvScroll() {
    final provider = context.read<ProductProvider>();
    final product = provider.selectedProduct;
    if (product == null) return;
    if (provider.hasMoreBatches &&
        _invScrollController.position.pixels >=
            _invScrollController.position.maxScrollExtent - 200) {
      provider.loadMoreBatches(product.id);
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
          IconButton(
            icon: const Icon(Icons.refresh, size: 24),
            tooltip: 'Làm mới tồn kho',
            onPressed: () async {
              final provider = context.read<ProductProvider>();
              await provider.refreshAllInventoryData();
              await provider.loadProductBatches(product.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã làm mới tồn kho & lô hàng')),
              );
            },
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
        // Apply local search by date or batch number
        final filtered = _filterBatches(provider.productBatches);
        final grouped = _groupBatchesByDate(filtered);

        final showFooter = provider.hasMoreBatches;

        return Column(
          children: [
            _buildInventorySearchBar(),
            _buildInventoryQuickChips(provider),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await provider.resetBatchesPagination(productId: product.id, pageSize: 20);
                  await provider.loadProductBatchesPaginated(productId: product.id, pageSize: 20);
                },
                child: ListView.builder(
                  controller: _invScrollController,
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
    );
  }

  Widget _buildInventoryRangePickers() {
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
                  label: Text(_invFromDate == null ? 'Từ ngày' : AppFormatter.formatDate(_invFromDate!)),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _invFromDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _invFromDate = picked);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(_invToDate == null ? 'Đến ngày' : AppFormatter.formatDate(_invToDate!)),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _invToDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _invToDate = picked);
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
                    setState(() => _invMinCost = double.tryParse(val.replaceAll(',', '')));
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
                    setState(() => _invMaxCost = double.tryParse(val.replaceAll(',', '')));
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInventorySearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        controller: _invSearchController,
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

  Widget _buildInventoryQuickChips(ProductProvider provider) {
    final hasDateFilter = _invFromDate != null || _invToDate != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
          ActionChip(
            label: const Text('Hôm nay'),
            onPressed: () {
              final now = DateTime.now();
              setState(() {
                _invFromDate = DateTime(now.year, now.month, now.day);
                _invToDate = DateTime(now.year, now.month, now.day);
              });
            },
          ),
          const SizedBox(width: 8),
          ActionChip(
            label: const Text('7 ngày'),
            onPressed: () {
              final now = DateTime.now();
              setState(() {
                _invFromDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
                _invToDate = DateTime(now.year, now.month, now.day);
              });
            },
          ),
          const SizedBox(width: 8),
          ActionChip(
            label: const Text('30 ngày'),
            onPressed: () {
              final now = DateTime.now();
              setState(() {
                _invFromDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
                _invToDate = DateTime(now.year, now.month, now.day);
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
                  _invFromDate = null;
                  _invToDate = null;
                });
              },
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.filter_list),
              tooltip: 'Bộ lọc Lô hàng',
              onPressed: _showBatchFilterSheet,
            ),
          ],
        ),
      ),
    );
  }

  List<_InvItem> _groupBatchesByDate(List<ProductBatch> batches) {
    final List<_InvItem> result = [];
    String? currentDateStr;
    int currentCount = 0;
    void pushHeader() {
      if (currentDateStr != null) {
        result.add(_InvItem.header(currentDateStr!, currentCount));
        currentCount = 0;
      }
    }
    for (final b in batches) {
      final ds = AppFormatter.formatDate(b.receivedDate);
      if (currentDateStr != ds) {
        // push previous header with count
        pushHeader();
        currentDateStr = ds;
      }
      result.add(_InvItem.item(b));
      currentCount += 1;
    }
    // push last header
    pushHeader();
    return result;
  }

  List<ProductBatch> _filterBatches(List<ProductBatch> batches) {
    final q = _invSearchController.text.trim().toLowerCase();
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

    var results = batches;
    // Supplier filter
    if (_invSupplierFilters.isNotEmpty) {
      results = results.where((b) => b.supplierId != null && _invSupplierFilters.contains(b.supplierId)).toList();
    }
    // date exact search
    if (dateQuery != null) {
      results = results.where((b) {
        final bd = DateTime(b.receivedDate.year, b.receivedDate.month, b.receivedDate.day);
        final dq = DateTime(dateQuery!.year, dateQuery!.month, dateQuery!.day);
        return bd == dq;
      }).toList();
    }
    // text search by batch number
    if (q.isNotEmpty && dateQuery == null) {
      results = results.where((b) => (b.batchNumber ?? '').toLowerCase().contains(q)).toList();
    }

    // local date range filter via quick chips
    if (_invFromDate != null) {
      final start = DateTime(_invFromDate!.year, _invFromDate!.month, _invFromDate!.day);
      results = results.where((b) {
        final bd = DateTime(b.receivedDate.year, b.receivedDate.month, b.receivedDate.day);
        return bd.isAtSameMomentAs(start) || bd.isAfter(start);
      }).toList();
    }
    if (_invToDate != null) {
      final end = DateTime(_invToDate!.year, _invToDate!.month, _invToDate!.day);
      results = results.where((b) {
        final bd = DateTime(b.receivedDate.year, b.receivedDate.month, b.receivedDate.day);
        return bd.isAtSameMomentAs(end) || bd.isBefore(end);
      }).toList();
    }

    // Expiry status filter
    if (_invShowExpired || _invShowNonExpired) {
      final today = DateTime.now();
      results = results.where((b) {
        final isExpired = (b.expiryDate != null) && !b.expiryDate!.isAfter(DateTime(today.year, today.month, today.day));
        final isNonExpired = (b.expiryDate == null) || b.expiryDate!.isAfter(DateTime(today.year, today.month, today.day));
        if (_invShowExpired && _invShowNonExpired) return true; // both selected => no filter
        if (_invShowExpired) return isExpired;
        if (_invShowNonExpired) return isNonExpired;
        return true;
      }).toList();
    }

    // Cost range filters
    if (_invMinCost != null) {
      results = results.where((b) => (b.costPrice ?? 0) >= _invMinCost!).toList();
    }
    if (_invMaxCost != null) {
      results = results.where((b) => (b.costPrice ?? 0) <= _invMaxCost!).toList();
    }

    // Ensure newest first (service already orders, but keep here after filtering)
    results.sort((a, b) => b.receivedDate.compareTo(a.receivedDate));
    return results;
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

  Widget _buildPriceHistoryTab(Product product) {
    return const SeasonalPriceList();
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
                      Expanded(child: _buildStatBox('Tồn kho', AppFormatter.formatNumber(stock), Icons.inventory_2, Colors.blue)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildStatBox('Giá hiện tại', AppFormatter.formatCurrency(currentPrice), Icons.attach_money, Colors.green)),
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
    final companyProvider = context.watch<CompanyProvider>();
    final poProvider = context.watch<PurchaseOrderProvider>();

    final supplier = companyProvider.companies.firstWhere(
      (c) => c.id == batch.supplierId,
      orElse: () => Company(id: '', name: 'Không xác định', createdAt: DateTime.now(), updatedAt: DateTime.now()),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
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
              child: Text('Lô: ${batch.batchNumber}', style: Theme.of(context).textTheme.titleMedium),
            ),
            const Divider(),
            _buildInfoRow('Số lượng', AppFormatter.formatNumber(batch.quantity)),
            _buildInfoRow('Giá nhập', AppFormatter.formatCurrency(batch.costPrice)),
            _buildInfoRow('Ngày nhập', AppFormatter.formatDate(batch.receivedDate)),
            if (batch.expiryDate != null) _buildInfoRow('Hạn sử dụng', AppFormatter.formatDate(batch.expiryDate!)),
            if (batch.supplierId != null) _buildInfoRow('Nhà cung cấp', supplier.name),
            if (batch.purchaseOrderId != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.bottomRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.receipt_long, size: 18),
                  label: const Text('Xem Đơn Nhập Gốc'),
                  onPressed: () async {
                    // Load PO details to pass to the screen
                    await poProvider.loadPODetails(batch.purchaseOrderId!);
                    final po = poProvider.selectedPO;
                    if (po != null) {
                      Navigator.of(context).pushNamed(RouteNames.purchaseOrderDetail, arguments: po);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Không tìm thấy đơn nhập gốc'), backgroundColor: Colors.red),
                      );
                    }
                  },
                ),
              ),
            ],
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

}