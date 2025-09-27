import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import '../../../../core/routing/route_names.dart';
import '../../../../shared/utils/formatter.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../models/purchase_order.dart';
import '../../models/purchase_order_status.dart';
import '../../providers/purchase_order_provider.dart';
import '../../providers/company_provider.dart';
import '../../models/company.dart';

class PurchaseOrderListScreen extends StatefulWidget {
  const PurchaseOrderListScreen({Key? key}) : super(key: key);

  @override
  State<PurchaseOrderListScreen> createState() => _PurchaseOrderListScreenState();
}

class _PurchaseOrderListScreenState extends State<PurchaseOrderListScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Initial load using the search pipeline
      context.read<PurchaseOrderProvider>().searchPurchaseOrders();
      // Also load companies for the filter panel
      context.read<CompanyProvider>().loadCompanies();
    });

    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
  }

  Widget _buildQuickChips() {
    final provider = context.watch<PurchaseOrderProvider>();
    final hasDateFilter = provider.fromDate != null || provider.toDate != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          ActionChip(
            label: const Text('Hôm nay'),
            onPressed: () {
              provider.quickToday();
              provider.applyFiltersAndSearch();
            },
          ),
          const SizedBox(width: 8),
          ActionChip(
            label: const Text('7 ngày'),
            onPressed: () {
              provider.quickLast7Days();
              provider.applyFiltersAndSearch();
            },
          ),
          const SizedBox(width: 8),
          ActionChip(
            label: const Text('30 ngày'),
            onPressed: () {
              provider.quickLast30Days();
              provider.applyFiltersAndSearch();
            },
          ),
          const SizedBox(width: 8),
          if (hasDateFilter)
            ActionChip(
              avatar: const Icon(Icons.clear, size: 16),
              label: const Text('Xóa ngày'),
              onPressed: () {
                provider.setDateRange(from: null, to: null);
                provider.applyFiltersAndSearch();
              },
            ),
        ],
      ),
    );
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
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final provider = context.read<PurchaseOrderProvider>();
      provider.setSearchText(_searchController.text);
      provider.applyFiltersAndSearch();
    });
  }

  void _showFilterSortSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => FilterSortSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PurchaseOrderProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử Nhập Hàng'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSortSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildQuickChips(),
          Expanded(child: _buildBody(provider)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).pushNamed(RouteNames.createPurchaseOrder);
        },
        icon: const Icon(Icons.add),
        label: const Text('Tạo Đơn Nhập'),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Tìm theo mã đơn, NCC, sản phẩm...',
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

  Widget _buildBody(PurchaseOrderProvider provider) {
    if (provider.isLoading && provider.visibleOrders.isEmpty) {
      return const Center(child: LoadingWidget());
    }

    if (provider.visibleOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('Không tìm thấy đơn hàng nào.', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    // Build grouped items by date
    final items = _buildGroupedItems(provider.visibleOrders);

    final showFooter = !provider.reachedEnd;

    return RefreshIndicator(
      onRefresh: () => provider.searchPurchaseOrders(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(8.0),
        itemCount: items.length + (showFooter ? 1 : 0),
        itemBuilder: (context, index) {
          if (showFooter && index == items.length) {
            return _buildLoadingFooter();
          }
          final it = items[index];
          if (it.isHeader) {
            return _buildDateHeader(it.headerText!);
          }
          return _buildPOListItem(context, it.po!);
        },
      ),
    );
  }

  List<_ListItem> _buildGroupedItems(List<PurchaseOrder> orders) {
    final List<_ListItem> result = [];
    String? currentDateStr;
    for (final po in orders) {
      final ds = AppFormatter.formatDate(po.orderDate);
      if (currentDateStr != ds) {
        currentDateStr = ds;
        result.add(_ListItem.header(ds));
      }
      result.add(_ListItem.item(po));
    }
    return result;
  }

  Widget _buildDateHeader(String dateText) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              dateText,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  void _onScroll() {
    final provider = context.read<PurchaseOrderProvider>();
    if (!provider.reachedEnd &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      provider.loadMore();
    }
  }

  Widget _buildLoadingFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Đang tải thêm...'),
        ],
      ),
    );
  }

  Widget _buildPOListItem(BuildContext context, PurchaseOrder po) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.of(context).pushNamed(RouteNames.purchaseOrderDetail, arguments: po);
        },
        onLongPress: () async {
          final text = po.poNumber ?? '';
          if (text.isNotEmpty) {
            await Clipboard.setData(ClipboardData(text: text));
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Đã sao chép mã PO: $text')),
              );
            }
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(po.poNumber ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  _buildStatusChip(po.status),
                ],
              ),
              const SizedBox(height: 8),
              Text('NCC: ${po.supplierName ?? 'N/A'}', style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 4),
              Text('Ngày đặt: ${AppFormatter.formatDate(po.orderDate)}', style: TextStyle(color: Colors.grey[600])),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tổng tiền', style: TextStyle(fontWeight: FontWeight.w500)),
                  Text(AppFormatter.formatCurrency(po.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(PurchaseOrderStatus status) {
    Color color;
    String text = status.name;

    switch (status) {
      case PurchaseOrderStatus.draft:
        color = Colors.grey;
        text = 'Nháp';
        break;
      case PurchaseOrderStatus.sent:
        color = Colors.blue;
        text = 'Đã gửi';
        break;
      case PurchaseOrderStatus.confirmed:
        color = Colors.orange;
        text = 'Đã xác nhận';
        break;
      case PurchaseOrderStatus.delivered:
        color = Colors.green;
        text = 'Đã nhận hàng';
        break;
      case PurchaseOrderStatus.cancelled:
        color = Colors.red;
        text = 'Đã hủy';
        break;
    }

    return Chip(
      label: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

// Helper model for grouped list rendering
class _ListItem {
  final bool isHeader;
  final String? headerText;
  final PurchaseOrder? po;

  _ListItem._(this.isHeader, this.headerText, this.po);

  factory _ListItem.header(String text) => _ListItem._(true, text, null);
  factory _ListItem.item(PurchaseOrder po) => _ListItem._(false, null, po);
}

class FilterSortSheet extends StatefulWidget {
  @override
  State<FilterSortSheet> createState() => _FilterSortSheetState();
}

class _FilterSortSheetState extends State<FilterSortSheet> {
  final TextEditingController _minCtrl = TextEditingController();
  final TextEditingController _maxCtrl = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    final poProvider = context.read<PurchaseOrderProvider>();
    _fromDate = poProvider.fromDate;
    _toDate = poProvider.toDate;
    if (poProvider.minTotal != null) _minCtrl.text = poProvider.minTotal!.toStringAsFixed(0);
    if (poProvider.maxTotal != null) _maxCtrl.text = poProvider.maxTotal!.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _fromDate = picked);
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _toDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final poProvider = context.watch<PurchaseOrderProvider>();
    final companyProvider = context.watch<CompanyProvider>();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sắp xếp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            _buildSortOptions(context, poProvider),
            const Divider(height: 32),
            const Text('Trạng thái đơn', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Nháp'),
                  selected: poProvider.statusFilters.contains(PurchaseOrderStatus.draft),
                  onSelected: (_) => poProvider.toggleStatusFilter(PurchaseOrderStatus.draft),
                ),
                FilterChip(
                  label: const Text('Đã gửi'),
                  selected: poProvider.statusFilters.contains(PurchaseOrderStatus.sent),
                  onSelected: (_) => poProvider.toggleStatusFilter(PurchaseOrderStatus.sent),
                ),
                FilterChip(
                  label: const Text('Đã xác nhận'),
                  selected: poProvider.statusFilters.contains(PurchaseOrderStatus.confirmed),
                  onSelected: (_) => poProvider.toggleStatusFilter(PurchaseOrderStatus.confirmed),
                ),
                FilterChip(
                  label: const Text('Đã nhận hàng'),
                  selected: poProvider.statusFilters.contains(PurchaseOrderStatus.delivered),
                  onSelected: (_) => poProvider.toggleStatusFilter(PurchaseOrderStatus.delivered),
                ),
                FilterChip(
                  label: const Text('Đã hủy'),
                  selected: poProvider.statusFilters.contains(PurchaseOrderStatus.cancelled),
                  onSelected: (_) => poProvider.toggleStatusFilter(PurchaseOrderStatus.cancelled),
                ),
              ],
            ),
            const Divider(height: 32),
            const Text('Lọc theo nhà cung cấp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            _buildSupplierFilter(context, poProvider, companyProvider),
            const Divider(height: 32),
            const Text('Khoảng thời gian', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(_fromDate == null ? 'Từ ngày' : AppFormatter.formatDate(_fromDate!)),
                    onPressed: _pickFromDate,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(_toDate == null ? 'Đến ngày' : AppFormatter.formatDate(_toDate!)),
                    onPressed: _pickToDate,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Khoảng tổng tiền', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Tối thiểu (VND)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _maxCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Tối đa (VND)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              onPressed: () {
                // Apply ranges
                final minVal = double.tryParse(_minCtrl.text.replaceAll(',', ''));
                final maxVal = double.tryParse(_maxCtrl.text.replaceAll(',', ''));
                poProvider.setDateRange(from: _fromDate, to: _toDate);
                poProvider.setAmountRange(min: minVal, max: maxVal);
                poProvider.applyFiltersAndSearch();
                Navigator.of(context).pop();
              },
              child: const Text('Áp dụng'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOptions(BuildContext context, PurchaseOrderProvider provider) {
    return Row(
      children: [
        Expanded(
          child: RadioListTile<String>(
            title: const Text('Ngày đặt'),
            value: 'order_date',
            groupValue: provider.sortBy,
            onChanged: (val) => provider.setSort(val!, provider.sortAsc),
          ),
        ),
        Expanded(
          child: RadioListTile<String>(
            title: const Text('Tổng tiền'),
            value: 'total_amount',
            groupValue: provider.sortBy,
            onChanged: (val) => provider.setSort(val!, provider.sortAsc),
          ),
        ),
        IconButton(
          icon: Icon(provider.sortAsc ? Icons.arrow_upward : Icons.arrow_downward),
          onPressed: () => provider.setSort(provider.sortBy, !provider.sortAsc),
        ),
      ],
    );
  }

  Widget _buildSupplierFilter(BuildContext context, PurchaseOrderProvider poProvider, CompanyProvider companyProvider) {
    if (companyProvider.isLoading) return const Center(child: CircularProgressIndicator());

    return Wrap(
      spacing: 8.0,
      children: companyProvider.companies.map((Company company) {
        final isSelected = poProvider.selectedSupplierIds.contains(company.id);
        return FilterChip(
          label: Text(company.name),
          selected: isSelected,
          onSelected: (selected) {
            poProvider.toggleSupplierFilter(company.id);
          },
          selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
          checkmarkColor: Theme.of(context).primaryColor,
        );
      }).toList(),
    );
  }
}