import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agricultural_pos/features/products/screens/reports/expiry_report_screen.dart';
import '../../../presentation/home/services/report_service.dart';
import '../../../presentation/home/models/daily_revenue.dart';
import '../../../shared/utils/formatter.dart';
import '../../../shared/widgets/loading_widget.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final ReportService _reportService = ReportService();

  bool _isLoading = false;
  Map<String, dynamic>? _monthlyData;
  Map<String, dynamic>? _quarterlyData;
  List<Map<String, dynamic>>? _topProducts;
  Map<String, dynamic>? _inventoryData;
  List<DailyRevenue>? _weeklyRevenue;

  DateTime _selectedMonth = DateTime.now();
  int _selectedQuarter = ((DateTime.now().month - 1) ~/ 3) + 1;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadMonthlyData(),
        _loadQuarterlyData(),
        _loadTopProducts(),
        _loadInventoryData(),
        _loadWeeklyRevenue(),
      ]);
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

  Future<void> _loadMonthlyData() async {
    final data = await _reportService.getMonthlyRevenue(_selectedYear, _selectedMonth.month);
    if (mounted) {
      setState(() => _monthlyData = data);
    }
  }

  Future<void> _loadQuarterlyData() async {
    final data = await _reportService.getQuarterlyRevenue(_selectedYear, _selectedQuarter);
    if (mounted) {
      setState(() => _quarterlyData = data);
    }
  }

  Future<void> _loadTopProducts() async {
    final startDate = DateTime.now().subtract(const Duration(days: 30));
    final data = await _reportService.getTopSellingProducts(
      startDate: startDate,
      endDate: DateTime.now(),
      limit: 10,
    );
    if (mounted) {
      setState(() => _topProducts = data);
    }
  }

  Future<void> _loadInventoryData() async {
    final data = await _reportService.getInventoryAnalytics();
    if (mounted) {
      setState(() => _inventoryData = data);
    }
  }

  Future<void> _loadWeeklyRevenue() async {
    final startDate = DateTime.now().subtract(const Duration(days: 6));
    final data = await _reportService.getRevenueForWeek(startDate);
    if (mounted) {
      setState(() => _weeklyRevenue = data);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo Cáo Kinh Doanh'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.trending_up), text: 'Doanh Thu'),
            Tab(icon: Icon(Icons.inventory), text: 'Tồn Kho'),
            Tab(icon: Icon(Icons.star), text: 'Sản Phẩm'),
            Tab(icon: Icon(Icons.report), text: 'Khác'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: LoadingWidget())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRevenueTab(),
                _buildInventoryTab(),
                _buildProductsTab(),
                _buildOtherReportsTab(),
              ],
            ),
    );
  }

  Widget _buildRevenueTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadMonthlyData();
        await _loadQuarterlyData();
        await _loadWeeklyRevenue();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildWeeklyRevenueCard(),
          const SizedBox(height: 16),
          _buildMonthlyRevenueCard(),
          const SizedBox(height: 16),
          _buildQuarterlyRevenueCard(),
        ],
      ),
    );
  }

  Widget _buildInventoryTab() {
    return RefreshIndicator(
      onRefresh: _loadInventoryData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInventoryOverviewCard(),
          const SizedBox(height: 16),
          _buildInventoryAlertsCard(),
        ],
      ),
    );
  }

  Widget _buildProductsTab() {
    return RefreshIndicator(
      onRefresh: _loadTopProducts,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTopProductsCard(),
        ],
      ),
    );
  }

  Widget _buildOtherReportsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildReportLinkCard(
          'Báo Cáo Hàng Sắp Hết Hạn',
          'Kiểm tra sản phẩm cần xử lý gấp',
          Icons.warning_amber,
          Colors.orange,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ExpiryReportScreen()),
          ),
        ),
        const SizedBox(height: 12),
        _buildReportLinkCard(
          'Xuất Dữ Liệu Thuế',
          'Chuẩn bị báo cáo thuế cho cơ quan thuế',
          Icons.receipt_long,
          Colors.blue,
          () => _showTaxExportDialog(),
        ),
        const SizedBox(height: 12),
        _buildReportLinkCard(
          'Phân Tích Xu Hướng',
          'Biểu đồ xu hướng bán hàng theo thời gian',
          Icons.trending_up,
          Colors.green,
          () => _showComingSoonDialog('Phân tích xu hướng'),
        ),
      ],
    );
  }

  Widget _buildWeeklyRevenueCard() {
    if (_weeklyRevenue == null) return const SizedBox.shrink();

    final totalRevenue = _weeklyRevenue!.fold<double>(0, (sum, day) => sum + day.revenue);
    final totalTransactions = _weeklyRevenue!.fold<int>(0, (sum, day) => sum + day.transactionCount);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.date_range, color: Colors.green[600]),
                const SizedBox(width: 8),
                Text(
                  '7 Ngày Qua',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    'Tổng Doanh Thu',
                    AppFormatter.formatCurrency(totalRevenue),
                    Icons.monetization_on,
                    Colors.green[600]!,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricItem(
                    'Giao Dịch',
                    '$totalTransactions',
                    Icons.receipt,
                    Colors.blue[600]!,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyRevenueCard() {
    if (_monthlyData == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month, color: Colors.green[600]),
                const SizedBox(width: 8),
                Text(
                  'Tháng ${_monthlyData!['month']}/${_monthlyData!['year']}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.date_range),
                  onPressed: _showMonthPicker,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricItem(
                        'Doanh Thu',
                        AppFormatter.formatCurrency(_monthlyData!['total_revenue'] ?? 0),
                        Icons.monetization_on,
                        Colors.green[600]!,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricItem(
                        'Thuế (1.5%)',
                        AppFormatter.formatCurrency(_monthlyData!['tax_amount'] ?? 0),
                        Icons.receipt_long,
                        Colors.orange[600]!,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricItem(
                        'Thu Tiền Mặt',
                        AppFormatter.formatCurrency(_monthlyData!['cash_revenue'] ?? 0),
                        Icons.payments,
                        Colors.blue[600]!,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricItem(
                        'Thu Nợ',
                        AppFormatter.formatCurrency(_monthlyData!['debt_revenue'] ?? 0),
                        Icons.credit_card,
                        Colors.red[600]!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuarterlyRevenueCard() {
    if (_quarterlyData == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_view_month, color: Colors.green[600]),
                const SizedBox(width: 8),
                Text(
                  'Quý ${_quarterlyData!['quarter']}/${_quarterlyData!['year']}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.date_range),
                  onPressed: _showQuarterPicker,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    'Doanh Thu',
                    AppFormatter.formatCurrency(_quarterlyData!['total_revenue'] ?? 0),
                    Icons.monetization_on,
                    Colors.green[600]!,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricItem(
                    'Lợi Nhuận Sau Thuế',
                    AppFormatter.formatCurrency(_quarterlyData!['net_revenue'] ?? 0),
                    Icons.trending_up,
                    Colors.purple[600]!,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryOverviewCard() {
    if (_inventoryData == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory, color: Colors.green[600]),
                const SizedBox(width: 8),
                Text(
                  'Tổng Quan Tồn Kho',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricItem(
                        'Giá Trị Tồn Kho',
                        AppFormatter.formatCurrency(_inventoryData!['total_inventory_value'] ?? 0),
                        Icons.monetization_on,
                        Colors.green[600]!,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricItem(
                        'Giá Trị Bán',
                        AppFormatter.formatCurrency(_inventoryData!['total_selling_value'] ?? 0),
                        Icons.sell,
                        Colors.blue[600]!,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricItem(
                        'Lợi Nhuận Dự Kiến',
                        AppFormatter.formatCurrency(_inventoryData!['potential_profit'] ?? 0),
                        Icons.trending_up,
                        Colors.purple[600]!,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricItem(
                        'Tỷ Suất LN',
                        '${(_inventoryData!['profit_margin'] ?? 0).toStringAsFixed(1)}%',
                        Icons.percent,
                        Colors.orange[600]!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryAlertsCard() {
    if (_inventoryData == null) return const SizedBox.shrink();

    final lowStock = _inventoryData!['low_stock_items'] ?? 0;
    final expiringSoon = _inventoryData!['expiring_soon_items'] ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.orange[600]),
                const SizedBox(width: 8),
                Text(
                  'Cảnh Báo Tồn Kho',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    'Sắp Hết Hàng',
                    '$lowStock',
                    Icons.inventory_2,
                    Colors.orange[600]!,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricItem(
                    'Sắp Hết Hạn',
                    '$expiringSoon',
                    Icons.schedule,
                    Colors.red[600]!,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProductsCard() {
    if (_topProducts == null || _topProducts!.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.star_border, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Chưa có dữ liệu bán hàng',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: Colors.green[600]),
                const SizedBox(width: 8),
                Text(
                  'Top 10 Sản Phẩm (30 ngày qua)',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _topProducts!.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final product = _topProducts![index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Colors.green[100],
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                  title: Text(
                    product['product_name'] ?? 'N/A',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    'Số lượng: ${(product['total_quantity'] ?? 0).toStringAsFixed(0)} ${product['unit'] ?? ''}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  trailing: Text(
                    AppFormatter.formatCompactCurrency(product['total_revenue'] ?? 0),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[600],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildReportLinkCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey[600]),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Future<void> _showMonthPicker() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );

    if (date != null) {
      setState(() => _selectedMonth = date);
      await _loadMonthlyData();
    }
  }

  Future<void> _showQuarterPicker() async {
    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chọn Quý'),
        content: SizedBox(
          width: double.minPositive,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int quarter = 1; quarter <= 4; quarter++)
                ListTile(
                  title: Text('Quý $quarter/$_selectedYear'),
                  onTap: () => Navigator.pop(context, {'quarter': quarter, 'year': _selectedYear}),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _selectedQuarter = result['quarter']!;
        _selectedYear = result['year']!;
      });
      await _loadQuarterlyData();
    }
  }

  Future<void> _showTaxExportDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xuất Dữ Liệu Thuế'),
        content: const Text(
          'Tính năng xuất dữ liệu thuế để chuẩn bị báo cáo cho cơ quan thuế.\n\nSẽ bao gồm:\n- Tổng doanh thu theo tháng/quý\n- Thuế GTGT (1.5%)\n- Chi tiết giao dịch\n- Báo cáo tài chính',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showComingSoonDialog('Xuất dữ liệu thuế');
            },
            child: const Text('Xuất File'),
          ),
        ],
      ),
    );
  }

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sắp Ra Mắt'),
        content: Text('Tính năng "$feature" đang được phát triển và sẽ có trong phiên bản tiếp theo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }
}
