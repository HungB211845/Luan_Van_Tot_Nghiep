/// Helper functions for date and time operations

/// Returns a Vietnamese greeting based on the current hour
/// - 04:00 - 10:59: "Chào buổi sáng"
/// - 11:00 - 13:59: "Chào buổi trưa"
/// - 14:00 - 17:59: "Chào buổi chiều"
/// - 18:00 - 03:59: "Chào buổi tối"
String getGreetingMessage() {
  final hour = DateTime.now().hour;
  if (hour >= 4 && hour < 11) {
    return 'Chào buổi sáng';
  } else if (hour >= 11 && hour < 14) {
    return 'Chào buổi trưa';
  } else if (hour >= 14 && hour < 18) {
    return 'Chào buổi chiều';
  } else {
    return 'Chào buổi tối';
  }
}
