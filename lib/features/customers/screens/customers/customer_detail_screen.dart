import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/customer_provider.dart';
import '../../models/customer.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/utils/formatter.dart';

import '../../../debt/models/debt.dart';
import '../../../debt/providers/debt_provider.dart';
import 'edit_customer_screen.dart';
import 'customer_transaction_history_screen.dart';
import '../../../debt/screens/customer_debt_detail_screen.dart';

class CustomerDetailScreen extends StatefulWidget {
  final Customer customer;

  const CustomerDetailScreen({Key? key, required this.customer}) : super(key: key);

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Load both statistics and debt list when the screen opens
      context.read<CustomerProvider>().loadCustomerStatistics(widget.customer.id);
      context.read<DebtProvider>().loadCustomerDebts(widget.customer.id);
    });
  }

  // ... (All other helper methods like _showDeleteDialog, _callCustomer, etc. remain unchanged)
  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 8),
              Text('Xác Nhận Xóa'),
            ],
          ),
          content: Text(
            'Bạn có chắc chắn muốn xóa khách hàng "${widget.customer.name}"?\n\nHành động này không thể hoàn tác.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Hủy Bỏ'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop(); // Đóng dialog trước

                final success = await Provider.of<CustomerProvider>(context, listen: false)
                    .deleteCustomer(widget.customer.id);

                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Đã xóa khách hàng "${widget.customer.name}"'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  Navigator.pop(context); // Quay về danh sách
                } else {
                  final error = Provider.of<CustomerProvider>(context, listen: false).errorMessage;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Lỗi xóa khách hàng: $error'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Xóa', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _callCustomer(BuildContext context) async {
    if (widget.customer.phone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Khách hàng chưa có số điện thoại'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final phoneUrl = Uri.parse('tel:${widget.customer.phone}');

    try {
      if (await canLaunchUrl(phoneUrl)) {
        await launchUrl(phoneUrl);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể gọi điện được'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendMessage(BuildContext context) async {
    if (widget.customer.phone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Khách hàng chưa có số điện thoại')),
      );
      return;
    }

    final message = Uri.encodeComponent(
      'Xin chào ${widget.customer.name}, hiện tại anh/chị có khoản nợ cần thanh toán. Mong sắp xếp trả sớm. Cảm ơn!'
    );

    final smsUrl = Uri.parse('sms:${widget.customer.phone}?body=$message');

    try {
      if (await canLaunchUrl(smsUrl)) {
        await launchUrl(smsUrl);
      } else {
        final basicSmsUrl = Uri.parse('sms:${widget.customer.phone}');
        await launchUrl(basicSmsUrl);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _navigateToTransactionHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerTransactionHistoryScreen(
          customer: widget.customer,
        ),
      ),
    );
  }

  void _navigateToDebtManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerDebtDetailScreen(
          customerId: widget.customer.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.customer.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.green,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditCustomerScreen(customer: widget.customer),
                ),
              );
            },
            icon: const Icon(Icons.edit),
            tooltip: 'Chỉnh sửa',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') _showDeleteDialog(context);
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Xóa khách hàng', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ... (Header card and other info cards remain unchanged)
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.green.shade400, Colors.green.shade600],
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.customer.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thông Tin Chi Tiết',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (widget.customer.phone != null)
                      _buildInfoRow(
                        icon: Icons.phone,
                        iconColor: Colors.blue,
                        label: 'Số Điện Thoại',
                        value: widget.customer.phone!,
                      ),
                    _buildInfoRow(
                      icon: Icons.money,
                      iconColor: Colors.orange,
                      label: 'Hạn Mức Nợ',
                      value: AppFormatter.formatCurrency(widget.customer.debtLimit),
                    ),
                    _buildInfoRow(
                      icon: Icons.percent,
                      iconColor: Colors.purple,
                      label: 'Lãi Suất',
                      value: '${widget.customer.interestRate}% / tháng',
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Consumer2<CustomerProvider, DebtProvider>(
              builder: (context, customerProvider, debtProvider, child) {
                final stats = customerProvider.customerStatistics;
                final isLoading = customerProvider.loadingStatistics || debtProvider.isLoading;
                // Calculate remaining debt directly from DebtProvider (same as Debt List Screen)
                final customerDebts = debtProvider.debts
                    .where((debt) => debt.customerId == widget.customer.id)
                    .toList();
                final outstandingDebt = customerDebts
                    .fold<double>(0, (sum, debt) => sum + debt.remainingAmount);

                print('🔍 DEBUG Customer Detail - Customer ID: ${widget.customer.id}');
                print('🔍 DEBUG Total debts in provider: ${debtProvider.debts.length}');
                print('🔍 DEBUG Customer debts: ${customerDebts.length}');
                print('🔍 DEBUG Outstanding debt: $outstandingDebt');
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Thống Kê',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (isLoading)
                          const Center(child: LoadingWidget())
                        else
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.shopping_cart,
                                  title: 'Giao Dịch',
                                  value: '${stats?['transaction_count'] ?? 0}',
                                  onTap: () => _navigateToTransactionHistory(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.money_off,
                                  title: 'Nợ Còn Lại',
                                  value: AppFormatter.formatCurrency(outstandingDebt),
                                  onTap: () => _navigateToDebtManagement(),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            // NEW DEBT LIST CARD - with corrected provider calls
            _buildDebtListCard(),
          ],
        ),
      ),
    );
  }

  // New method to build the debt list card - iOS style collapsible
  Widget _buildDebtListCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Icon(Icons.receipt_long, color: Colors.orange),
          title: Text(
            'Chi Tiết Công Nợ',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          children: [
            Consumer<DebtProvider>(
              builder: (context, debtProvider, child) {
                if (debtProvider.isLoading) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: LoadingWidget(),
                  );
                }
                if (debtProvider.errorMessage.isNotEmpty) {
                  return Center(child: Text(debtProvider.errorMessage));
                }
                if (debtProvider.debts.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text('Khách hàng này không có nợ.'),
                    ),
                  );
                }

                return Column(
                  children: debtProvider.debts
                      .map((debt) => _buildDebtItem(debt))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // New method to build a single debt item with corrected model properties
  Widget _buildDebtItem(Debt debt) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                // CORRECTED: Handle nullable transactionId
                'Mã đơn: ${debt.transactionId?.substring(0, 8) ?? 'N/A'}...',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              Text(
                AppFormatter.formatDate(debt.createdAt),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Nợ gốc:', style: TextStyle(fontWeight: FontWeight.w500)),
              Text(
                // CORRECTED: Use 'originalAmount'
                AppFormatter.formatCurrency(debt.originalAmount),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Đã trả:', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.green)),
              Text(
                // CORRECTED: Use 'paidAmount'
                AppFormatter.formatCurrency(debt.paidAmount),
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Còn lại:', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.red)),
              Text(
                AppFormatter.formatCurrency(debt.remainingAmount),
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (debt != context.read<DebtProvider>().debts.last)
            const Divider(height: 1),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    VoidCallback? onTap,
  }) {
    final child = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: child,
      );
    }

    return child;
  }
}
