import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/top_toast.dart';

class TrackOrderScreen extends StatefulWidget {
  final String orderId;

  const TrackOrderScreen({super.key, required this.orderId});

  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> {
  bool _refreshing = false;

  String _formatTimelineTime(DateTime dt) {
    final localDt = dt.toLocal();
    final hour = localDt.hour.toString().padLeft(2, '0');
    final minute = localDt.minute.toString().padLeft(2, '0');

    final now = DateTime.now();
    if (localDt.year == now.year &&
        localDt.month == now.month &&
        localDt.day == now.day) {
      return "$hour:$minute";
    }

    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final monthStr = months[localDt.month - 1];
    return "$monthStr ${localDt.day}, $hour:$minute";
  }

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

  void _showCancelConfirmation(BuildContext context, AppState appState) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Cancel Order',
            style: GoogleFonts.ebGaramond(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: AppTheme.primary,
            ),
          ),
          content: Text(
            'Are you sure you want to cancel this order? This action cannot be undone.',
            style: GoogleFonts.manrope(
              fontSize: 13.5,
              color: AppTheme.secondary,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'KEEP ORDER',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                _performCancellation(appState);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBA1A1A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text(
                'CANCEL IT',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performCancellation(AppState appState) async {
    setState(() => _refreshing = true);
    try {
      await appState.cancelOrder(widget.orderId);
      if (mounted) {
        showTopToast(context, 'Order cancelled successfully.');
      }
    } catch (e) {
      if (mounted) {
        showTopToast(context, 'Failed to cancel order: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final colors = Theme.of(context).colorScheme;

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

    const standardSteps = [
      OrderTimelineStep(
        status: "Pending",
        title: "Order Placed",
        description: "We have received your order.",
      ),
      OrderTimelineStep(
        status: "Confirmed",
        title: "Confirmed",
        description: "Your order has been confirmed by the store.",
      ),
      OrderTimelineStep(
        status: "Preparing",
        title: "Preparing",
        description: "Our specialists are preparing your selections.",
      ),
      OrderTimelineStep(
        status: "Ready",
        title: "Ready",
        description: "Your selections are packaged and ready.",
      ),
      OrderTimelineStep(
        status: "Dispatched",
        title: "Dispatched",
        description: "Your package has been dispatched.",
      ),
      OrderTimelineStep(
        status: "Delivered",
        title: "Delivered",
        description: "Your order has arrived.",
      ),
    ];

    final isCancelled = order.status.toLowerCase() == 'cancelled';
    final List<OrderTimelineStep> steps = [];
    int activeIndex = 0;
    bool reachedCurrent = false;

    final cancelledHistory = liveTimeline.firstWhere(
      (h) => h.status.toLowerCase() == 'cancelled',
      orElse: () => const OrderTimelineStep(
        status: "Cancelled",
        title: "Cancelled",
        description: "This order has been cancelled.",
      ),
    );

    for (int i = 0; i < standardSteps.length; i++) {
      final std = standardSteps[i];
      final historyMatch = liveTimeline.firstWhere(
        (h) => h.status.toLowerCase() == std.status.toLowerCase(),
        orElse: () =>
            const OrderTimelineStep(status: '', title: '', description: ''),
      );
      final bool hasHappened = historyMatch.status.isNotEmpty;

      if (hasHappened) {
        steps.add(OrderTimelineStep(
          status: std.status,
          title: std.title,
          description: historyMatch.description.isNotEmpty
              ? historyMatch.description
              : std.description,
          timestamp: historyMatch.timestamp,
        ));
        if (order.status.toLowerCase() == std.status.toLowerCase()) {
          activeIndex = steps.length - 1;
          reachedCurrent = true;
        }
      } else {
        if (isCancelled) {
          if (!reachedCurrent) {
            steps.add(OrderTimelineStep(
              status: "Cancelled",
              title: "Order Cancelled",
              description: cancelledHistory.description.isNotEmpty
                  ? cancelledHistory.description
                  : "This order has been cancelled.",
              timestamp: cancelledHistory.timestamp,
            ));
            activeIndex = steps.length - 1;
            reachedCurrent = true;
          }
          break;
        } else {
          steps.add(std);
          if (order.status.toLowerCase() == std.status.toLowerCase()) {
            activeIndex = steps.length - 1;
            reachedCurrent = true;
          }
        }
      }
    }

    if (!reachedCurrent && isCancelled) {
      steps.add(OrderTimelineStep(
        status: "Cancelled",
        title: "Order Cancelled",
        description: cancelledHistory.description.isNotEmpty
            ? cancelledHistory.description
            : "This order has been cancelled.",
        timestamp: cancelledHistory.timestamp,
      ));
      activeIndex = steps.length - 1;
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('TRACK '),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: colors.primary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
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
      body: RefreshIndicator(
        onRefresh: _refreshOrder,
        color: AppTheme.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.all(24.0),
          children: [
            // Order Card Header matching luxury theme
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary,
                    AppTheme.primaryContainer,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ORDER REFERENCE',
                    style: GoogleFonts.manrope(
                        fontSize: 9,
                        color: AppTheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          order.id,
                          style: GoogleFonts.ebGaramond(
                            fontSize: 22,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: order.status.toLowerCase() == 'delivered'
                              ? const Color(0xFFE2F3E5)
                              : order.status.toLowerCase() == 'cancelled'
                                  ? const Color(0xFFFFE6E6)
                                  : AppTheme.accent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          order.status.toUpperCase(),
                          style: GoogleFonts.manrope(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: order.status.toLowerCase() == 'delivered'
                                ? const Color(0xFF1E6C2E)
                                : order.status.toLowerCase() == 'cancelled'
                                    ? const Color(0xFFBA1A1A)
                                    : AppTheme.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(
                      color: Colors.white.withValues(alpha: 0.1), height: 1),
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        ' total',
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

            const SizedBox(height: 36),

            Text(
              'SHIPMENT PROGRESS',
              style: GoogleFonts.manrope(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: AppTheme.secondary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            // Vertical timeline tracker with IntrinsicHeight
            ...List.generate(steps.length, (idx) {
              final step = steps[idx];
              final isCompleted = idx < activeIndex;
              final isActive = idx == activeIndex;
              final isUpcoming = idx > activeIndex;
              final isStepCancelled = step.status.toLowerCase() == 'cancelled';

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Timeline left path indicator
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Column(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isCompleted
                                  ? AppTheme.success
                                  : isActive
                                      ? (isStepCancelled
                                          ? const Color(0xFFBA1A1A)
                                          : AppTheme.primary)
                                      : Colors.white,
                              border: Border.all(
                                color: isUpcoming
                                    ? AppTheme.border
                                    : (isStepCancelled
                                        ? const Color(0xFFBA1A1A)
                                        : AppTheme.primary),
                                width: 1.5,
                              ),
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: (isStepCancelled
                                                ? const Color(0xFFBA1A1A)
                                                : AppTheme.primary)
                                            .withValues(alpha: 0.15),
                                        blurRadius: 6,
                                        spreadRadius: 2,
                                      )
                                    ]
                                  : null,
                            ),
                            child: isCompleted
                                ? const Icon(Icons.check,
                                    size: 11, color: Colors.white)
                                : isActive
                                    ? (isStepCancelled
                                        ? const Icon(Icons.close,
                                            size: 11, color: Colors.white)
                                        : Center(
                                            child: Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color: AppTheme.accent,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ))
                                    : null,
                          ),
                          if (idx < steps.length - 1)
                            Expanded(
                              child: Container(
                                width: 1.2,
                                color: isCompleted
                                    ? AppTheme.success
                                    : AppTheme.border.withValues(alpha: 0.5),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Timeline right text labels
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  step.title,
                                  style: GoogleFonts.ebGaramond(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isUpcoming
                                        ? AppTheme.secondary
                                            .withValues(alpha: 0.5)
                                        : (isStepCancelled
                                            ? const Color(0xFFBA1A1A)
                                            : AppTheme.primary),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                              if (step.timestamp != null)
                                Text(
                                  _formatTimelineTime(step.timestamp!),
                                  style: GoogleFonts.manrope(
                                    fontSize: 10,
                                    color: AppTheme.secondary
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            step.description,
                            style: GoogleFonts.manrope(
                              fontSize: 11.5,
                              color: isUpcoming
                                  ? AppTheme.secondary.withValues(alpha: 0.5)
                                  : AppTheme.secondary,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 12),
            Divider(
                color: AppTheme.border.withValues(alpha: 0.5), thickness: 0.6),
            const SizedBox(height: 24),

            ...order.items.map((item) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F4F0).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.border.withValues(alpha: 0.3),
                      width: 0.8),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Image.network(item.product.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                                  color:
                                      AppTheme.border.withValues(alpha: 0.35),
                                  child: Icon(Icons.spa_outlined,
                                      color: AppTheme.secondary, size: 20),
                                )),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.product.name,
                            style: GoogleFonts.ebGaramond(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppTheme.primary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.quantity} x ${item.product.volume}',
                            style: GoogleFonts.manrope(
                                fontSize: 11, color: AppTheme.secondary),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '\$${item.totalPrice.toStringAsFixed(2)}',
                      style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary),
                    ),
                  ],
                ),
              );
            }),
            if (order.status.toLowerCase() == 'pending') ...[
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: _refreshing
                    ? null
                    : () => _showCancelConfirmation(context, appState),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFBA1A1A),
                  side: const BorderSide(color: Color(0xFFBA1A1A), width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Center(
                  child: Text(
                    'CANCEL ORDER',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
