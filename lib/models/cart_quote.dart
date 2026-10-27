/// Server-side pricing for the current bag, from `POST cart/quote`.
///
/// The backend applies promotions, bundles and tax, so these values are what
/// the customer is actually charged.
class CartQuote {
  final double subtotal;
  final double discount;
  final double deliveryFee;
  final double tax;
  final double total;

  /// The promotion or bundle names the backend applied.
  final List<String> appliedLabels;

  /// The order type the quote was priced for ('delivery' or 'pickup').
  final String orderType;
  final bool taxInclusive;
  final String taxLabel;

  const CartQuote({
    required this.subtotal,
    required this.discount,
    required this.deliveryFee,
    required this.tax,
    required this.total,
    this.appliedLabels = const [],
    this.orderType = 'pickup',
    this.taxInclusive = false,
    this.taxLabel = '',
  });

  factory CartQuote.fromJson(Map<String, dynamic> json, {String? orderType}) {
    final labels = <String>[];
    for (final key in const ['applied_promotions', 'applied_bundles']) {
      final entries = json[key];
      if (entries is! List) continue;
      for (final entry in entries) {
        if (entry is! Map) continue;
        final title = (entry['title'] ?? entry['name'] ?? '').toString().trim();
        if (title.isNotEmpty && !labels.contains(title)) {
          labels.add(title);
        }
      }
    }

    final taxInclusive = json['tax_inclusive'];
    return CartQuote(
      subtotal: _money(json['subtotal']),
      discount: _money(json['discount_amount'] ?? json['discount']),
      deliveryFee: _money(json['delivery_fee']),
      tax: _money(json['tax_amount'] ?? json['tax']),
      total: _money(json['total'] ?? json['grand_total']),
      appliedLabels: List.unmodifiable(labels),
      orderType: orderType ?? json['order_type']?.toString() ?? 'pickup',
      taxInclusive: taxInclusive == true ||
          taxInclusive == 1 ||
          taxInclusive?.toString() == '1' ||
          taxInclusive?.toString().toLowerCase() == 'true',
      taxLabel: json['tax_label']?.toString() ?? '',
    );
  }
}

double _money(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0.0;
}
