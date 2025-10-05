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
import 'providers/dashboard_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final productProvider = context.read<ProductProvider>();
      productProvider.loadDashboardStats();
      productProvider.loadAlerts();
      context.read<DebtProvider>().loadAllDebts();
      context.read<TransactionProvider>().loadTransactions(limit: 5);
      context.read<QuickAccessProvider>().loadConfiguration();
      context.read<DashboardProvider>().fetchRevenueData();
    });
  }

  Future<void> _refreshData() async {
    final productProvider = context.read<ProductProvider>();
    await Future.wait([
      productProvider.loadDashboardStats(),
      productProvider.loadAlerts(),
      context.read<DebtProvider>().loadAllDebts(),
      context.read<TransactionProvider>().loadTransactions(limit: 5),
      context.read<DashboardProvider>().fetchRevenueData(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      body: CustomScrollView(
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

                // Customizable Quick Actions Grid
                _buildQuickActionsWidget(),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // 👋 Dynamic Greeting Widget
  Widget _buildGreetingWidget() {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        final fullName = auth.currentUser?.fullName ?? '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${getGreetingMessage()},',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w400,
                color: Colors.grey.shade600,
              ),
            ),
            Text(
              fullName,
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1D1D1F),
              ),
            ),
          ],
        );
      },
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
                Text(
                  'Tìm kiếm sản phẩm, giao dịch...',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 📊 Interactive Revenue Chart Widget
  Widget _buildRevenueChartWidget() {
    return Consumer<DashboardProvider>(
      builder: (context, dashboard, child) {
        if (dashboard.isLoading) {
          return Container(
            height: 300,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final weeklyData = dashboard.weeklyData;
        final maxRevenue = weeklyData.isEmpty
            ? 100000.0
            : weeklyData.map((d) => d.revenue).reduce((a, b) => a > b ? a : b) *
                  1.2;

        return GestureDetector(
          // Swipe to navigate weeks
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity! > 0) {
              // Swipe right -> previous week
              dashboard.showPreviousWeek();
            } else if (details.primaryVelocity! < 0) {
              // Swipe left -> next week
              dashboard.showNextWeek();
            }
          },
          child: Container(
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
                // Header: Tap to view Reports
                GestureDetector(
                  onTap: () {
                    Navigator.of(
                      context,
                      rootNavigator: true,
                    ).pushNamed(RouteNames.reports);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Doanh thu 7 ngày',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Icon(
                        CupertinoIcons.chevron_right,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Interactive Bar Chart
                SizedBox(
                  height: 180,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxRevenue,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchCallback: (event, response) {
                          if (event.isInterestedForInteractions &&
                              response != null &&
                              response.spot != null) {
                            dashboard.selectDay(
                              response.spot!.touchedBarGroupIndex,
                            );
                          }
                        },
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (group) => Colors.black87,
                          tooltipBorder: const BorderSide(
                            color: Colors.transparent,
                          ),
                          tooltipPadding: const EdgeInsets.all(8),
                          tooltipMargin: 8,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            if (groupIndex >= weeklyData.length) return null;
                            final data = weeklyData[groupIndex];
                            return BarTooltipItem(
                              '${data.fullWeekdayName}\n${AppFormatter.formatCurrency(data.revenue)}',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= weeklyData.length)
                                return const SizedBox();
                              return Text(
                                weeklyData[index].weekdayLabel,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                  fontWeight:
                                      dashboard.selectedDayIndex == index
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: weeklyData
                          .asMap()
                          .entries
                          .map(
                            (entry) => _buildBarGroup(
                              entry.key,
                              entry.value.revenue,
                              isSelected:
                                  dashboard.selectedDayIndex == entry.key,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Tooltip: Tap to view transaction details
                if (dashboard.selectedDayIndex != null &&
                    dashboard.selectedDayData != null)
                  GestureDetector(
                    onTap: () {
                      // Navigate to transaction list filtered by date
                      Navigator.of(context, rootNavigator: true).pushNamed(
                        RouteNames.transactionList,
                        arguments: dashboard.selectedDayData!.date,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dashboard.selectedDayData!.fullWeekdayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '${dashboard.selectedDayData!.transactionCount} giao dịch',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            CupertinoIcons.chevron_right,
                            color: Colors.green,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),

                if (dashboard.selectedDayIndex != null)
                  const SizedBox(height: 16),

                // Summary: Tap to view Reports
                GestureDetector(
                  onTap: () {
                    Navigator.of(
                      context,
                      rootNavigator: true,
                    ).pushNamed(RouteNames.reports);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tổng tuần này',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      Text(
                        AppFormatter.formatCurrency(dashboard.weekTotalRevenue),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  BarChartGroupData _buildBarGroup(int x, double y, {bool isSelected = false}) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: isSelected ? Colors.green.shade700 : Colors.green,
          width: isSelected ? 24 : 20,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
      ],
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

  // ⚡ Customizable Quick Actions Grid
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Truy cập nhanh',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
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
                  style: TextStyle(color: Colors.green, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Dynamic Grid from QuickAccessProvider
          Consumer<QuickAccessProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final items = provider.visibleItems;
              if (items.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Chưa có mục nào. Nhấn "Sửa" để thêm.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }

              return GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                ),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _buildQuickActionCard(
                    icon: item.icon,
                    label: item.label,
                    color: item.color,
                    onTap: () => Navigator.of(
                      context,
                      rootNavigator: true,
                    ).pushNamed(item.route),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
