class Transaction {
  final String? id;
  final List<Map<String, dynamic>> items;
  final double subtotal;
  final double tax;
  final double discount;
  final double total;
  final DateTime timestamp;
  final bool isSynced;

  Transaction({
    this.id,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.discount,
    required this.total,
    required this.timestamp,
    this.isSynced = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'items': items,
      'subtotal': subtotal,
      'tax': tax,
      'discount': discount,
      'total': total,
      'timestamp': timestamp.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String?,
      items: List<Map<String, dynamic>>.from(json['items']),
      subtotal: json['subtotal'] as double,
      tax: json['tax'] as double,
      discount: json['discount'] as double,
      total: json['total'] as double,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isSynced: json['is_synced'] == 1,
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'items': items.toString(),
      'subtotal': subtotal,
      'tax': tax,
      'discount': discount,
      'total': total,
      'timestamp': timestamp.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
    };
  }
}
