# PO-POS-History Sync Issues Comprehensive Analysis

## 🔍 CURRENT DATA FLOW PROBLEMS:

### **1. POS Screen Price Loading Issue:**

#### **Current POS Price Loading:**
```dart
// POS Screen displays price from ProductProvider.getCurrentPrice()
AppFormatter.formatCurrency(_viewModel!.productProvider.getCurrentPrice(product.id))
```

#### **POS View Model Refresh:**
```dart
Future<void> initialize({bool forceRefresh = false}) async {
  // FIXED: Always refresh products to get latest prices and stock
  if (productProvider.products.isEmpty || forceRefresh) {
    await productProvider.loadProducts();  // ← Only loads at startup
  }
}

Future<void> refreshProducts() async {
  await productProvider.loadProducts();    // ← Manual refresh only
}
```

#### **⚠️ PROBLEM:** 
- **POS doesn't auto-refresh** after PO operations
- **ProductProvider.getCurrentPrice()** caches old prices
- **No real-time sync** between Create PO → Receive PO → POS

### **2. Missing Data Links in PO Screens:**

#### **PO List Screen Missing:**
```dart
// Currently only shows:
Text(AppFormatter.formatCurrency(po.totalAmount))  // ← Only total amount

// MISSING:
// - Individual product selling prices
// - Batch links for delivered POs  
// - Price history links
// - Inventory impact summary
```

#### **PO Detail Screen Missing:**
```dart
// Currently shows batches but limited info:
final batch = provider.batchesForPO[index];
Text('Lô: ${batch.batchNumber}');
Text('SL: ${batch.quantity}');        // ← Only quantity

// MISSING:
// - Cost price per batch
// - Selling price per batch  
// - Profit margin calculation
// - Link to Product Detail Screen
// - Link to Batch History Screen
// - Price history entries from this PO
```

### **3. History Screens Disconnected:**

#### **Inventory History Screen:**
```dart
// Shows batches but no PO connection:
class InventoryHistoryScreen extends StatefulWidget {
  final Product product;  // ← Only knows product
  
  // MISSING:
  // - Which PO created each batch
  // - PO number in batch display
  // - Link back to PO Detail
  // - Cost vs selling price comparison
}
```

#### **Batch History Screen:**
```dart
// Generic batch display without PO context:
// MISSING:
// - PO reference in each batch entry
// - "View source PO" action
// - Price changes triggered by PO
// - Supplier information from PO
```

## 🛠️ REQUIRED SYNCHRONIZATION FIXES:

### **Fix 1: POS Real-time Price Sync**

#### **Add PO completion listener to POS:**
```dart
class _POSScreenState extends State<POSScreen> {
  StreamSubscription<String>? _poCompletionSubscription;
  
  @override
  void initState() {
    super.initState();
    
    // ✅ Listen for PO completion events
    _poCompletionSubscription = POCompletionEventBus.listen((poId) async {
      // Auto-refresh POS products when PO is received
      await _viewModel?.forceRefresh();
      _showPriceUpdateNotification();
    });
  }
  
  void _showPriceUpdateNotification() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Giá sản phẩm đã được cập nhật từ đơn nhập hàng'),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'Làm mới',
          onPressed: () => _viewModel?.forceRefresh(),
        ),
      ),
    );
  }
}
```

### **Fix 2: Enhanced PO List Screen**

#### **Add selling price and inventory impact:**
```dart
Widget _buildPOListItem(PurchaseOrder po) {
  return Card(
    child: ExpansionTile(
      title: Text(po.poNumber ?? 'PO-${po.id.substring(0, 8)}'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tổng: ${AppFormatter.formatCurrency(po.totalAmount)}'),
          // ✅ ADD: Inventory impact summary
          if (po.status == PurchaseOrderStatus.delivered)
            FutureBuilder<Map<String, dynamic>>(
              future: _getInventoryImpact(po.id),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final impact = snapshot.data!;
                  return Text(
                    '📦 ${impact['batchCount']} lô • 💰 ${impact['totalProfit']}% lời',
                    style: TextStyle(color: Colors.green[600], fontSize: 12),
                  );
                }
                return SizedBox.shrink();
              },
            ),
        ],
      ),
      children: [
        // ✅ ADD: Product-level breakdown with selling prices
        ...po.items.map((item) => ListTile(
          title: Text(item.productName ?? 'Product ${item.productId}'),
          subtitle: Text('SL: ${item.quantity} • Giá nhập: ${AppFormatter.formatCurrency(item.unitCost)}'),
          trailing: FutureBuilder<double>(
            future: _getCurrentSellingPrice(item.productId),
            builder: (context, snapshot) => Text(
              'Giá bán: ${AppFormatter.formatCurrency(snapshot.data ?? 0)}',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
            ),
          ),
          onTap: () => _navigateToProductDetail(item.productId),
        )),
      ],
    ),
  );
}

Future<Map<String, dynamic>> _getInventoryImpact(String poId) async {
  final provider = context.read<PurchaseOrderProvider>();
  final batches = await provider.getBatchesFromPO(poId);
  
  double totalCost = 0;
  double totalSelling = 0;
  
  for (final batch in batches) {
    totalCost += batch.costPrice * batch.quantity;
    final currentPrice = await _getCurrentSellingPrice(batch.productId);
    totalSelling += currentPrice * batch.quantity;
  }
  
  final profitPercentage = totalCost > 0 ? ((totalSelling - totalCost) / totalCost * 100) : 0;
  
  return {
    'batchCount': batches.length,
    'totalProfit': profitPercentage.toStringAsFixed(1),
  };
}
```

### **Fix 3: Enhanced PO Detail Screen**

#### **Add comprehensive batch and price information:**
```dart
Widget _buildEnhancedBatchesSection() {
  return Consumer<PurchaseOrderProvider>(
    builder: (context, provider, child) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Lô hàng đã tạo', style: Theme.of(context).textTheme.titleLarge),
              // ✅ ADD: Batch history link
              TextButton.icon(
                icon: Icon(Icons.history),
                label: Text('Xem lịch sử'),
                onPressed: () => _navigateToBatchHistory(provider.selectedPO!.id),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (provider.batchesForPO.isEmpty)
            const Text('Chưa có lô hàng nào được tạo từ đơn này.'),
          
          // ✅ Enhanced batch display with prices and actions
          ...provider.batchesForPO.map((batch) => Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green[100],
                child: Icon(Icons.inventory_2, color: Colors.green[700]),
              ),
              title: Text(batch.productName ?? 'Product ${batch.productId}'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Lô: ${batch.batchNumber} • SL: ${batch.quantity}'),
                  // ✅ ADD: Cost and selling price comparison
                  FutureBuilder<double>(
                    future: _getCurrentSellingPrice(batch.productId),
                    builder: (context, snapshot) {
                      final sellingPrice = snapshot.data ?? 0;
                      final profit = batch.costPrice > 0 ? ((sellingPrice - batch.costPrice) / batch.costPrice * 100) : 0;
                      return Text(
                        'Giá nhập: ${AppFormatter.formatCurrency(batch.costPrice)} → Giá bán: ${AppFormatter.formatCurrency(sellingPrice)} (${profit.toStringAsFixed(1)}%)',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      );
                    },
                  ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (action) => _handleBatchAction(action, batch),
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'view_product', child: Text('Xem sản phẩm')),
                  PopupMenuItem(value: 'view_batches', child: Text('Xem tất cả lô')),
                  PopupMenuItem(value: 'price_history', child: Text('Lịch sử giá')),
                ],
              ),
            ),
          )),
        ],
      );
    },
  );
}

void _handleBatchAction(String action, ProductBatch batch) {
  switch (action) {
    case 'view_product':
      Navigator.pushNamed(context, RouteNames.productDetail, arguments: batch.productId);
      break;
    case 'view_batches':
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => InventoryHistoryScreen(product: Product(id: batch.productId, name: batch.productName ?? '')),
      ));
      break;
    case 'price_history':
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => PriceHistoryScreen(productId: batch.productId),
      ));
      break;
  }
}
```

### **Fix 4: Enhanced History Screens with PO Links**

#### **Inventory History with PO references:**
```dart
Widget _buildBatchItemWithPOLink(ProductBatch batch) {
  return Card(
    child: ListTile(
      title: Text('Lô: ${batch.batchNumber}'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SL: ${batch.quantity} • Giá nhập: ${AppFormatter.formatCurrency(batch.costPrice)}'),
          // ✅ ADD: PO reference if available
          if (batch.purchaseOrderId != null)
            Row(
              children: [
                Icon(Icons.receipt, size: 14, color: Colors.blue[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Từ đơn nhập: ${batch.purchaseOrderId}',
                    style: TextStyle(fontSize: 12, color: Colors.blue[600]),
                  ),
                ),
                TextButton(
                  onPressed: () => _viewSourcePO(batch.purchaseOrderId!),
                  child: Text('Xem đơn', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
        ],
      ),
      trailing: Text(
        AppFormatter.formatDate(batch.receivedDate),
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
    ),
  );
}

void _viewSourcePO(String poId) async {
  final provider = context.read<PurchaseOrderProvider>();
  await provider.loadPODetails(poId);
  if (provider.selectedPO != null) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PurchaseOrderDetailScreen(purchaseOrder: provider.selectedPO!),
    ));
  }
}
```

### **Fix 5: Cross-Screen Event Bus for Real-time Updates**

#### **Global event system for price/inventory changes:**
```dart
class InventoryUpdateEventBus {
  static final _controller = StreamController<InventoryUpdateEvent>.broadcast();
  
  static Stream<InventoryUpdateEvent> get stream => _controller.stream;
  
  static void notifyPOReceived(String poId, List<String> productIds) {
    _controller.add(InventoryUpdateEvent(
      type: InventoryUpdateType.poReceived,
      poId: poId,
      productIds: productIds,
    ));
  }
  
  static void notifyPriceUpdated(String productId, double newPrice) {
    _controller.add(InventoryUpdateEvent(
      type: InventoryUpdateType.priceUpdated,
      productIds: [productId],
      newPrice: newPrice,
    ));
  }
}

class InventoryUpdateEvent {
  final InventoryUpdateType type;
  final String? poId;
  final List<String> productIds;
  final double? newPrice;
  
  InventoryUpdateEvent({
    required this.type,
    this.poId,
    required this.productIds,
    this.newPrice,
  });
}

enum InventoryUpdateType { poReceived, priceUpdated, batchCreated }
```

## 🎯 EXPECTED RESULTS AFTER FIXES:

### **✅ Real-time Synchronization:**
- **POS Screen** auto-refreshes prices after PO completion
- **Product Detail Screen** shows PO sources for batches
- **All screens** receive live updates via event bus

### **✅ Complete Data Links:**
- **PO List** shows inventory impact and profit margins
- **PO Detail** shows detailed batch info with price comparisons  
- **Batch History** links back to source POs
- **Cross-navigation** between all related screens

### **✅ Consistent User Experience:**
- **No manual refresh** required across screens
- **Context-aware navigation** (PO → Product → Batches → History)
- **Real-time notifications** for price/inventory changes
- **Complete audit trail** from PO to final sale

**The key is creating bidirectional links and real-time event synchronization across all screens involved in the inventory-pricing workflow!** 🔄📊💰