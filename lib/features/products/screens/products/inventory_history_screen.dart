import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../models/product_batch.dart';
import '../../models/product_unit.dart';
import '../../providers/product_provider.dart';
import '../../widgets/inventory_batches_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/utils/formatter.dart';
import '../../utils/unit_display_formatter.dart';
import '../../../notification/providers/notification_provider.dart';
import '../../../notification/models/notification_message.dart';

class InventoryHistoryScreen extends StatefulWidget {
  final Product product;

  const InventoryHistoryScreen({
    Key? key,
    required this.product,
  }) : super(key: key);

  @override
  State<InventoryHistoryScreen> createState() => _InventoryHistoryScreenState();
}

class _InventoryHistoryScreenState extends State<InventoryHistoryScreen> {
  bool _isLoading = true;
  List<ProductBatch> _filteredBatches = [];
  List<ProductBatch> _allBatches = [];
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all'; // all, active, expired, low_stock
  List<ProductUnit> _productUnits = [];
  String _baseUnitName = '';
  double _currentLowStockThreshold = 10;
  Set<String> _lowStockBatchIds = {};
  Set<String> _lowStockBatchNumbers = {};

  @override
  void initState() {
    super.initState();
    _loadBatches();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final notificationProvider = Provider.of<NotificationProvider>(context);
    if (_productUnits.isNotEmpty || _allBatches.isNotEmpty) {
      final thresholdBase = notificationProvider.resolveLowStockThreshold(
        product: widget.product,
        units: _productUnits,
      );
      if ((thresholdBase - _currentLowStockThreshold).abs() > 0.01) {
        _applyFilters(notificationProvider);
      }
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBatches() async {
    setState(() => _isLoading = true);

    try {
      final provider = context.read<ProductProvider>();
      await provider.loadProductBatches(widget.product.id);

      _allBatches = List.from(provider.productBatches);
      final units = await provider.getProductUnits(widget.product.id);
      _productUnits = units;
      _baseUnitName = UnitDisplayFormatter.resolveBaseUnitName(
        units: units,
        fallback: widget.product.effectiveBaseUnit,
      );
      if (!mounted) return;
      final notificationProvider = context.read<NotificationProvider>();
      _applyFilters(notificationProvider);
      await notificationProvider.refresh();
      if (!mounted) return;
      _applyFilters(notificationProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải dữ liệu: $e'),
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

  void _onSearchChanged() {
    final notificationProvider = context.read<NotificationProvider>();
    _applyFilters(notificationProvider);
  }

  void _applyFilters(NotificationProvider notificationProvider) {
    final thresholdBase = notificationProvider.resolveLowStockThreshold(
      product: widget.product,
      units: _productUnits,
    );

    final notifications = notificationProvider.notifications
        .where((n) => n.productId == widget.product.id)
        .toList();
    final now = DateTime.now();

    final expiryNotifications = notifications.where((n) {
      if (n.topic == NotificationTopic.batchExpiry) return true;
      return n.expiryDays != null;
    }).toList();

    final lowStockNotifications = notifications.where((n) {
      if (n.topic == NotificationTopic.batchLowStock) return true;
      return n.topic == NotificationTopic.general &&
          n.id.startsWith('lowstock-batch-');
    }).toList();

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
    final Map<String, int> expiryDaysMap = {
      for (final n in expiryNotifications)
        if (n.batchNumber != null && n.expiryDays != null)
          n.batchNumber!: n.expiryDays!,
    };

    bool isExpiringSoon(ProductBatch batch) {
      if (expiringBatchNumbers.contains(batch.batchNumber)) return true;
      if (batch.expiryDate == null) return false;
      final diff = batch.expiryDate!.difference(now).inDays;
      return diff >= 0 && diff <= 90;
    }

    setState(() {
      _currentLowStockThreshold = thresholdBase;
      _lowStockBatchIds = lowStockBatchIds;
      _lowStockBatchNumbers = lowStockBatchNumbers;
      _filteredBatches = _allBatches.where((batch) {
        // Search filter
        final searchQuery = _searchController.text.toLowerCase();
        final matchesSearch = searchQuery.isEmpty ||
            batch.batchNumber.toLowerCase().contains(searchQuery) ||
            (batch.supplierName?.toLowerCase().contains(searchQuery) ?? false);

        if (!matchesSearch) return false;

        // Status filter
        switch (_selectedFilter) {
          case 'active':
            return batch.quantity > 0 && !batch.isExpired;
          case 'expired':
            return batch.isExpired ||
                expiredBatchNumbers.contains(batch.batchNumber);
          case 'low_stock':
            final quantity = batch.quantity.toDouble();
            final matchesNotification = lowStockBatchIds.contains(batch.id) ||
                lowStockBatchNumbers.contains(batch.batchNumber);

            if (quantity <= 0) {
              return false;
            }

            if (matchesNotification) {
              return true;
            }

            return quantity <= thresholdBase;
          case 'expiring':
            return isExpiringSoon(batch) && !batch.isExpired;
          case 'out_of_stock':
            return batch.quantity <= 0;
          default:
            return true;
        }
      }).toList();

      if (_selectedFilter == 'expiring' || _selectedFilter == 'expired') {
        _filteredBatches.sort((a, b) {
          final da = expiryDaysMap[a.batchNumber] ??
              (a.expiryDate != null
                  ? a.expiryDate!.difference(now).inDays
                  : 9999);
          final db = expiryDaysMap[b.batchNumber] ??
              (b.expiryDate != null
                  ? b.expiryDate!.difference(now).inDays
                  : 9999);
          return da.compareTo(db);
        });
      } else {
        _filteredBatches.sort((a, b) => b.receivedDate.compareTo(a.receivedDate));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lịch Sử Nhập Hàng',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.product.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBatches,
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          _buildSummaryStats(),
          Expanded(
            child: _isLoading
                ? const Center(child: LoadingWidget())
                : _buildBatchesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Tìm theo mã lô hoặc nhà cung cấp...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', 'Tất cả', Icons.all_inclusive),
                const SizedBox(width: 8),
                _buildFilterChip('active', 'Còn hàng', Icons.check_circle),
                const SizedBox(width: 8),
                _buildFilterChip('low_stock', 'Sắp hết', Icons.warning),
                const SizedBox(width: 8),
                _buildFilterChip('expiring', 'Sắp hết hạn', Icons.timer_outlined),
                const SizedBox(width: 8),
                _buildFilterChip('out_of_stock', 'Hết hàng', Icons.error),
                const SizedBox(width: 8),
                _buildFilterChip('expired', 'Hết hạn', Icons.event_busy),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, IconData icon) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : Colors.grey[600],
          ),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
          final np = context.read<NotificationProvider>();
          _applyFilters(np);
        });
      },
      selectedColor: Colors.green,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[600],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildSummaryStats() {
    if (_isLoading) return const SizedBox.shrink();

    final totalBatches = _allBatches.length;
    final activeBatches = _allBatches.where((b) => b.quantity > 0 && !b.isExpired).length;
    final totalStock = _allBatches.fold<int>(0, (sum, batch) => sum + batch.quantity);
    final totalStockLabel = _formatQuantity(totalStock.toDouble());
    final filteredCount = _filteredBatches.length;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatItem('Tổng lô', '$totalBatches', Icons.inventory_2),
              ),
              _buildStatDivider(),
              Expanded(
                child: _buildStatItem('Còn hàng', '$activeBatches', Icons.check_circle),
              ),
              _buildStatDivider(),
              Expanded(
                child: _buildStatItem('Tổng tồn kho', totalStockLabel, Icons.warehouse),
              ),
              if (filteredCount != totalBatches) ...[
                _buildStatDivider(),
                Expanded(
                  child: _buildStatItem('Lọc', '$filteredCount', Icons.filter_list),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.green[600], size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.green[700],
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 40,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.green[200],
    );
  }

  Widget _buildBatchesList() {
    if (_filteredBatches.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadBatches,
      child: Consumer<ProductProvider>(
        builder: (context, provider, child) {
          return InventoryBatchesWidget(
            batches: _filteredBatches,
            onBatchUpdated: _loadBatches,
            showTitle: false, // Don't show title in full screen mode
            productUnits: _productUnits,
            productBaseUnit: widget.product.effectiveBaseUnit,
            lowStockThreshold: _currentLowStockThreshold,
            lowStockBatchIds: _lowStockBatchIds,
            lowStockBatchNumbers: _lowStockBatchNumbers,
          );
        },
      ),
    );
  }

  String _formatQuantity(double baseQuantity) {
    if (_productUnits.isEmpty) {
      final base = widget.product.effectiveBaseUnit;
      final baseLabel = base.toLowerCase() == 'đơn vị'
          ? ''
          : ' ${base.toLowerCase()}';
      return '${AppFormatter.formatNumber(baseQuantity.round())}$baseLabel';
    }

    final baseUnitName = _baseUnitName.isNotEmpty
        ? _baseUnitName
        : widget.product.effectiveBaseUnit;

    final preferred = UnitDisplayFormatter.preferredQuantity(
      baseQuantity: baseQuantity,
      units: _productUnits,
      baseUnitName: baseUnitName,
    );

    if (preferred == null) {
      final baseLabel = baseUnitName.isEmpty || baseUnitName.toLowerCase() == 'đơn vị'
          ? ''
          : ' ${baseUnitName.toLowerCase()}';
      return '${AppFormatter.formatNumber(baseQuantity.round())}$baseLabel';
    }

    final value = UnitDisplayFormatter.formatQuantityValue(preferred.primaryQuantity);
    final unitLabel = UnitDisplayFormatter.simpleUnitName(preferred.unit);
    return '$value $unitLabel';
  }

  Widget _buildEmptyState() {
    final hasSearch = _searchController.text.isNotEmpty;
    final hasFilter = _selectedFilter != 'all';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasSearch || hasFilter ? Icons.search_off : Icons.inventory_2_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch || hasFilter
                  ? 'Không tìm thấy lô hàng nào'
                  : 'Chưa có lô hàng nào',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasSearch || hasFilter
                  ? 'Thử thay đổi từ khóa tìm kiếm hoặc bộ lọc'
                  : 'Sử dụng "Nhập Lô Nhanh" để thêm lô hàng đầu tiên',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            if (hasSearch || hasFilter) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _selectedFilter = 'all';
                    final np = context.read<NotificationProvider>();
                    _applyFilters(np);
                  });
                },
                icon: const Icon(Icons.clear),
                label: const Text('Xóa bộ lọc'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
