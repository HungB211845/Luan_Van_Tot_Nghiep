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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/product_batch.dart';
import '../../providers/product_provider.dart';
import '../../providers/company_provider.dart';
import '../../models/company.dart';
import '../../../../shared/utils/formatter.dart';
import '../../../../shared/widgets/loading_widget.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final productProvider = context.read<ProductProvider>();
      await productProvider.resetBatchesPagination(productId: widget.productId, pageSize: 20);
      await productProvider.loadProductBatchesPaginated(productId: widget.productId, pageSize: 20);
      // NCC for filter
      await context.read<CompanyProvider>().loadCompanies();
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

  @override
  Widget build(BuildContext context) {
    final title = widget.title ?? 'Lịch sử Lô hàng';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Consumer2<ProductProvider, CompanyProvider>(
        builder: (context, productProvider, companyProvider, child) {
          if (productProvider.isLoading && productProvider.productBatches.isEmpty) {
            return const Center(child: LoadingWidget());
          }

          final filtered = _applyFilters(productProvider.productBatches);
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
                  onRefresh: () async {
                    await productProvider.resetBatchesPagination(productId: widget.productId, pageSize: 20);
                    await productProvider.loadProductBatchesPaginated(productId: widget.productId, pageSize: 20);
                  },
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

  List<ProductBatch> _applyFilters(List<ProductBatch> batches) {
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

    var results = batches;

    // Supplier filter
    if (_supplierFilters.isNotEmpty) {
      results = results.where((b) => b.supplierId != null && _supplierFilters.contains(b.supplierId)).toList();
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

    // local date range filter via quick chips & pickers
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

    // Expiry status filter
    if (_showExpired || _showNonExpired) {
      final today = DateTime.now();
      results = results.where((b) {
        final isExpired = (b.expiryDate != null) && !b.expiryDate!.isAfter(DateTime(today.year, today.month, today.day));
        final isNonExpired = (b.expiryDate == null) || b.expiryDate!.isAfter(DateTime(today.year, today.month, today.day));
        if (_showExpired && _showNonExpired) return true; // both selected => no filter
        if (_showExpired) return isExpired;
        if (_showNonExpired) return isNonExpired;
        return true;
      }).toList();
    }

    // Cost range filters
    if (_minCost != null) {
      results = results.where((b) => (b.costPrice ?? 0) >= _minCost!).toList();
    }
    if (_maxCost != null) {
      results = results.where((b) => (b.costPrice ?? 0) <= _maxCost!).toList();
    }

    // Ensure newest first
    results.sort((a, b) => b.receivedDate.compareTo(a.receivedDate));
    return results;
  }

  Widget _buildBatchCard(BuildContext context, ProductBatch batch) {
    final companyProvider = context.watch<CompanyProvider>();
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
          ],
        ),
      ),
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
