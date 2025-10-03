import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../widgets/price_history_widget.dart';
import '../../providers/product_provider.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/utils/formatter.dart';

class PriceHistoryScreen extends StatefulWidget {
  final Product product;

  const PriceHistoryScreen({
    Key? key,
    required this.product,
  }) : super(key: key);

  @override
  State<PriceHistoryScreen> createState() => _PriceHistoryScreenState();
}

class _PriceHistoryScreenState extends State<PriceHistoryScreen> {
  bool _isLoading = true;
  List<PriceHistoryItem> _filteredHistory = [];
  List<PriceHistoryItem> _allHistory = [];
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all'; // all, increase, decrease, manual, auto

  @override
  void initState() {
    super.initState();
    _loadPriceHistory();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPriceHistory() async {
    setState(() => _isLoading = true);

    try {
      final provider = context.read<ProductProvider>();
      final history = await provider.getPriceHistory(widget.product.id);

      _allHistory = List.from(history);
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
      _filteredHistory = _allHistory.where((item) {
        // Search filter
        final searchQuery = _searchController.text.toLowerCase();
        final matchesSearch = searchQuery.isEmpty ||
            AppFormatter.formatCompactCurrency(item.newPrice).toLowerCase().contains(searchQuery) ||
            (item.reason?.toLowerCase().contains(searchQuery) ?? false);

        if (!matchesSearch) return false;

        // Status filter
        switch (_selectedFilter) {
          case 'increase':
            return item.oldPrice != null && item.newPrice > item.oldPrice!;
          case 'decrease':
            return item.oldPrice != null && item.newPrice < item.oldPrice!;
          case 'manual':
            return (item.reason?.toLowerCase().contains('manual') ?? false) ||
                   (item.reason?.toLowerCase().contains('thủ công') ?? false) ||
                   (item.reason?.toLowerCase().contains('giao diện') ?? false);
          case 'auto':
            return (item.reason?.toLowerCase().contains('auto') ?? false) ||
                   (item.reason?.toLowerCase().contains('đồng bộ') ?? false) ||
                   (item.reason?.toLowerCase().contains('sync') ?? false);
          default:
            return true;
        }
      }).toList();

      // Sort by changed date (newest first)
      _filteredHistory.sort((a, b) => b.changedAt.compareTo(a.changedAt));
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
              'Lịch Sử Giá Bán',
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
            onPressed: _loadPriceHistory,
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
                : _buildHistoryList(),
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
              hintText: 'Tìm theo giá hoặc lý do thay đổi...',
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
                _buildFilterChip('increase', 'Tăng giá', Icons.trending_up),
                const SizedBox(width: 8),
                _buildFilterChip('decrease', 'Giảm giá', Icons.trending_down),
                const SizedBox(width: 8),
                _buildFilterChip('manual', 'Thủ công', Icons.edit),
                const SizedBox(width: 8),
                _buildFilterChip('auto', 'Tự động', Icons.sync),
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

    final totalChanges = _allHistory.length;
    final increases = _allHistory.where((h) => h.oldPrice != null && h.newPrice > h.oldPrice!).length;
    final decreases = _allHistory.where((h) => h.oldPrice != null && h.newPrice < h.oldPrice!).length;
    final filteredCount = _filteredHistory.length;

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
            child: _buildStatItem('Tổng thay đổi', '$totalChanges', Icons.history, Colors.green[600]!),
          ),
          _buildStatDivider(),
          Expanded(
            child: _buildStatItem('Tăng giá', '$increases', Icons.trending_up, Colors.green[600]!),
          ),
          _buildStatDivider(),
          Expanded(
            child: _buildStatItem('Giảm giá', '$decreases', Icons.trending_down, Colors.red[600]!),
          ),
          if (filteredCount != totalChanges) ...[
            _buildStatDivider(),
            Expanded(
              child: _buildStatItem('Lọc', '$filteredCount', Icons.filter_list, Colors.blue[600]!),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
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

  Widget _buildHistoryList() {
    if (_filteredHistory.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadPriceHistory,
      child: ListView.separated(
        itemCount: _filteredHistory.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: Colors.grey[300],
        ),
        itemBuilder: (context, index) {
          final item = _filteredHistory[index];
          return _buildPriceHistoryItem(item);
        },
      ),
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
              hasSearch || hasFilter ? Icons.search_off : Icons.history,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch || hasFilter
                  ? 'Không tìm thấy thay đổi giá nào'
                  : 'Chưa có lịch sử thay đổi giá',
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
                  : 'Mọi thay đổi giá sẽ được ghi lại tại đây',
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

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} giờ trước';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} phút trước';
    } else {
      return 'Vừa xong';
    }
  }
}