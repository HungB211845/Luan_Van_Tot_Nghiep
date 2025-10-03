import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../models/product_batch.dart';
import '../../providers/product_provider.dart';
import '../../widgets/inventory_batches_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';

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

  @override
  void initState() {
    super.initState();
    _loadBatches();
    _searchController.addListener(_onSearchChanged);
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
      _applyFilters();
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
    _applyFilters();
  }

  void _applyFilters() {
    setState(() {
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
            return batch.isExpired;
          case 'low_stock':
            return batch.quantity > 0 && batch.quantity <= 10;
          case 'out_of_stock':
            return batch.quantity <= 0;
          default:
            return true;
        }
      }).toList();

      // Sort by received date (newest first)
      _filteredBatches.sort((a, b) => b.receivedDate.compareTo(a.receivedDate));
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
          _applyFilters();
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
    final filteredCount = _filteredBatches.length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
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
            child: _buildStatItem('Tổng tồn kho', '$totalStock', Icons.warehouse),
          ),
          if (filteredCount != totalBatches) ...[
            _buildStatDivider(),
            Expanded(
              child: _buildStatItem('Lọc', '$filteredCount', Icons.filter_list),
            ),
          ],
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
          );
        },
      ),
    );
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
                    _applyFilters();
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