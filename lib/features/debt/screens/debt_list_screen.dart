import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/debt_provider.dart';
import '../models/debt.dart';
import 'customer_debt_detail_screen.dart';
import '../../customers/services/customer_service.dart';
import '../../customers/models/customer.dart';
import '../../customers/providers/customer_provider.dart';
import 'package:intl/intl.dart';
import '../../../shared/widgets/loading_widget.dart';

enum DebtFilterStatus { all, overdue, dueSoon }
enum DebtSortOption { highestDebt, lowestDebt, nameAZ, mostRecent }

class DebtListScreen extends StatefulWidget {
  const DebtListScreen({super.key});

  @override
  State<DebtListScreen> createState() => _DebtListScreenState();
}

class _DebtListScreenState extends State<DebtListScreen> {
  final TextEditingController _searchController = TextEditingController();
  DebtFilterStatus _selectedFilter = DebtFilterStatus.all;
  DebtSortOption _sortOption = DebtSortOption.highestDebt;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) setState(() => _searchQuery = _searchController.text);
    });
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    context.read<DebtProvider>().loadAllDebts();
    context.read<CustomerProvider>().loadCustomers();
  }

  List<MapEntry<String, List<Debt>>> _getProcessedData(DebtProvider provider) {
    List<Debt> filteredDebts;
    switch (_selectedFilter) {
      case DebtFilterStatus.overdue:
        filteredDebts = provider.debts.where((d) => d.isOverdue).toList();
        break;
      case DebtFilterStatus.dueSoon:
        filteredDebts = provider.debts.where((d) => d.isDueSoon).toList();
        break;
      default:
        filteredDebts = provider.debts;
        break;
    }

    final Map<String, List<Debt>> debtsByCustomer = {};
    for (final debt in filteredDebts) {
      if (debt.remainingAmount > 0) {
        debtsByCustomer.putIfAbsent(debt.customerId, () => []).add(debt);
      }
    }

    if (_searchQuery.isNotEmpty) {
      final customerProvider = context.read<CustomerProvider>();
      final query = _searchQuery.toLowerCase();
      debtsByCustomer.removeWhere((customerId, debts) {
        final customer = customerProvider.getCustomerFromCache(customerId);
        if (customer == null) return true;
        return !customer.name.toLowerCase().contains(query) &&
               !(customer.phone?.contains(query) ?? false);
      });
    }

    var sortedEntries = debtsByCustomer.entries.toList();
    final customerProvider = context.read<CustomerProvider>();
    sortedEntries.sort((a, b) {
      switch (_sortOption) {
        case DebtSortOption.highestDebt:
          final totalA = a.value.fold<double>(0, (sum, d) => sum + d.remainingAmount);
          final totalB = b.value.fold<double>(0, (sum, d) => sum + d.remainingAmount);
          return totalB.compareTo(totalA);
        case DebtSortOption.lowestDebt:
          final totalA = a.value.fold<double>(0, (sum, d) => sum + d.remainingAmount);
          final totalB = b.value.fold<double>(0, (sum, d) => sum + d.remainingAmount);
          return totalA.compareTo(totalB);
        case DebtSortOption.nameAZ:
          final nameA = customerProvider.getCustomerFromCache(a.key)?.name ?? '';
          final nameB = customerProvider.getCustomerFromCache(b.key)?.name ?? '';
          return nameA.compareTo(nameB);
        case DebtSortOption.mostRecent:
          final dateA = a.value.map((d) => d.createdAt).reduce((c, n) => c.isAfter(n) ? c : n);
          final dateB = b.value.map((d) => d.createdAt).reduce((c, n) => c.isAfter(n) ? c : n);
          return dateB.compareTo(dateA);
      }
    });

    return sortedEntries;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double tabletBreakpoint = 768;
        if (constraints.maxWidth >= tabletBreakpoint) {
          return _buildDesktopLayout();
        }
        return _buildMobileLayout();
      },
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      body: _buildListContent(isMasterDetail: false),
      bottomNavigationBar: _buildSummaryFooter(),
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      body: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              children: [
                AppBar(title: const Text('Quản Lý Công Nợ'), backgroundColor: Colors.green, foregroundColor: Colors.white, actions: [_buildSortButton()]),
                Expanded(child: _buildListContent(isMasterDetail: true)),
              ],
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            flex: 6,
            child: Consumer<DebtProvider>(
              builder: (context, provider, child) {
                if (provider.selectedCustomerId == null) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Chọn một khách hàng để xem sổ cái', style: TextStyle(fontSize: 16, color: Colors.grey)),
                      ],
                    ),
                  );
                }
                return CustomerDebtDetailScreen(customerId: provider.selectedCustomerId!);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListContent({required bool isMasterDetail}) {
    return Consumer<DebtProvider>(
      builder: (context, provider, _) {
        final processedData = _getProcessedData(provider);
        return RefreshIndicator(
          onRefresh: _loadData,
          child: CustomScrollView(
            slivers: [
              if (!isMasterDetail)
                SliverAppBar(
                  title: const Text('Quản Lý Công Nợ'),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  pinned: true,
                  floating: true,
                  actions: [_buildSortButton()],
                ),
              SliverToBoxAdapter(child: _buildSegmentedControl()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: CupertinoSearchTextField(
                    controller: _searchController,
                    placeholder: 'Tìm theo tên hoặc SĐT khách hàng',
                  ),
                ),
              ),
              _buildSliverDebtList(provider, processedData, isMasterDetail),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSliverDebtList(DebtProvider provider, List<MapEntry<String, List<Debt>>> sortedEntries, bool isMasterDetail) {
    if (provider.isLoading && sortedEntries.isEmpty) {
      return const SliverFillRemaining(child: Center(child: LoadingWidget()));
    }
    if (sortedEntries.isEmpty) {
      return const SliverFillRemaining(child: Center(child: Text('Không có công nợ nào khớp bộ lọc.')));
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final entry = sortedEntries[index];
          return _buildCustomerDebtCard(entry.key, entry.value, isMasterDetail);
        },
        childCount: sortedEntries.length,
      ),
    );
  }

  Widget _buildCustomerDebtCard(String customerId, List<Debt> debts, bool isMasterDetail) {
    final totalRemaining = debts.fold<double>(0, (sum, debt) => sum + debt.remainingAmount);
    final bool hasOverdue = debts.any((d) => d.isOverdue);
    final bool hasDueSoon = !hasOverdue && debts.any((d) => d.isDueSoon);
    final customer = context.read<CustomerProvider>().getCustomerFromCache(customerId);
    final provider = context.read<DebtProvider>();
    final bool isSelected = isMasterDetail && provider.selectedCustomerId == customerId;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: isSelected ? 4 : 2,
      color: isSelected ? Colors.green.withOpacity(0.1) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isSelected ? Colors.green : Colors.grey[200]!, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (isMasterDetail) {
            provider.selectCustomerForDetail(customerId);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CustomerDebtDetailScreen(customerId: customerId)),
            ).then((_) => _loadData());
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customer?.name ?? 'KH: ${customerId.substring(0, 8)}...', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    if (customer?.phone != null) Padding(padding: const EdgeInsets.only(top: 4.0), child: Text(customer!.phone!, style: TextStyle(color: Colors.grey[600], fontSize: 14))),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Còn nợ', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (hasOverdue) const Icon(Icons.error, color: Colors.red, size: 20)
                      else if (hasDueSoon) const Icon(Icons.hourglass_bottom, color: Colors.orange, size: 20),
                      if (hasOverdue || hasDueSoon) const SizedBox(width: 6),
                      Text(NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(totalRemaining), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortButton() {
    return TextButton(
      onPressed: _showSortSheet,
      child: Row(
        children: [
          const Text('Sắp xếp', style: TextStyle(color: Colors.white)),
          const SizedBox(width: 2),
          const Icon(CupertinoIcons.arrow_up_arrow_down, color: Colors.white, size: 16),
        ],
      ),
    );
  }

  void _showSortSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Sắp xếp theo'),
        actions: <CupertinoActionSheetAction>[
          _buildSortAction(DebtSortOption.highestDebt, 'Nợ nhiều nhất'),
          _buildSortAction(DebtSortOption.lowestDebt, 'Nợ ít nhất'),
          _buildSortAction(DebtSortOption.nameAZ, 'Tên A-Z'),
          _buildSortAction(DebtSortOption.mostRecent, 'Ngày nợ gần nhất'),
        ],
        cancelButton: CupertinoActionSheetAction(isDestructiveAction: true, onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
      ),
    );
  }

  CupertinoActionSheetAction _buildSortAction(DebtSortOption option, String text) {
    final bool isSelected = _sortOption == option;
    return CupertinoActionSheetAction(
      onPressed: () {
        setState(() => _sortOption = option);
        Navigator.pop(context);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(text, style: TextStyle(color: isSelected ? Colors.green : null, fontWeight: isSelected ? FontWeight.bold : null)),
          if (isSelected) ...[const SizedBox(width: 8), const Icon(Icons.check, color: Colors.green, size: 20)],
        ],
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: CupertinoSlidingSegmentedControl<DebtFilterStatus>(
        groupValue: _selectedFilter,
        backgroundColor: Colors.green.withOpacity(0.1),
        thumbColor: Colors.green,
        onValueChanged: (DebtFilterStatus? value) {
          if (value != null) setState(() => _selectedFilter = value);
        },
        children: {
          DebtFilterStatus.all: _buildSegmentItem('Tất cả', _selectedFilter == DebtFilterStatus.all),
          DebtFilterStatus.overdue: _buildSegmentItem('Quá hạn', _selectedFilter == DebtFilterStatus.overdue),
          DebtFilterStatus.dueSoon: _buildSegmentItem('Sắp đến hạn', _selectedFilter == DebtFilterStatus.dueSoon),
        },
      ),
    );
  }

  Widget _buildSegmentItem(String text, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
<<<<<<< HEAD
      child: Text(
        text,
        style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontSize: 14, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal),
      ),
    );
  }

  Widget _buildSummaryFooter() {
    return Consumer<DebtProvider>(
      builder: (context, provider, _) {
        final totalRemaining = provider.totalRemainingDebt;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey[200]!)),
          ),
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tổng công nợ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text(NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(totalRemaining), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
              ],
            ),
          ),
        );
      },
    );
  }
}