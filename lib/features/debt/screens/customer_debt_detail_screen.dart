import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../shared/utils/responsive.dart';
import '../../customers/models/customer.dart';
import '../../customers/services/customer_service.dart';
import '../../../../shared/utils/formatter.dart';
import '../../../../shared/utils/input_formatters.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../models/debt.dart';
import '../models/debt_payment.dart';
import '../providers/debt_provider.dart';
import '../../pos/models/transaction.dart';
import '../../pos/providers/transaction_provider.dart';
import '../../pos/screens/transaction/transaction_detail_screen.dart';
import 'add_payment_screen.dart';

// Data classes for the new grouped structure
enum LedgerEntryType { debt, payment, paymentGroup }

class PaymentGroup {
  final List<DebtPayment> payments;
  final DateTime date;
  double get totalAmount => payments.fold(0, (sum, p) => sum + p.amount);

  PaymentGroup({required this.payments, required this.date});
}

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

  bool get isActive =>
      startDate != null || endDate != null || entryType != null || onlyOverdue;
}

class CustomerDebtDetailScreen extends StatefulWidget {
  final String customerId;

  const CustomerDebtDetailScreen({super.key, required this.customerId});

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final debtProvider = context.read<DebtProvider>();
    await Future.wait([
      _customerService
          .getCustomerById(widget.customerId)
          .then((c) => _customer = c),
      debtProvider.loadCustomerDebts(widget.customerId),
      debtProvider.loadCustomerPayments(widget.customerId),
      debtProvider.loadCustomerDebtSummary(widget.customerId),
    ]);
    if (mounted) setState(() {});
  }

  List<dynamic> _groupConsecutivePayments(List<DebtPayment> payments) {
    if (payments.isEmpty) return [];

    payments.sort((a, b) => a.paymentDate.compareTo(b.paymentDate));

    List<dynamic> processedEntries = [];
    List<DebtPayment> currentGroup = [];

    for (int i = 0; i < payments.length; i++) {
      if (currentGroup.isEmpty) {
        currentGroup.add(payments[i]);
      } else {
        final lastPaymentInGroup = currentGroup.last;
        final currentPayment = payments[i];
        // Group payments within a 5-second threshold
        if (currentPayment.paymentDate
                .difference(lastPaymentInGroup.paymentDate)
                .inSeconds <
            5) {
          currentGroup.add(currentPayment);
        } else {
          if (currentGroup.length > 1) {
            processedEntries.add(PaymentGroup(
                payments: List.from(currentGroup), date: currentGroup.first.paymentDate));
          } else {
            processedEntries.add(currentGroup.first);
          }
          currentGroup = [currentPayment];
        }
      }
    }

    // Add the last group
    if (currentGroup.isNotEmpty) {
      if (currentGroup.length > 1) {
        processedEntries.add(PaymentGroup(
            payments: List.from(currentGroup), date: currentGroup.first.paymentDate));
      } else {
        processedEntries.add(currentGroup.first);
      }
    }

    return processedEntries;
  }

  List<MonthlyLedgerGroup> _createGroupedLedger(
    List<Debt> debts,
    List<DebtPayment> payments,
  ) {
    List<LedgerEntry> allEntries = [];

    final filteredDebts = debts.where((d) {
      if (_filter.onlyOverdue && !d.isOverdue) return false;
      if (_filter.startDate != null && d.createdAt.isBefore(_filter.startDate!))
        return false;
      if (_filter.endDate != null && d.createdAt.isAfter(_filter.endDate!))
        return false;
      return true;
    }).toList();

    final filteredPayments = payments.where((p) {
      if (_filter.startDate != null &&
          p.paymentDate.isBefore(_filter.startDate!))
        return false;
      if (_filter.endDate != null && p.paymentDate.isAfter(_filter.endDate!))
        return false;
      return true;
    }).toList();

    if (_filter.entryType != LedgerEntryType.payment && _filter.entryType != LedgerEntryType.paymentGroup) {
      for (var debt in filteredDebts) {
        allEntries.add(
          LedgerEntry(
            entry: debt,
            date: debt.createdAt,
            type: LedgerEntryType.debt,
          ),
        );
      }
    }
    if (_filter.entryType != LedgerEntryType.debt) {
      final processedPayments = _groupConsecutivePayments(filteredPayments);
      for (var paymentEntry in processedPayments) {
        if (paymentEntry is DebtPayment) {
           allEntries.add(
            LedgerEntry(
              entry: paymentEntry,
              date: paymentEntry.paymentDate,
              type: LedgerEntryType.payment,
            ),
          );
        } else if (paymentEntry is PaymentGroup) {
          allEntries.add(
            LedgerEntry(
              entry: paymentEntry,
              date: paymentEntry.date,
              type: LedgerEntryType.paymentGroup,
            ),
          );
        }
      }
    }

    // Search logic needs to be adapted for PaymentGroup
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      allEntries.removeWhere((entry) {
        if (entry.type == LedgerEntryType.debt) {
          final Debt debt = entry.entry;
          return !(debt.transactionId?.toLowerCase().contains(query) ??
                  false) &&
              !(debt.originalAmount.toString().contains(query));
        } else if (entry.type == LedgerEntryType.payment) {
          final DebtPayment payment = entry.entry;
          return !(payment.amount.toString().contains(query)) &&
              !(payment.notes?.toLowerCase().contains(query) ?? false);
        } else if (entry.type == LedgerEntryType.paymentGroup) {
          final PaymentGroup group = entry.entry;
          return !group.totalAmount.toString().contains(query) && !group.payments.any((p) => p.notes?.toLowerCase().contains(query) ?? false);
        }
        return true;
      });
    }

    allEntries.sort((a, b) => b.date.compareTo(a.date));

    Map<String, MonthlyLedgerGroup> groupedMap = {};
    for (var entry in allEntries) {
      String monthKey = DateFormat('yyyy-MM').format(entry.date);
      double debtIncurred = 0;
      double amountPaid = 0;

      if (entry.type == LedgerEntryType.debt) {
        debtIncurred = (entry.entry as Debt).originalAmount;
      } else if (entry.type == LedgerEntryType.payment) {
        amountPaid = (entry.entry as DebtPayment).amount;
      } else if (entry.type == LedgerEntryType.paymentGroup) {
        amountPaid = (entry.entry as PaymentGroup).totalAmount;
      }

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

  Future<void> _navigateToTransactionDetails(String transactionId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final tx = await context.read<TransactionProvider>().getTransactionById(
        transactionId,
      );
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
          const SnackBar(
            content: Text('Không tìm thấy chi tiết giao dịch.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải giao dịch: $e'),
            backgroundColor: Colors.red,
          ),
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

  void _showAddTransactionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddTransactionSheet(
        customerId: widget.customerId,
        onSuccess: () {
          _loadData(); // Reload data on success
        },
      ),
    );
  }

  String _buildAppBarTitle() {
    if (!_filter.isActive) return 'Sổ Cái Công Nợ';
    if (_filter.onlyOverdue) return 'Sổ Cái (Quá hạn)';
    if (_filter.entryType == LedgerEntryType.debt)
      return 'Sổ Cái (Nợ phát sinh)';
    if (_filter.entryType == LedgerEntryType.payment || _filter.entryType == LedgerEntryType.paymentGroup) return 'Sổ Cái (Đã trả)';
    return 'Sổ Cái (Đã lọc)';
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      title: _buildAppBarTitle(),
      showBackButton: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: _showAddTransactionSheet,
          tooltip: 'Thêm Giao Dịch',
        ),
        IconButton(
          icon: Icon(
            _filter.isActive
                ? Icons.filter_alt
                : Icons.filter_alt_outlined,
          ),
          onPressed: _showFilterSheet,
          tooltip: 'Lọc',
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Consumer<DebtProvider>(
          builder: (context, provider, _) {
            final groupedLedger = _createGroupedLedger(
              provider.debts,
              provider.payments,
            );
            return CustomScrollView(
              slivers: [
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
          // Keep this for quick payment, but our new button is more versatile
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddPaymentScreen(customerId: widget.customerId),
            ),
          ).then((_) => _loadData());
        },
        icon: const Icon(Icons.payment),
        label: const Text('Thanh Toán'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildLedgerContent(
    DebtProvider provider,
    List<MonthlyLedgerGroup> groupedLedger,
  ) {
    if (provider.isLoading && groupedLedger.isEmpty) {
      return const SliverFillRemaining(child: Center(child: LoadingWidget()));
    }
    if (groupedLedger.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: Text('Không có hoạt động nào khớp bộ lọc.')),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final monthGroup = groupedLedger[index];
        return _buildMonthGroup(monthGroup);
      }, childCount: groupedLedger.length),
    );
  }

  Widget _buildMonthGroup(MonthlyLedgerGroup group) {
    final monthDate = DateFormat('yyyy-MM').parse(group.monthKey);
    final formattedMonth = 'Tháng ${monthDate.month}, ${monthDate.year}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            top: 24,
            bottom: 8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formattedMonth,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Phát sinh: ${AppFormatter.formatCurrency(group.debtIncurred)}',
                    style: const TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                  Text(
                    'Đã trả: ${AppFormatter.formatCurrency(group.amountPaid)}',
                    style: const TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ],
              ),
            ],
          ),
        ),
        ...group.entries.map((entry) => _buildLedgerItem(entry)),
      ],
    );
  }

  Widget _buildLedgerItem(LedgerEntry ledgerEntry) {
    switch (ledgerEntry.type) {
      case LedgerEntryType.debt:
        return _buildDebtItem(ledgerEntry.entry as Debt);
      case LedgerEntryType.payment:
        return _buildPaymentItem(ledgerEntry.entry as DebtPayment);
      case LedgerEntryType.paymentGroup:
        return _buildPaymentGroupItem(ledgerEntry.entry as PaymentGroup);
    }
  }

  Widget _buildDebtItem(Debt debt) {
    final String title = (debt.notes?.contains('Ghi nợ thủ công') ?? false)
        ? 'Ghi nợ thủ công'
        : 'Giao dịch bán hàng';
    final String dateSubtitle =
        'Ngày tạo: ${AppFormatter.formatDate(debt.createdAt)} • Đáo hạn: ${debt.dueDate != null ? AppFormatter.formatDate(debt.dueDate!) : 'N/A'}';
    final String amountText = '+ ${AppFormatter.formatCurrency(debt.originalAmount)}';
    final Color amountColor = Colors.orange;
    final IconData icon = Icons.add_shopping_cart;
    final VoidCallback? onTap = debt.transactionId != null
        ? () => _navigateToTransactionDetails(debt.transactionId!)
        : null;

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        onLongPress: () {
          if (debt.transactionId != null) {
            Clipboard.setData(ClipboardData(text: debt.transactionId!));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đã sao chép Mã Giao Dịch'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey[200]!, width: 1),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: amountColor, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateSubtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: (debt.isOverdue)
                            ? Colors.red
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                amountText,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: amountColor,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentItem(DebtPayment payment, {bool isGrouped = false}) {
     final String title = 'Thanh toán (${payment.paymentMethod})';
     final String dateSubtitle = 'Ngày trả: ${AppFormatter.formatDate(payment.paymentDate)}';
     final String amountText = '- ${AppFormatter.formatCurrency(payment.amount)}';
     final Color amountColor = Colors.green;
     final IconData icon = Icons.check_circle;

    return Material(
      color: isGrouped ? Colors.transparent : Colors.white,
      child: Container(
          padding: EdgeInsets.symmetric(horizontal: isGrouped ? 24 : 16, vertical: 12),
          decoration: BoxDecoration(
            border: isGrouped ? null : Border(
              bottom: BorderSide(color: Colors.grey[200]!, width: 1),
            ),
          ),
          child: Row(
            children: [
              if (!isGrouped) ...[
                Icon(icon, color: amountColor, size: 28),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: isGrouped ? 14 : 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateSubtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                     if (payment.notes?.isNotEmpty ?? false)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          'Ghi chú: ${payment.notes}',
                          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey[700]),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                amountText,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: amountColor,
                  fontSize: isGrouped ? 15 : 16,
                ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildPaymentGroupItem(PaymentGroup group) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
      leading: const Icon(Icons.check_circle, color: Colors.green, size: 28),
      title: Text(
        'Thanh toán gộp',
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
      ),
      subtitle: Text(
        'Ngày: ${AppFormatter.formatDate(group.date)}',
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      trailing: Text(
        '- ${AppFormatter.formatCurrency(group.totalAmount)}',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.green,
          fontSize: 16,
        ),
      ),
      children: group.payments.map((p) => _buildPaymentItem(p, isGrouped: true)).toList(),
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
                  const Text(
                    'Hiện còn nợ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    AppFormatter.formatCurrency(remaining),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
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

// The new Bottom Sheet for adding transactions (Refactored and Simplified)
class _AddTransactionSheet extends StatefulWidget {
  final String customerId;
  final VoidCallback onSuccess;

  const _AddTransactionSheet({
    required this.customerId,
    required this.onSuccess,
  });

  @override
  State<_AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<_AddTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isProcessing = true);

    final amount = double.tryParse(_amountController.text.replaceAll('.', '')) ?? 0;
    final notes = _notesController.text;
    final provider = context.read<DebtProvider>();

    try {
      final success = await provider.createManualDebt(
        customerId: widget.customerId,
        amount: amount,
        notes: notes,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ghi nợ thành công!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context); // Close the sheet
          widget.onSuccess(); // Trigger data reload
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(provider.errorMessage.isNotEmpty
                  ? provider.errorMessage
                  : 'Đã có lỗi xảy ra khi ghi nợ.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi nghiêm trọng: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ghi Nợ Thủ Công', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Số tiền nợ', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()],
              validator: (value) {
                if (value == null || value.isEmpty) return 'Vui lòng nhập số tiền';
                final amount = double.tryParse(value.replaceAll('.', '')) ?? 0;
                if (amount <= 0) return 'Số tiền phải lớn hơn 0';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Ghi chú (tùy chọn)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, // Correct color
                  foregroundColor: Colors.white, // Set text color for better contrast
                ),
                onPressed: _isProcessing ? null : _submit,
                child: _isProcessing
                    ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.white))
                    : const Text('Xác nhận Ghi Nợ'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
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
          const Text(
            'Lọc Sổ Cái',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
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
        const Text(
          'Khoảng thời gian',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.date_range, size: 18),
                label: Text(
                  _localFilter.startDate == null
                      ? 'Từ ngày'
                      : AppFormatter.formatDate(_localFilter.startDate!),
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _localFilter.startDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null)
                    setState(
                      () => _localFilter = LedgerFilter(
                        startDate: picked,
                        endDate: _localFilter.endDate,
                        entryType: _localFilter.entryType,
                        onlyOverdue: _localFilter.onlyOverdue,
                      ),
                    );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.date_range, size: 18),
                label: Text(
                  _localFilter.endDate == null
                      ? 'Đến ngày'
                      : AppFormatter.formatDate(_localFilter.endDate!),
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _localFilter.endDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null)
                    setState(
                      () => _localFilter = LedgerFilter(
                        startDate: _localFilter.startDate,
                        endDate: picked,
                        entryType: _localFilter.entryType,
                        onlyOverdue: _localFilter.onlyOverdue,
                      ),
                    );
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
        const Text(
          'Loại giao dịch',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Tất cả'),
              selected: _localFilter.entryType == null,
              onSelected: (selected) {
                if (selected)
                  setState(
                    () => _localFilter = LedgerFilter(
                      startDate: _localFilter.startDate,
                      endDate: _localFilter.endDate,
                      entryType: null,
                      onlyOverdue: _localFilter.onlyOverdue,
                    ),
                  );
              },
            ),
            ChoiceChip(
              label: const Text('Nợ phát sinh'),
              selected: _localFilter.entryType == LedgerEntryType.debt,
              onSelected: (selected) {
                if (selected)
                  setState(
                    () => _localFilter = LedgerFilter(
                      startDate: _localFilter.startDate,
                      endDate: _localFilter.endDate,
                      entryType: LedgerEntryType.debt,
                      onlyOverdue: _localFilter.onlyOverdue,
                    ),
                  );
              },
            ),
            ChoiceChip(
              label: const Text('Đã trả'),
              selected: _localFilter.entryType == LedgerEntryType.payment,
              onSelected: (selected) {
                if (selected)
                  setState(
                    () => _localFilter = LedgerFilter(
                      startDate: _localFilter.startDate,
                      endDate: _localFilter.endDate,
                      entryType: LedgerEntryType.payment,
                      onlyOverdue: _localFilter.onlyOverdue,
                    ),
                  );
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
        setState(
          () => _localFilter = LedgerFilter(
            startDate: _localFilter.startDate,
            endDate: _localFilter.endDate,
            entryType: _localFilter.entryType,
            onlyOverdue: value,
          ),
        );
      },
      contentPadding: EdgeInsets.zero,
    );
  }
}
