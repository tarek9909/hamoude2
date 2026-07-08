import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_refresh.dart';
import '../widgets/top_toast.dart';
import '../models/product.dart';
import 'product_detail_screen.dart';
import 'promotion_detail_screen.dart';
import 'bundle_detail_screen.dart';
import 'policies_webview_screen.dart';
import 'live_support_screen.dart';
import 'profile_screen.dart'; // For TicketThreadScreen
import 'track_order_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final notifications = appState.notifications;
    final colors = Theme.of(context).colorScheme;

    final hasUnread = notifications.any((n) => n['isRead'] != true);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: colors.primary, size: 20),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        centerTitle: true,
        title: Text(
          'NOTIFICATIONS',
          style: GoogleFonts.ebGaramond(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 3.0,
            color: colors.primary,
          ),
        ),
        actions: [
          if (notifications.isNotEmpty && hasUnread)
            TextButton(
              onPressed: () {
                for (var n in notifications) {
                  if (n['isRead'] != true) {
                    appState.markNotificationRead(n['id']);
                  }
                }
                showTopToast(context, 'Marked all as read');
              },
              child: Text(
                'Mark all read',
                style: GoogleFonts.manrope(
                  color: colors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: !appState.notificationsEnabled
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(
                    'Notifications are unavailable for this store.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: AppTheme.secondary,
                      height: 1.5,
                    ),
                  ),
                ),
              )
            : AppRefresh(
                child: notifications.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.72,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF2F4F0),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.notifications_off_outlined,
                                        color: AppTheme.secondary,
                                        size: 40,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      'Your Inbox is Empty',
                                      style: GoogleFonts.ebGaramond(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: colors.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Check back for seasonal campaigns, new botanical arrivals, and special collection launches.',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.manrope(
                                        fontSize: 13,
                                        color: AppTheme.secondary,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        itemCount: notifications.length,
                        itemBuilder: (context, index) {
                          final notification = notifications[index];
                          final isRead = notification['isRead'] as bool;
                          final title = notification['title']?.toString() ?? '';
                          final message =
                              notification['message']?.toString() ?? '';
                          final time = notification['time']?.toString() ?? '';

                          return GestureDetector(
                            onTap: () {
                              appState.markNotificationRead(notification['id']);

                              final actionType = notification['actionType']
                                      ?.toString()
                                      .toLowerCase() ??
                                  'none';
                              final actionValue =
                                  notification['actionValue']?.toString() ?? '';

                              if (actionType == 'none' || actionValue.isEmpty) {
                                return;
                              }

                              if (actionType == 'product') {
                                if (!appState.productsEnabled) {
                                  showTopToast(
                                      context, 'Catalog is unavailable');
                                  return;
                                }
                                try {
                                  final product = appState.products.firstWhere(
                                    (p) =>
                                        Product.compareIds(p.id, actionValue),
                                  );
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ProductDetailScreen(product: product),
                                    ),
                                  );
                                } catch (e) {
                                  showTopToast(context,
                                      'Formula is no longer available');
                                }
                              } else if (actionType == 'category') {
                                if (!appState.categoriesEnabled ||
                                    !appState.productsEnabled) {
                                  showTopToast(
                                      context, 'Categories are unavailable');
                                  return;
                                }
                                appState.setCategory(actionValue);
                                appState.setTabIndex(1);
                                Navigator.pop(context);
                              } else if (actionType == 'promotion') {
                                if (!appState.promotionsEnabled) {
                                  showTopToast(
                                      context, 'Promotions are unavailable');
                                  return;
                                }
                                Map<String, dynamic>? foundPromo;
                                for (final p in appState.promotions) {
                                  if ((p['id']?.toString() == actionValue) ||
                                      (p['name']?.toString().toLowerCase() ==
                                          actionValue.toLowerCase()) ||
                                      (p['title']?.toString().toLowerCase() ==
                                          actionValue.toLowerCase())) {
                                    foundPromo = p;
                                    break;
                                  }
                                }
                                if (foundPromo != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PromotionDetailScreen(
                                          promotion: foundPromo!),
                                    ),
                                  );
                                } else {
                                  showTopToast(context,
                                      'Promotion is no longer available');
                                }
                              } else if (actionType == 'bundle') {
                                if (!appState.bundlesEnabled) {
                                  showTopToast(
                                      context, 'Bundles are unavailable');
                                  return;
                                }
                                Map<String, dynamic>? foundBundle;
                                for (final b in appState.bundles) {
                                  if (b['id']?.toString() == actionValue ||
                                      b['name']?.toString().toLowerCase() ==
                                          actionValue.toLowerCase()) {
                                    foundBundle = b;
                                    break;
                                  }
                                }
                                if (foundBundle != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => BundleDetailScreen(
                                          bundle: foundBundle!),
                                    ),
                                  );
                                } else {
                                  showTopToast(
                                      context, 'Bundle is no longer available');
                                }
                              } else if (actionType == 'url') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PoliciesWebViewScreen(
                                      title: title,
                                      url: actionValue,
                                    ),
                                  ),
                                );
                              } else if (actionType == 'support' ||
                                  actionType == 'support_reply') {
                                if (appState.supportEnabled) {
                                  SupportTicket? foundTicket;
                                  for (final t in appState.tickets) {
                                    if (t.id == actionValue) {
                                      foundTicket = t;
                                      break;
                                    }
                                  }
                                  if (foundTicket != null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TicketThreadScreen(
                                            ticket: foundTicket!),
                                      ),
                                    );
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const LiveSupportScreen(),
                                      ),
                                    );
                                  }
                                }
                              } else if (actionType == 'order') {
                                if (!appState.ordersEnabled) {
                                  showTopToast(
                                      context, 'Orders are unavailable');
                                  return;
                                }
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        TrackOrderScreen(orderId: actionValue),
                                  ),
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: isRead
                                    ? Colors.white
                                    : const Color(0xFFF2F4F0),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isRead
                                      ? AppTheme.border.withValues(alpha: 0.4)
                                      : AppTheme.primary.withValues(alpha: 0.1),
                                  width: 0.8,
                                ),
                                boxShadow: isRead
                                    ? []
                                    : [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.02),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isRead
                                          ? const Color(0xFFF2F4F0)
                                          : AppTheme.primary
                                              .withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.spa_outlined,
                                      color: isRead
                                          ? AppTheme.secondary
                                          : AppTheme.primary,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                title,
                                                style: GoogleFonts.manrope(
                                                  fontWeight: isRead
                                                      ? FontWeight.w500
                                                      : FontWeight.bold,
                                                  color: AppTheme.primary,
                                                  fontSize: 13.5,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              time,
                                              style: GoogleFonts.manrope(
                                                color: AppTheme.secondary,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          message,
                                          style: GoogleFonts.manrope(
                                            color: isRead
                                                ? const Color(0xFF5E5E5B)
                                                : AppTheme.primary,
                                            fontSize: 12.5,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
      ),
    );
  }
}
