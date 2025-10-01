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

  List<dynamic> _getGroupedCustomerList(List<Customer> customers) {
    if (customers.isEmpty) return [];
    List<CustomerInfo> customerInfoList = customers.map((customer) {
      String tag = customer.name.isNotEmpty ? customer.name.substring(0, 1).toUpperCase() : '#';
      return CustomerInfo(customer: customer, tag: tag);
    }).toList();
    customerInfoList.sort((a, b) => a.customer.name.compareTo(b.customer.name));
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
    return LayoutBuilder(
      builder: (context, constraints) {
        const double tabletBreakpoint = 768;
        if (constraints.maxWidth >= tabletBreakpoint && !widget.isSelectionMode) {
          return _buildDesktopLayout();
        }
        return _buildMobileLayout();
      },
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isSelectionMode ? 'Chọn Khách Hàng' : 'Danh Sách Khách Hàng'),
        backgroundColor: Colors.green,
      ),
      body: _buildListContent(isMasterDetail: false),
      floatingActionButton: widget.isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AddCustomerScreen())),
              backgroundColor: Colors.green,
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản Lý Khách Hàng'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AddCustomerScreen())),
            tooltip: 'Thêm khách hàng',
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 4,
            child: _buildListContent(isMasterDetail: true),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            flex: 6,
            child: Consumer<CustomerProvider>(
              builder: (context, provider, child) {
                if (provider.selectedCustomer == null) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Chọn một khách hàng để xem chi tiết', style: TextStyle(fontSize: 16, color: Colors.grey)),
                      ],
                    ),
                  );
                }
                return CustomerDetailScreen(customer: provider.selectedCustomer!);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListContent({required bool isMasterDetail}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Tìm theo tên, số điện thoại...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (query) => _viewModel.handleSearch(query),
          ),
        ),
        Expanded(
          child: Consumer<CustomerProvider>(
            builder: (context, customerProvider, child) {
              if (customerProvider.isLoading && customerProvider.customers.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (customerProvider.hasError) {
                return Center(child: Text('Lỗi: ${customerProvider.errorMessage}'));
              }
              final groupedList = _getGroupedCustomerList(customerProvider.customers);
              if (groupedList.isEmpty) {
                return const Center(child: Text('Không tìm thấy khách hàng nào'));
              }
              return ListView.builder(
                itemCount: groupedList.length,
                itemBuilder: (context, index) {
                  final item = groupedList[index];
                  if (item is String) {
                    return _buildSuspensionWidget(item);
                  } else if (item is CustomerInfo) {
                    return _buildCustomerListItem(item, isMasterDetail);
                  }
                  return const SizedBox.shrink();
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSuspensionWidget(String tag) {
    return Container(
      height: 24,
      width: double.infinity,
      padding: const EdgeInsets.only(left: 16.0),
      color: Colors.grey[200],
      alignment: Alignment.centerLeft,
      child: Text(tag, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)),
    );
  }

  Widget _buildCustomerListItem(CustomerInfo info, bool isMasterDetail) {
    final customer = info.customer;
    final provider = context.read<CustomerProvider>();
    final bool isSelected = isMasterDetail && provider.selectedCustomer?.id == customer.id;

    return ListTile(
      tileColor: isSelected ? Colors.green.withOpacity(0.1) : null,
      leading: CircleAvatar(
        backgroundColor: Colors.green.withOpacity(0.2),
        child: Text(info.tag, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
      ),
      title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(customer.phone ?? 'Không có SĐT'),
      onTap: () {
        provider.selectCustomer(customer);
        if (!isMasterDetail) {
          if (widget.isSelectionMode) {
            Navigator.pop(context, customer);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => CustomerDetailScreen(customer: customer)),
            );
          }
        }
      },
    );
  }
}
