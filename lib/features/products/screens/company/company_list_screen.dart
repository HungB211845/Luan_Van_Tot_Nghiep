import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/routing/route_names.dart';
import '../../providers/company_provider.dart';

class CompanyListScreen extends StatefulWidget {
  const CompanyListScreen({Key? key}) : super(key: key);

  static const String routeName = RouteNames.companies;

  @override
  _CompanyListScreenState createState() => _CompanyListScreenState();
}

class _CompanyListScreenState extends State<CompanyListScreen> {
  @override
  void initState() {
    super.initState();
    // Load companies when the screen is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CompanyProvider>().loadCompanies();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhà Cung Cấp'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Thêm nhà cung cấp',
            onPressed: () {
              Navigator.of(context).pushNamed(RouteNames.addCompany);
            },
          ),
        ],
      ),
      body: Consumer<CompanyProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.companies.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.hasError) {
            return Center(
              child: Text('Đã xảy ra lỗi: ${provider.errorMessage}'),
            );
          }

          if (provider.companies.isEmpty) {
            return const Center(
              child: Text('Chưa có nhà cung cấp nào.'),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadCompanies(),
            child: ListView.builder(
              itemCount: provider.companies.length,
              itemBuilder: (context, index) {
                final company = provider.companies[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: ListTile(
                    title: Text(company.name),
                    subtitle: Text(company.phone ?? 'Không có SĐT'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).pushNamed(RouteNames.companyDetail, arguments: company);
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.receipt_long),
        label: const Text('Tạo Đơn Nhập Hàng'),
        onPressed: () {
          Navigator.of(context).pushNamed(RouteNames.createPurchaseOrder);
        },
      ),
    );
  }
}
