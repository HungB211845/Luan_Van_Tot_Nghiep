import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/routing/route_names.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../core/providers/navigation_provider.dart';
import '../../features/products/providers/product_provider.dart';
import '../../features/debt/providers/debt_provider.dart';
import '../../features/pos/providers/transaction_provider.dart';
import '../../shared/utils/formatter.dart';
import '../../shared/utils/datetime_helpers.dart';
import 'providers/quick_access_provider.dart';
import '../../features/reports/providers/report_provider.dart';
import 'package:intl/intl.dart';
import '../../features/reports/models/daily_revenue.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // PageController for QuickAccess Carousel (per HIG spec)
  PageController? _quickAccessPageController;
  int _currentQuickAccessPage = 0;

  // Local state for revenue chart day selection
  int? _selectedDayIndex;

  @override
  void initState() {
    super.initState();

    // Initialize PageController for carousel
    _quickAccessPageController = PageController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // OPTIMIZED: Use parallel loading with new ReportService methods
      // Load alerts separately for "For You" widget
      context.read<ProductProvider>().loadAlerts();
      context.read<DebtProvider>().loadAllDebts();
      context.read<TransactionProvider>().loadTransactions(limit: 5);
      context.read<QuickAccessProvider>().loadConfiguration();
      
      // Load weekly revenue specifically for "7 ngày" widget
      context.read<ReportProvider>().loadWeeklyRevenueForHome();
      
      // PRELOAD: Background load all report data for faster Reports screen access
      // Delay slightly to not interfere with critical HomeScreen data
      Future.delayed(const Duration(milliseconds: 500), () {
        context.read<ReportProvider>().preloadAllReportData();
      });
    });
  }

  @override
  void dispose() {
    _quickAccessPageController?.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    // OPTIMIZED: Parallel loading with new methods
    await Future.wait([
      context.read<ProductProvider>().loadAlerts(), // For low stock/expiring alerts
      context.read<DebtProvider>().loadAllDebts(),
      context.read<TransactionProvider>().loadTransactions(limit: 5),
      context.read<ReportProvider>().loadDashboardData(), // For revenue chart (7 days)
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Desktop breakpoint: 1024px+ for true multi-column dashboard
          if (constraints.maxWidth >= 1024) {
            return _buildDesktopLayout();
          }
          // Mobile/tablet: traditional single column layout
          return _buildMobileLayout();
        },
      ),
    );
  }

  // Traditional single-column layout for mobile/tablet
  Widget _buildMobileLayout() {
    return CustomScrollView(
      slivers: [
        // Minimal AppBar - Clean Navigation Bar
        SliverAppBar(
          floating: false,
          pinned: true,
          backgroundColor: Colors.green,
          elevation: 0,
          leading: Consumer<AuthProvider>(
            builder: (context, auth, child) {
              final initial = (auth.currentUser?.fullName ?? 'U')
                  .substring(0, 1)
                  .toUpperCase();
              return GestureDetector(
                onTap: () {
                  context.read<NavigationProvider>().goToProfile();
                },
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(CupertinoIcons.bell),
              onPressed: () {
                // TODO: Navigate to notifications screen
              },
            ),
          ],
        ),

        // Pull to refresh
        CupertinoSliverRefreshControl(onRefresh: _refreshData),

        // Widget Dashboard Content
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Dynamic Greeting Widget
              _buildGreetingWidget(),
              const SizedBox(height: 16),

              // Global Search Bar
              _buildSearchBar(),
              const SizedBox(height: 24),

              // Revenue Chart Widget
              _buildRevenueChartWidget(),
              const SizedBox(height: 16),

              // Smart "For You" Widget (Alerts + Recent Activity)
              _buildForYouWidget(),
              const SizedBox(height: 16),

              // HIG-Compliant Carousel Quick Actions
              _buildQuickActionsWidget(),
              const SizedBox(height: 32),
            ]),
          ),
        ),
      ],
    );
  }

  // Multi-column dashboard for desktop/wide screens (HIG Spec)
  Widget _buildDesktopLayout() {
    return CustomScrollView(
      slivers: [
        // Pull to refresh
        CupertinoSliverRefreshControl(onRefresh: _refreshData),

        // Desktop Grid Layout per HIG Spec
        SliverPadding(
          padding: const EdgeInsets.all(24), // Increased padding for desktop
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Greeting + Search (full width)
              _buildGreetingWidget(),
              const SizedBox(height: 16),
              _buildSearchBar(),
              const SizedBox(height: 24),

              // Multi-column dashboard layout per HIG spec
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left column: Revenue chart (2/3 width)
                  Expanded(
                    flex: 2,
                    child: _buildRevenueChartWidget(),
                  ),
                  
                  const SizedBox(width: 24), // Gap between columns
                  
                  // Right column: Alerts + Recent Activity (1/3 width)
                  Expanded(
                    flex: 1,
                    child: _buildForYouWidget(),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Full-width Quick Access Carousel (bottom row)
              _buildQuickActionsWidget(),
              const SizedBox(height: 32),
            ]),
          ),
        ),
      ],
    );
  }

  // 👋 Dynamic Greeting Widget
  Widget _buildGreetingWidget() {
    return Text(
      getGreetingMessage(),
      style: const TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1D1D1F),
      ),
    );
  }

  // 🔍 Global Search Bar
  Widget _buildSearchBar() {
    return Hero(
      tag: 'global_search',
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: () {
            Navigator.of(
              context,
              rootNavigator: true,
            ).pushNamed(RouteNames.globalSearch);
          },
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.search,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tìm kiếm sản phẩm, giao dịch...',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 📊 Interactive Revenue Chart Widget (Cloned from Reports Screen)
  Widget _buildRevenueChartWidget() {
    return Consumer<ReportProvider>(
      builder: (context, reportProvider, child) {
        // Show loading while data is being fetched
        if (reportProvider.homeScreenRevenueTrend.isEmpty && reportProvider.errorMessage == null) {
          return Container(
            height: 300,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Đang tải dữ liệu doanh thu 7 ngày...'),
                ],
              ),
            ),
          );
        }
        
        // Show error state if loading failed
        if (reportProvider.errorMessage != null && reportProvider.homeScreenRevenueTrend.isEmpty) {
          return Container(
            height: 300,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Không thể tải dữ liệu doanh thu'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => reportProvider.loadWeeklyRevenueForHome(),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          );
        }

        // Use weekly revenue trend data (forced weekly range)
        final weeklyTrend = reportProvider.homeScreenRevenueTrend;
        final double maxDailyRevenue = weeklyTrend.isEmpty
            ? 0.0
            : weeklyTrend.map((point) => point.currentPeriodRevenue).reduce((a, b) => a > b ? a : b);

        final maxRevenue = (maxDailyRevenue > 0) ? maxDailyRevenue * 1.2 : 100000.0;

        final totalWeekRevenue = weeklyTrend.fold<double>(
          0.0,
          (sum, point) => sum + point.currentPeriodRevenue,
        );

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with navigation arrows for week switching
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Previous week button
                  IconButton(
                    onPressed: () => reportProvider.showPreviousWeekForHome(),
                    icon: Icon(
                      Icons.chevron_left,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  
                  // Title and date range (tap to go to Reports)
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(
                          context,
                          rootNavigator: true,
                        ).pushNamed(RouteNames.reports);
                      },
                      child: Column(
                        children: [
                          const Text(
                            'Doanh thu 7 ngày',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${DateFormat('dd/MM').format(reportProvider.homeScreenWeekStart)} - ${DateFormat('dd/MM').format(reportProvider.homeScreenWeekStart.add(const Duration(days: 6)))}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Next week button  
                  IconButton(
                    onPressed: reportProvider.canShowNextWeekForHome
                        ? () => reportProvider.showNextWeekForHome()
                        : null, // Disable button if next week is in the future
                    icon: Icon(
                      Icons.chevron_right,
                      color: reportProvider.canShowNextWeekForHome
                          ? Colors.grey.shade600
                          : Colors.grey.shade300, // Visually indicate disabled state
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Total revenue display
              Text(
                AppFormatter.formatCurrency(totalWeekRevenue),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 16),

              // Interactive Bar Chart (Cloned from Reports)
              SizedBox(
                height: 180,
                child: BarChart(
                  BarChartData(
                    maxY: maxRevenue,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          if (groupIndex >= weeklyTrend.length) return null;
                          final point = weeklyTrend[groupIndex];
                          final weekday = DateFormat('EEEE', 'vi').format(point.reportDate);
                          return BarTooltipItem(
                            '$weekday\n${AppFormatter.formatCurrency(rod.toY)}',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                      touchCallback: (FlTouchEvent event, barTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              barTouchResponse == null ||
                              barTouchResponse.spot == null) {
                            _selectedDayIndex = null;
                            return;
                          }
                          _selectedDayIndex = barTouchResponse.spot!.touchedBarGroupIndex;
                        });
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            if (value.toInt() >= weeklyTrend.length) return const Text('');
                            final date = weeklyTrend[value.toInt()].reportDate;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                DateFormat('E', 'vi').format(date),
                                style: TextStyle(
                                  color: _selectedDayIndex == value.toInt()
                                      ? Colors.green
                                      : Colors.grey.shade600,
                                  fontSize: 12,
                                  fontWeight: _selectedDayIndex == value.toInt()
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: weeklyTrend.asMap().entries.map((entry) {
                      final index = entry.key;
                      final point = entry.value;
                      final isSelected = _selectedDayIndex == index;
                      
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: point.currentPeriodRevenue,
                            color: isSelected ? Colors.green.shade700 : Colors.green.shade400,
                            width: 20,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ],
                      );
                    }).toList(),
                    gridData: FlGridData(
                      show: true,
                      drawHorizontalLine: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxRevenue / 4,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.grey.shade200,
                          strokeWidth: 1,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  // 🎯 Smart "For You" Widget - Actionable Insights
  Widget _buildForYouWidget() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Cần chú ý',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),

          // Priority: Alerts first
          Consumer<ProductProvider>(
            builder: (context, provider, child) {
              final lowStockCount = provider.lowStockProducts.length;
              if (lowStockCount == 0) return const SizedBox.shrink();
              return Column(
                children: [
                  _buildActionableInsight(
                    icon: CupertinoIcons.exclamationmark_triangle_fill,
                    iconColor: Colors.orange,
                    title: 'Sắp hết hàng',
                    subtitle: '$lowStockCount sản phẩm cần nhập thêm',
                    onTap: () {
                      // TODO: Navigate to low stock products
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                ],
              );
            },
          ),

          Consumer<DebtProvider>(
            builder: (context, provider, child) {
              final overdueCount = provider.overdueDebts.length;
              if (overdueCount == 0) return const SizedBox.shrink();
              return Column(
                children: [
                  _buildActionableInsight(
                    icon: CupertinoIcons.xmark_octagon_fill,
                    iconColor: Colors.red,
                    title: 'Nợ quá hạn',
                    subtitle: '$overdueCount khoản cần thu hồi',
                    onTap: () {
                      // TODO: Navigate to overdue debts
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                ],
              );
            },
          ),

          // Fallback: Recent Activity if no alerts
          Consumer2<ProductProvider, DebtProvider>(
            builder: (context, productProvider, debtProvider, child) {
              final hasAlerts =
                  productProvider.lowStockProducts.isNotEmpty ||
                  debtProvider.overdueDebts.isNotEmpty;

              if (hasAlerts) return const SizedBox.shrink();

              return Consumer<TransactionProvider>(
                builder: (context, txProvider, child) {
                  if (txProvider.transactions.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Chưa có hoạt động nào hôm nay',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  final recentTx = txProvider.transactions.first;
                  return _buildActionableInsight(
                    icon: CupertinoIcons.doc_text_fill,
                    iconColor: Colors.blue,
                    title: 'Giao dịch gần nhất',
                    subtitle: AppFormatter.formatCurrency(recentTx.totalAmount),
                    onTap: () {
                      // TODO: Navigate to transaction detail
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionableInsight({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                color: Colors.grey[400],
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ⚡ 8px Grid System Compliant QuickAccess Widget  
  Widget _buildQuickActionsWidget() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Critical: prevent overflow
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header với 8px grid padding
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0.0), // Consistent padding
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TRUY CẬP NHANH',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF8E8E93), // iOS secondary label
                    letterSpacing: 0.5,
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await Navigator.of(
                      context,
                      rootNavigator: true,
                    ).pushNamed(RouteNames.editQuickAccess);
                    if (context.mounted) {
                      context.read<QuickAccessProvider>().loadConfiguration();
                    }
                  },
                  child: const Text(
                    'Sửa',
                    style: TextStyle(
                      fontSize: 17, // iOS button standard
                      color: Colors.green,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Exact 16px spacing per 8px grid system
          const SizedBox(height: 16.0),
          
          // Grid Content với chính xác calculated height
          Consumer<QuickAccessProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return const SizedBox(
                  height: 120, // 8px grid compliant
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final items = provider.visibleItems;
              if (items.isEmpty) {
                return const SizedBox(
                  height: 120,
                  child: Center(
                    child: Text(
                      'Chưa có mục nào. Nhấn "Sửa" để thêm.',
                      style: TextStyle(color: Color(0xFF8E8E93)),
                    ),
                  ),
                );
              }

              return _build8pxGridCarousel(items);
            },
          ),

          // Add bottom padding to match card style
          const SizedBox(height: 16.0),
        ],
      ),
    );
  }

  Widget _build8pxGridCarousel(List<dynamic> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive columns based on available width
        int columns;
        if (constraints.maxWidth >= 1200) {
          columns = 6; // Desktop: 6 columns
        } else if (constraints.maxWidth >= 800) {
          columns = 5; // Tablet landscape: 5 columns
        } else if (constraints.maxWidth >= 600) {
          columns = 4; // Tablet portrait: 4 columns
        } else {
          columns = 4; // Mobile: 4 columns
        }
        
        const int rows = 2;
        final int itemsPerPage = columns * rows;
        final int totalPages = (items.length / itemsPerPage).ceil();
        
        // ✅ PRECISE Height Calculation per 8px Grid System
        const double iconContainerSize = 60.0;  // 8px grid: 60 = 8 * 7.5
        const double iconTextSpacing = 8.0;     // 8px grid: 8 = 8 * 1
        const double textHeight = 32.0;         // 8px grid: 32 = 8 * 4
        const double mainAxisSpacing = 24.0;    // 8px grid: 24 = 8 * 3
        const double numberOfRows = 2;
        
        // Formula: (itemHeight * rows) + (spacing * (rows - 1))
        final double calculatedHeight = (iconContainerSize + iconTextSpacing + textHeight) * numberOfRows + 
                                       mainAxisSpacing * (numberOfRows - 1);
        
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // PageView với calculated height (NO magic numbers)
            SizedBox(
              height: calculatedHeight, // Dynamic calculation, not fixed 200
              child: PageView.builder(
                controller: _quickAccessPageController,
                itemCount: totalPages,
                onPageChanged: (page) {
                  setState(() {
                    _currentQuickAccessPage = page;
                  });
                },
                itemBuilder: (context, pageIndex) {
                  final startIndex = pageIndex * itemsPerPage;
                  final endIndex = (startIndex + itemsPerPage).clamp(0, items.length);
                  final pageItems = items.sublist(startIndex, endIndex);
                  
                  return _build8pxGridPage(pageItems);
                },
              ),
            ),
            
            const SizedBox(height: 16.0), // 8px grid spacing
            
            // Page indicator với iOS styling
            if (totalPages > 1)
              _buildIOSPageIndicator(_currentQuickAccessPage, totalPages),
          ],
        );
      },
    );
  }

  Widget _build8pxGridPage(List<dynamic> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive columns based on available width
        int crossAxisCount;
        if (constraints.maxWidth >= 1200) {
          crossAxisCount = 6; // Desktop: 6 columns
        } else if (constraints.maxWidth >= 800) {
          crossAxisCount = 5; // Tablet landscape: 5 columns
        } else if (constraints.maxWidth >= 600) {
          crossAxisCount = 4; // Tablet portrait: 4 columns
        } else {
          crossAxisCount = 4; // Mobile: 4 columns (default)
        }
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0), // 8px grid
          child: GridView.builder(
            padding: EdgeInsets.zero, // No extra padding
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 24.0,  // 8px grid: 24 = 8 * 3
              mainAxisSpacing: 24.0,   // 8px grid: 24 = 8 * 3
              childAspectRatio: 0.75, // Adjust for shorter, single-line text content
            ),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _build8pxGridCard(
                icon: item.icon,
                label: item.label,
                onTap: () => Navigator.of(
                  context,
                  rootNavigator: true,
                ).pushNamed(item.route),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildIOSPageIndicator(int currentPage, int totalPages) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        totalPages,
        (index) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 4.0), // 8px grid
          width: 8.0,  // 8px grid: 8 = 8 * 1
          height: 8.0, // 8px grid: 8 = 8 * 1
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: index == currentPage
                ? Colors.green // Active indicator
                : const Color(0xFFD1D1D6), // iOS inactive gray
          ),
        ),
      ),
    );
  }

  // ⚡ 8px Grid System Card (NO StatefulBuilder, NO AnimatedScale)
  Widget _build8pxGridCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min, // Critical for grid layout
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon Container với 8px grid dimensions
          Container(
            width: 60.0,   // 8px grid: 60 = 8 * 7.5
            height: 60.0,  // 8px grid: 60 = 8 * 7.5
            decoration: BoxDecoration(
              // User request: Revert to default Colors.green
              color: Colors.green, 
              borderRadius: BorderRadius.circular(16.0), // 8px grid: 16 = 8 * 2
            ),
            child: Icon(
              icon,
              size: 30.0, // Optimal size for 60px container
              color: Colors.white, // Maximum contrast
            ),
          ),
          
          // Exact 8px spacing per grid system
          const SizedBox(height: 8.0), // 8px grid: 8 = 8 * 1
          
          // Text label with single-line enforcement
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1, // ENFORCE: Single line only
            overflow: TextOverflow.ellipsis, // ENFORCE: Use ellipsis for long text
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1D1D1F),
            ),
          ),
        ],
      ),
    );
  }
}
