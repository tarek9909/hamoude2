import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final canCheckout = appState.checkoutEnabled;
    final productReviews = appState.reviews
        .where(
            (review) => review['product_id']?.toString() == widget.product.id)
        .toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Elegant Header with Full-Bleed Product Image
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            backgroundColor: AppTheme.background,
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'product_img_${widget.product.id}',
                child: Image.network(
                  widget.product.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppTheme.border.withValues(alpha: 0.35),
                    child: Icon(Icons.spa_outlined,
                        size: 48, color: AppTheme.secondary),
                  ),
                ),
              ),
            ),
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.white.withValues(alpha: 0.9),
                child: IconButton(
                  icon:
                      Icon(Icons.arrow_back, color: AppTheme.primary, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          // Product Information
          SliverToBoxAdapter(
            child: Container(
              color: AppTheme.background,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category & Volume tags
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(4),
                          border:
                              Border.all(color: AppTheme.border, width: 0.5),
                        ),
                        child: Text(
                          widget.product.category.toUpperCase(),
                          style: GoogleFonts.manrope(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Text(
                        'Volume: ${widget.product.volume}',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Product Name in EB Garamond
                  Text(
                    widget.product.name,
                    style: GoogleFonts.ebGaramond(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Rating details
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          color: Color(0xFFE5B556), size: 18),
                      const SizedBox(width: 4),
                      Text(
                        widget.product.rating.toString(),
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(${widget.product.reviewsCount} verified reviews)',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: AppTheme.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Price tag
                  Text(
                    '\$${widget.product.price.toStringAsFixed(2)}',
                    style: GoogleFonts.manrope(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Divider(color: AppTheme.border, thickness: 0.6),
                  const SizedBox(height: 20),
                  // Target concerns
                  Text(
                    'DESIGNED FOR',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondary,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: widget.product.skinTypes.map((type) {
                      return Chip(
                        label: Text(type),
                        backgroundColor: Colors.white,
                        side: BorderSide(color: AppTheme.border, width: 0.8),
                        labelStyle: GoogleFonts.manrope(
                          fontSize: 11,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  // Product Description
                  Text(
                    'THE ELIXIR',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondary,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.product.description,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: AppTheme.primary,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Ingredients collapsible details matching Stitch panel
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border, width: 0.8),
                    ),
                    child: Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        leading: Icon(Icons.science_outlined,
                            color: AppTheme.primary),
                        title: Text(
                          'Key Active Ingredients',
                          style: GoogleFonts.ebGaramond(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                                left: 20, right: 20, bottom: 20),
                            child: Text(
                              widget.product.ingredients,
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: AppTheme.secondary,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (appState.reviewsEnabled && productReviews.isNotEmpty) ...[
                    Text(
                      'CUSTOMER REVIEWS',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.secondary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...productReviews.take(3).map((review) {
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: AppTheme.border, width: 0.8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.star_rounded,
                                    color: Color(0xFFE5B556), size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  '${review['rating'] ?? 5}',
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    review['reviewer_name']?.toString() ??
                                        'Verified customer',
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.manrope(
                                      fontSize: 11,
                                      color: AppTheme.secondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if ((review['title'] ?? review['body']) !=
                                null) ...[
                              const SizedBox(height: 8),
                              Text(
                                (review['title'] ?? review['body']).toString(),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  color: AppTheme.primary,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                  ],

                  // Application ritual card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border, width: 0.8),
                    ),
                    child: Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        leading: Icon(Icons.self_improvement_outlined,
                            color: AppTheme.primary),
                        title: Text(
                          'How To Use',
                          style: GoogleFonts.ebGaramond(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                                left: 20, right: 20, bottom: 20),
                            child: Text(
                              "Warm 2-3 drops or a dime-sized amount in clean palms. Gently press onto slightly damp skin of the face, neck, and decollete until fully absorbed. Apply morning or evening as your ritual dictates.",
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: AppTheme.secondary,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(
                      height: 120), // Spacing for absolute bottom sheet
                ],
              ),
            ),
          ),
        ],
      ),
      // Sticky Flat Bottom Buy Bar
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              offset: const Offset(0, -4),
              blurRadius: 8,
            ),
          ],
          border: Border(
            top: BorderSide(color: AppTheme.border, width: 0.8),
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              if (canCheckout && widget.product.stockQuantity > 0) ...[
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.border, width: 0.8),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove,
                            size: 14, color: AppTheme.primary),
                        onPressed: () {
                          if (_quantity > 1) {
                            setState(() => _quantity--);
                          }
                        },
                      ),
                      Text(
                        _quantity.toString(),
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      IconButton(
                        icon:
                            Icon(Icons.add, size: 14, color: AppTheme.primary),
                        onPressed: () {
                          if (_quantity < widget.product.stockQuantity) {
                            setState(() => _quantity++);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Only ${widget.product.stockQuantity} items in stock.'),
                                backgroundColor: AppTheme.primary,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: canCheckout && widget.product.stockQuantity > 0
                    ? ElevatedButton(
                        onPressed: () {
                          for (int i = 0; i < _quantity; i++) {
                            appState.addToCart(widget.product);
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  '$_quantity x ${widget.product.name} added to bag'),
                              backgroundColor: AppTheme.primary,
                              duration: const Duration(seconds: 2),
                              action: SnackBarAction(
                                label: 'VIEW BAG',
                                textColor: AppTheme.accent,
                                onPressed: () {
                                  appState.goToCartTab();
                                },
                              ),
                            ),
                          );
                          Navigator.pop(context);
                        },
                        child: Text(
                            'ADD TO BAG - \$${(widget.product.price * _quantity).toStringAsFixed(2)}'),
                      )
                    : Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppTheme.border,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Center(
                          child: Text(
                            canCheckout ? 'SOLD OUT' : 'CHECKOUT DISABLED',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.secondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
