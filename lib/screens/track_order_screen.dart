import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

class TrackOrderScreen extends StatefulWidget {
  final String orderId;

  const TrackOrderScreen({super.key, required this.orderId});

  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> {
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshOrder());
  }

  Future<void> _refreshOrder() async {
    final appState = Provider.of<AppState>(context, listen: false);
    if (!appState.isCustomerSignedIn) {
      return;
    }
    setState(() => _refreshing = true);
    await appState.refreshOrder(widget.orderId);
    if (mounted) {
      setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    // Find matching order in state
    final order = appState.orders.firstWhere(
      (o) => o.id == widget.orderId,
      orElse: () => AppOrder(
        id: widget.orderId,
        items: [],
        subtotal: 0.0,
        deliveryFee: 0.0,
        discount: 0.0,
        total: 0.0,
        deliveryType: "Delivery",
        status: "Pending",
        createdAt: DateTime.now(),
        address: "Loading...",
      ),
    );

    final liveTimeline = appState.timelineForOrder(widget.orderId);
    final steps = liveTimeline.isNotEmpty
        ? liveTimeline
        : const [
            OrderTimelineStep(
              status: "Pending",
              title: "Order Placed",
              description: "We have received your order.",
            ),
            OrderTimelineStep(
              status: "Preparing",
              title: "Processing",
              description: "The store is preparing your items.",
            ),
            OrderTimelineStep(
              status: "Dispatched",
              title: "Shipped",
              description: "Your order has left the store.",
            ),
            OrderTimelineStep(
              status: "Out for Delivery",
              title: "Out for Delivery",
              description: "SKIN-CELLA courier is en route.",
            ),
            OrderTimelineStep(
              status: "Delivered",
              title: "Delivered",
              description: "Your order has arrived.",
            ),
          ];

    // Find current active index
    int activeIndex = 0;
    if (order.status == "Pending") activeIndex = 0;
    if (order.status == "Preparing" || order.status == "Confirmed") {
      activeIndex = 1;
    }
    if (order.status == "Dispatched" || order.status == "Ready") {
      activeIndex = 2;
    }
    if (order.status == "Out for Delivery") activeIndex = 3;
    if (order.status == "Delivered") activeIndex = 4;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TRACK REGIMEN'),
        actions: [
          if (appState.isCustomerSignedIn)
            IconButton(
              onPressed: _refreshing ? null : _refreshOrder,
              icon: _refreshing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          // Order Card Header matching track_your_order.html
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order Reference',
                  style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: AppTheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      order.id,
                      style: GoogleFonts.ebGaramond(
                        fontSize: 22,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        order.status.toUpperCase(),
                        style: GoogleFonts.manrope(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: Colors.white12),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Fulfillment',
                      style: GoogleFonts.manrope(
                          fontSize: 12, color: Colors.white60),
                    ),
                    Text(
                      order.deliveryType,
                      style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Regimen total',
                      style: GoogleFonts.manrope(
                          fontSize: 12, color: Colors.white60),
                    ),
                    Text(
                      '\$${order.total.toStringAsFixed(2)}',
                      style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: AppTheme.accent,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          Text(
            'SHIPMENT PROGRESS',
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppTheme.secondary,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 20),

          // Vertical timeline tracker
          ...List.generate(steps.length, (idx) {
            final step = steps[idx];
            final isCompleted = idx < activeIndex;
            final isActive = idx == activeIndex;
            final isUpcoming = idx > activeIndex;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline left path indicator
                Column(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                            ? AppTheme.success
                            : isActive
                                ? AppTheme.primary
                                : Colors.white,
                        border: Border.all(
                          color:
                              isUpcoming ? AppTheme.border : AppTheme.primary,
                          width: 1.5,
                        ),
                      ),
                      child: isCompleted
                          ? const Icon(Icons.check,
                              size: 10, color: Colors.white)
                          : isActive
                              ? Center(
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: AppTheme.accent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                )
                              : null,
                    ),
                    if (idx < steps.length - 1)
                      Container(
                        width: 1.5,
                        height: 48,
                        color: isCompleted ? AppTheme.success : AppTheme.border,
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                // Timeline right text labels
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.title,
                        style: GoogleFonts.ebGaramond(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isUpcoming
                              ? AppTheme.secondary
                              : AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        step.description,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: AppTheme.secondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            );
          }),

          const SizedBox(height: 20),
          Divider(color: AppTheme.border, thickness: 0.6),
          const SizedBox(height: 20),

          // Items List brief
          Text(
            'FORMULAS INCLUDED',
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppTheme.secondary,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),

          ...order.items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Image.network(item.product.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                                color: AppTheme.border.withValues(alpha: 0.35),
                                child: Icon(Icons.spa_outlined,
                                    color: AppTheme.secondary, size: 18),
                              )),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.product.name,
                          style: GoogleFonts.ebGaramond(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppTheme.primary),
                        ),
                        Text(
                          '${item.quantity} x ${item.product.volume}',
                          style: GoogleFonts.manrope(
                              fontSize: 10, color: AppTheme.secondary),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '\$${item.totalPrice.toStringAsFixed(2)}',
                    style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
