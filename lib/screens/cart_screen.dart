import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shimmer.dart';
import '../widgets/apothecary_icons.dart';
import 'checkout_screen.dart';
import '../widgets/app_refresh.dart';
import '../widgets/top_toast.dart';
import 'product_detail_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('YOUR BAG'),
            if (appState.isWholesaleMode) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8ECE5),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.primary, width: 0.5),
                ),
                child: Text(
                  'WHOLESALE',
                  style: GoogleFonts.manrope(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (appState.cart.isNotEmpty)
            IconButton(
              icon: Icon(Icons.share_outlined, color: AppTheme.primary),
              onPressed: () async {
                final shareUrl =
                    'https://zeyy.app/store/${appState.api.storeSlug}/cart?items=${appState.cart.map((item) => '${item.product.id}:${item.quantity}').join(',')}';
                await Clipboard.setData(ClipboardData(text: shareUrl));
                if (context.mounted) {
                  showTopToast(context, 'Cart link copied to clipboard!');
                }
              },
              tooltip: 'Share Cart',
            ),
        ],
      ),
      body: !appState.checkoutEnabled
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  'Checkout is unavailable for this store.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: AppTheme.secondary,
                    height: 1.5,
                  ),
                ),
              ),
            )
          : appState.cart.isEmpty
              ? AppRefresh(
                  child: LayoutBuilder(builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics()),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ApothecaryBagIcon(
                                  size: 64,
                                  color: AppTheme.border.withValues(alpha: 0.6),
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
                                  'Discover the collection and add clean formulas to your skincare rituals.',
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
                        ),
                      ),
                    );
                  }),
                )
              : Column(
                  children: [
                    // Scrollable cart items list
                    Expanded(
                      child: AppRefresh(
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics()),
                          padding: const EdgeInsets.all(24.0),
                          children: [
                            ...appState.cart.map((item) {
                              final showOriginalPrice = appState
                                      .isWholesaleMode &&
                                  item.product.retailPrice != null &&
                                  item.product.retailPrice! > item.unitPrice;
                              final originalPrice = item.product.retailPrice
                                  ?.toStringAsFixed(
                                      item.product.retailPrice! % 1 == 0
                                          ? 0
                                          : 2);
                              return InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ProductDetailScreen(
                                        product: item.product,
                                      ),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
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
                                          child: ShimmerImage(
                                            imageUrl: item.imageUrl,
                                            fit: BoxFit.cover,
                                            width: 72,
                                            height: 72,
                                            errorWidget: Container(
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
                                              item.displayName,
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
                                              [
                                                item.product.category,
                                                item.product.measurementLabel,
                                                if (item
                                                        .product
                                                        .measurementLabel
                                                        .isEmpty &&
                                                    item.product.volume
                                                        .isNotEmpty)
                                                  item.product.volume,
                                                if (item
                                                    .selectedSize.isNotEmpty)
                                                  'Size: ${item.selectedSize}',
                                              ]
                                                  .where((value) =>
                                                      value.trim().isNotEmpty)
                                                  .join(' - '),
                                              style: GoogleFonts.manrope(
                                                fontSize: 10,
                                                color: AppTheme.secondary,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              '\$${item.unitPrice.toStringAsFixed(2)}',
                                              style: GoogleFonts.manrope(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.primary,
                                              ),
                                            ),
                                            if (showOriginalPrice &&
                                                originalPrice != null) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                '\$$originalPrice',
                                                style: GoogleFonts.manrope(
                                                  fontSize: 11,
                                                  color: AppTheme.secondary,
                                                  decoration: TextDecoration
                                                      .lineThrough,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          IconButton(
                                            icon: ApothecaryTrashIcon(
                                                size: 16,
                                                color: AppTheme.secondary),
                                            onPressed: () =>
                                                appState.removeCartItem(item),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              GestureDetector(
                                                onTap: () => appState
                                                    .updateCartItemQuantity(
                                                        item,
                                                        item.quantity - 1),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.all(5),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.background,
                                                    border: Border.all(
                                                        color: AppTheme.border
                                                            .withValues(
                                                                alpha: 0.5),
                                                        width: 0.8),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: ApothecaryMinusIcon(
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
                                                      item.stockQuantity) {
                                                    final updated = appState
                                                        .updateCartItemQuantity(
                                                            item,
                                                            item.quantity + 1);
                                                    if (!updated) {
                                                      showTopToast(
                                                        context,
                                                        'Only ${item.stockQuantity} items in stock.',
                                                      );
                                                    }
                                                  } else {
                                                    showTopToast(
                                                      context,
                                                      'Only ${item.stockQuantity} items in stock.',
                                                    );
                                                  }
                                                },
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.all(5),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.background,
                                                    border: Border.all(
                                                        color: AppTheme.border
                                                            .withValues(
                                                                alpha: 0.5),
                                                        width: 0.8),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: ApothecaryPlusIcon(
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
                                ),
                              );
                            }),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),

                    // Stitch Premium Gold Order Summary Container
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 38),
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
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Delivery Charge',
                                    style: GoogleFonts.manrope(
                                        color: AppTheme.secondary,
                                        fontSize: 13)),
                                Text(
                                  appState.cartDeliveryFee == 0
                                      ? '\$0.00'
                                      : '\$${appState.cartDeliveryFee.toStringAsFixed(2)}',
                                  style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Divider(color: AppTheme.border, thickness: 0.6),
                            const SizedBox(height: 8),
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
                            const SizedBox(height: 12),
                            if (appState.isWholesaleMode &&
                                appState.cartSubtotal <
                                    appState.wholesaleMinOrderAmount) ...[
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(
                                      0xFFFFF4E5), // Light warm orange/yellow warning background
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFFFFD19A)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded,
                                        color: Color(0xFFB76E00), size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Minimum order amount for wholesale is \$${appState.wholesaleMinOrderAmount.toStringAsFixed(2)}. Your current subtotal is \$${appState.cartSubtotal.toStringAsFixed(2)}.',
                                        style: GoogleFonts.manrope(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFFB76E00),
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: (appState.isWholesaleMode &&
                                        appState.cartSubtotal <
                                            appState.wholesaleMinOrderAmount)
                                    ? null
                                    : () {
                                        if (!appState.isCustomerSignedIn) {
                                          showTopToast(
                                            context,
                                            'Sign in or create an account to continue to checkout.',
                                          );
                                          appState.setTabIndex(4);
                                          return;
                                        }
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
