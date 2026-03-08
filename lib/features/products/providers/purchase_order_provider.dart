import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/purchase_order.dart';
import '../models/purchase_order_item.dart';
import '../models/purchase_order_status.dart';
import '../models/product_batch.dart';
import '../models/product_unit.dart'; // Add this import
import '../services/purchase_order_service.dart';
import '../services/product_service.dart'; // For product filtering
import '../models/product.dart'; // For adding to cart
import './product_provider.dart'; // Import ProductProvider
import './product_unit_provider.dart';
import '../../../shared/services/base_service.dart';
import '../../../shared/utils/formatter.dart'; // 🔥 ADD: For proper formatting

// Trạng thái cho giỏ hàng nhập

// Trạng thái cho giỏ hàng nhập
enum PricingUnitSelection { container, base }

class FormattedQuantity {
  final String display;
  final String? conversionNote;
  final ProductUnit? displayUnit;
  final ProductUnit? baseUnit;

  const FormattedQuantity({
    required this.display,
    this.conversionNote,
    this.displayUnit,
    this.baseUnit,
  });
}

class POCartItem {
  final Product product;
  int quantity;
  double unitCost;
  double? sellingPrice;
  String? unit;
  String? unitId;
  String? defaultUnitId;
  String? defaultUnitName;
  double? selectedUnitFactor;
  double? defaultUnitFactor;
  double? defaultUnitCost;
  double? displaySellingPrice;
  double? baseSellingPrice;
  PricingUnitSelection pricingSelection;
  bool allowsPricingToggle;

  final TextEditingController quantityController;
  final TextEditingController unitCostController;
  final TextEditingController sellingPriceController;
  final TextEditingController defaultUnitCostController;
  final TextEditingController displaySellingPriceController;

  POCartItem({
    required this.product,
    this.quantity = 1,
    this.unitCost = 0.0,
    this.sellingPrice,
    this.unit,
    this.unitId,
    this.defaultUnitId,
    this.defaultUnitName,
    this.selectedUnitFactor,
    this.defaultUnitFactor,
    this.defaultUnitCost,
    this.displaySellingPrice,
    this.baseSellingPrice,
    this.pricingSelection = PricingUnitSelection.container,
    this.allowsPricingToggle = false,
  })  : quantityController = TextEditingController(text: quantity.toString()),
        unitCostController = TextEditingController(
          text: unitCost > 0 ? AppFormatter.formatNumber(unitCost) : '',
        ),
        sellingPriceController = TextEditingController(
          text: (() {
            final seed = sellingPrice ?? product.currentSellingPrice;
            return seed > 0 ? AppFormatter.formatNumber(seed) : '';
          })(),
        ),
        defaultUnitCostController = TextEditingController(
          text: defaultUnitCost != null && defaultUnitCost! > 0
              ? AppFormatter.formatNumber(defaultUnitCost!)
              : '',
        ),
        displaySellingPriceController = TextEditingController(
          text: (() {
            final seed = displaySellingPrice ??
                sellingPrice ?? product.currentSellingPrice;
            return seed > 0 ? AppFormatter.formatNumber(seed) : '';
          })(),
        ) {
    this.sellingPrice ??= product.currentSellingPrice;
    this.displaySellingPrice ??= sellingPrice ?? product.currentSellingPrice;
    if (this.baseSellingPrice == null &&
        this.displaySellingPrice != null &&
        this.defaultUnitFactor != null &&
        this.defaultUnitFactor! > 0) {
      this.baseSellingPrice =
          this.displaySellingPrice! / this.defaultUnitFactor!;
    }
  }

  void dispose() {
    quantityController.dispose();
    unitCostController.dispose();
    sellingPriceController.dispose();
    defaultUnitCostController.dispose();
    displaySellingPriceController.dispose();
  }

  POCartItem copyWith({
    Product? product,
    int? quantity,
    double? unitCost,
    double? sellingPrice,
    String? unit,
    String? unitId,
    String? defaultUnitId,
    String? defaultUnitName,
    double? selectedUnitFactor,
    double? defaultUnitFactor,
    double? defaultUnitCost,
    double? displaySellingPrice,
    double? baseSellingPrice,
    PricingUnitSelection? pricingSelection,
    bool? allowsPricingToggle,
  }) {
    return POCartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      unitCost: unitCost ?? this.unitCost,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      unit: unit ?? this.unit,
      unitId: unitId ?? this.unitId,
      defaultUnitId: defaultUnitId ?? this.defaultUnitId,
      defaultUnitName: defaultUnitName ?? this.defaultUnitName,
      selectedUnitFactor: selectedUnitFactor ?? this.selectedUnitFactor,
      defaultUnitFactor: defaultUnitFactor ?? this.defaultUnitFactor,
      defaultUnitCost: defaultUnitCost ?? this.defaultUnitCost,
      displaySellingPrice: displaySellingPrice ?? this.displaySellingPrice,
      baseSellingPrice: baseSellingPrice ?? this.baseSellingPrice,
      pricingSelection: pricingSelection ?? this.pricingSelection,
      allowsPricingToggle: allowsPricingToggle ?? this.allowsPricingToggle,
    );
  }
}
enum POStatus { idle, loading, success, error }

class PurchaseOrderProvider extends ChangeNotifier {
  final PurchaseOrderService _poService = PurchaseOrderService();
  final ProductService _productService = ProductService();
  final ProductProvider _productProvider;
  final ProductUnitProvider _productUnitProvider;

  PurchaseOrderProvider(
    this._productProvider,
    this._productUnitProvider,
  );

  // State
  List<PurchaseOrder> _purchaseOrders = [];
  PurchaseOrder? _selectedPO;
  List<PurchaseOrderItem> _selectedPOItems = [];
  List<ProductBatch> _batchesForPO = []; // State mới
  final Map<String, List<ProductUnit>> _productUnitsById = {};
  POStatus _status = POStatus.idle;
  String _errorMessage = '';

  // PO Cart State
  String? _selectedSupplierId;
  List<POCartItem> _poCartItems = [];

  // Product Filtering State
  List<Product> _filteredProducts = [];
  bool _loadingProducts = false;

  // Search and Filter State
  String _searchText = '';
  List<String> _selectedSupplierIds = [];
  String _sortBy = 'order_date'; // Default sort
  bool _sortAsc = false;

  // Pagination for list screen (client-side)
  final int _pageSize = 20;
  int _visibleCount = 20;

  // Range filters
  DateTime? _fromDate;
  DateTime? _toDate;
  double? _minTotal;
  double? _maxTotal;
  // Status filters
  Set<PurchaseOrderStatus> _statusFilters = {};

  // Getters
  List<PurchaseOrder> get purchaseOrders => _purchaseOrders;
  PurchaseOrder? get selectedPO => _selectedPO;
  List<PurchaseOrderItem> get selectedPOItems => _selectedPOItems;
  List<ProductBatch> get batchesForPO => _batchesForPO; // Getter mới
  List<ProductUnit>? unitsForProduct(String productId) =>
      _productUnitsById[productId];
  POStatus get status => _status;
  String get errorMessage => _errorMessage;
  bool get isLoading => _status == POStatus.loading;

  // PO Cart Getters
  List<POCartItem> get poCartItems => _poCartItems;
  String? get selectedSupplierId => _selectedSupplierId;
  double get poCartTotal => _poCartItems.fold(0, (sum, item) {
    // Only include items with quantity > 0 in total
    return sum + (item.quantity > 0 ? item.quantity * item.unitCost : 0);
  });

  // Get valid items for PO creation (quantity > 0)
  List<POCartItem> get validPOCartItems =>
      _poCartItems.where((item) => item.quantity > 0).toList();

  // Product Filtering Getters
  List<Product> get filteredProducts => _filteredProducts;
  bool get loadingProducts => _loadingProducts;

  // Search and Filter Getters
  String get searchText => _searchText;
  List<String> get selectedSupplierIds => _selectedSupplierIds;
  String get sortBy => _sortBy;
  bool get sortAsc => _sortAsc;

  // Pagination getters
  List<PurchaseOrder> get visibleOrders =>
      _purchaseOrders.take(_visibleCount).toList();
  bool get reachedEnd => _visibleCount >= _purchaseOrders.length;

  // Range filter getters
  DateTime? get fromDate => _fromDate;
  DateTime? get toDate => _toDate;
  double? get minTotal => _minTotal;
  double? get maxTotal => _maxTotal;
  Set<PurchaseOrderStatus> get statusFilters => _statusFilters;

  // Methods
  Future<void> loadPurchaseOrders() async {
    _setStatus(POStatus.loading);
    try {
      _purchaseOrders = await _poService.getPurchaseOrders();
      _setStatus(POStatus.success);
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> searchPurchaseOrders() async {
    _setStatus(POStatus.loading);
    try {
      // All filtering and sorting is now done by the database RPC.
      final fetched = await _poService.searchPurchaseOrders(
        searchText: _searchText,
        supplierIds: _selectedSupplierIds.isNotEmpty ? _selectedSupplierIds : null,
        statusFilters: _statusFilters.isNotEmpty ? _statusFilters : null,
        fromDate: _fromDate,
        toDate: _toDate,
        minTotal: _minTotal,
        maxTotal: _maxTotal,
        sortBy: _sortBy,
        sortAsc: _sortAsc,
      );

      _purchaseOrders = fetched;

      debugPrint(
        '🔍 searchPurchaseOrders: RPC returned ${_purchaseOrders.length} rows, first=${_purchaseOrders.isNotEmpty ? _purchaseOrders.first.poNumber : 'none'}',
      );

      // Reset pagination on every search
      _visibleCount = _pageSize;
      _setStatus(POStatus.success);
    } catch (e) {
      _setError(e.toString());
    }
  }

  // Methods to update filters
  void setSearchText(String text) {
    _searchText = text;
    notifyListeners();
    // Optional: debounce search
  }

  void toggleSupplierFilter(String supplierId) {
    if (_selectedSupplierIds.contains(supplierId)) {
      _selectedSupplierIds.remove(supplierId);
    } else {
      _selectedSupplierIds.add(supplierId);
    }
    notifyListeners();
  }

  void setSort(String sortBy, bool ascending) {
    _sortBy = sortBy;
    _sortAsc = ascending;
    notifyListeners();
  }

  void applyFiltersAndSearch() {
    searchPurchaseOrders();
  }

  // Load next page (client-side)
  void loadMore() {
    if (reachedEnd) return;
    _visibleCount = (_visibleCount + _pageSize).clamp(
      0,
      _purchaseOrders.length,
    );
    notifyListeners();
  }

  // Range filter setters
  void setDateRange({DateTime? from, DateTime? to}) {
    _fromDate = from;
    _toDate = to;
    notifyListeners();
  }

  void setAmountRange({double? min, double? max}) {
    _minTotal = min;
    _maxTotal = max;
    notifyListeners();
  }

  // Status filter setter
  void toggleStatusFilter(PurchaseOrderStatus status) {
    if (_statusFilters.contains(status)) {
      _statusFilters.remove(status);
    } else {
      _statusFilters.add(status);
    }
    notifyListeners();
  }

  // Quick date ranges
  void quickToday() {
    final now = DateTime.now();
    setDateRange(from: now, to: now);
  }

  void quickLast7Days() {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 6));
    setDateRange(from: start, to: now);
  }

  void quickLast30Days() {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 29));
    setDateRange(from: start, to: now);
  }

  Future<void> loadPODetails(String poId) async {
    // Clear previously selected order to avoid flashing stale data while loading.
    _selectedPO = null;
    _selectedPOItems = [];
    _batchesForPO = [];
    _setStatus(POStatus.loading);
    try {
      final details = await _poService.getPurchaseOrderDetails(poId);
      // Gán giá trị sau khi đã có dữ liệu để tránh lỗi
      _selectedPO = details['order'];
      _selectedPOItems = details['items'];
      await _ensureUnitsForProducts(
        _selectedPOItems.map((item) => item.productId).toSet(),
      );
      await loadBatchesForPO(poId);
      _setStatus(POStatus.success);
    } catch (e) {
      _setError(e.toString());
    } finally {
      // Đảm bảo notify dù thành công hay thất bại
      notifyListeners();
    }
  }

  // Method mới để tải batches từ PO
  Future<void> loadBatchesForPO(String poId) async {
    try {
      _batchesForPO = await _poService.getBatchesFromPO(poId);
      notifyListeners();
    } catch (e) {
      // Lỗi này có thể bỏ qua một cách nhẹ nhàng vì nó là dữ liệu phụ
      print('Error loading batches for PO: $e');
    }
  }

  // Method mới cho quy trình nhận hàng
  Future<bool> receivePO(String poId) async {
    _setStatus(POStatus.loading);
    try {
      // Ensure PO is in CONFIRMED state before receiving (backend requirement)
      final currentStatus = _selectedPO?.status;
      if (currentStatus == PurchaseOrderStatus.sent) {
        final confirmedPO = await _poService.updatePurchaseOrderStatus(
          poId,
          PurchaseOrderStatus.confirmed,
        );
        _selectedPO = confirmedPO;
        _updatePurchaseOrderInList(confirmedPO);
      }

      final result = await _poService.receivePurchaseOrder(poId);
      final updatedPO = result['po'] as PurchaseOrder;
      final updatedProducts = (result['products'] as List<Product>?) ?? const [];
      final unitsMap = (result['units'] as Map<String, List<ProductUnit>>?) ??
          const <String, List<ProductUnit>>{};

      // Update local PO state
      _selectedPO = updatedPO;
      _updatePurchaseOrderInList(updatedPO);

      // Determine affected product IDs (fallback to existing items if service didn't return products)
      final productIds = updatedProducts.isNotEmpty
          ? updatedProducts.map((p) => p.id).toList()
          : _selectedPOItems.map((item) => item.productId).toList();

      // Refresh product data & caches
      for (final productId in productIds) {
        await _productProvider.refreshProductSummary(productId);
        final prefetchedUnits = unitsMap[productId];

        // Invalidate ProductUnitProvider cache and reload latest units
        _productUnitProvider.clearCache(productId: productId);
        final refreshedUnits = prefetchedUnits != null && prefetchedUnits.isNotEmpty
            ? prefetchedUnits
            : await _productUnitProvider.getUnitsForProduct(
                productId,
                forceRefresh: true,
              );
        if (refreshedUnits.isNotEmpty) {
          _productUnitsById[productId] = refreshedUnits;
        }
      }
      if (productIds.isNotEmpty) {
        await _productProvider.refreshInventoryAfterGoodsReceipt(productIds);
        
        // 🔥 FIX: Force refresh stock for affected products to prevent 0 stock display
        await _forceRefreshStockForProducts(productIds);
      }

      await loadPODetails(poId);

      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// 🔥 NEW: Force refresh stock cache for specific products
  Future<void> _forceRefreshStockForProducts(List<String> productIds) async {
    try {
      for (final productId in productIds) {
        // Force reload stock from database
        final updatedStock = await _productService.getAvailableStock(productId);
        
        // Update ProductProvider stock cache directly
        _productProvider.updateStockCache(productId, updatedStock);
        
        debugPrint('🔄 Force refreshed stock for $productId: $updatedStock');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to force refresh stock: $e');
    }
  }

  void _updatePurchaseOrderInList(PurchaseOrder updatedPO) {
    final index = _purchaseOrders.indexWhere((po) => po.id == updatedPO.id);
    if (index != -1) {
      _purchaseOrders[index] = updatedPO;
    } else {
      _purchaseOrders.insert(0, updatedPO);
    }
  }

  Future<void> _ensureUnitsForProducts(Set<String> productIds) async {
    for (final productId in productIds) {
      if (_productUnitsById.containsKey(productId) &&
          _productUnitsById[productId]!.isNotEmpty) {
        continue;
      }
      try {
        final units =
            await _productUnitProvider.getUnitsForProduct(productId);
        _productUnitsById[productId] = units;
      } catch (e) {
        debugPrint('Unable to load units for $productId: $e');
      }
    }
  }

  FormattedQuantity formatItemQuantity(PurchaseOrderItem item) {
    return _formatQuantityForProduct(
      productId: item.productId,
      baseQuantity: item.quantity,
      fallbackUnitName: item.unit,
    );
  }

  PriceDisplayInfo? itemImportPriceDisplay(PurchaseOrderItem item) {
    final units = _productUnitsById[item.productId];
    if (units == null || units.isEmpty) return null;
    return _productUnitProvider.buildPriceDisplayFromUnits(
      units: units,
      basePrice: item.unitCost,
      mode: PriceDisplayMode.defaultUnit,
    );
  }

  PriceDisplayInfo? itemSellingPriceDisplay(PurchaseOrderItem item) {
    final sellingBase = item.sellingPrice ?? 0;
    if (sellingBase <= 0) return null;
    final units = _productUnitsById[item.productId];
    if (units == null || units.isEmpty) return null;
    return _productUnitProvider.buildPriceDisplayFromUnits(
      units: units,
      basePrice: sellingBase,
      mode: PriceDisplayMode.defaultUnit,
    );
  }

  PriceDisplayInfo? cartItemPriceDisplay(
    POCartItem item, {
    required bool forSelling,
    PriceDisplayMode mode = PriceDisplayMode.defaultUnit,
  }) {
    final units = _productUnitsById[item.product.id];
    if (units == null || units.isEmpty) return null;

    double? basePrice;
    String? targetUnitId = mode == PriceDisplayMode.selectedUnit
        ? item.unitId
        : item.defaultUnitId;

    if (forSelling) {
      basePrice = item.baseSellingPrice;
      if (basePrice == null || basePrice <= 0) {
        final defaultPrice = item.displaySellingPrice;
        if (defaultPrice != null &&
            defaultPrice > 0 &&
            item.defaultUnitFactor != null &&
            item.defaultUnitFactor! > 0) {
          basePrice = defaultPrice / item.defaultUnitFactor!;
        } else if (item.sellingPrice != null && item.sellingPrice! > 0) {
          basePrice = _productUnitProvider.convertPriceToBaseFromUnits(
            units: units,
            displayPrice: item.sellingPrice!,
            fromUnitId: item.unitId,
          );
        }
      }
      basePrice ??= item.product.currentSellingPrice;
    } else {
      basePrice = item.defaultUnitCost;
      if (basePrice == null || basePrice <= 0) {
        basePrice = _productUnitProvider.convertPriceToBaseFromUnits(
          units: units,
          displayPrice: item.unitCost,
          fromUnitId: item.unitId,
        );
      }
      basePrice ??= item.unitCost;
    }

    if (basePrice == null || basePrice <= 0) return null;
    return _productUnitProvider.buildPriceDisplayFromUnits(
      units: units,
      basePrice: basePrice,
      targetUnitId: targetUnitId,
      mode: mode,
    );
  }

  FormattedQuantity formatBatchQuantity(ProductBatch batch) {
    return _formatQuantityForProduct(
      productId: batch.productId,
      baseQuantity: batch.quantity,
    );
  }

  String _formatQuantity(double value) {
    final rounded = value.roundToDouble();
    if ((rounded - value).abs() < 0.0001) {
      return rounded.toInt().toString();
    }
    return value.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(
          RegExp(r'\.$'),
          '',
        );
  }

  FormattedQuantity _formatQuantityForProduct({
    required String productId,
    required int baseQuantity,
    String? fallbackUnitName,
  }) {
    final units = _productUnitsById[productId];
    if (units != null && units.isNotEmpty) {
      final List<ProductUnit> positiveUnits = units
          .where((u) => u.conversionFactor > 0)
          .toList()
        ..sort(
          (a, b) => b.conversionFactor.compareTo(a.conversionFactor),
        );

      if (positiveUnits.isNotEmpty) {
        final ProductUnit baseUnit = positiveUnits.reduce(
          (value, element) =>
              element.conversionFactor < value.conversionFactor
                  ? element
                  : value,
        );

        final List<ProductUnit> containerUnits =
            positiveUnits.where((u) => u != baseUnit).toList();

        ProductUnit chosenUnit = baseUnit;
        double quantityInChosen =
            baseQuantity / chosenUnit.conversionFactor;

        if (containerUnits.isNotEmpty) {
          ProductUnit? divisibleUnit;
          double? divisibleQty;
          for (final unit in containerUnits) {
            final double raw = baseQuantity / unit.conversionFactor;
            if (_isWhole(raw)) {
              divisibleUnit = unit;
              divisibleQty = raw;
              break;
            }
          }
          chosenUnit = divisibleUnit ?? containerUnits.first;
          quantityInChosen =
              divisibleQty ?? (baseQuantity / chosenUnit.conversionFactor);
        }

        final ProductUnit noteUnit = _selectNoteUnit(
          units: positiveUnits,
          chosenUnit: chosenUnit,
          baseUnit: baseUnit,
        );

        if (chosenUnit == baseUnit) {
          return FormattedQuantity(
            display: _formatUnitQuantityWithName(quantityInChosen, baseUnit),
            displayUnit: baseUnit,
            baseUnit: baseUnit,
          );
        }

        final double chosenFactor = chosenUnit.conversionFactor;
        final int wholePortion = (baseQuantity / chosenFactor).floor();

        if (wholePortion == 0) {
          final double baseCount =
              baseQuantity / noteUnit.conversionFactor;
          return FormattedQuantity(
            display: _formatUnitQuantityWithName(baseCount, noteUnit),
            conversionNote: _buildConversionNote(
              chosenUnit: chosenUnit,
              noteUnit: noteUnit,
            ),
            displayUnit: noteUnit,
            baseUnit: noteUnit,
          );
        }

        final double remainderBaseUnits =
            baseQuantity - (wholePortion * chosenFactor);
        final double remainderInNoteUnit =
            remainderBaseUnits / noteUnit.conversionFactor;
        final bool hasRemainder =
            !_isWhole(quantityInChosen) && remainderBaseUnits > 0;

        String display;
        if (!hasRemainder) {
          display =
              '${_formatQuantity(quantityInChosen)} ${chosenUnit.unitName}';
        } else if (remainderInNoteUnit > 0) {
          final String remainderLabel = _isWhole(remainderInNoteUnit)
              ? _formatUnitQuantityWithName(remainderInNoteUnit, noteUnit)
              : _formatUnitQuantityWithName(
                  remainderBaseUnits / baseUnit.conversionFactor,
                  baseUnit,
                );
          display =
              '${_formatQuantity(wholePortion.toDouble())} ${chosenUnit.unitName} + $remainderLabel';
        } else {
          display =
              '${_formatQuantity(quantityInChosen)} ${chosenUnit.unitName}';
        }

        final String? note = _buildConversionNote(
          chosenUnit: chosenUnit,
          noteUnit: noteUnit,
        );

        return FormattedQuantity(
          display: display,
          conversionNote: note,
          displayUnit: chosenUnit,
          baseUnit: noteUnit,
        );
      }
    }

    final String display = (fallbackUnitName != null &&
            fallbackUnitName.isNotEmpty)
        ? '${_formatQuantity(baseQuantity.toDouble())} $fallbackUnitName'
        : _formatQuantity(baseQuantity.toDouble());

    return FormattedQuantity(display: display);
  }

  bool _isWhole(double value) {
    return (value - value.round()).abs() < 1e-4;
  }

  ProductUnit _selectNoteUnit({
    required List<ProductUnit> units,
    required ProductUnit chosenUnit,
    required ProductUnit baseUnit,
  }) {
    final candidates = units
        .where((u) =>
            u.conversionFactor <= chosenUnit.conversionFactor &&
            u.conversionFactor > 0)
        .toList()
      ..sort((a, b) => a.conversionFactor.compareTo(b.conversionFactor));

    ProductUnit? preferred = candidates.firstWhere(
      (u) => u != chosenUnit && _looksLikePack(u.unitName),
      orElse: () => baseUnit,
    );

    if (preferred == chosenUnit) {
      preferred = baseUnit;
    }

    return preferred ?? baseUnit;
  }

  String _formatUnitQuantityWithName(double quantity, ProductUnit unit) {
    final String formattedQuantity = _formatQuantity(quantity);
    final lower = unit.unitName.trim().toLowerCase();

    if (lower == 'ml') {
      final double liters = quantity / 1000;
      if (liters >= 1 && _isWhole(liters)) {
        return '${_formatQuantity(liters)} L';
      }
    }
    if (lower == 'g') {
      final double kilograms = quantity / 1000;
      if (kilograms >= 1 && _isWhole(kilograms)) {
        return '${_formatQuantity(kilograms)} kg';
      }
    }

    return '$formattedQuantity ${unit.unitName}';
  }

  bool _looksLikePack(String name) {
    final lower = name.toLowerCase();
    return lower.contains('gói') ||
        lower.contains('chai') ||
        lower.contains('lọ') ||
        lower.contains('hộp') ||
        lower.contains('bao') ||
        lower.contains('túi') ||
        lower.contains('bịch') ||
        RegExp(r'\d').hasMatch(lower);
  }

  String? _buildConversionNote({
    required ProductUnit chosenUnit,
    required ProductUnit noteUnit,
  }) {
    if (chosenUnit == noteUnit) {
      return null;
    }
    final double ratio =
        chosenUnit.conversionFactor / noteUnit.conversionFactor;
    final String formatted = _formatUnitQuantityWithName(ratio, noteUnit);
    return '(1 ${chosenUnit.unitName} = $formatted)';
  }

  // Get product IDs from PO items for inventory refresh
  List<String> getProductIdsFromPO(String poId) {
    return _selectedPOItems.map((item) => item.productId).toList();
  }

  // PO Cart Management
  void setSupplierForCart(String supplierId) {
    if (_selectedSupplierId != supplierId) {
      // Store references to dispose later (after UI rebuild)
      final itemsToDispose = List<POCartItem>.from(_poCartItems);
      
      // Clear cart immediately for UI
      _poCartItems.clear();
      _selectedSupplierId = supplierId;
      _loadProductsForSupplier(); // Auto-load filtered products
      
      // Notify listeners first so UI rebuilds with empty cart
      notifyListeners();
      
      // THEN dispose controllers after a short delay to allow UI to rebuild
      Future.delayed(Duration.zero, () {
        for (var item in itemsToDispose) {
          item.dispose();
        }
      });
    } else {
      _selectedSupplierId = supplierId;
      notifyListeners();
    }
  }

  // Load products filtered by selected supplier
  Future<void> _loadProductsForSupplier() async {
    if (_loadingProducts) return; // Prevent concurrent calls

    _loadingProducts = true;
    notifyListeners();

    try {
      _filteredProducts = await _productService.getProductsByCompany(
        _selectedSupplierId,
      );
    } catch (e) {
      debugPrint('Error loading products for supplier: $e');
      _filteredProducts = [];
    } finally {
      _loadingProducts = false;
      notifyListeners();
    }
  }

  // Force reload products for current supplier
  Future<void> refreshProductsForSupplier() async {
    await _loadProductsForSupplier();
  }

  void addToPOCart(
    Product product, {
    int quantity = 1,
    double? unitCost,
    String? unit,
    double? sellingPrice,
  }) {
    final existingIndex = _poCartItems.indexWhere(
      (item) => item.product.id == product.id,
    );
    if (existingIndex != -1) {
      _poCartItems[existingIndex].quantity += quantity;
    } else {
      _poCartItems.add(
        POCartItem(
          product: product,
          quantity: quantity,
          unitCost: unitCost ?? 0.0,
          sellingPrice: sellingPrice,
          unit: unit,
        ),
      );
    }
    notifyListeners();
  }

  void addPOCartItem(POCartItem item) {
    final existingIndex = _poCartItems.indexWhere(
      (cartItem) => cartItem.product.id == item.product.id,
    );
    if (existingIndex != -1) {
      // Dispose old item's controllers before replacing
      _poCartItems[existingIndex].dispose();
      _poCartItems[existingIndex] = item;
    } else {
      _poCartItems.add(item);
    }
    notifyListeners();
  }

  void updatePOCartItem(
    String productId, {
    int? newQuantity,
    double? newUnitCost,
    double? newDefaultUnitCost,
    double? newSellingPrice,
    double? newDisplaySellingPrice,
    String? newUnit,
    String? newUnitId, // 🔥 NEW: Add unitId parameter
    String? newDefaultUnitId,
    String? newDefaultUnitName,
    double? newSelectedUnitFactor,
    double? newDefaultUnitFactor,
    PricingUnitSelection? newPricingSelection,
    bool? newAllowsPricingToggle,
    bool? clearSellingPrice, // Add explicit flag for clearing
    bool? clearDefaultUnitCost,
    bool? clearDisplaySellingPrice,
  }) {
    final index = _poCartItems.indexWhere(
      (item) => item.product.id == productId,
    );
    if (index == -1) return;

    final item = _poCartItems[index];

    double? _ratioForItem(POCartItem cartItem) {
      final selected = cartItem.selectedUnitFactor;
      final base = cartItem.defaultUnitFactor;
      if (selected == null || base == null || base == 0) return null;
      return selected / base;
    }

    double? _toBase(POCartItem cartItem, double containerValue) {
      final ratio = _ratioForItem(cartItem);
      if (ratio == null || ratio == 0) return null;
      return containerValue / ratio;
    }

    double? _toContainer(POCartItem cartItem, double baseValue) {
      final ratio = _ratioForItem(cartItem);
      if (ratio == null) return null;
      return baseValue * ratio;
    }

    void syncControllers(POCartItem cartItem) {
      final containerCost =
          cartItem.unitCost > 0 ? cartItem.unitCost : null;
      final baseCost = cartItem.defaultUnitCost ??
          (containerCost != null ? _toBase(cartItem, containerCost) : null);
      if (baseCost != null) {
        cartItem.defaultUnitCost = baseCost;
        cartItem.defaultUnitCostController.text =
            baseCost > 0 ? AppFormatter.formatNumber(baseCost) : '';
      } else {
        cartItem.defaultUnitCostController.text = '';
      }
      if (containerCost != null) {
        cartItem.unitCostController.text =
            AppFormatter.formatNumber(containerCost);
      } else {
        cartItem.unitCostController.text = '';
      }

      double? containerSell = cartItem.sellingPrice;
      if ((containerSell == null || containerSell <= 0) &&
          cartItem.displaySellingPrice != null) {
        containerSell =
            _toContainer(cartItem, cartItem.displaySellingPrice!);
        if (containerSell != null) {
          cartItem.sellingPrice = containerSell;
        }
      }

      final displaySell = cartItem.displaySellingPrice ??
          (containerSell != null ? _toBase(cartItem, containerSell) : null);
      if (displaySell != null) {
        cartItem.displaySellingPrice = displaySell;
        cartItem.displaySellingPriceController.text =
            displaySell > 0 ? AppFormatter.formatNumber(displaySell) : '';
      } else {
        cartItem.displaySellingPriceController.text = '';
      }
      if (containerSell != null && containerSell > 0) {
        cartItem.sellingPriceController.text =
            AppFormatter.formatNumber(containerSell);
      } else {
        cartItem.sellingPriceController.text = '';
      }
    }

    void _recomputeBaseSellingPrice(POCartItem cartItem) {
      final double? defaultPrice = cartItem.displaySellingPrice;
      final double? factor = cartItem.defaultUnitFactor;
      if (defaultPrice != null && defaultPrice > 0) {
        if (factor != null && factor > 0) {
          cartItem.baseSellingPrice = defaultPrice / factor;
        } else {
          cartItem.baseSellingPrice = defaultPrice;
        }
      } else {
        cartItem.baseSellingPrice = null;
      }
    }

    if (newAllowsPricingToggle != null) {
      item.allowsPricingToggle = newAllowsPricingToggle;
    }

    if (newQuantity != null) {
      item.quantity = newQuantity.clamp(0, 999999);
      // 🔥 WEB FIX: Only update controller text if it's significantly different
      // to avoid interfering with user typing
      final expectedText = item.quantity.toString();
      if (item.quantityController.text != expectedText) {
        // Only update if controller text doesn't match expected value
        // This prevents overriding user input during typing
        final currentValue = int.tryParse(item.quantityController.text) ?? 0;
        if (currentValue != item.quantity) {
          if (kIsWeb) {
            // Web: Use safe TextEditingValue to prevent assertions
            item.quantityController.value = TextEditingValue(
              text: expectedText,
              selection: TextSelection.collapsed(offset: expectedText.length),
              composing: TextRange.empty,
            );
          } else {
            item.quantityController.text = expectedText;
          }
        }
      }
    }
    if (newUnit != null) {
      item.unit = newUnit;
    }
    if (newUnitId != null) {
      item.unitId = newUnitId;
    }
    if (newDefaultUnitId != null) {
      item.defaultUnitId = newDefaultUnitId;
    }
    if (newDefaultUnitName != null) {
      item.defaultUnitName = newDefaultUnitName;
    }
    if (newSelectedUnitFactor != null) {
      item.selectedUnitFactor = newSelectedUnitFactor;
    }
    if (newDefaultUnitFactor != null) {
      item.defaultUnitFactor = newDefaultUnitFactor;
    }

    if (newUnitCost != null) {
      item.unitCost = newUnitCost.clamp(0.0, double.infinity);
      final baseCost = _toBase(item, item.unitCost);
      if (baseCost != null) {
        item.defaultUnitCost = baseCost;
      }
    }
    if (newDefaultUnitCost != null) {
      item.defaultUnitCost = newDefaultUnitCost.clamp(0.0, double.infinity);
      final containerCost = _toContainer(item, item.defaultUnitCost!);
      if (containerCost != null) {
        item.unitCost = containerCost;
      }
    }
    if (clearDefaultUnitCost == true) {
      item.defaultUnitCost = null;
    }

    if (clearSellingPrice == true) {
      item.sellingPrice = null;
      item.displaySellingPrice = null;
      item.baseSellingPrice = null;
    } else if (newSellingPrice != null) {
      item.sellingPrice = newSellingPrice.clamp(0.0, double.infinity);
      final baseSell =
          item.sellingPrice != null ? _toBase(item, item.sellingPrice!) : null;
      if (baseSell != null) {
        item.displaySellingPrice = baseSell;
      }
    }
    if (clearDisplaySellingPrice == true) {
      item.displaySellingPrice = null;
      item.baseSellingPrice = null;
    } else if (newDisplaySellingPrice != null) {
      item.displaySellingPrice =
          newDisplaySellingPrice.clamp(0.0, double.infinity);
      final containerSell = _toContainer(item, item.displaySellingPrice!);
      if (containerSell != null) {
        item.sellingPrice = containerSell;
      }
    }

    if (newPricingSelection != null) {
      item.pricingSelection = newPricingSelection;
    }

    syncControllers(item);
    _recomputeBaseSellingPrice(item);
    notifyListeners();
  }

  // Explicit method for removing items from cart
  void removeFromPOCartWithConfirmation(String productId) {
    // This method is for UI to call when user explicitly wants to delete
    removeFromPOCart(productId);
  }

  void removeFromPOCart(String productId) {
    final index = _poCartItems.indexWhere(
      (item) => item.product.id == productId,
    );
    if (index != -1) {
      _poCartItems[index].dispose(); // Dispose controllers
      _poCartItems.removeAt(index);
    }
    notifyListeners();
  }

  void clearPOCart() {
    // DON'T clear supplier selection - only clear cart items
    // _selectedSupplierId should be preserved during PO creation workflow
    for (var item in _poCartItems) {
      item.dispose(); // Dispose all controllers
    }
    _poCartItems.clear();
    // Keep _filteredProducts if supplier is still selected
    // _filteredProducts.clear(); // Don't clear - may be needed
    notifyListeners();
  }

  void clearPOCartAndSupplier() {
    // Use this method when truly starting fresh (e.g., after PO creation success)
    _selectedSupplierId = null;
    for (var item in _poCartItems) {
      item.dispose(); // Dispose all controllers
    }
    _poCartItems.clear();
    _filteredProducts.clear();
    notifyListeners();
  }

  void syncPOCartItems(List<POCartItem> newItems) {
    // Efficiently sync cart without disposing existing controllers unnecessarily
    final Map<String, POCartItem> existingItemsMap = {
      for (var item in _poCartItems) item.product.id: item
    };
    final Map<String, POCartItem> newItemsMap = {
      for (var item in newItems) item.product.id: item
    };

    // Items to remove (exist in current but not in new)
    final itemsToRemove = <POCartItem>[];
    for (var existingItem in _poCartItems) {
      if (!newItemsMap.containsKey(existingItem.product.id)) {
        itemsToRemove.add(existingItem);
      }
    }

    // Remove items no longer needed
    for (var item in itemsToRemove) {
      item.dispose();
      _poCartItems.removeWhere((cartItem) => cartItem.product.id == item.product.id);
    }

    // Build new list maintaining order from newItems
    final List<POCartItem> updatedCartItems = [];
    
    // Update or add items in the order provided by newItems
    for (var newItem in newItems) {
      final existingItem = existingItemsMap[newItem.product.id];
      if (existingItem != null) {
        // Update existing item properties without recreating controllers
        existingItem.quantity = newItem.quantity;
        existingItem.unitCost = newItem.unitCost;
        existingItem.sellingPrice = newItem.sellingPrice;
        existingItem.unit = newItem.unit;
        existingItem.unitId = newItem.unitId;
        existingItem.defaultUnitId = newItem.defaultUnitId;
        existingItem.defaultUnitName = newItem.defaultUnitName;
        existingItem.selectedUnitFactor = newItem.selectedUnitFactor;
        existingItem.defaultUnitFactor = newItem.defaultUnitFactor;
        existingItem.defaultUnitCost = newItem.defaultUnitCost;
        existingItem.displaySellingPrice = newItem.displaySellingPrice;
        existingItem.baseSellingPrice = newItem.baseSellingPrice;
        existingItem.pricingSelection = newItem.pricingSelection;
        existingItem.allowsPricingToggle = newItem.allowsPricingToggle;
        
        // Update controller text values (avoid overriding user input during typing)
        final expectedQuantityText = newItem.quantity.toString();
        if (existingItem.quantityController.text != expectedQuantityText) {
          final currentQty = int.tryParse(existingItem.quantityController.text) ?? 0;
          if (currentQty != newItem.quantity) {
            if (kIsWeb) {
              existingItem.quantityController.value = TextEditingValue(
                text: expectedQuantityText,
                selection: TextSelection.collapsed(offset: expectedQuantityText.length),
                composing: TextRange.empty,
              );
            } else {
              existingItem.quantityController.text = expectedQuantityText;
            }
          }
        }
        existingItem.unitCostController.text = newItem.unitCost > 0 
            ? AppFormatter.formatNumber(newItem.unitCost) 
            : '';
        existingItem.sellingPriceController.text = newItem.sellingPrice != null && newItem.sellingPrice! > 0
            ? AppFormatter.formatNumber(newItem.sellingPrice!)
            : '';
        existingItem.defaultUnitCostController.text = newItem.defaultUnitCost != null && newItem.defaultUnitCost! > 0
            ? AppFormatter.formatNumber(newItem.defaultUnitCost!)
            : '';
        existingItem.displaySellingPriceController.text = newItem.displaySellingPrice != null && newItem.displaySellingPrice! > 0
            ? AppFormatter.formatNumber(newItem.displaySellingPrice!)
            : '';
            
        // Dispose the newItem controllers since we're not using them
        newItem.dispose();
        
        // Add the updated existing item to the new list
        updatedCartItems.add(existingItem);
      } else {
        // Add completely new item
        updatedCartItems.add(newItem);
      }
    }
    
    // Replace the entire cart list to maintain order
    _poCartItems = updatedCartItems;
    
    notifyListeners();
  }

  void _clearAllFilters() {
    _searchText = '';
    _selectedSupplierIds = [];
    _statusFilters.clear();
    _fromDate = null;
    _toDate = null;
    _minTotal = null;
    _maxTotal = null;
    _sortBy = 'order_date';
    _sortAsc = false;
  }

  Future<PurchaseOrder?> createPOFromCart({
    String? notes,
    PurchaseOrderStatus status = PurchaseOrderStatus.draft,
  }) async {
    final validItems = validPOCartItems;
    if (_selectedSupplierId == null || validItems.isEmpty) {
      _status = POStatus.error;
      _errorMessage =
          'Vui lòng chọn nhà cung cấp và thêm sản phẩm có số lượng > 0 vào đơn hàng';
      notifyListeners();
      return null;
    }

    if (_status == POStatus.loading) return null; // Prevent re-entrant calls

    _status = POStatus.loading;
    _errorMessage = '';

    PurchaseOrder? newPO;
    try {
      await _ensureUnitsForProducts(
        validItems.map((item) => item.product.id).toSet(),
      );
      final items = <PurchaseOrderItem>[];
      double computedSubtotal = 0.0;

      for (final cartItem in validItems) {
        final units = _productUnitsById[cartItem.product.id] ?? const [];

        if (units.isNotEmpty) {
          final selectedUnit = cartItem.unitId != null
              ? units.firstWhere(
                  (u) => u.id == cartItem.unitId,
                  orElse: () => units.first,
                )
              : null;
          final defaultUnit = units.firstWhere(
            (u) => u.isDefaultSellingUnit,
            orElse: () => selectedUnit ?? units.first,
          );

          if (selectedUnit != null) {
            cartItem.selectedUnitFactor ??= selectedUnit.conversionFactor;
          }
          cartItem.defaultUnitFactor ??= defaultUnit.conversionFactor;
          cartItem.defaultUnitId ??= defaultUnit.id;
          cartItem.defaultUnitName ??= defaultUnit.unitName;
        }

        debugPrint(
          '🧾 createPOFromCart → item ${cartItem.product.name}: '
          'qty=${cartItem.quantity} ${cartItem.unit}, '
          'unitCost=${cartItem.unitCost}, '
          'sellingPrice=${cartItem.sellingPrice}, '
          'defaultSelling=${cartItem.displaySellingPrice}, '
          'unitId=${cartItem.unitId}, defaultUnitId=${cartItem.defaultUnitId}',
        );

        final double convertedQuantity = _productUnitProvider
                .convertQuantityToBaseFromUnits(
                  units: units,
                  quantity: cartItem.quantity.toDouble(),
                  fromUnitId: cartItem.unitId,
                ) ??
            cartItem.quantity.toDouble();
        final int baseQuantity = convertedQuantity.round();

        final double baseUnitCost = _productUnitProvider
                .convertPriceToBaseFromUnits(
                  units: units,
                  displayPrice: cartItem.unitCost,
                  fromUnitId: cartItem.unitId,
                ) ??
            cartItem.unitCost;
        String unitName = cartItem.unit ?? cartItem.product.effectiveBaseUnit;

        unitName = cartItem.product.effectiveBaseUnit;

        double? displaySellingPrice = cartItem.displaySellingPrice;
        bool hasUserDisplayPrice =
            displaySellingPrice != null && displaySellingPrice > 0;
        if (!hasUserDisplayPrice &&
            cartItem.sellingPrice != null &&
            cartItem.selectedUnitFactor != null &&
            cartItem.defaultUnitFactor != null &&
            cartItem.selectedUnitFactor! > 0 &&
            cartItem.defaultUnitFactor! > 0) {
          displaySellingPrice =
              cartItem.sellingPrice! *
                  (cartItem.defaultUnitFactor! / cartItem.selectedUnitFactor!);
          hasUserDisplayPrice =
              displaySellingPrice != null && displaySellingPrice > 0;
        }

        double? baseSellingPrice = cartItem.baseSellingPrice;
        if ((baseSellingPrice == null || baseSellingPrice <= 0) &&
            displaySellingPrice != null &&
            cartItem.defaultUnitFactor != null &&
            cartItem.defaultUnitFactor! > 0) {
          baseSellingPrice = displaySellingPrice / cartItem.defaultUnitFactor!;
        }
        if ((baseSellingPrice == null || baseSellingPrice <= 0) &&
            displaySellingPrice != null) {
          baseSellingPrice =
              _productUnitProvider.convertPriceToBaseFromUnits(
                    units: units,
                    displayPrice: displaySellingPrice,
                    fromUnitId: cartItem.defaultUnitId,
                  ) ??
                  displaySellingPrice;
        }
        if ((displaySellingPrice == null || displaySellingPrice <= 0) &&
            baseSellingPrice != null &&
            baseSellingPrice > 0 &&
            cartItem.defaultUnitFactor != null &&
            cartItem.defaultUnitFactor! > 0) {
          displaySellingPrice =
              baseSellingPrice * cartItem.defaultUnitFactor!;
        }
        if ((baseSellingPrice == null || baseSellingPrice <= 0) &&
            cartItem.sellingPrice != null) {
          baseSellingPrice =
              _productUnitProvider.convertPriceToBaseFromUnits(
                    units: units,
                    displayPrice: cartItem.sellingPrice!,
                    fromUnitId: cartItem.unitId,
                  ) ??
                  cartItem.sellingPrice;
        }
        displaySellingPrice ??= cartItem.product.currentSellingPrice;
        baseSellingPrice ??= _productUnitProvider.convertPriceToBaseFromUnits(
              units: units,
              displayPrice: displaySellingPrice ?? 0,
              fromUnitId: cartItem.defaultUnitId,
            ) ??
            displaySellingPrice ??
            cartItem.product.currentSellingPrice;

        cartItem.displaySellingPrice = displaySellingPrice;
        cartItem.baseSellingPrice = baseSellingPrice;

        if (hasUserDisplayPrice &&
            displaySellingPrice != null &&
            displaySellingPrice > 0 &&
            displaySellingPrice != cartItem.product.currentSellingPrice) {
          try {
            debugPrint(
              '💰 Updating product ${cartItem.product.name} selling price (default unit): '
              '$displaySellingPrice',
            );
            await _productService.updateCurrentSellingPrice(
              cartItem.product.id,
              displaySellingPrice,
              reason: 'Updated via Purchase Order creation',
            );
            debugPrint(
                'DEBUG: Updated selling price for ${cartItem.product.name}: $displaySellingPrice (default unit)');
          } catch (e) {
            debugPrint(
                'Warning: Could not update selling price for ${cartItem.product.name}: $e');
          }
        }

        final double totalCost = baseQuantity * baseUnitCost;
        computedSubtotal += totalCost;

        final String? displayUnitId =
            cartItem.defaultUnitId ??
            units.firstWhere(
              (u) => u.isDefaultSellingUnit,
              orElse: () => units.first,
            ).id;

        debugPrint(
          '🧮 Converted item ${cartItem.product.name}: '
          'baseQty=$baseQuantity (${cartItem.quantity} ${cartItem.unit}), '
          'baseCost=$baseUnitCost, baseSell=$baseSellingPrice '
          '(defaultUnitId=$displayUnitId)',
        );

        items.add(PurchaseOrderItem(
          id: '',
          purchaseOrderId: '',
          productId: cartItem.product.id,
          quantity: baseQuantity,
          unitCost: baseUnitCost,
          sellingPrice: baseSellingPrice ?? 0,
          unit: unitName,
          totalCost: totalCost,
          createdAt: DateTime.now(),
          storeId: BaseService.getDefaultStoreId(),
          notes: cartItem.unitId != null
              ? 'Unit conversion: ${cartItem.quantity} ${cartItem.unit} @ ${AppFormatter.formatNumber(cartItem.unitCost)} → $baseQuantity $unitName @ ${AppFormatter.formatNumber(baseUnitCost)}'
              : null,
        ));
      }

      final order = PurchaseOrder(
        id: '', // Handled by DB
        supplierId: _selectedSupplierId!,
        orderDate: DateTime.now(),
        status: status,
        notes: notes,
        totalAmount: computedSubtotal,
        subtotal: computedSubtotal,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        storeId: BaseService.getDefaultStoreId(),
      );

      newPO = await _poService.createPurchaseOrder(order, items);
      if (newPO != null) {
        debugPrint(
          '✅ createPOFromCart: created PO ${newPO.id} (${newPO.poNumber}) status=${newPO.status.name} total=${newPO.totalAmount}',
        );
      }

      _selectedSupplierId = null;
      for (var item in _poCartItems) {
        item.dispose();
      }
      _poCartItems.clear();
      _filteredProducts.clear();
      _clearAllFilters(); // Clear filters before refreshing

      // Refresh affected products to sync cache with database
      // This ensures POS and Product Detail screens show updated prices
      final affectedProductIds = validItems
          .map((item) => item.product.id)
          .toList();
      await _productProvider.refreshProductsByIds(affectedProductIds);

      await searchPurchaseOrders(); // Refresh list view with filters applied
      return newPO;
    } catch (e) {
      _status = POStatus.error;
      _errorMessage = e.toString();
      debugPrint('❌ createPOFromCart failed: $e');
      return null;
    } finally {
      notifyListeners();
    }
  }

  Future<bool> updatePOStatus(String poId, PurchaseOrderStatus status) async {
    _setStatus(POStatus.loading);
    try {
      final updatedPO = await _poService.updatePurchaseOrderStatus(
        poId,
        status,
      );
      final index = _purchaseOrders.indexWhere((po) => po.id == poId);
      if (index != -1) {
        _purchaseOrders[index] = updatedPO;
      }
      if (_selectedPO?.id == poId) {
        _selectedPO = updatedPO;
      }
      notifyListeners(); // Notify UI of all changes
      _setStatus(POStatus.success);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  void _setStatus(POStatus status) {
    _status = status;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _status = POStatus.error;
    notifyListeners();
  }
}
