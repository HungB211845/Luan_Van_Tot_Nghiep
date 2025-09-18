class Transaction {
  final int? id;
  final int customerId;
  final double totalAmount;
  final DateTime transactionDate;
  final String status;
  final List<TransactionItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  Transaction({
    this.id,
    required this.customerId,
    required this.totalAmount,
    required this.transactionDate,
    required this.status,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      customerId: json['customer_id'],
      totalAmount: (json['total_amount'] as num).toDouble(),
      transactionDate: DateTime.parse(json['transaction_date']),
      status: json['status'],
      items: (json['items'] as List)
          .map((item) => TransactionItem.fromJson(item))
          .toList(),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'total_amount': totalAmount,
      'transaction_date': transactionDate.toIso8601String(),
      'status': status,
      'items': items.map((item) => item.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class TransactionItem {
  final int? id;
  final int transactionId;
  final int productId;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  TransactionItem({
    this.id,
    required this.transactionId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    return TransactionItem(
      id: json['id'],
      transactionId: json['transaction_id'],
      productId: json['product_id'],
      quantity: json['quantity'],
      unitPrice: (json['unit_price'] as num).toDouble(),
      totalPrice: (json['total_price'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
    };
  }
}