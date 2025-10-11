import 'package:flutter/foundation.dart';
import '../../../features/reports/models/daily_revenue.dart';
import '../../../features/reports/services/report_service.dart';

class DashboardProvider with ChangeNotifier {
  final ReportService _reportService = ReportService();

  DateTime _displayedWeekStartDate = _getMonday(DateTime.now());
  List<DailyRevenue>? _weeklyData; // 🔥 FIX: null instead of empty list
  int? _selectedDayIndex;
  bool _isLoading = false;

  DateTime get displayedWeekStartDate => _displayedWeekStartDate;
  List<DailyRevenue> get weeklyData => _weeklyData ?? []; // 🔥 FIX: return empty list if null
  int? get selectedDayIndex => _selectedDayIndex;
  bool get isLoading => _isLoading;
  
  // 🔥 NEW: Check if data has been loaded at least once
  bool get hasData => _weeklyData != null;

  /// Calculate Monday of the current week
  static DateTime _getMonday(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  /// Get total revenue for the displayed week
  double get weekTotalRevenue {
    if (_weeklyData == null) return 0.0; // 🔥 FIX: handle null case
    return _weeklyData!.fold(0.0, (sum, day) => sum + day.revenue);
  }

  /// Load revenue data for the displayed week
  Future<void> fetchRevenueData() async {
    _isLoading = true;
    notifyListeners();

    try {
      _weeklyData = await _reportService.getRevenueForWeek(_displayedWeekStartDate);
    } catch (e) {
      debugPrint('Error fetching revenue data: $e');
      _weeklyData = []; // 🔥 FIX: set empty list on error, not null
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Show previous week (swipe right / navigate back)
  Future<void> showPreviousWeek() async {
    _displayedWeekStartDate = _displayedWeekStartDate.subtract(const Duration(days: 7));
    _selectedDayIndex = null;
    await fetchRevenueData();
  }

  /// Show next week (swipe left / navigate forward)
  Future<void> showNextWeek() async {
    _displayedWeekStartDate = _displayedWeekStartDate.add(const Duration(days: 7));
    _selectedDayIndex = null;
    await fetchRevenueData();
  }

  /// Select a day to view details (tap on bar)
  void selectDay(int index) {
    _selectedDayIndex = index;
    notifyListeners();
  }

  /// Clear day selection
  void clearSelection() {
    _selectedDayIndex = null;
    notifyListeners();
  }

  /// Get selected day's data
  DailyRevenue? get selectedDayData {
    if (_selectedDayIndex == null || _weeklyData == null || _selectedDayIndex! >= _weeklyData!.length) {
      return null;
    }
    return _weeklyData![_selectedDayIndex!];
  }
}
