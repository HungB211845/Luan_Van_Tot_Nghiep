import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../customers/models/customer.dart';
import '../../../customers/providers/customer_provider.dart';
import '../../models/payment_method.dart';
import '../../models/transaction.dart';
import '../../providers/transaction_provider.dart';
import '../../../../shared/utils/formatter.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/agri_bottom_nav_wrapper.dart';
import '../../../../core/routing/route_names.dart';
import 'transaction_detail_screen.dart';

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Initial load
      context.read<TransactionProvider>().loadTransactions();
      // Load customers for the filter sheet
      context.read<CustomerProvider>().loadCustomers();
    });

    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final provider = context.read<TransactionProvider>();
      final newFilter = provider.filter.copyWith(
        searchText: _searchController.text,
      );
      provider.updateFilter(newFilter);
    });
  }

  void _onScroll() {
    final provider = context.read<TransactionProvider>();
    if (provider.hasMore &&
        !provider.isLoadingMore &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300) {
      provider.loadMore();
    }
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Add swipe gesture for iOS-style back navigation
      onHorizontalDragEnd: (DragEndDetails details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
          // Swipe right detected, navigate back
          Navigator.of(context).pop();
        }
      },
      // Add tap-to-scroll-to-top for status bar area (iOS behavior)
      onTapUp: (TapUpDetails details) {
        final statusBarHeight = MediaQuery.of(context).padding.top;
        if (details.globalPosition.dy <= statusBarHeight) {
          _scrollToTop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Lịch Sử Giao Dịch'),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          centerTitle: true,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () => _showFilterSheet(context),
            ),
          ],
        ),
        body: Column(
          children: [
            _buildSearchBar(),
            _buildQuickChips(),
            Expanded(child: _buildTransactionList()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Tìm theo mã HĐ hoặc tên khách hàng...',
            prefixIcon: const Icon(Icons.search, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.grey[200],
            contentPadding: const EdgeInsets.symmetric(
              vertical: 0,
              horizontal: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickChips() {
    final provider = context.read<TransactionProvider>();
    final currentFilter = provider.filter;

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          children: [
            ActionChip(
              label: const Text('Hôm nay'),
              onPressed: () {
                final now = DateTime.now();
                provider.updateFilter(
                  currentFilter.copyWith(
                    startDate: DateTime(now.year, now.month, now.day),
                    endDate: now,
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            ActionChip(
              label: const Text('7 ngày'),
              onPressed: () {
                final now = DateTime.now();
                provider.updateFilter(
                  currentFilter.copyWith(
                    startDate: now.subtract(const Duration(days: 6)),
                    endDate: now,
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            ActionChip(
              label: const Text('30 ngày'),
              onPressed: () {
                final now = DateTime.now();
                provider.updateFilter(
                  currentFilter.copyWith(
                    startDate: now.subtract(const Duration(days: 29)),
                    endDate: now,
                  ),
                );
              },
            ),
            const Spacer(),
            if (currentFilter.startDate != null ||
                currentFilter.endDate != null)
              ActionChip(
                avatar: const Icon(Icons.clear, size: 16),
                label: const Text('Xóa ngày'),
                onPressed: () {
                  provider.updateFilter(
                    currentFilter.copyWith(
                      clearStartDate: true,
                      clearEndDate: true,
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList() {
    return Consumer<TransactionProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.transactions.isEmpty) {
          return const Center(
            child: LoadingWidget(message: 'Đang tải giao dịch...'),
          );
        }

        if (provider.status == TransactionStatus.error &&
            provider.transactions.isEmpty) {
          return Center(child: Text('Lỗi: ${provider.errorMessage}'));
        }

        if (provider.transactions.isEmpty) {
          return const Center(child: Text('Không tìm thấy giao dịch nào.'));
        }

        final grouped = provider.groupedTransactions;
        final dateKeys = grouped.keys.toList();

        return RefreshIndicator(
          onRefresh: provider.refresh,
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: dateKeys.length + (provider.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == dateKeys.length) {
                return _buildLoadingFooter();
              }

              final dateKey = dateKeys[index];
              final transactionsOnDate = grouped[dateKey]!;

              // Calculate total revenue for this date
              final totalRevenue = transactionsOnDate.fold<double>(
                0.0,
                (sum, tx) => sum + tx.totalAmount,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
                    child: Text(
                      '$dateKey  •  ${transactionsOnDate.length} giao dịch  •  ${AppFormatter.formatCurrency(totalRevenue)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  ...transactionsOnDate.map(
                    (tx) => _buildTransactionCard(context, tx),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTransactionCard(BuildContext context, Transaction transaction) {
    // Smart primary info selection
    final hasCustomerName = transaction.customerName != null &&
                             transaction.customerName!.isNotEmpty &&
                             transaction.customerName != 'Khách lẻ';

    final primaryText = hasCustomerName
        ? transaction.customerName!
        : _formatInvoiceShort(transaction.invoiceNumber);

    final secondaryText = hasCustomerName
        ? _formatInvoiceShort(transaction.invoiceNumber)
        : 'Khách lẻ';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onLongPress: () {
          Clipboard.setData(
            ClipboardData(text: transaction.invoiceNumber ?? ''),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã sao chép mã HĐ: ${transaction.invoiceNumber}'),
              backgroundColor: Colors.green,
            ),
          );
        },
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  TransactionDetailScreen(transaction: transaction),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side: Primary character (name or invoice)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Primary text (large, bold)
                    Text(
                      primaryText,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: Colors.black87,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Secondary text (small, gray)
                    Text(
                      secondaryText,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Right side: Amount and time
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Amount (large, bold, green)
                  Text(
                    AppFormatter.formatCurrency(transaction.totalAmount),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: Colors.green,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Time and payment method
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(transaction.transactionDate),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _getPaymentIcon(transaction.paymentMethod),
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      if (transaction.isDebt) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.credit_card,
                          size: 14,
                          color: Colors.red[600],
                        ),
                      ],
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

  String _formatInvoiceShort(String? invoiceNumber) {
    if (invoiceNumber == null || invoiceNumber.isEmpty) return 'N/A';

    // Format: INV...31565 (show last 5 digits)
    if (invoiceNumber.length > 8) {
      final lastDigits = invoiceNumber.substring(invoiceNumber.length - 5);
      return 'INV...$lastDigits';
    }
    return invoiceNumber;
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  IconData _getPaymentIcon(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return Icons.money;
      case PaymentMethod.bankTransfer:
        return Icons.account_balance;
      case PaymentMethod.debt:
        return Icons.credit_card;
      default:
        return Icons.payment;
    }
  }

  Widget _buildPaymentMethodChip(PaymentMethod method) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: method == PaymentMethod.cash
            ? Colors.green.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: method == PaymentMethod.cash ? Colors.green : Colors.orange,
          width: 0.5,
        ),
      ),
      child: Text(
        method.displayName,
        style: TextStyle(
          color: method == PaymentMethod.cash
              ? Colors.green[800]
              : Colors.orange[800],
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDebtStatusChip(bool isUnpaid) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isUnpaid
            ? Colors.red.withOpacity(0.1)
            : Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnpaid ? Colors.red : Colors.blue,
          width: 0.5,
        ),
      ),
      child: Text(
        isUnpaid ? 'Còn nợ' : 'Đã trả',
        style: TextStyle(
          color: isUnpaid ? Colors.red[800] : Colors.blue[800],
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildLoadingFooter() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16.0),
      child: Center(child: LoadingWidget(message: 'Đang tải thêm...')),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(
            value: context.read<TransactionProvider>(),
          ),
          ChangeNotifierProvider.value(value: context.read<CustomerProvider>()),
        ],
        child: const _FilterSheet(),
      ),
    );
  }
}

/// The content of the filter bottom sheet.
class _FilterSheet extends StatefulWidget {
  const _FilterSheet();

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late TransactionFilter _localFilter;

  @override
  void initState() {
    super.initState();
    _localFilter = context.read<TransactionProvider>().filter;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bộ lọc nâng cao',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            Expanded(
              child: ListView(
                children: [
                  _buildDateRangePicker(),
                  const SizedBox(height: 16),
                  _buildAmountRange(),
                  const SizedBox(height: 16),
                  _buildPaymentMethodFilter(),
                  const SizedBox(height: 16),
                  _buildDebtStatusFilter(),
                  const SizedBox(height: 16),
                  _buildCustomerFilter(),
                ],
              ),
            ),
            const Divider(height: 24),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Khoảng ngày',
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
                      () => _localFilter = _localFilter.copyWith(
                        startDate: picked,
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
                      () =>
                          _localFilter = _localFilter.copyWith(endDate: picked),
                    );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAmountRange() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Khoảng tiền',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Tối thiểu',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => _localFilter = _localFilter.copyWith(
                  minAmount: double.tryParse(v),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Tối đa',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => _localFilter = _localFilter.copyWith(
                  maxAmount: double.tryParse(v),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentMethodFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Phương thức thanh toán',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        Wrap(
          spacing: 8,
          children: PaymentMethod.values.map((method) {
            final isSelected = _localFilter.paymentMethods.contains(method);
            return FilterChip(
              label: Text(method.displayName),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  final newMethods = Set<PaymentMethod>.from(
                    _localFilter.paymentMethods,
                  );
                  if (selected) {
                    newMethods.add(method);
                  } else {
                    newMethods.remove(method);
                  }
                  _localFilter = _localFilter.copyWith(
                    paymentMethods: newMethods,
                  );
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDebtStatusFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Trạng thái ghi nợ',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        Wrap(
          spacing: 8,
          children: ['unpaid', 'paid'].map((status) {
            final isSelected = _localFilter.debtStatus == status;
            return FilterChip(
              label: Text(status == 'unpaid' ? 'Còn nợ' : 'Đã trả'),
              selected: isSelected,
              onSelected: (selected) {
                setState(
                  () => _localFilter = _localFilter.copyWith(
                    debtStatus: selected ? status : null,
                  ),
                );
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCustomerFilter() {
    return Consumer<CustomerProvider>(
      builder: (context, customerProvider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Khách hàng',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Wrap(
              spacing: 8,
              children: customerProvider.customers.map((customer) {
                final isSelected = _localFilter.customerIds.contains(
                  customer.id,
                );
                return FilterChip(
                  label: Text(customer.name),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      final newIds = Set<String>.from(_localFilter.customerIds);
                      if (selected) {
                        newIds.add(customer.id);
                      } else {
                        newIds.remove(customer.id);
                      }
                      _localFilter = _localFilter.copyWith(customerIds: newIds);
                    });
                  },
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            child: const Text('Reset'),
            onPressed: () {
              context.read<TransactionProvider>().updateFilter(
                const TransactionFilter(),
              );
              Navigator.pop(context);
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            child: const Text('Áp dụng'),
            onPressed: () {
              context.read<TransactionProvider>().updateFilter(_localFilter);
              Navigator.pop(context);
            },
          ),
        ),
      ],
    );
  }
}
