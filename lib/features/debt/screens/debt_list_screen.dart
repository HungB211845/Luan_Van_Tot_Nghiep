import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/debt_provider.dart';
import '../models/debt.dart';
import '../models/debt_status.dart';
import 'customer_debt_detail_screen.dart';
import '../../customers/services/customer_service.dart';
import '../../customers/models/customer.dart';
import 'package:intl/intl.dart';
import '../../customers/providers/customer_provider.dart';
import '../../../shared/widgets/loading_widget.dart';

/// Screen to list all debts grouped by customer
class DebtListScreen extends StatefulWidget {
  const DebtListScreen({super.key});

  @override
  State<DebtListScreen> createState() => _DebtListScreenState();
}

class _DebtListScreenState extends State<DebtListScreen> {
  final CustomerService _customerService = CustomerService();
  String _selectedStatus = 'all';
  bool _onlyOverdue = false;

  @override
  void initState() {
    super.initState();
    _loadDebts();
  }

  Future<void> _loadDebts() async {
    final provider = context.read<DebtProvider>();
    await provider.loadAllDebts(
      status: _selectedStatus == 'all' ? null : _selectedStatus,
      onlyOverdue: _onlyOverdue,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản Lý Công Nợ'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: Consumer<DebtProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.errorMessage.isNotEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(provider.errorMessage),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadDebts,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.debts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Không có công nợ',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return _buildDebtList(provider.debts);
              },
            ),
          ),
          _buildSummaryFooter(),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Trạng thái',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('Tất cả')),
                    ...DebtStatus.values.map((status) {
                      return DropdownMenuItem(
                        value: status.value,
                        child: Text(status.displayName),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value!;
                      _onlyOverdue = false;
                    });
                    _loadDebts();
                  },
                ),
              ),
              const SizedBox(width: 12),
              FilterChip(
                label: const Text('Chỉ quá hạn'),
                selected: _onlyOverdue,
                onSelected: (selected) {
                  setState(() {
                    _onlyOverdue = selected;
                    if (selected) _selectedStatus = 'all';
                  });
                  _loadDebts();
                },
                backgroundColor: Colors.white,
                selectedColor: Colors.red[100],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDebtList(List<Debt> debts) {
    // Group debts by customer
    final Map<String, List<Debt>> debtsByCustomer = {};
    for (final debt in debts) {
      debtsByCustomer.putIfAbsent(debt.customerId, () => []).add(debt);
    }

    return RefreshIndicator(
      onRefresh: _loadDebts,
      child: ListView.builder(
        itemCount: debtsByCustomer.length,
        itemBuilder: (context, index) {
          final customerId = debtsByCustomer.keys.elementAt(index);
          final customerDebts = debtsByCustomer[customerId]!;

          return _buildCustomerDebtCard(customerId, customerDebts);
        },
      ),
    );
  }

  Widget _buildCustomerDebtCard(String customerId, List<Debt> debts) {
    final totalRemaining = debts.fold<double>(
      0,
      (sum, debt) => sum + debt.remainingAmount,
    );

    // Determine status for icons
    final bool hasOverdue = debts.any((d) => d.isOverdue);
    final bool hasDueSoon = debts.any((d) => d.isDueSoon);

    if (totalRemaining <= 0) {
      return const SizedBox.shrink();
    }

    // Get customer info synchronously from the provider's cache
    final customer = context.read<CustomerProvider>().getCustomerFromCache(customerId);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CustomerDebtDetailScreen(customerId: customerId),
            ),
          ).then((_) => _loadDebts());
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Customer Info (Name & Phone)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer?.name ?? 'KH: ${customerId.substring(0, 8)}...',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (customer?.phone != null)
                      Text(
                        customer!.phone!,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Debt Info (Remaining Amount & Status Icon)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Còn nợ',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (hasOverdue)
                        const Icon(Icons.error, color: Colors.red, size: 20)
                      else if (hasDueSoon)
                        const Icon(Icons.hourglass_bottom, color: Colors.orange, size: 20),
                      if (hasOverdue || hasDueSoon) const SizedBox(width: 6),
                      Text(
                        NumberFormat.currency(locale: 'vi_VN', symbol: '₫')
                            .format(totalRemaining),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
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

  Widget _buildSummaryFooter() {
    return Consumer<DebtProvider>(
      builder: (context, provider, _) {
        final totalRemaining = provider.totalRemainingDebt;
        final overdueCount = provider.overdueDebts.length;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green[50],
            border: Border(
              top: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Tổng công nợ',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    NumberFormat.currency(locale: 'vi_VN', symbol: '₫')
                        .format(totalRemaining),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              if (overdueCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$overdueCount khoản quá hạn',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
