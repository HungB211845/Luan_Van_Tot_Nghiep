// lib/features/pos/models/payment_method.dart

enum PaymentMethod {
  cash('CASH'),
  bankTransfer('BANK_TRANSFER'),
  debt('DEBT');

  const PaymentMethod(this.value);
  final String value;

  factory PaymentMethod.fromString(String value) {
    return PaymentMethod.values.firstWhere(
      (method) => method.value == value,
      orElse: () => PaymentMethod.cash,
    );
  }

  String get displayName {
    switch (this) {
      case PaymentMethod.cash:
        return 'Tiền mặt';
      case PaymentMethod.bankTransfer:
        return 'Chuyển khoản';
      case PaymentMethod.debt:
        return 'Ghi nợ';
    }
  }
}