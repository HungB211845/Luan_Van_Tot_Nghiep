import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/customer.dart';
import '../../providers/customer_provider.dart';
import 'add_customer_screen.dart';
import 'customer_detail_screen.dart';
import 'customer_list_viewmodel.dart';

// Wrapper class to hold tag information
class CustomerInfo {
  final Customer customer;
  final String tag;

  CustomerInfo({required this.customer, required this.tag});
}

class CustomerListScreen extends StatefulWidget {
  final bool isSelectionMode;

  const CustomerListScreen({Key? key, this.isSelectionMode = false})
      : super(key: key);

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
        Provider.of<CustomerProvider>(context, listen: false));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel.initialize();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Helper to process and group the list
  List<dynamic> _getGroupedCustomerList(List<Customer> customers) {
    if (customers.isEmpty) return [];

    // Create info objects with tags
    List<CustomerInfo> customerInfoList = customers.map((customer) {
      String tag = customer.name.isNotEmpty
          ? customer.name.substring(0, 1).toUpperCase()
          : '#';
      return CustomerInfo(customer: customer, tag: tag);
    }).toList();

    // Sort alphabetically
    customerInfoList.sort((a, b) => a.customer.name.compareTo(b.customer.name));

    // Manually insert headers
    List<dynamic> groupedList = [];
    String? lastTag;
    for (var info in customerInfoList) {
      if (info.tag != lastTag) {
        lastTag = info.tag;
        groupedList.add(lastTag!);
      }
      groupedList.add(info);
    }
    return groupedList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isSelectionMode
            ? 'Chọn Khách Hàng'
            : 'Danh Sách Khách Hàng'),
        backgroundColor: Colors.green,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm theo tên, số điện thoại...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
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
                if (customerProvider.isLoading && customerProvider.customers.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (customerProvider.hasError) {
                  return Center(
                      child: Text('Lỗi: ${customerProvider.errorMessage}'));
                }

                final groupedList = _getGroupedCustomerList(customerProvider.customers);

                if (groupedList.isEmpty) {
                  return const Center(child: Text('Không tìm thấy khách hàng nào'));
                }

                // Use standard ListView.builder
                return ListView.builder(
                  itemCount: groupedList.length,
                  itemBuilder: (context, index) {
                    final item = groupedList[index];
                    if (item is String) {
                      // It's a header tag
                      return _buildSuspensionWidget(item);
                    } else if (item is CustomerInfo) {
                      // It's a customer item
                      return _buildCustomerListItem(item);
                    }
                    return const SizedBox.shrink(); // Should not happen
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: widget.isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddCustomerScreen(),
                  ),
                );
              },
              backgroundColor: Colors.green,
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildSuspensionWidget(String tag) {
    return Container(
      height: 24,
      width: double.infinity,
      padding: const EdgeInsets.only(left: 16.0),
      color: Colors.grey[200],
      alignment: Alignment.centerLeft,
      child: Text(
        tag,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.black54,
        ),
      ),
    );
  }

  Widget _buildCustomerListItem(CustomerInfo info) {
    final customer = info.customer;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.green.withOpacity(0.1),
        child: Text(
          info.tag,
          style: const TextStyle(
              color: Colors.green, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(customer.name,
          style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(customer.phone ?? 'Không có SĐT'),
      onTap: () {
        if (widget.isSelectionMode) {
          Navigator.pop(context, customer);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CustomerDetailScreen(customer: customer),
            ),
          );
        }
      },
    );
  }
}