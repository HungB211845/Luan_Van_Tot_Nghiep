
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/report_service.dart';
import '../models/revenue_trend_point.dart';
import '../models/inventory_analytics.dart';
import '../models/top_product.dart';

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

  // Main data loading function for the new dashboard
  Future<void> loadDashboardData() async {
    _isLoading = true;
    _errorMessage = null;
    // DO NOT notifyListeners() here. This is an anti-pattern.

    try {
      // Use Future.wait for concurrent fetching based on the selected date range
      final results = await Future.wait([
        _reportService.getRevenueSummaryWithComparison(_selectedDateRange.start, _selectedDateRange.end),
        _reportService.getRevenueTrend(_selectedDateRange.start, _selectedDateRange.end),
        _reportService.getTopPerformingProducts(startDate: _selectedDateRange.start, endDate: _selectedDateRange.end),
        _reportService.getInventoryAnalytics(), // This one is independent of date range for now
      ]);

      // Assign results safely
      _revenueSummary = results[0] as Map<String, dynamic>;
      _revenueTrend = results[1] as List<RevenueTrendPoint>;
      _topProducts = results[2] as List<TopProduct>;
      _inventoryAnalytics = results[3] as InventoryAnalytics;

    } catch (e) {
      _errorMessage = e.toString();
      print('Error loading dashboard data: $e');
    } finally {
      _isLoading = false;
      notifyListeners(); // Notify listeners ONCE at the end.
    }
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
    // After setting the new range, reload all data
    await loadDashboardData();
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
    await loadDashboardData();
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
    await loadDashboardData();
  }
}
