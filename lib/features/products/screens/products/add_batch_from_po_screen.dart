import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/purchase_order.dart';
import '../../models/purchase_order_status.dart';
import '../../models/company.dart';
import '../../providers/purchase_order_provider.dart';
import '../../providers/company_provider.dart';
import '../../providers/product_provider.dart';
import '../../../../shared/utils/formatter.dart';
import '../../../../shared/services/base_service.dart';
import 'receive_po_items_screen.dart';

/// Màn hình chọn PO để nhận hàng
/// Hiển thị danh sách PO thông minh: Mã PO + Nhà cung cấp + Ngày đặt
class AddBatchFromPOScreen extends StatefulWidget {
  const AddBatchFromPOScreen({Key? key}) : super(key: key);

  @override
  State<AddBatchFromPOScreen> createState() => _AddBatchFromPOScreenState();
}

class _AddBatchFromPOScreenState extends State<AddBatchFromPOScreen> {
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        context.read<PurchaseOrderProvider>().loadPurchaseOrders(),
        context.read<CompanyProvider>().loadCompanies(),
      ]);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<PurchaseOrder> _getFilteredPOs(List<PurchaseOrder> allPOs) {
    // Only show POs that are sent or confirmed (not draft or cancelled or delivered)
    var filtered = allPOs.where((po) {
      return po.status == PurchaseOrderStatus.sent ||
             po.status == PurchaseOrderStatus.confirmed;
    }).toList();

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((po) {
        final poNumber = (po.poNumber ?? '').toLowerCase();
        final companyProvider = context.read<CompanyProvider>();
        final supplier = companyProvider.companies.firstWhere(
          (c) => c.id == po.supplierId,
          orElse: () => Company(
            id: '',
            name: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            storeId: BaseService.getDefaultStoreId(),
          ),
        );
        final supplierName = supplier.name.toLowerCase();

        return poNumber.contains(query) || supplierName.contains(query);
      }).toList();
    }

    // Sort by date descending (newest first)
    filtered.sort((a, b) => b.orderDate.compareTo(a.orderDate));

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final product = context.read<ProductProvider>().selectedProduct;

    if (product == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Nhận Hàng từ PO'),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Không tìm thấy sản phẩm'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Chọn Đơn Nhập Hàng',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Product info banner
          Container(
            width: double.infinity,
            color: Colors.orange.withOpacity(0.1),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.inventory_2,
                  color: Colors.orange[700],
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sản phẩm',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm theo mã PO hoặc nhà cung cấp...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // PO list
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Consumer2<PurchaseOrderProvider, CompanyProvider>(
                  builder: (context, poProvider, companyProvider, _) {
                    final filteredPOs = _getFilteredPOs(poProvider.purchaseOrders);

                    if (filteredPOs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                ? 'Không tìm thấy đơn hàng nào'
                                : 'Chưa có đơn hàng nào để nhận',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Chỉ hiển thị đơn có trạng thái "Đã gửi" hoặc "Đã xác nhận"',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: filteredPOs.length,
                        itemBuilder: (context, index) {
                          final po = filteredPOs[index];
                          final supplier = companyProvider.companies.firstWhere(
                            (c) => c.id == po.supplierId,
                            orElse: () => Company(
                              id: '',
                              name: 'Không xác định',
                              createdAt: DateTime.now(),
                              updatedAt: DateTime.now(),
                              storeId: BaseService.getDefaultStoreId(),
                            ),
                          );

                          return _buildPOCard(context, po, supplier);
                        },
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildPOCard(BuildContext context, PurchaseOrder po, Company supplier) {
    Color statusColor;
    String statusText;

    switch (po.status) {
      case PurchaseOrderStatus.sent:
        statusColor = Colors.blue;
        statusText = 'Đã gửi';
        break;
      case PurchaseOrderStatus.confirmed:
        statusColor = Colors.indigo;
        statusText = 'Đã xác nhận';
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Khác';
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () async {
          // Load PO details before navigating
          await context.read<PurchaseOrderProvider>().loadPODetails(po.id);

          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ReceivePOItemsScreen(purchaseOrder: po),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // PO number and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      po.poNumber ?? 'PO-không có mã',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Supplier
              Row(
                children: [
                  Icon(
                    Icons.business,
                    size: 18,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      supplier.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Order date
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 18,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Ngày đặt: ${AppFormatter.formatDate(po.orderDate)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Total amount
              Row(
                children: [
                  Icon(
                    Icons.attach_money,
                    size: 18,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Tổng giá trị: ${AppFormatter.formatCurrency(po.totalAmount)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Action hint
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Nhấn để xem chi tiết',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}