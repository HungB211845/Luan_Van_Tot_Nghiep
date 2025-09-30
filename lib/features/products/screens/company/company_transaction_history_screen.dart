import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../../../../core/routing/route_names.dart';
import '../../../../shared/utils/formatter.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../models/purchase_order.dart';
import '../../models/purchase_order_status.dart';
import '../../models/company.dart';
import '../../providers/purchase_order_provider.dart';

class CompanyTransactionHistoryScreen extends StatefulWidget {
  final Company company;

  const CompanyTransactionHistoryScreen({Key? key, required this.company}) : super(key: key);

  @override
  State<CompanyTransactionHistoryScreen> createState() => _CompanyTransactionHistoryScreenState();
}

class _CompanyTransactionHistoryScreenState extends State<CompanyTransactionHistoryScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  final ScrollController _scrollController = ScrollController();

  // Filter state
  Set<PurchaseOrderStatus> _selectedStatuses = {};
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrders();
    });

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadOrders() {
    // Set supplier filter and load
    final provider = context.read<PurchaseOrderProvider>();
    provider.setSearchText(_searchController.text);
    provider.toggleSupplierFilter(widget.company.id);

    // Apply date filters if set
    if (_fromDate != null || _toDate != null) {
      provider.setDateRange(from: _fromDate, to: _toDate);
    }

    // Apply status filters
    if (_selectedStatuses.isNotEmpty) {
      for (var status in _selectedStatuses) {
        provider.toggleStatusFilter(status);
      }
    }

    provider.searchPurchaseOrders();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _loadOrders();
    });
  }

  Widget _buildQuickChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ActionChip(
              label: const Text('Hôm nay'),
              backgroundColor: _isToday() ? Colors.green[100] : null,
              onPressed: () {
                setState(() {
                  final now = DateTime.now();
                  _fromDate = DateTime(now.year, now.month, now.day);
                  _toDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
                });
                _loadOrders();
              },
            ),
            const SizedBox(width: 8),
            ActionChip(
              label: const Text('7 ngày'),
              backgroundColor: _isLast7Days() ? Colors.green[100] : null,
              onPressed: () {
                setState(() {
                  final now = DateTime.now();
                  _fromDate = now.subtract(const Duration(days: 7));
                  _toDate = now;
                });
                _loadOrders();
              },
            ),
            const SizedBox(width: 8),
            ActionChip(
              label: const Text('30 ngày'),
              backgroundColor: _isLast30Days() ? Colors.green[100] : null,
              onPressed: () {
                setState(() {
                  final now = DateTime.now();
                  _fromDate = now.subtract(const Duration(days: 30));
                  _toDate = now;
                });
                _loadOrders();
              },
            ),
            const SizedBox(width: 8),
            if (_fromDate != null || _toDate != null)
              ActionChip(
                avatar: const Icon(Icons.clear, size: 16),
                label: const Text('Xóa ngày'),
                onPressed: () {
                  setState(() {
                    _fromDate = null;
                    _toDate = null;
                  });
                  _loadOrders();
                },
              ),
          ],
        ),
      ),
    );
  }

  bool _isToday() {
    if (_fromDate == null || _toDate == null) return false;
    final now = DateTime.now();
    return _fromDate!.day == now.day &&
           _fromDate!.month == now.month &&
           _fromDate!.year == now.year;
  }

  bool _isLast7Days() {
    if (_fromDate == null) return false;
    final now = DateTime.now();
    final diff = now.difference(_fromDate!).inDays;
    return diff >= 6 && diff <= 7;
  }

  bool _isLast30Days() {
    if (_fromDate == null) return false;
    final now = DateTime.now();
    final diff = now.difference(_fromDate!).inDays;
    return diff >= 29 && diff <= 30;
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bộ lọc',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),

                  // Status filter
                  Text('Trạng thái', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: PurchaseOrderStatus.values.map((status) {
                      final isSelected = _selectedStatuses.contains(status);
                      return FilterChip(
                        label: Text(status.displayName),
                        selected: isSelected,
                        onSelected: (selected) {
                          setModalState(() {
                            if (selected) {
                              _selectedStatuses.add(status);
                            } else {
                              _selectedStatuses.remove(status);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setModalState(() {
                              _selectedStatuses.clear();
                              _fromDate = null;
                              _toDate = null;
                            });
                            setState(() {
                              _selectedStatuses.clear();
                              _fromDate = null;
                              _toDate = null;
                            });
                            Navigator.pop(context);
                            _loadOrders();
                          },
                          child: const Text('Xóa bộ lọc'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {}); // Update parent state
                            Navigator.pop(context);
                            _loadOrders();
                          },
                          child: const Text('Áp dụng'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PurchaseOrderProvider>();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Lịch sử nhập - ${widget.company.name}'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildQuickChips(),
          const SizedBox(height: 8),
          Expanded(child: _buildBody(provider)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Tìm theo mã đơn, sản phẩm...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _loadOrders();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.green, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildBody(PurchaseOrderProvider provider) {
    if (provider.isLoading && provider.purchaseOrders.isEmpty) {
      return const LoadingWidget();
    }

    final orders = provider.purchaseOrders;

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Chưa có đơn nhập hàng',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Chưa có đơn nhập hàng nào từ nhà cung cấp này',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        _loadOrders();
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          return _buildOrderCard(order);
        },
      ),
    );
  }

  Widget _buildOrderCard(PurchaseOrder order) {
    final statusColor = _getStatusColor(order.status);
    final totalAmount = order.totalAmount ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.of(context, rootNavigator: true).pushNamed(
            RouteNames.purchaseOrderDetail,
            arguments: order,
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
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      order.status.displayName,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Order ID
                  Text(
                    '#${order.id.substring(0, 8)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Order date
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    AppFormatter.formatDate(order.orderDate),
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ],
              ),

              if (order.notes != null && order.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.note, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.notes!,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Total amount
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tổng tiền:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    AppFormatter.formatCurrency(totalAmount),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(PurchaseOrderStatus status) {
    switch (status) {
      case PurchaseOrderStatus.draft:
        return Colors.grey;
      case PurchaseOrderStatus.sent:
      case PurchaseOrderStatus.confirmed:
        return Colors.indigo;
      case PurchaseOrderStatus.delivered:
        return Colors.green;
      case PurchaseOrderStatus.cancelled:
        return Colors.red;
    }
  }
}
