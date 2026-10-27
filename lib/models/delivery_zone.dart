/// An active delivery zone from `GET delivery-zones`.
class DeliveryZone {
  final String id;

  /// Null when the zone applies to every branch.
  final int? branchId;
  final String name;
  final String description;
  final double minimumOrderAmount;
  final int? estimatedDeliveryMinutes;

  const DeliveryZone({
    required this.id,
    this.branchId,
    required this.name,
    this.description = '',
    this.minimumOrderAmount = 0.0,
    this.estimatedDeliveryMinutes,
  });

  factory DeliveryZone.fromJson(Map<String, dynamic> json) {
    return DeliveryZone(
      id: (json['id'] ?? '').toString(),
      branchId: int.tryParse(json['branch_id']?.toString() ?? ''),
      name: (json['name'] ?? 'Delivery zone').toString(),
      description: (json['description'] ?? '').toString(),
      minimumOrderAmount:
          double.tryParse(json['minimum_order_amount']?.toString() ?? '') ??
              0.0,
      estimatedDeliveryMinutes:
          int.tryParse(json['estimated_delivery_minutes']?.toString() ?? ''),
    );
  }

  /// Whether this zone can serve [branchId].
  bool servesBranch(int branchId) =>
      this.branchId == null || this.branchId == branchId;

  /// The numeric id the backend expects, or null for malformed rows.
  int? get numericId => int.tryParse(id);
}
