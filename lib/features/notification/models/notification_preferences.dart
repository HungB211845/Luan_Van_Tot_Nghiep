class NotificationPreferences {
  final bool enablePushNotifications;
  final bool inventoryAlerts;
  final bool purchaseOrderAlerts;
  final bool debtAlerts;
  final bool notify30Days;
  final bool notify60Days;
  final bool notify90Days;

  const NotificationPreferences({
    this.enablePushNotifications = true,
    this.inventoryAlerts = true,
    this.purchaseOrderAlerts = false,
    this.debtAlerts = false,
    this.notify30Days = true,
    this.notify60Days = true,
    this.notify90Days = true,
  });

  NotificationPreferences copyWith({
    bool? enablePushNotifications,
    bool? inventoryAlerts,
    bool? purchaseOrderAlerts,
    bool? debtAlerts,
    bool? notify30Days,
    bool? notify60Days,
    bool? notify90Days,
  }) {
    return NotificationPreferences(
      enablePushNotifications:
          enablePushNotifications ?? this.enablePushNotifications,
      inventoryAlerts: inventoryAlerts ?? this.inventoryAlerts,
      purchaseOrderAlerts:
          purchaseOrderAlerts ?? this.purchaseOrderAlerts,
      debtAlerts: debtAlerts ?? this.debtAlerts,
      notify30Days: notify30Days ?? this.notify30Days,
      notify60Days: notify60Days ?? this.notify60Days,
      notify90Days: notify90Days ?? this.notify90Days,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enablePushNotifications': enablePushNotifications,
      'inventoryAlerts': inventoryAlerts,
      'purchaseOrderAlerts': purchaseOrderAlerts,
      'debtAlerts': debtAlerts,
      'notify30Days': notify30Days,
      'notify60Days': notify60Days,
      'notify90Days': notify90Days,
    };
  }

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      enablePushNotifications:
          json['enablePushNotifications'] as bool? ?? true,
      inventoryAlerts: json['inventoryAlerts'] as bool? ?? true,
      purchaseOrderAlerts: json['purchaseOrderAlerts'] as bool? ?? false,
      debtAlerts: json['debtAlerts'] as bool? ?? false,
      notify30Days: json['notify30Days'] as bool? ?? true,
      notify60Days: json['notify60Days'] as bool? ?? true,
      notify90Days: json['notify90Days'] as bool? ?? true,
    );
  }
}
