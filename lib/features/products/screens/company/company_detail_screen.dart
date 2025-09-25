import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../shared/utils/formatter.dart'; // Thêm import
import '../../models/company.dart';
import '../../providers/company_provider.dart';

class CompanyDetailScreen extends StatefulWidget {
  final Company company;

  const CompanyDetailScreen({Key? key, required this.company}) : super(key: key);

  static const String routeName = '/company-detail';

  @override
  _CompanyDetailScreenState createState() => _CompanyDetailScreenState();
}

class _CompanyDetailScreenState extends State<CompanyDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CompanyProvider>().loadCompanyProducts(widget.company.id);
    });
  }

  Future<void> _deleteCompany() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xác nhận xóa'),
          content: Text('Mày có chắc muốn xóa nhà cung cấp "${widget.company.name}" không?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Hủy'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Xóa'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final provider = context.read<CompanyProvider>();
      final success = await provider.deleteCompany(widget.company.id);

      if (mounted) {
        if (success) {
          Navigator.of(context).pop(); // Quay về danh sách
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa nhà cung cấp'), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: ${provider.errorMessage}'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _editCompany() {
    Navigator.of(context).pushNamed(RouteNames.editCompany, arguments: widget.company);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.company.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Sửa',
            onPressed: _editCompany,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Xóa',
            onPressed: _deleteCompany,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCompanyDetailsCard(),
            const SizedBox(height: 24),
            _buildProductList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyDetailsCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(Icons.person, 'Người liên hệ', widget.company.contactPerson),
            _buildDetailRow(Icons.phone, 'Số điện thoại', widget.company.phone),
            
            _buildDetailRow(Icons.location_on, 'Địa chỉ', widget.company.address),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 16),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  Widget _buildProductList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sản phẩm được cung cấp',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Consumer<CompanyProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (provider.companyProducts.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text('Không có sản phẩm nào từ nhà cung cấp này.'),
                ),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: provider.companyProducts.length,
              itemBuilder: (context, index) {
                final product = provider.companyProducts[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ListTile(
                    title: Text(product.name),
                    subtitle: Text('Tồn kho: ${AppFormatter.formatNumber(product.availableStock ?? 0)}'),
                    trailing: Text(AppFormatter.formatCurrency(product.currentPrice ?? 0)),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

