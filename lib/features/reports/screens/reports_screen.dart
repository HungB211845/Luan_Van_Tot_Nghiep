import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../providers/report_provider.dart';
import '../models/inventory_analytics.dart';
import '../models/tax_summary.dart';
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
  const ReportsScreen({super.key});

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

    // Load initial tab data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDataBasedOnPlatform();
    });
  }

  void _loadDataBasedOnPlatform() {
    final provider = context.read<ReportProvider>();
    
    // Get screen size để determine platform
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1200 || kIsWeb;
    
    if (isDesktop) {
      // Desktop: Load all 3 tabs data simultaneously for triple-column layout
      print('🖥️ Desktop detected - loading all dashboard data simultaneously');
      provider.loadDashboardData(forceRefresh: false);
    } else {
      // Mobile/Tablet: Load only current tab data (lazy loading)
      print('📱 Mobile/Tablet detected - loading current tab only');
      _loadDataForCurrentTab();
    }
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

  String _formatTaxRate(double rate) {
    if ((rate - rate.round()).abs() < 0.0001) {
      return '${rate.toStringAsFixed(0)}%';
    }
    return '${rate.toStringAsFixed(2)}%';
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
        // Debug logging for desktop data loading
        if (kDebugMode && kIsWeb) {
          print('🔍 DEBUG Reports Build:');
          print('  - Screen width: ${MediaQuery.of(context).size.width}');
          print('  - Revenue loaded: ${provider.revenueLoaded}');
          print('  - Inventory loaded: ${provider.inventoryLoaded}');
          print('  - Tax loaded: ${provider.taxLoaded}');
          print('  - Is loading: ${provider.isLoading}');
        }
        
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

  Widget _buildTabbedLayout(ReportProvider provider, {EdgeInsets? padding}) {
    final content = Column(
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

    if (padding != null) {
      return Padding(
        padding: padding,
        child: content,
      );
    }

    return content;
  }

  // Mobile Layout: Standard TabBar
  Widget _buildMobileLayout(ReportProvider provider) {
    return _buildTabbedLayout(provider);
  }

  // Tablet Layout: Side tabs with larger content area
  Widget _buildTabletLayout(ReportProvider provider) {
    return _buildTabbedLayout(
      provider,
      padding: EdgeInsets.all(context.sectionPadding),
    );
  }

  // Desktop Layout: Triple-column dashboard - ALL TABS VISIBLE SIMULTANEOUSLY
  Widget _buildDesktopLayout(ReportProvider provider) {
    // Force load all data on first build if not loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!provider.inventoryLoaded) {
        print('🔧 FORCE: Desktop layout triggering inventory load');
        provider.loadInventoryData(forceRefresh: false);
      }
      if (!provider.taxLoaded) {
        print('🔧 FORCE: Desktop layout triggering tax load');
        provider.loadTaxData(forceRefresh: false);
      }
      if (!provider.revenueLoaded) {
        print('🔧 FORCE: Desktop layout triggering revenue load');
        provider.loadRevenueData(forceRefresh: false);
      }
    });
    
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Desktop Header
          Container(
            padding: const EdgeInsets.only(bottom: 24),
            child: Row(
              children: [
                Icon(Icons.analytics, color: Colors.green, size: 32),
                const SizedBox(width: 16),
                const Text(
                  'Business Analytics Dashboard',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          
          // Triple-column content (1/3 - 1/3 - 1/3)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Column 1: Revenue Analytics (1/3)
                Expanded(
                  flex: 1,
                  child: _buildCompactRevenueTab(provider),
                ),
                const SizedBox(width: 24),
                
                // Column 2: Inventory Management (1/3)
                Expanded(
                  flex: 1,
                  child: _buildCompactInventoryTab(provider),
                ),
                const SizedBox(width: 24),
                
                // Column 3: Tax Reporting (1/3)
                Expanded(
                  flex: 1,
                  child: _buildCompactTaxTab(provider),
                ),
              ],
            ),
          ),
        ],
      ),
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
    final selectedEnd = provider.selectedDateRange.end;

    // Get current period end based on selected preset type
    DateTime currentPeriodEnd;
    switch (provider.selectedPreset) {
      case DateRangePreset.thisWeek:
      case DateRangePreset.custom:
        // Current week end (Sunday)
        final now = DateTime.now();
        final firstDayOfWeek = now.subtract(Duration(days: now.weekday - 1));
        currentPeriodEnd = firstDayOfWeek.add(const Duration(days: 6));
        break;
      case DateRangePreset.thisMonth:
        // Current month end
        final now = DateTime.now();
        currentPeriodEnd = DateTime(now.year, now.month + 1, 0);
        break;
      case DateRangePreset.thisYear:
        // Current year end
        final now = DateTime.now();
        currentPeriodEnd = DateTime(now.year, 12, 31);
        break;
      default:
        currentPeriodEnd = DateTime.now();
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
  Widget _buildTaxObligationCard(TaxSummary taxSummary, ReportProvider provider) {
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
                Text(
                  'THUẾ PHẢI NỘP (${_formatTaxRate(taxSummary.taxRate)})',
                  style: const TextStyle(
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
            const SizedBox(height: 4),
            Text(
              'Mức thuế khoán có thể điều chỉnh tại Cài đặt hóa đơn.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
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
                  Expanded(
                    child: Column(
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
                  ),
                  const SizedBox(width: 8),
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

  // Helper: Get tax deadline based on period
  String _getTaxDeadline(DateTimeRange range) {
    // Tax deadline is typically the 20th of the month following the tax period
    final lastDayOfPeriod = range.end;
    final deadlineMonth = lastDayOfPeriod.month == 12 ? 1 : lastDayOfPeriod.month + 1;
    final deadlineYear = lastDayOfPeriod.month == 12 ? lastDayOfPeriod.year + 1 : lastDayOfPeriod.year;
    final deadline = DateTime(deadlineYear, deadlineMonth, 20);
    return DateFormat('dd/MM/yyyy').format(deadline);
  }

  // ===========================================================================
  // COMPACT DESKTOP LAYOUTS - TRIPLE COLUMN DESIGN
  // ===========================================================================

  /// Compact Revenue Tab for Desktop Triple-Column Layout
  Widget _buildCompactRevenueTab(ReportProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Column Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade600, Colors.green.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.trending_up, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Revenue Analytics',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Track revenue trends',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Content Area
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => provider.loadRevenueData(forceRefresh: true),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCompactMetrics(provider),
                    const SizedBox(height: 24),
                    _buildCompactChart(provider),
                    const SizedBox(height: 20),
                    _buildCompactTimeSelector(provider),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Compact Inventory Tab for Desktop Triple-Column Layout
  Widget _buildCompactInventoryTab(ReportProvider provider) {
    final analytics = provider.inventoryAnalytics;
    final isLoading = provider.isLoading;
    
    if (kDebugMode) {
      print('🔍 DEBUG Compact Inventory Tab:');
      print('  - analytics: ${analytics != null ? "loaded" : "null"}');
      print('  - isLoading: $isLoading');
      print('  - inventoryLoaded: ${provider.inventoryLoaded}');
    }
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Column Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade600, Colors.blue.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.inventory_2, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inventory Management',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Monitor stock levels',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Content Area
          Expanded(
            child: analytics == null && !provider.inventoryLoaded
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Đang tải dữ liệu tồn kho...'),
                      ],
                    ),
                  )
                : analytics == null
                  ? const Center(child: Text('Không có dữ liệu tồn kho'))
                  : RefreshIndicator(
                      onRefresh: () => provider.loadInventoryData(forceRefresh: true),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Section 1: Giá trị Tồn kho
                            const Text(
                              'GIÁ TRỊ TỒN KHO',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildCompactValueMetrics(analytics),
                            const SizedBox(height: 24),
                            _buildCompactAlerts(analytics),
                            const SizedBox(height: 24),
                            _buildCompactAnalytics(provider),
                          ],
                        ),
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  /// Compact Tax Tab for Desktop Triple-Column Layout
  Widget _buildCompactTaxTab(ReportProvider provider) {
    final taxSummary = provider.taxSummary;
    final isLoading = provider.isLoading;
    
    if (kDebugMode) {
      print('🔍 DEBUG Compact Tax Tab:');
      print('  - taxSummary: ${taxSummary != null ? "loaded" : "null"}');
      print('  - isLoading: $isLoading');
      print('  - taxLoaded: ${provider.taxLoaded}');
    }
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Column Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade600, Colors.orange.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tax Reporting',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Calculate tax obligations',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Content Area
          Expanded(
            child: taxSummary == null && !provider.taxLoaded
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Đang tải dữ liệu thuế...'),
                      ],
                    ),
                  )
                : taxSummary == null
                  ? const Center(child: Text('Không có dữ liệu thuế'))
                  : RefreshIndicator(
                      onRefresh: () => provider.loadTaxData(forceRefresh: true),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCompactTaxObligation(taxSummary, provider),
                            const SizedBox(height: 20),
                            _buildCompactTaxBreakdown(taxSummary),
                            const SizedBox(height: 20),
                            _buildCompactTaxTimeSelector(provider),
                          ],
                        ),
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // COMPACT WIDGET HELPERS FOR DESKTOP COLUMNS
  // ===========================================================================

  Widget _buildCompactMetrics(ReportProvider provider) {
    final summary = provider.revenueSummary;
    final percentageChange = summary?['revenue_change_percentage'] as num?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TỔNG DOANH THU',
            style: TextStyle(
              fontSize: 12,
              color: Colors.green.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  AppFormatter.formatCompactCurrency(summary?['current_total_revenue'] ?? 0),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (percentageChange != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: percentageChange >= 0 ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        percentageChange >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                        color: Colors.white,
                        size: 12,
                      ),
                      Text(
                        '${percentageChange.abs().toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${summary?['current_total_transactions'] ?? 0} giao dịch',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactChart(ReportProvider provider) {
    if (provider.revenueTrend.isEmpty) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text(
            "Không có dữ liệu xu hướng",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final currentSpots = provider.revenueTrend.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.currentPeriodRevenue);
    }).toList();

    return SizedBox(
      height: 120,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(show: false),
          lineTouchData: LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: currentSpots,
              isCurved: true,
              color: Colors.green,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.green.withOpacity(0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactTimeSelector(ReportProvider provider) {
    return SegmentedButton<DateRangePreset>(
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        textStyle: const TextStyle(fontSize: 11),
        selectedBackgroundColor: Colors.green,
        selectedForegroundColor: Colors.white,
      ),
    );
  }

  Widget _buildCompactValueMetrics(InventoryAnalytics analytics) {
    return Column(
      children: [
        _buildCompactValueRow(
          'Giá Trị Kho (Giá vốn)',
          AppFormatter.formatCompactCurrency(analytics.totalInventoryValue),
          Colors.blue,
        ),
        const SizedBox(height: 8),
        _buildCompactValueRow(
          'Giá Trị Hàng Hóa (Giá bán)',
          AppFormatter.formatCompactCurrency(analytics.totalSellingValue),
          Colors.indigo,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Lợi Nhuận Tiềm Năng',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    AppFormatter.formatCompactCurrency(analytics.potentialProfit),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${analytics.profitMargin.toStringAsFixed(1)}% biên lợi nhuận',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactValueRow(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactAlerts(InventoryAnalytics analytics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CẢNH BÁO',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        _buildCompactAlertRow(
          'Sắp hết hàng',
          analytics.lowStockItems,
          Colors.orange,
          Icons.inventory_2_outlined,
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
        _buildCompactAlertRow(
          'Sắp hết hạn',
          analytics.expiringSoonItems,
          Colors.red,
          Icons.schedule,
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
        _buildCompactAlertRow(
          'Hàng ế',
          analytics.slowMovingItems,
          Colors.grey.shade700,
          Icons.pause_circle_outline,
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

  Widget _buildCompactAlertRow(String label, int count, Color color, IconData icon, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: count > 0 ? color.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: count > 0 ? color.withOpacity(0.3) : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: count > 0 ? color : Colors.grey, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: count > 0 ? null : Colors.grey.shade600,
                ),
              ),
            ),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 14,
                fontWeight: count > 0 ? FontWeight.bold : FontWeight.w400,
                color: count > 0 ? color : Colors.grey,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
                size: 16,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompactAnalytics(ReportProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PHÂN TÍCH',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        _buildCompactAnalyticsRow(
          'Top Sản phẩm Giá trị cao',
          provider.topValueProducts.length,
          Icons.inventory,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TopValueProductsScreen()),
            );
          },
        ),
        const SizedBox(height: 8),
        _buildCompactAnalyticsRow(
          'Top Hàng bán nhanh',
          provider.fastTurnoverProducts.length,
          Icons.speed,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FastTurnoverProductsScreen()),
            );
          },
        ),
        const SizedBox(height: 8),
        _buildCompactAnalyticsRow(
          'Top Hàng bán chậm',
          provider.slowTurnoverProducts.length,
          Icons.slow_motion_video,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SlowTurnoverProductsScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCompactAnalyticsRow(String label, int count, IconData icon, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.blue.shade700, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
                size: 16,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompactTaxObligation(TaxSummary taxSummary, ReportProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tax Obligation Summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NGHĨA VỤ THUẾ',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tổng Doanh thu Kê khai',
                    style: TextStyle(fontSize: 12),
                  ),
                  Text(
                    AppFormatter.formatCompactCurrency(taxSummary.totalRevenue),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'THUẾ PHẢI NỘP (${_formatTaxRate(taxSummary.taxRate)})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hạn nộp: ${_getTaxDeadline(provider.selectedDateRange)}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    AppFormatter.formatCompactCurrency(taxSummary.estimatedTax),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactTaxBreakdown(TaxSummary taxSummary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DIỄN GIẢI',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        
        // Revenue Breakdown
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Doanh thu Bán hàng (POS)',
                    style: TextStyle(fontSize: 12),
                  ),
                  Text(
                    AppFormatter.formatCompactCurrency(taxSummary.totalRevenue),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${taxSummary.totalTransactions} giao dịch',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Expense Breakdown
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Chi phí Nhập hàng (PO)',
                style: TextStyle(fontSize: 12),
              ),
              Text(
                AppFormatter.formatCompactCurrency(taxSummary.totalExpenses),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Net Profit
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade300),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Lợi nhuận thực (sau thuế)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    AppFormatter.formatCompactCurrency(taxSummary.netProfit),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${taxSummary.profitMargin.toStringAsFixed(1)}% biên lợi nhuận',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactTaxTimeSelector(ReportProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'KHOẢNG THỜI GIAN KÊ KHAI',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<DateRangePreset>(
          segments: const [
            ButtonSegment(value: DateRangePreset.thisMonth, label: Text('Tháng')),
            ButtonSegment(value: DateRangePreset.thisQuarter, label: Text('Quý')),
            ButtonSegment(value: DateRangePreset.thisYear, label: Text('Năm')),
          ],
          selected: {provider.selectedPreset},
          onSelectionChanged: (newSelection) {
            provider.setDateRangeForTaxSilent(newSelection.first);
          },
          style: SegmentedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            textStyle: const TextStyle(fontSize: 10),
            selectedBackgroundColor: Colors.orange,
            selectedForegroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _getTaxPeriodDescription(provider.selectedDateRange),
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // SHARED WIDGETS (Could be moved to shared/widgets)
  // ===========================================================================

}
