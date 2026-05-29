import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('YOUR BAG'),
      ),
      body: !appState.checkoutEnabled
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'Checkout is disabled for this store.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: AppTheme.secondary,
                    height: 1.4,
                  ),
                ),
              ),
            )
          : appState.cart.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.local_mall_outlined,
                          size: 56,
                          color: AppTheme.border,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Your bag is empty',
                          style: GoogleFonts.ebGaramond(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Discover this store catalog and add your favorite products to the bag.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: AppTheme.secondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Scrollable cart items list
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(24.0),
                        children: [
                          ...appState.cart.map((item) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: AppTheme.border, width: 0.8),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox(
                                      width: 72,
                                      height: 72,
                                      child: Image.network(
                                        item.product.imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: AppTheme.border
                                              .withValues(alpha: 0.35),
                                          child: Icon(Icons.spa_outlined,
                                              color: AppTheme.secondary),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.product.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.ebGaramond(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${item.product.category} - ${item.product.volume}',
                                          style: GoogleFonts.manrope(
                                            fontSize: 10,
                                            color: AppTheme.secondary,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '\$${item.product.price.toStringAsFixed(2)}',
                                          style: GoogleFonts.manrope(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.close,
                                            size: 15,
                                            color: AppTheme.secondary),
                                        onPressed: () => appState
                                            .removeFromCart(item.product),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          GestureDetector(
                                            onTap: () =>
                                                appState.updateQuantity(
                                                    item.product,
                                                    item.quantity - 1),
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                    color: AppTheme.border,
                                                    width: 0.8),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(Icons.remove,
                                                  size: 10,
                                                  color: AppTheme.primary),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            item.quantity.toString(),
                                            style: GoogleFonts.manrope(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          GestureDetector(
                                            onTap: () {
                                              if (item.quantity <
                                                  item.product.stockQuantity) {
                                                appState.updateQuantity(
                                                    item.product,
                                                    item.quantity + 1);
                                              } else {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                        'Only ${item.product.stockQuantity} items in stock.'),
                                                    backgroundColor:
                                                        AppTheme.primary,
                                                  ),
                                                );
                                              }
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                    color: AppTheme.border,
                                                    width: 0.8),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(Icons.add,
                                                  size: 10,
                                                  color: AppTheme.primary),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),

                          const SizedBox(height: 12),

                          // Shipping Free Banner
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color:
                                      AppTheme.success.withValues(alpha: 0.2),
                                  width: 0.8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.delivery_dining_outlined,
                                    color: AppTheme.success, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    appState.cartSubtotal >= 75.0
                                        ? "Complimentary Home Delivery unlocked."
                                        : "Add \$${(75.0 - appState.cartSubtotal).toStringAsFixed(2)} more to unlock complimentary Home Delivery.",
                                    style: GoogleFonts.manrope(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.success,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Stitch Premium Gold Order Summary Container
                    Container(
                      padding: const EdgeInsets.only(
                          left: 24, right: 24, top: 24, bottom: 92),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.4),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20)),
                        border: Border(
                          top: BorderSide(color: AppTheme.border, width: 0.8),
                        ),
                      ),
                      child: SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Subtotal',
                                    style: GoogleFonts.manrope(
                                        color: AppTheme.secondary,
                                        fontSize: 13)),
                                Text(
                                    '\$${appState.cartSubtotal.toStringAsFixed(2)}',
                                    style: GoogleFonts.manrope(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Standard Shipping',
                                    style: GoogleFonts.manrope(
                                        color: AppTheme.secondary,
                                        fontSize: 13)),
                                Text(
                                  appState.cartDeliveryFee == 0
                                      ? 'FREE'
                                      : '\$${appState.cartDeliveryFee.toStringAsFixed(2)}',
                                  style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: appState.cartDeliveryFee == 0
                                        ? AppTheme.success
                                        : AppTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (appState.cartDiscount > 0) ...[
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Spring Collection Discount (15%)',
                                      style: GoogleFonts.manrope(
                                          color: AppTheme.success,
                                          fontSize: 13)),
                                  Text(
                                    '-\$${appState.cartDiscount.toStringAsFixed(2)}',
                                    style: GoogleFonts.manrope(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.success,
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                            Divider(color: AppTheme.border, thickness: 0.6),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total Estimate',
                                  style: GoogleFonts.ebGaramond(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                Text(
                                  '\$${appState.cartTotal.toStringAsFixed(2)}',
                                  style: GoogleFonts.manrope(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const CheckoutScreen()),
                                  );
                                },
                                child: const Text('PROCEED TO CHECKOUT'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
