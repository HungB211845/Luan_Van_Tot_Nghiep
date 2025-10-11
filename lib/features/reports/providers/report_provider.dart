
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/report_service.dart';
import '../models/revenue_trend_point.dart';
import '../models/inventory_analytics.dart';
import '../models/top_product.dart';
import '../models/inventory_product.dart';
import '../models/tax_summary.dart';

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
  bool _isLoadingTax = false;

  // Per-tab loaded flags for lazy loading
  bool _revenueLoaded = false;
  bool _inventoryLoaded = false;
  bool _taxLoaded = false;

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

  // State for HomeScreen widget
  List<RevenueTrendPoint> _homeScreenRevenueTrend = [];
  List<RevenueTrendPoint> get homeScreenRevenueTrend => _homeScreenRevenueTrend;

  Map<String, dynamic>? _homeScreenRevenueSummary;
  Map<String, dynamic>? get homeScreenRevenueSummary => _homeScreenRevenueSummary;

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

  TaxSummary? _taxSummary;
  TaxSummary? get taxSummary => _taxSummary;

  // Export state for sales ledger
  bool _isExporting = false;
  bool get isExporting => _isExporting;

  String? _exportError;
  String? get exportError => _exportError;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Getters for loaded states (used by Reports screen to check cache)
  bool get revenueLoaded => _revenueLoaded;
  bool get inventoryLoaded => _inventoryLoaded; 
  bool get taxLoaded => _taxLoaded;

  ReportProvider()
      : _selectedDateRange = _getThisMonthRange(), // Default to month for tax reporting
        _selectedPreset = DateRangePreset.thisMonth;

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
      // Only log when debug mode is enabled
      if (kDebugMode) print('📊 Revenue data already loaded, skipping...');
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
      // Only log loading in debug mode
      if (kDebugMode) print('📊 Loading revenue data for date range: ${_selectedDateRange.start} to ${_selectedDateRange.end}');

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
      // Only log success in debug mode
      if (kDebugMode) print('✅ Revenue data loaded successfully');
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
      // Only log success in debug mode
      if (kDebugMode) print('✅ Inventory data loaded successfully');
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
  // LAZY LOADING: Tab 3 - Tax Data
  // ============================================================================
  Future<void> loadTaxData({bool forceRefresh = false}) async {
    if (_taxLoaded && !forceRefresh) {
      if (kDebugMode) print('💰 Tax data already loaded, skipping...');
      return;
    }

    if (_isLoadingTax) {
      print('⚠️ Already loading tax data, skipping...');
      return;
    }

    _isLoadingTax = true;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('💰 [PROVIDER] Loading tax data for date range: ${_selectedDateRange.start} to ${_selectedDateRange.end}');
      print('💰 [PROVIDER] Force refresh: $forceRefresh');

      // Use ReportService direct method instead of TaxService RPC
      final result = await _reportService.getTaxSummaryDirect(_selectedDateRange.start, _selectedDateRange.end);
      
      print('💰 [PROVIDER] Tax service returned: $result');
      print('💰 [PROVIDER] Total revenue: ${result.totalRevenue}');
      print('💰 [PROVIDER] Estimated tax: ${result.estimatedTax}');
      print('💰 [PROVIDER] Total expenses: ${result.totalExpenses}');
      print('💰 [PROVIDER] Total transactions: ${result.totalTransactions}');

      _taxSummary = result;
      _taxLoaded = true;
      
      print('✅ [PROVIDER] Tax data loaded and assigned to _taxSummary successfully');
    } catch (e) {
      _errorMessage = e.toString();
      print('❌ [PROVIDER] Error loading tax data: $e');
      print('❌ [PROVIDER] Error type: ${e.runtimeType}');
      
      // Set fallback empty data to prevent null UI issues
      _taxSummary = TaxSummary(
        totalRevenue: 0,
        estimatedTax: 0,
        totalExpenses: 0,
        totalTransactions: 0,
      );
    } finally {
      _isLoadingTax = false;
      _isLoading = false;
      notifyListeners();
      print('💰 [PROVIDER] loadTaxData completed, notifyListeners called');
    }
  }

  /// Silent version of loadTaxData that doesn't show loading states
  Future<void> _loadTaxDataSilent({bool forceRefresh = false}) async {
    if (_isLoadingTax) return;

    _isLoadingTax = true;
    
    try {
      final result = await _reportService.getTaxSummaryDirect(_selectedDateRange.start, _selectedDateRange.end);
      
      _taxSummary = result;
      _taxLoaded = true;
      
      // Only notify after data is ready
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      
      _taxSummary = TaxSummary(
        totalRevenue: 0,
        estimatedTax: 0,
        totalExpenses: 0,
        totalTransactions: 0,
      );
      notifyListeners(); // Notify on error
    } finally {
      _isLoadingTax = false;
    }
  }

  // ============================================================================
  // LEGACY: Load all data at once (for backward compatibility & refresh)
  // ============================================================================
  Future<void> loadDashboardData({bool forceRefresh = false}) async {
    // Removed dashboard loading log to reduce spam
    // if (kDebugMode) print('🔄 Loading all dashboard data...');
    await Future.wait([
      loadRevenueData(forceRefresh: forceRefresh),
      loadInventoryData(forceRefresh: forceRefresh),
      loadTaxData(forceRefresh: forceRefresh),
    ]);
    // Only log completion in debug mode
    if (kDebugMode) print('✅ All dashboard data loaded');
  }

  // Reset loaded flags when date range changes
  void _resetLoadedFlags() {
    _revenueLoaded = false;
    _inventoryLoaded = false;
    _taxLoaded = false;
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

  // State for HomeScreen weekly navigation
  DateTime _homeScreenWeekStart = _getMonday(DateTime.now());
  DateTime get homeScreenWeekStart => _homeScreenWeekStart;

  /// Check if the next week for the home screen is in the future.
  bool get canShowNextWeekForHome {
    final nextWeekStart = _homeScreenWeekStart.add(const Duration(days: 7));
    final today = DateTime.now();
    return !nextWeekStart.isAfter(today);
  }

  /// Navigate to previous week for HomeScreen widget
  Future<void> showPreviousWeekForHome() async {
    _homeScreenWeekStart = _homeScreenWeekStart.subtract(const Duration(days: 7));
    await loadWeeklyRevenueForHome();
  }

  /// Navigate to next week for HomeScreen widget  
  Future<void> showNextWeekForHome() async {
    _homeScreenWeekStart = _homeScreenWeekStart.add(const Duration(days: 7));
    await loadWeeklyRevenueForHome();
  }

  /// Helper to get Monday of current week
  static DateTime _getMonday(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  // NEW: Load weekly revenue data specifically for HomeScreen "7 ngày" widget
  Future<void> loadWeeklyRevenueForHome() async {
    try {
      if (kDebugMode) print('📊 Loading weekly revenue for HomeScreen (7 ngày)...');
      
      // Use HomeScreen specific week range (not Reports _selectedDateRange)
      final weekStart = DateTime(_homeScreenWeekStart.year, _homeScreenWeekStart.month, _homeScreenWeekStart.day);
      final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      
      if (kDebugMode) {
        print('📊 HomeScreen weekly range: $weekStart to $weekEnd');
        print('📊 (Independent from Reports range: ${_selectedDateRange.start} to ${_selectedDateRange.end})');
      }
      
      // Load trend data for THIS SPECIFIC WEEK ONLY
      _homeScreenRevenueTrend = await _reportService.getRevenueTrend(
        weekStart, 
        weekEnd,
      );
      
      // Also load summary for weekly totals
      _homeScreenRevenueSummary = await _reportService.getRevenueSummaryWithComparison(
        weekStart,
        weekEnd,
      );
      
      // Important: Notify listeners so UI updates
      notifyListeners();
      
      if (kDebugMode) {
        print('✅ Weekly revenue data loaded for HomeScreen:');
        print('  - Weekly range: $weekStart to $weekEnd');
        print('  - Trend points: ${_homeScreenRevenueTrend.length}');
        print('  - Total weekly revenue: ${_homeScreenRevenueSummary?['current_period_revenue'] ?? 0}');
      }
    } catch (e) {
      _errorMessage = e.toString();
      print('❌ Error loading weekly revenue for HomeScreen: $e');
      
      // Set empty data to stop infinite loading
      _revenueTrend = [];
      _revenueSummary = {};
      
      // Still notify listeners to update UI with empty state
      notifyListeners();
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
    final oldPreset = _selectedPreset;
    final oldRange = _selectedDateRange;
    
    // Update UI state immediately for smooth transition
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
      case DateRangePreset.thisYear:
        final now = DateTime.now();
        _selectedDateRange = DateTimeRange(start: DateTime(now.year, 1, 1), end: DateTime(now.year, 12, 31));
        break;
      case DateRangePreset.custom:
        if (customRange != null) {
          _selectedDateRange = customRange;
        } else {
          // Restore previous state if invalid custom range
          _selectedPreset = oldPreset;
          _selectedDateRange = oldRange;
          return;
        }
        break;
    }
    
    // Notify UI for smooth segment control animation
    notifyListeners();
    
    // Then load data in background (reset loaded flags and force refresh revenue data)
    _resetLoadedFlags();
    
    // Load revenue data without notifyListeners to avoid UI jumps
    await _loadRevenueDataSilent(forceRefresh: true);
  }

  /// DEDICATED method for tax tab to prevent lag - NO notifyListeners during transition
  void setDateRangeForTaxSilent(DateRangePreset preset, {DateTimeRange? customRange}) {
    final oldPreset = _selectedPreset;
    final oldRange = _selectedDateRange;
    
    // Update state silently
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
      case DateRangePreset.thisYear:
        final now = DateTime.now();
        _selectedDateRange = DateTimeRange(start: DateTime(now.year, 1, 1), end: DateTime(now.year, 12, 31));
        break;
      case DateRangePreset.custom:
        if (customRange != null) {
          _selectedDateRange = customRange;
        } else {
          // Restore previous state if invalid custom range
          _selectedPreset = oldPreset;
          _selectedDateRange = oldRange;
          return;
        }
        break;
    }
    
    // IMMEDIATE notify for smooth segment animation
    notifyListeners();
    
    // Load tax data with optimized caching - NO await to prevent blocking
    _resetTaxLoadedFlag(); // Only reset tax flag for efficiency
    _loadTaxDataSilent(forceRefresh: true);
  }

  /// NEW: Preload all report data in background for better UX
  /// Called during app initialization to cache data
  Future<void> preloadAllReportData() async {
    try {
      if (kDebugMode) print('🔄 Preloading all report data in background...');
      
      // Load all data in parallel without blocking UI
      await Future.wait<void>([
        _loadRevenueDataSilent(forceRefresh: false),
        _loadInventoryDataSilent(forceRefresh: false), 
        _loadTaxDataSilent(forceRefresh: false),
      ]);
      
      // Mark all as loaded for instant access
      _revenueLoaded = true;
      _inventoryLoaded = true;
      _taxLoaded = true;
      
      if (kDebugMode) print('✅ All report data preloaded and cached successfully');
      
      // Don't notify listeners - this is background loading
    } catch (e) {
      if (kDebugMode) print('⚠️ Preload failed (non-critical): $e');
      // Don't block app startup if preload fails
    }
  }

  /// Reset only tax loaded flag for efficiency
  void _resetTaxLoadedFlag() {
    _taxLoaded = false;
  }

  /// Silent inventory loading without UI updates
  Future<void> _loadInventoryDataSilent({bool forceRefresh = false}) async {
    if (_isLoadingInventory || (_inventoryLoaded && !forceRefresh)) {
      return;
    }

    _isLoadingInventory = true;

    try {
      _inventoryAnalytics = await _reportService.getInventoryAnalytics();
      _inventoryLoaded = true;
      
      if (kDebugMode) print('✅ [SILENT] Inventory data loaded');
    } catch (e) {
      _errorMessage = e.toString();
      if (kDebugMode) print('❌ [SILENT] Error loading inventory data: $e');
    } finally {
      _isLoadingInventory = false;
    }
  }

  /// Silent revenue loading without UI updates - NO FORCE REFRESH ON TAB SWITCH
  Future<void> _loadRevenueDataSilent({bool forceRefresh = false}) async {
    if (_isLoadingRevenue || (_revenueLoaded && !forceRefresh)) {
      return; // Skip if already loaded to prevent unnecessary refreshes
    }

    _isLoadingRevenue = true;

    try {
      if (kDebugMode) print('📊 [SILENT] Loading revenue data for date range: ${_selectedDateRange.start} to ${_selectedDateRange.end}');

      final results = await Future.wait([
        _reportService.getRevenueSummaryWithComparison(_selectedDateRange.start, _selectedDateRange.end),
        _reportService.getRevenueTrend(_selectedDateRange.start, _selectedDateRange.end),
        _reportService.getTopPerformingProducts(startDate: _selectedDateRange.start, endDate: _selectedDateRange.end),
      ]);

      _revenueSummary = results[0] as Map<String, dynamic>;
      _revenueTrend = results[1] as List<RevenueTrendPoint>;
      _topProducts = results[2] as List<TopProduct>;
      _revenueLoaded = true;
      
      if (kDebugMode) print('✅ [SILENT] Revenue data loaded successfully');
      
      // Only notify after data is loaded to prevent loading state flicker
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      if (kDebugMode) print('❌ [SILENT] Error loading revenue data: $e');
      notifyListeners(); // Notify on error to show error state
    } finally {
      _isLoadingRevenue = false;
    }
  }

  /// Export Sales Ledger Action - Called from UI
  /// Handles the complete export flow with loading states and error handling
  Future<void> exportSalesLedgerAction() async {
    if (_isExporting) {
      return; // Prevent multiple simultaneous exports
    }

    _isExporting = true;
    _exportError = null;
    notifyListeners(); // Show loading indicator

    try {
      await _reportService.exportSalesLedger(_selectedDateRange.start, _selectedDateRange.end);
      
      // Success - no need for success state since Share dialog handles UX
      _exportError = null;
    } catch (e) {
      _exportError = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isExporting = false;
      notifyListeners(); // Hide loading indicator
    }
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
