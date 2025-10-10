
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/report_service.dart';
import '../models/revenue_trend_point.dart';
import '../models/inventory_analytics.dart';
import '../models/top_product.dart';
import '../models/inventory_product.dart';

// Defines the preset date ranges for the UI filter.
enum DateRangePreset {
  today,
  thisWeek,
  thisMonth,
  thisQuarter,
  thisYear, // Added
  custom
}

class ReportProvider with ChangeNotifier {
  final ReportService _reportService = ReportService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Per-tab loading flags to prevent duplicate calls
  bool _isLoadingRevenue = false;
  bool _isLoadingInventory = false;
  bool _isLoadingProduct = false;

  // Per-tab loaded flags for lazy loading
  bool _revenueLoaded = false;
  bool _inventoryLoaded = false;
  bool _productLoaded = false;

  // State for the new flexible date range
  DateTimeRange _selectedDateRange;
  DateTimeRange get selectedDateRange => _selectedDateRange;

  DateRangePreset _selectedPreset;
  DateRangePreset get selectedPreset => _selectedPreset;

  // This will now hold the complex object with comparison data
  Map<String, dynamic>? _revenueSummary;
  Map<String, dynamic>? get revenueSummary => _revenueSummary;

  List<RevenueTrendPoint> _revenueTrend = [];
  List<RevenueTrendPoint> get revenueTrend => _revenueTrend;

  List<TopProduct> _topProducts = [];
  List<TopProduct> get topProducts => _topProducts;

  InventoryAnalytics? _inventoryAnalytics;
  InventoryAnalytics? get inventoryAnalytics => _inventoryAnalytics;

  List<InventoryProduct> _topValueProducts = [];
  List<InventoryProduct> get topValueProducts => _topValueProducts;

  List<InventoryProduct> _fastTurnoverProducts = [];
  List<InventoryProduct> get fastTurnoverProducts => _fastTurnoverProducts;

  List<InventoryProduct> _slowTurnoverProducts = [];
  List<InventoryProduct> get slowTurnoverProducts => _slowTurnoverProducts;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  ReportProvider()
      : _selectedDateRange = _getThisWeekRange(),
        _selectedPreset = DateRangePreset.thisWeek;

  // Helper to get the range for "This Week"
  static DateTimeRange _getThisWeekRange() {
    final now = DateTime.now();
    final firstDayOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final lastDayOfWeek = firstDayOfWeek.add(const Duration(days: 6));
    return DateTimeRange(start: firstDayOfWeek, end: lastDayOfWeek);
  }

  // Helper to get the range for "This Month"
  static DateTimeRange _getThisMonthRange() {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);
    return DateTimeRange(start: firstDay, end: lastDay);
  }

  // ============================================================================
  // LAZY LOADING: Tab 1 - Revenue Data
  // ============================================================================
  Future<void> loadRevenueData({bool forceRefresh = false}) async {
    // Skip if already loaded and not forcing refresh
    if (_revenueLoaded && !forceRefresh) {
      print('📊 Revenue data already loaded, skipping...');
      return;
    }

    // Skip if already loading
    if (_isLoadingRevenue) {
      print('⚠️ Already loading revenue data, skipping...');
      return;
    }

    _isLoadingRevenue = true;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners(); // Show loading state immediately

    try {
      print('📊 Loading revenue data for date range: ${_selectedDateRange.start} to ${_selectedDateRange.end}');

      // Load only revenue-related data (3 RPCs)
      final results = await Future.wait([
        _reportService.getRevenueSummaryWithComparison(_selectedDateRange.start, _selectedDateRange.end),
        _reportService.getRevenueTrend(_selectedDateRange.start, _selectedDateRange.end),
        _reportService.getTopPerformingProducts(startDate: _selectedDateRange.start, endDate: _selectedDateRange.end),
      ]);

      _revenueSummary = results[0] as Map<String, dynamic>;
      _revenueTrend = results[1] as List<RevenueTrendPoint>;
      _topProducts = results[2] as List<TopProduct>;

      _revenueLoaded = true;
      print('✅ Revenue data loaded successfully');
    } catch (e) {
      _errorMessage = e.toString();
      print('❌ Error loading revenue data: $e');
    } finally {
      _isLoadingRevenue = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============================================================================
  // LAZY LOADING: Tab 2 - Inventory Data
  // ============================================================================
  Future<void> loadInventoryData({bool forceRefresh = false}) async {
    // Skip if already loaded and not forcing refresh
    if (_inventoryLoaded && !forceRefresh) {
      print('📦 Inventory data already loaded, skipping...');
      return;
    }

    // Skip if already loading
    if (_isLoadingInventory) {
      print('⚠️ Already loading inventory data, skipping...');
      return;
    }

    _isLoadingInventory = true;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners(); // Show loading state immediately

    try {
      print('📦 Loading inventory data...');

      // Load only inventory-related data (2 RPCs)
      final results = await Future.wait([
        _reportService.getInventoryAnalytics(),
        _reportService.getInventoryAnalyticsLists(),
      ]);

      _inventoryAnalytics = results[0] as InventoryAnalytics;

      final analyticsLists = results[1] as Map<String, List<InventoryProduct>>;
      _topValueProducts = analyticsLists['top_value'] ?? [];
      _fastTurnoverProducts = analyticsLists['fast_turnover'] ?? [];
      _slowTurnoverProducts = analyticsLists['slow_turnover'] ?? [];

      _inventoryLoaded = true;
      print('✅ Inventory data loaded successfully');
    } catch (e) {
      _errorMessage = e.toString();
      print('❌ Error loading inventory data: $e');
    } finally {
      _isLoadingInventory = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============================================================================
  // LAZY LOADING: Tab 3 - Product Data (Future Implementation)
  // ============================================================================
  Future<void> loadProductData({bool forceRefresh = false}) async {
    if (_productLoaded && !forceRefresh) {
      print('⭐ Product data already loaded, skipping...');
      return;
    }

    if (_isLoadingProduct) {
      print('⚠️ Already loading product data, skipping...');
      return;
    }

    _isLoadingProduct = true;
    _isLoading = true;
    notifyListeners();

    try {
      print('⭐ Loading product data...');
      // TODO: Implement product-specific data loading when needed
      await Future.delayed(const Duration(milliseconds: 100)); // Placeholder
      _productLoaded = true;
      print('✅ Product data loaded successfully');
    } catch (e) {
      _errorMessage = e.toString();
      print('❌ Error loading product data: $e');
    } finally {
      _isLoadingProduct = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============================================================================
  // LEGACY: Load all data at once (for backward compatibility & refresh)
  // ============================================================================
  Future<void> loadDashboardData({bool forceRefresh = false}) async {
    print('🔄 Loading all dashboard data...');
    await Future.wait([
      loadRevenueData(forceRefresh: forceRefresh),
      loadInventoryData(forceRefresh: forceRefresh),
      loadProductData(forceRefresh: forceRefresh),
    ]);
    print('✅ All dashboard data loaded');
  }

  // Reset loaded flags when date range changes
  void _resetLoadedFlags() {
    _revenueLoaded = false;
    _inventoryLoaded = false;
    _productLoaded = false;
  }

  // Optimized method to load ONLY today's revenue for HomeScreen dashboard
  Future<void> loadTodayRevenue() async {
    try {
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final todayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);

      _revenueSummary = await _reportService.getRevenueSummaryWithComparison(todayStart, todayEnd);
    } catch (e) {
      _errorMessage = e.toString();
      print('Error loading today revenue: $e');
      rethrow;
    }
  }

  // Optimized method to load inventory analytics WITHOUT notifyListeners
  // Used for HomeScreen to avoid multiple rebuilds
  Future<void> loadInventoryAnalytics() async {
    try {
      _inventoryAnalytics = await _reportService.getInventoryAnalytics();
    } catch (e) {
      _errorMessage = e.toString();
      print('Error loading inventory analytics: $e');
      rethrow;
    }
  }

  // UI calls this method to change the date range
  Future<void> setDateRange(DateRangePreset preset, {DateTimeRange? customRange}) async {
    _selectedPreset = preset;
    switch (preset) {
      case DateRangePreset.today:
        final now = DateTime.now();
        _selectedDateRange = DateTimeRange(start: now, end: now);
        break;
      case DateRangePreset.thisWeek:
        final now = DateTime.now();
        final firstDayOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final lastDayOfWeek = firstDayOfWeek.add(const Duration(days: 6));
        _selectedDateRange = DateTimeRange(start: firstDayOfWeek, end: lastDayOfWeek);
        break;
      case DateRangePreset.thisMonth:
        _selectedDateRange = _getThisMonthRange();
        break;
      case DateRangePreset.thisQuarter:
        final now = DateTime.now();
        final quarter = (now.month - 1) ~/ 3 + 1;
        final firstMonthOfQuarter = (quarter - 1) * 3 + 1;
        final lastMonthOfQuarter = firstMonthOfQuarter + 2;
        final firstDay = DateTime(now.year, firstMonthOfQuarter, 1);
        final lastDay = DateTime(now.year, lastMonthOfQuarter + 1, 0);
        _selectedDateRange = DateTimeRange(start: firstDay, end: lastDay);
        break;
      case DateRangePreset.thisYear: // Added
        final now = DateTime.now();
        _selectedDateRange = DateTimeRange(start: DateTime(now.year, 1, 1), end: DateTime(now.year, 12, 31));
        break;
      case DateRangePreset.custom:
        if (customRange != null) {
          _selectedDateRange = customRange;
        } else {
          return;
        }
        break;
    }
    // Date range changed - reset loaded flags and force refresh revenue data
    _resetLoadedFlags();
    await loadRevenueData(forceRefresh: true);
  }

  Future<void> selectNextPeriod() async {
    final currentRange = _selectedDateRange;
    DateTime newStart;
    DateTime newEnd;

    switch (_selectedPreset) {
      case DateRangePreset.thisWeek:
        newStart = currentRange.start.add(const Duration(days: 7));
        newEnd = currentRange.end.add(const Duration(days: 7));
        break;
      case DateRangePreset.thisMonth:
        newStart = DateTime(currentRange.start.year, currentRange.start.month + 1, 1);
        newEnd = DateTime(newStart.year, newStart.month + 2, 0);
        break;
      case DateRangePreset.thisYear:
        newStart = DateTime(currentRange.start.year + 1, 1, 1);
        newEnd = DateTime(currentRange.start.year + 1, 12, 31);
        break;
      default: // Handles custom and others
        final duration = currentRange.duration;
        newStart = currentRange.start.add(duration);
        newEnd = currentRange.end.add(duration);
        break;
    }
    _selectedDateRange = DateTimeRange(start: newStart, end: newEnd);
    _selectedPreset = DateRangePreset.custom; // Any navigated range is custom
    _resetLoadedFlags();
    await loadRevenueData(forceRefresh: true);
  }

  Future<void> selectPreviousPeriod() async {
    final currentRange = _selectedDateRange;
    DateTime newStart;
    DateTime newEnd;

    switch (_selectedPreset) {
      case DateRangePreset.thisWeek:
        newStart = currentRange.start.subtract(const Duration(days: 7));
        newEnd = currentRange.end.subtract(const Duration(days: 7));
        break;
      case DateRangePreset.thisMonth:
        newEnd = DateTime(currentRange.start.year, currentRange.start.month, 0);
        newStart = DateTime(newEnd.year, newEnd.month, 1);
        break;
      case DateRangePreset.thisYear:
        newStart = DateTime(currentRange.start.year - 1, 1, 1);
        newEnd = DateTime(currentRange.start.year - 1, 12, 31);
        break;
      default: // Handles custom and others
        final duration = currentRange.duration;
        newStart = currentRange.start.subtract(duration);
        newEnd = currentRange.end.subtract(duration);
        break;
    }
    _selectedDateRange = DateTimeRange(start: newStart, end: newEnd);
    _selectedPreset = DateRangePreset.custom; // Any navigated range is custom
    _resetLoadedFlags();
    await loadRevenueData(forceRefresh: true);
  }
}
