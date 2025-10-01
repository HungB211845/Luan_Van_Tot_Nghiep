/// Debt status enum
enum DebtStatus {
  pending('pending', 'Chưa trả'),
  partial('partial', 'Trả một phần'),
  paid('paid', 'Đã trả hết'),
  overdue('overdue', 'Quá hạn'),
  cancelled('cancelled', 'Đã hủy');

  const DebtStatus(this.value, this.displayName);
  final String value;
  final String displayName;

  static DebtStatus fromString(String value) {
    return DebtStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => DebtStatus.pending,
    );
  }
}
