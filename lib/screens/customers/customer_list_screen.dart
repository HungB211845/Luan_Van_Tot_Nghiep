import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/customer_provider.dart';
import '../../models/customer.dart';
import 'customer_list_viewmodel.dart';
import 'add_customer_screen.dart';
import 'customer_detail_screen.dart';

class CustomerListScreen extends StatefulWidget {
  @override
  _CustomerListScreenState createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  late CustomerListViewModel _viewModel;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _viewModel = CustomerListViewModel(
      Provider.of<CustomerProvider>(context, listen: false)
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Danh Sách Khách Hàng'),
        backgroundColor: Colors.green,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'name_asc':
                  _viewModel.handleSort('name', true);
                  break;
                case 'name_desc':
                  _viewModel.handleSort('name', false);
                  break;
                case 'debt_high':
                  _viewModel.handleSort('debt_limit', false);
                  break;
                case 'created_new':
                  _viewModel.handleSort('created_at', false);
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'name_asc',
                child: Row(
                  children: [
                    Icon(Icons.sort_by_alpha, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Tên A-Z'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'name_desc',
                child: Row(
                  children: [
                    Icon(Icons.sort_by_alpha, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Tên Z-A'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'debt_high',
                child: Row(
                  children: [
                    Icon(Icons.money, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Hạn mức cao → thấp'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'created_new',
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.purple),
                    SizedBox(width: 8),
                    Text('Mới nhất → cũ nhất'),
                  ],
                ),
              ),
            ],
            icon: Icon(Icons.sort),
            tooltip: 'Sắp xếp',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm theo tên, số điện thoại hoặc địa chỉ...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (query) {
                _viewModel.handleSearch(query);
              },
            ),
          ),

          Expanded(
            child: Consumer<CustomerProvider>(
              builder: (context, customerProvider, child) {
                if (customerProvider.isLoading) {
                  return Center(child: CircularProgressIndicator());
                }

                if (customerProvider.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Lỗi: ${customerProvider.errorMessage}',
                          style: TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => _viewModel.handleRefresh(),
                          child: Text('Thử Lại'),
                        ),
                      ],
                    ),
                  );
                }

                final customers = customerProvider.customers;

                if (customers.isEmpty) {
                  return Center(
                    child: Text('Chưa có khách hàng nào'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => _viewModel.handleRefresh(),
                  child: ListView.builder(
                    itemCount: customers.length,
                    itemBuilder: (context, index) {
                      final customer = customers[index];
                      return Card(
                        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          title: Text(
                            customer.name,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (customer.phone != null)
                                Text('📞 ${customer.phone}'),
                              if (customer.address != null)
                                Text('📍 ${customer.address}'),
                              Text('💰 Hạn mức: ${customer.debtLimit.toStringAsFixed(0)} VNĐ'),
                              Text('💸 Lãi suất: ${customer.interestRate.toStringAsFixed(1)}%'),
                            ],
                          ),
                          trailing: Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CustomerDetailScreen(customer: customer),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddCustomerScreen(),
            ),
          );
        },
        child: Icon(Icons.add),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}