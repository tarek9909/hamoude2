import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'track_order_screen.dart';

class TrackOrdersListScreen extends StatefulWidget {
  const TrackOrdersListScreen({super.key});

  @override
  State<TrackOrdersListScreen> createState() => _TrackOrdersListScreenState();
}

class _TrackOrdersListScreenState extends State<TrackOrdersListScreen> {
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF5),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          children: [
            // Elegant Header
            Text(
              appState.appName.toUpperCase(),
              style: GoogleFonts.ebGaramond(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 4.0,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "ACTIVE REGIMENS & ORDERS",
              style: GoogleFonts.manrope(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: AppTheme.secondary,
                letterSpacing: 2.0,
              ),
            ),
            const Divider(height: 32, thickness: 0.8),

            if (!appState.isCustomerSignedIn)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F4F0),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.receipt_long_outlined, size: 36, color: Color(0xFF7E807C)),
                    const SizedBox(height: 16),
                    Text(
                      'Sign in to track orders',
                      style: GoogleFonts.ebGaramond(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please access the Me profile tab to sign in or register and sync your active regimens, order histories, and support tickets.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: AppTheme.secondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        // Switch to Profile Tab
                        appState.setTabIndex(4);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text(
                        'GO TO PROFILE',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (appState.orders.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    const Icon(Icons.receipt_outlined, size: 40, color: Color(0xFFC2C7C4)),
                    const SizedBox(height: 16),
                    Text(
                      'No orders found',
                      style: GoogleFonts.ebGaramond(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Explore our catalog and curate your personal ritual to place your first boutique order.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: AppTheme.secondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: appState.orders.map((order) {
                  final formattedDate =
                      "${order.createdAt.year}-${order.createdAt.month.toString().padLeft(2, '0')}-${order.createdAt.day.toString().padLeft(2, '0')}";
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F4F0),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border.withValues(alpha: 0.5), width: 0.8),
                    ),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TrackOrderScreen(orderId: order.id),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  order.id.toUpperCase(),
                                  style: GoogleFonts.ebGaramond(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: colors.primary,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: order.status.toLowerCase() == 'delivered'
                                        ? const Color(0xFFE2F3E5)
                                        : const Color(0xFFFEF2E5),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    order.status.toUpperCase(),
                                    style: GoogleFonts.manrope(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                      color: order.status.toLowerCase() == 'delivered'
                                          ? const Color(0xFF1E6C2E)
                                          : const Color(0xFFB35E00),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'DATE PLACED',
                                      style: GoogleFonts.manrope(
                                        fontSize: 9,
                                        color: AppTheme.secondary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      formattedDate,
                                      style: GoogleFonts.manrope(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: colors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'TOTAL',
                                      style: GoogleFonts.manrope(
                                        fontSize: 9,
                                        color: AppTheme.secondary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '\$${order.total.toStringAsFixed(2)}',
                                      style: GoogleFonts.manrope(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Divider(height: 24, thickness: 0.8),
                            Row(
                              children: [
                                const Icon(Icons.local_shipping_outlined, size: 14, color: Color(0xFF7E807C)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    order.deliveryType == 'Delivery'
                                        ? 'Courier Delivery to ${order.address}'
                                        : 'In-Store Pickup',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.manrope(
                                      fontSize: 11.5,
                                      color: AppTheme.secondary,
                                    ),
                                  ),
                                ),
                                Icon(Icons.arrow_forward_ios, size: 10, color: colors.primary),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

            // Spacing at the bottom to prevent covering
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }
}
