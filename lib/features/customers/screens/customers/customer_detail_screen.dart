import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/customer_provider.dart';
import '../../models/customer.dart';

import 'edit_customer_screen.dart';

class CustomerDetailScreen extends StatelessWidget {
  final Customer customer;

  const CustomerDetailScreen({Key? key, required this.customer}) : super(key: key);

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
            'Bạn có chắc chắn muốn xóa khách hàng "${customer.name}"?\n\nHành động này không thể hoàn tác.',
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
                    .deleteCustomer(customer.id);

                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Đã xóa khách hàng "${customer.name}"'),
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
    if (customer.phone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Khách hàng chưa có số điện thoại'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final phoneUrl = Uri.parse('tel:${customer.phone}');

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
    if (customer.phone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Khách hàng chưa có số điện thoại')),
      );
      return;
    }

    // Thử cách này trước
    final message = Uri.encodeComponent(
      'Xin chào ${customer.name}, hiện tại anh/chị có khoản nợ cần thanh toán. Mong sắp xếp trả sớm. Cảm ơn!'
    );

    final smsUrl = Uri.parse('sms:${customer.phone}?body=$message');

    try {
      if (await canLaunchUrl(smsUrl)) {
        await launchUrl(smsUrl);
      } else {
        // Fallback: chỉ mở SMS app
        final basicSmsUrl = Uri.parse('sms:${customer.phone}');
        await launchUrl(basicSmsUrl);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _sendDebtReminder(BuildContext context) async {
    if (customer.phone == null) return;

    final message = Uri.encodeComponent(
      'Xin chào ${customer.name}, hiện tại anh/chị có khoản nợ cần thanh toán. Mong sắp xếp trả sớm. Cảm ơn!'
    );

    final smsUrl = Uri.parse('sms:${customer.phone}?body=$message');

    try {
      if (await canLaunchUrl(smsUrl)) {
        await launchUrl(smsUrl);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể gửi tin nhắn được'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          customer.name,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.green,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditCustomerScreen(customer: customer),
                ),
              );
            },
            icon: Icon(Icons.edit),
            tooltip: 'Chỉnh sửa',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'delete':
                  _showDeleteDialog(context);
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
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
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header với avatar và tên
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
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
                      child: Icon(
                        Icons.person,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      customer.name,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (customer.note != null) ...[
                      SizedBox(height: 4),
                      Text(
                        customer.note!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Quick actions
            if (customer.phone != null)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _callCustomer(context),
                              icon: Icon(Icons.phone, color: Colors.white),
                              label: Text('Gọi Điện', style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _sendMessage(context),
                              icon: Icon(Icons.message, color: Colors.white),
                              label: Text('Tin Nhắn', style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _sendDebtReminder(context),
                          icon: Icon(Icons.notifications, color: Colors.white),
                          label: Text('Gửi Nhắc Nợ', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            SizedBox(height: 16),

            // Thông tin chi tiết
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: EdgeInsets.all(16),
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
                    SizedBox(height: 16),

                    // Số điện thoại
                    if (customer.phone != null)
                      _buildInfoRow(
                        icon: Icons.phone,
                        iconColor: Colors.blue,
                        label: 'Số Điện Thoại',
                        value: customer.phone!,
                      ),

                    // Địa chỉ
                    if (customer.address != null)
                      _buildInfoRow(
                        icon: Icons.location_on,
                        iconColor: Colors.red,
                        label: 'Địa Chỉ',
                        value: customer.address!,
                        isMultiLine: true,
                      ),

                    // Hạn mức nợ
                    _buildInfoRow(
                      icon: Icons.money,
                      iconColor: Colors.orange,
                      label: 'Hạn Mức Nợ',
                      value: '${customer.debtLimit.toStringAsFixed(0)} VNĐ',
                    ),

                    // Lãi suất
                    _buildInfoRow(
                      icon: Icons.percent,
                      iconColor: Colors.purple,
                      label: 'Lãi Suất',
                      value: '${customer.interestRate}% / tháng',
                    ),

                    // Ngày tạo
                    _buildInfoRow(
                      icon: Icons.calendar_today,
                      iconColor: Colors.green,
                      label: 'Ngày Tạo',
                      value: '${customer.createdAt.day}/${customer.createdAt.month}/${customer.createdAt.year}',
                    ),

                    // Cập nhật cuối
                    _buildInfoRow(
                      icon: Icons.update,
                      iconColor: Colors.grey,
                      label: 'Cập Nhật Cuối',
                      value: '${customer.updatedAt.day}/${customer.updatedAt.month}/${customer.updatedAt.year}',
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Thống kê (placeholder for future features)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thống Kê',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.shopping_cart,
                            iconColor: Colors.blue,
                            title: 'Giao Dịch',
                            value: '0', // TODO: Load from database
                            subtitle: 'Tổng số lần mua',
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.money_off,
                            iconColor: Colors.red,
                            title: 'Công Nợ',
                            value: '0 VNĐ', // TODO: Load from database
                            subtitle: 'Hiện tại',
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.account_balance_wallet,
                            iconColor: Colors.green,
                            title: 'Doanh Thu',
                            value: '0 VNĐ', // TODO: Load from database
                            subtitle: 'Tổng mua hàng',
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.star,
                            iconColor: Colors.orange,
                            title: 'Mức Độ',
                            value: customer.debtLimit > 3000000 ? 'VIP' : 'Thường',
                            subtitle: 'Phân loại',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    bool isMultiLine = false,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Row(
        crossAxisAlignment: isMultiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          SizedBox(width: 12),
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
                SizedBox(height: 2),
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
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 24),
          SizedBox(height: 8),
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
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}