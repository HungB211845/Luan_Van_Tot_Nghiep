import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../customers/models/customer.dart';
import '../../customers/services/customer_service.dart';
import '../../../../shared/utils/formatter.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../models/debt.dart';
import '../models/debt_payment.dart';
import '../providers/debt_provider.dart';
import '../../pos/models/transaction.dart';
import '../../pos/providers/transaction_provider.dart';
import '../../pos/screens/transaction/transaction_detail_screen.dart';
import 'add_payment_screen.dart';

// Data classes for the new grouped structure
enum LedgerEntryType { debt, payment }

class LedgerEntry {
  final dynamic entry;
  final DateTime date;
  final LedgerEntryType type;

  LedgerEntry({required this.entry, required this.date, required this.type});
}

class MonthlyLedgerGroup {
  final String monthKey; // e.g., "2025-09"
  final List<LedgerEntry> entries;
  final double debtIncurred;
  final double amountPaid;

  MonthlyLedgerGroup({
    required this.monthKey,
    required this.entries,
    this.debtIncurred = 0.0,
    this.amountPaid = 0.0,
  });
}

// Filter state class
class LedgerFilter {
  final DateTime? startDate;
  final DateTime? endDate;
  final LedgerEntryType? entryType;
  final bool onlyOverdue;

  const LedgerFilter({
    this.startDate,
    this.endDate,
    this.entryType,
    this.onlyOverdue = false,
  });

  bool get isActive => startDate != null || endDate != null || entryType != null || onlyOverdue;
}

class CustomerDebtDetailScreen extends StatefulWidget {
  final String customerId;

  const CustomerDebtDetailScreen({
    super.key,
    required this.customerId,
  });

  @override
  State<CustomerDebtDetailScreen> createState() =>
      _CustomerDebtDetailScreenState();
}

class _CustomerDebtDetailScreenState extends State<CustomerDebtDetailScreen> {
  final CustomerService _customerService = CustomerService();
  final TextEditingController _searchController = TextEditingController();
  Customer? _customer;
  LedgerFilter _filter = const LedgerFilter();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final debtProvider = context.read<DebtProvider>();
    await Future.wait([
      _customerService.getCustomerById(widget.customerId).then((c) => _customer = c),
      debtProvider.loadCustomerDebts(widget.customerId),
      debtProvider.loadCustomerPayments(widget.customerId),
      debtProvider.loadCustomerDebtSummary(widget.customerId),
    ]);
    if (mounted) setState(() {});
  }

  List<MonthlyLedgerGroup> _createGroupedLedger(List<Debt> debts, List<DebtPayment> payments) {
    List<LedgerEntry> allEntries = [];

    final filteredDebts = debts.where((d) {
      if (_filter.onlyOverdue && !d.isOverdue) return false;
      if (_filter.startDate != null && d.createdAt.isBefore(_filter.startDate!)) return false;
      if (_filter.endDate != null && d.createdAt.isAfter(_filter.endDate!)) return false;
      return true;
    }).toList();

    final filteredPayments = payments.where((p) {
       if (_filter.startDate != null && p.paymentDate.isBefore(_filter.startDate!)) return false;
       if (_filter.endDate != null && p.paymentDate.isAfter(_filter.endDate!)) return false;
       return true;
    }).toList();

    if (_filter.entryType != LedgerEntryType.payment) {
      for (var debt in filteredDebts) {
        allEntries.add(LedgerEntry(entry: debt, date: debt.createdAt, type: LedgerEntryType.debt));
      }
    }
    if (_filter.entryType != LedgerEntryType.debt) {
      for (var payment in filteredPayments) {
        allEntries.add(LedgerEntry(entry: payment, date: payment.paymentDate, type: LedgerEntryType.payment));
      }
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      allEntries.removeWhere((entry) {
        if (isDebtEntry(entry)) {
          final Debt debt = entry.entry;
          return !(debt.transactionId?.toLowerCase().contains(query) ?? false) &&
                 !(debt.originalAmount.toString().contains(query));
        } else {
          final DebtPayment payment = entry.entry;
          return !(payment.amount.toString().contains(query)) &&
                 !(payment.notes?.toLowerCase().contains(query) ?? false);
        }
      });
    }

    allEntries.sort((a, b) => b.date.compareTo(a.date));

    Map<String, MonthlyLedgerGroup> groupedMap = {};
    for (var entry in allEntries) {
      String monthKey = DateFormat('yyyy-MM').format(entry.date);
      double debtIncurred = isDebtEntry(entry) ? (entry.entry as Debt).originalAmount : 0;
      double amountPaid = !isDebtEntry(entry) ? (entry.entry as DebtPayment).amount : 0;

      groupedMap.update(
        monthKey,
        (group) => MonthlyLedgerGroup(
          monthKey: monthKey,
          entries: [...group.entries, entry],
          debtIncurred: group.debtIncurred + debtIncurred,
          amountPaid: group.amountPaid + amountPaid,
        ),
        ifAbsent: () => MonthlyLedgerGroup(
          monthKey: monthKey,
          entries: [entry],
          debtIncurred: debtIncurred,
          amountPaid: amountPaid,
        ),
      );
    }
    return groupedMap.values.toList();
  }

  bool isDebtEntry(LedgerEntry entry) => entry.type == LedgerEntryType.debt;

  Future<void> _navigateToTransactionDetails(String transactionId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final tx = await context.read<TransactionProvider>().getTransactionById(transactionId);
      Navigator.pop(context);
      if (tx != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TransactionDetailScreen(transaction: tx),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tìm thấy chi tiết giao dịch.'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải giao dịch: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showFilterSheet() async {
    final result = await showModalBottomSheet<LedgerFilter>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(currentFilter: _filter),
    );
    if (result != null) setState(() => _filter = result);
  }

  String _buildAppBarTitle() {
    if (!_filter.isActive) return 'Sổ Cái Công Nợ';
    if (_filter.onlyOverdue) return 'Sổ Cái (Quá hạn)';
    if (_filter.entryType == LedgerEntryType.debt) return 'Sổ Cái (Nợ phát sinh)';
    if (_filter.entryType == LedgerEntryType.payment) return 'Sổ Cái (Đã trả)';
    return 'Sổ Cái (Đã lọc)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Consumer<DebtProvider>(
          builder: (context, provider, _) {
            final groupedLedger = _createGroupedLedger(provider.debts, provider.payments);
            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  title: Text(_buildAppBarTitle()),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  pinned: true,
                  floating: true,
                  actions: [
                    IconButton(
                      icon: Icon(_filter.isActive ? Icons.filter_alt : Icons.filter_alt_outlined),
                      onPressed: _showFilterSheet,
                      tooltip: 'Lọc',
                    ),
                  ],
                ),
                SliverToBoxAdapter(child: _buildCustomerHeader()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: CupertinoSearchTextField(
                      controller: _searchController,
                      placeholder: 'Tìm theo số tiền, mã giao dịch...',
                      onChanged: (query) {
                        setState(() {
                          _searchQuery = query;
                        });
                      },
                    ),
                  ),
                ),
                _buildLedgerContent(provider, groupedLedger),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddPaymentScreen(customerId: widget.customerId)),
          ).then((_) => _loadData());
        },
        icon: const Icon(Icons.payment),
        label: const Text('Thanh Toán'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildLedgerContent(DebtProvider provider, List<MonthlyLedgerGroup> groupedLedger) {
    if (provider.isLoading && groupedLedger.isEmpty) {
      return const SliverFillRemaining(child: Center(child: LoadingWidget()));
    }
    if (groupedLedger.isEmpty) {
      return const SliverFillRemaining(child: Center(child: Text('Không có hoạt động nào khớp bộ lọc.')));
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final monthGroup = groupedLedger[index];
          return _buildMonthGroup(monthGroup);
        },
        childCount: groupedLedger.length,
      ),
    );
  }

  Widget _buildMonthGroup(MonthlyLedgerGroup group) {
    final monthDate = DateFormat('yyyy-MM').parse(group.monthKey);
    final formattedMonth = 'Tháng ${monthDate.month}, ${monthDate.year}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 24, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formattedMonth, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Phát sinh: ${AppFormatter.formatCurrency(group.debtIncurred)}', style: const TextStyle(fontSize: 12, color: Colors.orange)),
                  Text('Đã trả: ${AppFormatter.formatCurrency(group.amountPaid)}', style: const TextStyle(fontSize: 12, color: Colors.green)),
                ],
              )
            ],
          ),
        ),
        ...group.entries.map((entry) => _buildLedgerItem(entry)),
      ],
    );
  }

  Widget _buildLedgerItem(LedgerEntry ledgerEntry) {
    final bool isDebtEntry = ledgerEntry.type == LedgerEntryType.debt;
    final Debt? debt = isDebtEntry ? ledgerEntry.entry as Debt : null;
    final DebtPayment? payment = !isDebtEntry ? ledgerEntry.entry as DebtPayment : null;
    final String title = isDebtEntry ? 'Giao dịch bán hàng' : 'Thanh toán (${payment!.paymentMethod})';
    final String dateSubtitle;
    if (isDebtEntry) {
      final isOverdue = debt!.isOverdue;
      dateSubtitle = 'Ngày tạo: ${AppFormatter.formatDate(debt.createdAt)} • Đáo hạn: ${debt.dueDate != null ? AppFormatter.formatDate(debt.dueDate!) : 'N/A'}';
    } else {
      dateSubtitle = 'Ngày trả: ${AppFormatter.formatDate(payment!.paymentDate)}';
    }
    final String amountText = isDebtEntry ? '+ ${AppFormatter.formatCurrency(debt!.originalAmount)}' : '- ${AppFormatter.formatCurrency(payment!.amount)}';
    final Color amountColor = isDebtEntry ? Colors.orange : Colors.green;
    final IconData icon = isDebtEntry ? Icons.add_shopping_cart : Icons.check_circle;
    final VoidCallback? onTap = isDebtEntry && debt!.transactionId != null ? () => _navigateToTransactionDetails(debt.transactionId!) : null;

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        onLongPress: () {
          if (isDebtEntry && debt?.transactionId != null) {
            Clipboard.setData(ClipboardData(text: debt!.transactionId!));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Đã sao chép Mã Giao Dịch'), backgroundColor: Colors.green),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
          ),
          child: Row(
            children: [
              Icon(icon, color: amountColor, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(
                      dateSubtitle,
                      style: TextStyle(fontSize: 12, color: (isDebtEntry && debt!.isOverdue) ? Colors.red : Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                amountText,
                style: TextStyle(fontWeight: FontWeight.bold, color: amountColor, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_customer != null)
            Text(
              _customer!.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          const SizedBox(height: 12),
          Consumer<DebtProvider>(
            builder: (context, provider, _) {
              final summary = provider.debtSummary;
              final remaining = summary?['total_remaining']?.toDouble() ?? 0.0;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Hiện còn nợ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  Text(
                    AppFormatter.formatCurrency(remaining),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final LedgerFilter currentFilter;
  const _FilterSheet({required this.currentFilter});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late LedgerFilter _localFilter;

  @override
  void initState() {
    super.initState();
    _localFilter = widget.currentFilter;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Lọc Sổ Cái', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Divider(height: 24),
          _buildDateRangePicker(),
          const SizedBox(height: 16),
          _buildEntryTypeFilter(),
          const SizedBox(height: 16),
          _buildOverdueFilter(),
          const SizedBox(height: 24),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context, const LedgerFilter()),
                child: const Text('Reset'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, _localFilter),
                  child: const Text('Áp dụng'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Khoảng thời gian', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.date_range, size: 18),
                label: Text(_localFilter.startDate == null ? 'Từ ngày' : AppFormatter.formatDate(_localFilter.startDate!)),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _localFilter.startDate ?? DateTime.now(),
                    firstDate: DateTime(2020), lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _localFilter = LedgerFilter(startDate: picked, endDate: _localFilter.endDate, entryType: _localFilter.entryType, onlyOverdue: _localFilter.onlyOverdue));
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.date_range, size: 18),
                label: Text(_localFilter.endDate == null ? 'Đến ngày' : AppFormatter.formatDate(_localFilter.endDate!)),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _localFilter.endDate ?? DateTime.now(),
                    firstDate: DateTime(2020), lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _localFilter = LedgerFilter(startDate: _localFilter.startDate, endDate: picked, entryType: _localFilter.entryType, onlyOverdue: _localFilter.onlyOverdue));
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEntryTypeFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Loại giao dịch', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Tất cả'),
              selected: _localFilter.entryType == null,
              onSelected: (selected) {
                if (selected) setState(() => _localFilter = LedgerFilter(startDate: _localFilter.startDate, endDate: _localFilter.endDate, entryType: null, onlyOverdue: _localFilter.onlyOverdue));
              },
            ),
            ChoiceChip(
              label: const Text('Nợ phát sinh'),
              selected: _localFilter.entryType == LedgerEntryType.debt,
              onSelected: (selected) {
                if (selected) setState(() => _localFilter = LedgerFilter(startDate: _localFilter.startDate, endDate: _localFilter.endDate, entryType: LedgerEntryType.debt, onlyOverdue: _localFilter.onlyOverdue));
              },
            ),
            ChoiceChip(
              label: const Text('Đã trả'),
              selected: _localFilter.entryType == LedgerEntryType.payment,
              onSelected: (selected) {
                if (selected) setState(() => _localFilter = LedgerFilter(startDate: _localFilter.startDate, endDate: _localFilter.endDate, entryType: LedgerEntryType.payment, onlyOverdue: _localFilter.onlyOverdue));
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOverdueFilter() {
    return SwitchListTile(
      title: const Text('Chỉ xem nợ quá hạn'),
      value: _localFilter.onlyOverdue,
      onChanged: (value) {
        setState(() => _localFilter = LedgerFilter(startDate: _localFilter.startDate, endDate: _localFilter.endDate, entryType: _localFilter.entryType, onlyOverdue: value));
      },
      contentPadding: EdgeInsets.zero,
    );
  }
}
