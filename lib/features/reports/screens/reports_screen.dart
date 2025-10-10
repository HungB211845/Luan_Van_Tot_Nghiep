import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../providers/report_provider.dart';
import '../models/inventory_analytics.dart';
import '../../../shared/utils/formatter.dart';
import '../../../shared/widgets/loading_widget.dart';
import 'package:agricultural_pos/features/products/screens/reports/expiry_report_screen.dart';
import 'package:agricultural_pos/features/products/screens/reports/low_stock_report_screen.dart';
import 'package:agricultural_pos/features/products/screens/reports/slow_moving_report_screen.dart';

// Custom iOS-style spring physics for PageView
class IOSSpringScrollPhysics extends ScrollPhysics {
  const IOSSpringScrollPhysics({super.parent});

  @override
  IOSSpringScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return IOSSpringScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => const SpringDescription(
    mass: 0.5,
    stiffness: 100.0,
    damping: 15.0, // iOS-like damping
  );
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late PageController _pageController;
  bool _isPageChanging = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _pageController = PageController(initialPage: 1); // Start at middle page

    // Add listener to load data lazily when tab changes
    _tabController.addListener(_onTabChanged);

    // Load initial tab data (Tab 0: Revenue)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDataForCurrentTab();
    });
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      // Only trigger when tab animation completes
      _loadDataForCurrentTab();
    }
  }

  void _loadDataForCurrentTab() {
    final provider = context.read<ReportProvider>();
    final currentTab = _tabController.index;

    print('📑 Tab changed to: $currentTab');

    switch (currentTab) {
      case 0: // Revenue Tab
        provider.loadRevenueData();
        break;
      case 1: // Inventory Tab
        provider.loadInventoryData();
        break;
      case 2: // Product Tab
        provider.loadProductData();
        break;
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportProvider>(
      builder: (context, provider, child) {
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
              ],
            ),
          ),
          body: provider.isLoading
              ? const Center(child: LoadingWidget())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRevenueTab(provider),
                    _buildInventoryTab(provider),
                    _buildProductsTab(provider),
                  ],
                ),
        );
      },
    );
  }

  // ===========================================================================
  // TAB 1: REVENUE DASHBOARD (NEW REFACRED DESIGN)
  // ===========================================================================
  Widget _buildRevenueTab(ReportProvider provider) {
    return RefreshIndicator(
      onRefresh: () => provider.loadRevenueData(forceRefresh: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTrendAnalysisCard(provider),
          const SizedBox(height: 24),
          _buildRankings(provider),
        ],
      ),
    );
  }

  Widget _buildTrendAnalysisCard(ReportProvider provider) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildMetrics(provider),
            const SizedBox(height: 24),
            _buildInteractiveChart(provider),
            const SizedBox(height: 16),
            _buildTimeRangeSelector(provider),
          ],
        ),
      ),
    );
  }

  Widget _buildMetrics(ReportProvider provider) {
    final summary = provider.revenueSummary;
    final percentageChange = summary?['revenue_change_percentage'] as num?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('TỔNG DOANH THU', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                AppFormatter.formatCompactCurrency(summary?['current_total_revenue'] ?? 0),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (percentageChange != null)
              Padding(
                padding: const EdgeInsets.only(left: 8.0, bottom: 2.0),
                child: Row(
                  children: [
                    Icon(
                      percentageChange >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                      color: percentageChange >= 0 ? Colors.green : Colors.red,
                      size: 16,
                    ),
                    Text(
                      '${percentageChange.abs().toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: percentageChange >= 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${summary?['current_total_transactions'] ?? 0} giao dịch',
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildTimeRangeSelector(ReportProvider provider) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<DateRangePreset>(
        segments: const [
          ButtonSegment(value: DateRangePreset.thisWeek, label: Text('Tuần')),
          ButtonSegment(value: DateRangePreset.thisMonth, label: Text('Tháng')),
          ButtonSegment(value: DateRangePreset.thisYear, label: Text('Năm')),
        ],
        selected: {provider.selectedPreset},
        onSelectionChanged: (newSelection) {
          provider.setDateRange(newSelection.first);
        },
        style: SegmentedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          selectedBackgroundColor: Colors.lightGreen,
          selectedForegroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildInteractiveChart(ReportProvider provider) {
    // Check if actually viewing PAST period (not current/future)
    final isViewingPast = _isActuallyViewingPast(provider);

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: Stack(
            children: [
              // PageView with 3 pages (Previous/Current/Next)
              PageView.builder(
                controller: _pageController,
                physics: isViewingPast
                  ? const IOSSpringScrollPhysics() // iOS spring animation when viewing past
                  : const NeverScrollableScrollPhysics(), // Block swipe when at current
                onPageChanged: (index) async {
                  if (_isPageChanging) return;
                  _isPageChanging = true;

                  if (index == 0) {
                    // Swiped left to previous period
                    await provider.selectPreviousPeriod();
                  } else if (index == 2) {
                    // Swiped right to next period (only possible when isViewingPast)
                    await provider.selectNextPeriod();
                  }

                  // Reset to middle page
                  if (mounted) {
                    await _pageController.animateToPage(
                      1,
                      duration: const Duration(milliseconds: 1),
                      curve: Curves.linear,
                    );
                  }
                  _isPageChanging = false;
                },
                itemCount: 3,
                itemBuilder: (context, index) => _buildChartPage(provider),
              ),

              // Left Arrow (Previous Period)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    onPressed: (provider.isLoading || _isPageChanging) ? null : () async {
                      _isPageChanging = true;
                      await provider.selectPreviousPeriod();
                      _isPageChanging = false;
                    },
                    icon: const Icon(Icons.chevron_left),
                    color: Colors.grey.shade400,
                    iconSize: 28,
                  ),
                ),
              ),

              // Right Arrow (Next Period) - Disabled if at current period
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    onPressed: (provider.isLoading || !isViewingPast || _isPageChanging)
                      ? null
                      : () async {
                          _isPageChanging = true;
                          await provider.selectNextPeriod();
                          _isPageChanging = false;
                        },
                    icon: const Icon(Icons.chevron_right),
                    color: isViewingPast ? Colors.grey.shade400 : Colors.grey.shade300,
                    iconSize: 28,
                    disabledColor: Colors.grey.shade300,
                  ),
                ),
              ),
            ],
          ),
        ),

        // "Back to Current" button (only show when viewing past)
        if (isViewingPast)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton.icon(
              onPressed: (provider.isLoading || _isPageChanging) ? null : () {
                // Return to current period based on currently selected preset type
                final currentPreset = _getCurrentPresetFromCustomRange(provider);
                provider.setDateRange(currentPreset);
              },
              icon: const Icon(Icons.today, size: 16),
              label: const Text('Trở về hiện tại'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.green,
                textStyle: const TextStyle(fontSize: 13),
              ),
            ),
          ),
      ],
    );
  }

  DateRangePreset _getCurrentPresetFromCustomRange(ReportProvider provider) {
    // Determine what the "current" preset should be based on the time range being viewed
    final now = DateTime.now();
    final rangeInDays = provider.selectedDateRange.duration.inDays;

    if (rangeInDays <= 7) return DateRangePreset.thisWeek;
    if (rangeInDays <= 31) return DateRangePreset.thisMonth;
    return DateRangePreset.thisYear;
  }

  bool _isActuallyViewingPast(ReportProvider provider) {
    // Check if the selected date range is actually in the PAST
    // by comparing range end with current period end based on preset type
    final now = DateTime.now();
    final selectedEnd = provider.selectedDateRange.end;

    // Get current period end based on selected preset type
    DateTime currentPeriodEnd;
    switch (provider.selectedPreset) {
      case DateRangePreset.thisWeek:
      case DateRangePreset.custom:
        // Current week end (Sunday)
        final firstDayOfWeek = now.subtract(Duration(days: now.weekday - 1));
        currentPeriodEnd = firstDayOfWeek.add(const Duration(days: 6));
        break;
      case DateRangePreset.thisMonth:
        // Current month end
        currentPeriodEnd = DateTime(now.year, now.month + 1, 0);
        break;
      case DateRangePreset.thisYear:
        // Current year end
        currentPeriodEnd = DateTime(now.year, 12, 31);
        break;
      default:
        currentPeriodEnd = now;
    }

    // Viewing past if selected range ends BEFORE current period end (with 1 day tolerance)
    return selectedEnd.isBefore(currentPeriodEnd.subtract(const Duration(days: 1)));
  }

  Widget _buildChartPage(ReportProvider provider) {
    if (provider.revenueTrend.isEmpty) {
      return const Center(child: Text("Không có dữ liệu xu hướng."));
    }

    final currentSpots = provider.revenueTrend.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.currentPeriodRevenue);
    }).toList();

    final previousSpots = provider.revenueTrend.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.previousPeriodRevenue);
    }).toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),

        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final date = provider.revenueTrend[spot.spotIndex].reportDate;
                final revenue = spot.y;
                return LineTooltipItem(
                  '${DateFormat.MMMd().format(date)}\n${AppFormatter.formatCurrency(revenue)}',
                  const TextStyle(color: Colors.white),
                );
              }).toList();
            },
          ),
        ),

        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: (provider.revenueTrend.length / 5).ceil().toDouble(),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= provider.revenueTrend.length) return const SizedBox();
                final date = provider.revenueTrend[index].reportDate;
                return SideTitleWidget(
                  meta: meta,
                  space: 10,
                  child: Text(DateFormat.MMMd().format(date), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                );
              },
            ),
          ),
        ),

        lineBarsData: [
          // Previous period line (dashed and faint)
          LineChartBarData(
            spots: previousSpots,
            isCurved: true,
            color: Colors.grey.withOpacity(0.5),
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            dashArray: [5, 5],
            belowBarData: BarAreaData(show: false),
          ),
          // Current period line (solid, gradient, with area)
          LineChartBarData(
            spots: currentSpots,
            isCurved: true,
            gradient: const LinearGradient(
              colors: [Colors.green, Colors.teal],
            ),
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [Colors.green.withOpacity(0.3), Colors.teal.withOpacity(0.0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankings(ReportProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Bảng Xếp Hạng', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        _buildTopProductsCard(provider),

      ],
    );
  }

  // ===========================================================================
  // TAB 2: INVENTORY DASHBOARD (Tổng Quan Tồn Kho)
  // ===========================================================================
  Widget _buildInventoryTab(ReportProvider provider) {
    final analytics = provider.inventoryAnalytics;

    if (analytics == null) {
      return const Center(child: Text('Không có dữ liệu tồn kho'));
    }

    return RefreshIndicator(
      onRefresh: () => provider.loadInventoryData(forceRefresh: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section 1: Giá trị Tồn kho
          Text('Giá Trị Tồn Kho', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _buildInventoryValueMetrics(analytics),

          const SizedBox(height: 24),

          // Section 2: Cảnh báo Hành động
          Text('Cảnh Báo & Hành Động', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _buildInventoryAlerts(analytics),

          const SizedBox(height: 24),

          // Section 3: Phân tích Tồn kho
          Text('Phân Tích Tồn Kho', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _buildInventoryAnalytics(provider),
        ],
      ),
    );
  }

  /// Section 1: Widget "Giá trị Tồn kho" - 3 financial metrics
  Widget _buildInventoryValueMetrics(InventoryAnalytics analytics) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    'Giá Mua Vào',
                    AppFormatter.formatCompactCurrency(analytics.totalInventoryValue),
                    Icons.shopping_cart,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricItem(
                    'Giá Bán Ra',
                    AppFormatter.formatCompactCurrency(analytics.totalSellingValue),
                    Icons.sell,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildMetricItem(
              'Lợi Nhuận Tiềm Năng (${analytics.profitMargin.toStringAsFixed(1)}%)',
              AppFormatter.formatCompactCurrency(analytics.potentialProfit),
              Icons.trending_up,
              Colors.teal,
            ),
          ],
        ),
      ),
    );
  }

  /// Section 2: Widget "Cảnh báo Hành động" - 3 actionable alerts
  Widget _buildInventoryAlerts(InventoryAnalytics analytics) {
    return Column(
      children: [
        _buildAlertCard(
          title: 'Tồn Kho Thấp',
          count: analytics.lowStockItems,
          icon: Icons.inventory_2_outlined,
          color: analytics.lowStockItems > 0 ? Colors.orange : Colors.grey.shade400,
          subtitle: analytics.lowStockItems == 0 ? 'Tất cả sản phẩm đầy đủ' : null,
          onTap: analytics.lowStockItems > 0
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LowStockReportScreen()),
                  );
                }
              : null,
        ),
        const SizedBox(height: 8),
        _buildAlertCard(
          title: 'Sắp Hết Hạn',
          count: analytics.expiringSoonItems,
          icon: Icons.warning_amber_rounded,
          color: analytics.expiringSoonItems > 0 ? Colors.red : Colors.grey.shade400,
          subtitle: analytics.expiringSoonItems == 0 ? 'Không có hàng sắp hết hạn' : null,
          onTap: analytics.expiringSoonItems > 0
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ExpiryReportScreen()),
                  );
                }
              : null,
        ),
        const SizedBox(height: 8),
        _buildAlertCard(
          title: 'Hàng Ế',
          count: analytics.slowMovingItems,
          icon: Icons.pause_circle_outline,
          color: analytics.slowMovingItems > 0 ? Colors.grey.shade700 : Colors.grey.shade400,
          subtitle: analytics.slowMovingItems == 0 ? 'Hàng hóa luân chuyển tốt' : null,
          onTap: analytics.slowMovingItems > 0
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SlowMovingReportScreen()),
                  );
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildAlertCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    final isDisabled = onTap == null;

    return Card(
      elevation: isDisabled ? 0 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: isDisabled ? Colors.grey.shade50 : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDisabled ? Colors.grey.shade600 : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$count sản phẩm',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: count > 0 ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: isDisabled ? Colors.grey.shade300 : Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Section 3: Widget "Phân tích Tồn kho" - 3 expandable ranking lists
  Widget _buildInventoryAnalytics(ReportProvider provider) {
    return Column(
      children: [
        _buildExpandableProductList(
          title: 'Top 5 Sản Phẩm Giá Trị Cao',
          products: provider.topValueProducts,
          icon: Icons.star,
          color: Colors.amber,
          valueLabel: 'Giá trị',
          isValueMetric: true,
        ),
        const SizedBox(height: 8),
        _buildExpandableProductList(
          title: 'Top 5 Hàng Bán Nhanh',
          products: provider.fastTurnoverProducts,
          icon: Icons.speed,
          color: Colors.green,
          valueLabel: 'Tỷ lệ',
          isValueMetric: false,
        ),
        const SizedBox(height: 8),
        _buildExpandableProductList(
          title: 'Top 5 Hàng Bán Chậm',
          products: provider.slowTurnoverProducts,
          icon: Icons.slow_motion_video,
          color: Colors.grey,
          valueLabel: 'Tỷ lệ',
          isValueMetric: false,
        ),
      ],
    );
  }

  Widget _buildExpandableProductList({
    required String title,
    required List products,
    required IconData icon,
    required Color color,
    required String valueLabel,
    required bool isValueMetric,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            '${products.length} sản phẩm',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          children: products.isEmpty
              ? [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Không có dữ liệu',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ]
              : products.map<Widget>((product) {
                  return ListTile(
                    dense: true,
                    title: Text(
                      product.productName,
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(
                      product.sku,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          valueLabel,
                          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        ),
                        Text(
                          isValueMetric
                              ? AppFormatter.formatCompactCurrency(product.metricValue)
                              : product.metricValue.toStringAsFixed(2),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 3: PRODUCT PERFORMANCE (Placeholder)
  // ===========================================================================
  Widget _buildProductsTab(ReportProvider provider) {
    return const Center(child: Text('Nội dung Sản Phẩm sắp ra mắt'));
  }

  // ===========================================================================
  // SHARED WIDGETS (Could be moved to shared/widgets)
  // ===========================================================================

  Widget _buildTopProductsCard(ReportProvider provider) {
    final topProducts = provider.topProducts;
    if (topProducts.isEmpty) {
      return const Card(child: ListTile(title: Text('Không có dữ liệu sản phẩm bán chạy')));
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Top 5 Sản Phẩm Bán Chạy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          ...topProducts.map((product) {
            return ListTile(
              title: Text(product.productName),
              subtitle: Text('Số lượng: ${product.totalQuantity.toStringAsFixed(0)}'),
              trailing: Text(AppFormatter.formatCurrency(product.totalRevenue)),
            );
          }).toList(),
        ],
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
}

// Extension to give readable names to presets
extension on DateRangePreset {
  String get name {
    switch (this) {
      case DateRangePreset.today:
        return 'Hôm nay';
      case DateRangePreset.thisWeek:
        return 'Tuần này';
      case DateRangePreset.thisMonth:
        return 'Tháng này';
      case DateRangePreset.thisQuarter:
        return 'Quý này';
      case DateRangePreset.thisYear:
        return 'Năm nay';
      case DateRangePreset.custom:
        return 'Tùy chỉnh';
    }
  }
}