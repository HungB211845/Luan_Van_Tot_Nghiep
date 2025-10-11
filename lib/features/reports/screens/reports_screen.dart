import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../providers/report_provider.dart';
import '../models/inventory_analytics.dart';
import '../../../shared/utils/formatter.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/utils/responsive.dart';
import 'package:agricultural_pos/features/products/screens/reports/expiry_report_screen.dart';
import 'package:agricultural_pos/features/products/screens/reports/low_stock_report_screen.dart';
import 'package:agricultural_pos/features/products/screens/reports/slow_moving_report_screen.dart';
import 'top_value_products_screen.dart';
import 'fast_turnover_products_screen.dart';
import 'slow_turnover_products_screen.dart';

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

  /// Helper to get tax period description
  String _getTaxPeriodDescription(DateTimeRange range) {
    final start = DateFormat('dd/MM/yyyy').format(range.start);
    final end = DateFormat('dd/MM/yyyy').format(range.end);
    return 'Từ $start đến $end';
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
        return ResponsiveScaffold(
          title: 'Báo Cáo Kinh Doanh',
          body: provider.isLoading
              ? const Center(child: LoadingWidget())
              : context.adaptiveWidget(
                  mobile: _buildMobileLayout(provider),
                  tablet: _buildTabletLayout(provider), 
                  desktop: _buildDesktopLayout(provider),
                ),
        );
      },
    );
  }

  // Mobile Layout: Standard TabBar
  Widget _buildMobileLayout(ReportProvider provider) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: Colors.green,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.green,
          tabs: const [
            Tab(icon: Icon(Icons.trending_up), text: 'Doanh Thu'),
            Tab(icon: Icon(Icons.inventory), text: 'Tồn Kho'),
            Tab(icon: Icon(Icons.receipt_long), text: 'Thuế'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildRevenueTab(provider),
              _buildInventoryTab(provider),
              _buildTaxTab(provider),
            ],
          ),
        ),
      ],
    );
  }

  // Tablet Layout: Side tabs with larger content area
  Widget _buildTabletLayout(ReportProvider provider) {
    return Row(
      children: [
        // Side Navigation Panel
        Container(
          width: context.adaptiveValue(mobile: 200.0, tablet: 250.0, desktop: 300.0),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(right: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Column(
            children: [
              _buildTabletNavigationTile(
                index: 0,
                icon: Icons.trending_up,
                title: 'Doanh Thu',
                subtitle: 'Phân tích doanh thu',
                provider: provider,
              ),
              _buildTabletNavigationTile(
                index: 1,
                icon: Icons.inventory,
                title: 'Tồn Kho',
                subtitle: 'Quản lý kho hàng',
                provider: provider,
              ),
              _buildTabletNavigationTile(
                index: 2,
                icon: Icons.receipt_long,
                title: 'Thuế',
                subtitle: 'Báo cáo thuế',
                provider: provider,
              ),
            ],
          ),
        ),
        
        // Content Area
        Expanded(
          child: Container(
            padding: EdgeInsets.all(context.sectionPadding),
            child: _getCurrentTabContent(provider),
          ),
        ),
      ],
    );
  }

  // Desktop Layout: Master-Detail with enhanced navigation
  Widget _buildDesktopLayout(ReportProvider provider) {
    return Row(
      children: [
        // Enhanced Side Navigation
        Container(
          width: 320,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(right: BorderSide(color: Colors.grey.shade200)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(2, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              // Navigation Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade600, Colors.green.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.analytics, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Business Analytics',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Navigation Items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  children: [
                    _buildDesktopNavigationTile(
                      index: 0,
                      icon: Icons.trending_up,
                      title: 'Revenue Analytics',
                      subtitle: 'Track revenue trends and performance',
                      provider: provider,
                    ),
                    _buildDesktopNavigationTile(
                      index: 1,
                      icon: Icons.inventory_2,
                      title: 'Inventory Management', 
                      subtitle: 'Monitor stock levels and alerts',
                      provider: provider,
                    ),
                    _buildDesktopNavigationTile(
                      index: 2,
                      icon: Icons.receipt_long,
                      title: 'Tax Reporting',
                      subtitle: 'Calculate tax obligations',
                      provider: provider,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Main Content Area
        Expanded(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            padding: const EdgeInsets.all(32),
            child: _getCurrentTabContent(provider),
          ),
        ),
      ],
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
          selectedBackgroundColor: Colors.green,
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

  // ===========================================================================
  // TAB 2: INVENTORY DASHBOARD (Apple HIG Grouped List Style)
  // ===========================================================================
  Widget _buildInventoryTab(ReportProvider provider) {
    final analytics = provider.inventoryAnalytics;

    if (analytics == null) {
      return const Center(child: Text('Không có dữ liệu tồn kho'));
    }

    return RefreshIndicator(
      onRefresh: () => provider.loadInventoryData(forceRefresh: true),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // Section 1: Giá trị Tồn kho
          _buildSectionHeader('GIÁ TRỊ TỒN KHO'),
          _buildValueMetricsGroup(analytics),

          const SizedBox(height: 32),

          // Section 2: Cảnh báo
          _buildSectionHeader('CẢNH BÁO'),
          _buildAlertsGroup(analytics),

          const SizedBox(height: 32),

          // Section 3: Phân tích
          _buildSectionHeader('PHÂN TÍCH'),
          _buildAnalyticsGroup(provider),
        ],
      ),
    );
  }

  /// iOS-style section header
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// Section 1: Value Metrics - Simple rows without decoration colors
  Widget _buildValueMetricsGroup(InventoryAnalytics analytics) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
      ),
      child: Column(
        children: [
          _buildValueRow(
            label: 'Giá Trị Kho (Giá vốn)',
            value: AppFormatter.formatCurrency(analytics.totalInventoryValue),
            isFirst: true,
          ),
          Divider(height: 1, thickness: 0.5, color: Colors.grey.shade300),
          _buildValueRow(
            label: 'Giá Trị Hàng Hóa (Giá bán)',
            value: AppFormatter.formatCurrency(analytics.totalSellingValue),
          ),
          Divider(height: 1, thickness: 0.5, color: Colors.grey.shade300),
          _buildValueRow(
            label: 'Lợi Nhuận Tiềm Năng',
            value: AppFormatter.formatCurrency(analytics.potentialProfit),
            valueColor: Colors.green, // Semantic color: positive indicator
            subtitle: '${analytics.profitMargin.toStringAsFixed(1)}% biên lợi nhuận',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildValueRow({
    required String label,
    required String value,
    Color? valueColor,
    String? subtitle,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  /// Section 2: Alerts - Navigable rows with semantic colors
  Widget _buildAlertsGroup(InventoryAnalytics analytics) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
      ),
      child: Column(
        children: [
          _buildAlertRow(
            label: 'Sắp hết hàng',
            count: analytics.lowStockItems,
            icon: Icons.inventory_2_outlined,
            color: analytics.lowStockItems > 0 ? Colors.orange : null,
            onTap: analytics.lowStockItems > 0
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LowStockReportScreen()),
                    );
                  }
                : null,
            isFirst: true,
          ),
          Divider(height: 1, thickness: 0.5, color: Colors.grey.shade300),
          _buildAlertRow(
            label: 'Sắp hết hạn',
            count: analytics.expiringSoonItems,
            icon: Icons.schedule,
            color: analytics.expiringSoonItems > 0 ? Colors.red : null,
            onTap: analytics.expiringSoonItems > 0
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ExpiryReportScreen()),
                    );
                  }
                : null,
          ),
          Divider(height: 1, thickness: 0.5, color: Colors.grey.shade300),
          _buildAlertRow(
            label: 'Hàng ế',
            count: analytics.slowMovingItems,
            icon: Icons.pause_circle_outline,
            color: analytics.slowMovingItems > 0 ? Colors.grey.shade700 : null,
            onTap: analytics.slowMovingItems > 0
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SlowMovingReportScreen()),
                    );
                  }
                : null,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildAlertRow({
    required String label,
    required int count,
    required IconData icon,
    Color? color,
    VoidCallback? onTap,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final hasAlert = count > 0;
    final displayColor = color ?? Colors.grey.shade400;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(10) : Radius.zero,
        bottom: isLast ? const Radius.circular(10) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: displayColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: hasAlert ? null : Colors.grey.shade600,
                ),
              ),
            ),
            Text(
              '$count sản phẩm',
              style: TextStyle(
                fontSize: 14,
                fontWeight: hasAlert ? FontWeight.w600 : FontWeight.w400,
                color: hasAlert ? displayColor : Colors.grey.shade500,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: Colors.grey.shade400,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// Section 3: Analytics - Navigable rows to dedicated screens
  Widget _buildAnalyticsGroup(ReportProvider provider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
      ),
      child: Column(
        children: [
          _buildAnalyticsRow(
            label: 'Top Sản phẩm Giá trị cao',
            count: provider.topValueProducts.length,
            icon: Icons.inventory,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TopValueProductsScreen()),
              );
            },
            isFirst: true,
          ),
          Divider(height: 1, thickness: 0.5, color: Colors.grey.shade300),
          _buildAnalyticsRow(
            label: 'Top Hàng bán nhanh',
            count: provider.fastTurnoverProducts.length,
            icon: Icons.speed,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FastTurnoverProductsScreen()),
              );
            },
          ),
          Divider(height: 1, thickness: 0.5, color: Colors.grey.shade300),
          _buildAnalyticsRow(
            label: 'Top Hàng bán chậm',
            count: provider.slowTurnoverProducts.length,
            icon: Icons.slow_motion_video,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SlowTurnoverProductsScreen()),
              );
            },
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsRow({
    required String label,
    required int count,
    required IconData icon,
    required VoidCallback onTap,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(10) : Radius.zero,
        bottom: isLast ? const Radius.circular(10) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey.shade700, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Text(
              '$count sản phẩm',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: Colors.grey.shade400,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 3: TAX DASHBOARD
  // ===========================================================================
  Widget _buildTaxTab(ReportProvider provider) {
    final taxSummary = provider.taxSummary;

    if (taxSummary == null) {
      return const Center(child: Text('Không có dữ liệu thuế'));
    }

    return RefreshIndicator(
      onRefresh: () => provider.loadTaxData(forceRefresh: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Time Range Selector for Tax Period
          _buildTaxTimeRangeSelector(provider),
          const SizedBox(height: 16),

          // Tax Obligation Summary Card
          _buildTaxObligationCard(taxSummary, provider),
          const SizedBox(height: 16),

          // Revenue Breakdown Card
          _buildRevenueBreakdownCard(taxSummary),
          const SizedBox(height: 16),

          // Expense Breakdown Card
          _buildExpenseBreakdownCard(taxSummary),
          const SizedBox(height: 16),

          // Actions Section
          _buildTaxActionsCard(),
        ],
      ),
    );
  }

  /// Tax-specific time range selector with month as default
  Widget _buildTaxTimeRangeSelector(ReportProvider provider) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'KHOẢNG THỜI GIAN KÊ KHAI',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            
            // Remove AnimatedSwitcher to prevent rebuilds - use simple SegmentedButton
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<DateRangePreset>(
                segments: const [
                  ButtonSegment(value: DateRangePreset.thisWeek, label: Text('Tuần')),
                  ButtonSegment(value: DateRangePreset.thisMonth, label: Text('Tháng')),
                  ButtonSegment(value: DateRangePreset.thisQuarter, label: Text('Quý')),
                  ButtonSegment(value: DateRangePreset.thisYear, label: Text('Năm')),
                ],
                selected: {provider.selectedPreset},
                onSelectionChanged: (newSelection) {
                  // Immediate UI update without await to prevent blocking
                  provider.setDateRangeForTaxSilent(newSelection.first);
                },
                style: SegmentedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  selectedBackgroundColor: Colors.green,
                  selectedForegroundColor: Colors.white,
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Simple text without AnimatedSwitcher
            Text(
              _getTaxPeriodDescription(provider.selectedDateRange),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Widget 2: Tax Obligation Summary Card
  Widget _buildTaxObligationCard(taxSummary, ReportProvider provider) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'NGHĨA VỤ THUẾ',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),

            // Tổng Doanh Thu Kê Khai
            _buildTaxSummaryRow(
              label: 'Tổng Doanh thu Kê khai',
              value: AppFormatter.formatCurrency(taxSummary.totalRevenue),
            ),
            const Divider(height: 24),

            // Thuế Phải Nộp (Highlighted)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'THUẾ PHẢI NỘP (1.5%)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  AppFormatter.formatCurrency(taxSummary.estimatedTax),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Hạn Nộp (Placeholder - will calculate from period)
            Text(
              'Hạn nộp: ${_getTaxDeadline(provider.selectedDateRange)}',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Widget 3: Revenue Breakdown Card
  Widget _buildRevenueBreakdownCard(taxSummary) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DIỄN GIẢI DOANH THU',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),

            _buildTaxSummaryRow(
              label: 'Doanh thu Bán hàng (POS)',
              value: AppFormatter.formatCurrency(taxSummary.totalRevenue),
              subtitle: '${taxSummary.totalTransactions} giao dịch',
            ),
            const Divider(height: 24),

            _buildTaxSummaryRow(
              label: 'Doanh thu từ các nguồn khác',
              value: AppFormatter.formatCurrency(0),
              subtitle: 'Chưa áp dụng',
              isPlaceholder: true,
            ),
            const Divider(height: 24),

            _buildTaxSummaryRow(
              label: 'TỔNG DOANH THU KÊ KHAI',
              value: AppFormatter.formatCurrency(taxSummary.totalRevenue),
              isBold: true,
            ),
          ],
        ),
      ),
    );
  }

  /// Widget 4: Expense Breakdown Card
  Widget _buildExpenseBreakdownCard(taxSummary) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DIỄN GIẢI CHI PHÍ',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),

            _buildTaxSummaryRow(
              label: 'Chi phí Nhập hàng (PO)',
              value: AppFormatter.formatCurrency(taxSummary.totalExpenses),
            ),
            const Divider(height: 24),

            _buildTaxSummaryRow(
              label: 'Chi phí Vận hành khác',
              value: AppFormatter.formatCurrency(0),
              subtitle: 'Chưa áp dụng',
              isPlaceholder: true,
            ),
            const Divider(height: 24),

            _buildTaxSummaryRow(
              label: 'TỔNG CHI PHÍ',
              value: AppFormatter.formatCurrency(taxSummary.totalExpenses),
              isBold: true,
            ),
            const SizedBox(height: 16),

            // Lợi nhuận thực (Info only)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lợi nhuận thực (sau thuế)',
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                      Text(
                        '${taxSummary.profitMargin.toStringAsFixed(1)}% biên lợi nhuận',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  Text(
                    AppFormatter.formatCurrency(taxSummary.netProfit),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Widget 5: Actions Card with Export Functionality
  Widget _buildTaxActionsCard() {
    return Consumer<ReportProvider>(
      builder: (context, provider, child) {
        // Platform-specific subtitle text
        String getExportSubtitle() {
          if (kIsWeb) {
            return 'Chức năng xuất file chưa hỗ trợ trên web, vui lòng sử dụng ứng dụng mobile';
          } else if (context.isMobile) {
            return 'Chia sẻ qua AirDrop, Email hoặc lưu vào Files';
          } else {
            return 'Lưu file CSV vào máy tính của bạn';
          }
        }

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              ListTile(
                leading: provider.isExporting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download, color: Colors.green),
                title: const Text('Xuất Bảng kê Bán hàng'),
                subtitle: Text(
                  provider.isExporting
                      ? 'Đang tạo và xử lý file...'
                      : getExportSubtitle(),
                ),
                trailing: provider.isExporting
                    ? null
                    : const Icon(Icons.chevron_right),
                onTap: provider.isExporting
                    ? null
                    : () async {
                        await provider.exportSalesLedgerAction();
                        
                        // Show error snackbar if export failed
                        if (provider.exportError != null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(provider.exportError!),
                              backgroundColor: Colors.red,
                              action: SnackBarAction(
                                label: 'Thử lại',
                                textColor: Colors.white,
                                onPressed: () => provider.exportSalesLedgerAction(),
                              ),
                            ),
                          );
                        } else if (provider.exportError == null && context.mounted) {
                          // Show success message for desktop (mobile has native feedback)
                          if (!context.isMobile && !kIsWeb) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('✅ File đã được lưu thành công!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        }
                      },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.description, color: Colors.blue),
                title: const Text('Xuất Tờ khai Thuế (Mẫu 01/CNKD)'),
                subtitle: const Text('Xem và sao chép thông tin cho tờ khai'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Màn hình tờ khai sẽ được triển khai sau')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Helper widget for tax summary rows
  Widget _buildTaxSummaryRow({
    required String label,
    required String value,
    String? subtitle,
    bool isBold = false,
    bool isPlaceholder = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: isBold ? 15 : 14,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  color: isPlaceholder ? Colors.grey.shade500 : null,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 16),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 15,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isPlaceholder ? Colors.grey.shade500 : Colors.black87,
          ),
        ),
      ],
    );
  }

  void _loadDataForCurrentTab() {
    final provider = context.read<ReportProvider>();
    final currentTab = _tabController.index;

    switch (currentTab) {
      case 0: // Revenue Tab
        // Check if data already loaded from preload cache - NO FORCE REFRESH
        if (!provider.revenueLoaded) {
          provider.loadRevenueData(forceRefresh: false);
        }
        break;
      case 1: // Inventory Tab
        // Check if data already loaded from preload cache - NO FORCE REFRESH
        if (!provider.inventoryLoaded) {
          provider.loadInventoryData(forceRefresh: false);
        }
        break;
      case 2: // Tax Tab
        // Check if data already loaded from preload cache - NO FORCE REFRESH
        if (!provider.taxLoaded) {
          provider.loadTaxData(forceRefresh: false);
        }
        break;
    }
  }

  // Helper: Get current tab content based on selected index
  Widget _getCurrentTabContent(ReportProvider provider) {
    switch (_tabController.index) {
      case 0:
        return _buildRevenueTab(provider);
      case 1:
        return _buildInventoryTab(provider);
      case 2:
        return _buildTaxTab(provider);
      default:
        return _buildRevenueTab(provider);
    }
  }

  // Tablet Navigation Tile
  Widget _buildTabletNavigationTile({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    required ReportProvider provider,
  }) {
    final isSelected = _tabController.index == index;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? Colors.green : Colors.grey.shade600,
          size: 24,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.green : Colors.grey.shade800,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        selected: isSelected,
        selectedTileColor: Colors.green.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        onTap: () {
          _tabController.animateTo(index);
          _loadDataForCurrentTab();
        },
      ),
    );
  }

  // Desktop Navigation Tile (Enhanced)
  Widget _buildDesktopNavigationTile({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    required ReportProvider provider,
  }) {
    final isSelected = _tabController.index == index;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: isSelected ? Colors.green.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            _tabController.animateTo(index);
            _loadDataForCurrentTab();
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? Colors.green.withOpacity(0.2)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.green : Colors.grey.shade600,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.green.shade700 : Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Helper to calculate tax deadline based on period
  String _getTaxDeadline(DateTimeRange range) {
    // Tax deadline is typically the 20th of the month following the tax period
    final lastDayOfPeriod = range.end;
    final deadlineMonth = lastDayOfPeriod.month == 12 ? 1 : lastDayOfPeriod.month + 1;
    final deadlineYear = lastDayOfPeriod.month == 12 ? lastDayOfPeriod.year + 1 : lastDayOfPeriod.year;
    final deadline = DateTime(deadlineYear, deadlineMonth, 20);
    return DateFormat('dd/MM/yyyy').format(deadline);
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