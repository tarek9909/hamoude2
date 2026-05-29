import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';
import '../widgets/product_card.dart';

class ShopCatalogScreen extends StatefulWidget {
  /// When non-null, the screen filters to only show products of this brand
  /// and hides category filter chips.
  final String? brandFilter;
  final String? categoryFilter;

  const ShopCatalogScreen({super.key, this.brandFilter, this.categoryFilter});

  @override
  State<ShopCatalogScreen> createState() => _ShopCatalogScreenState();
}

class _ShopCatalogScreenState extends State<ShopCatalogScreen> {
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final categories = appState.categories;
    final colors = Theme.of(context).colorScheme;
    final isBrandMode = widget.brandFilter != null && widget.brandFilter!.isNotEmpty;
    final isCategoryMode = widget.categoryFilter != null && widget.categoryFilter!.isNotEmpty;
    final isFilteredMode = isBrandMode || isCategoryMode;

    // Filter products: by brand/category if in filtered mode, otherwise use the existing filters
    final List<Product> products;
    if (isBrandMode) {
      products = appState.products
          .where((p) =>
              p.brand.toLowerCase() == widget.brandFilter!.toLowerCase())
          .toList();
    } else if (isCategoryMode) {
      products = appState.products
          .where((p) =>
              p.category.toLowerCase() == widget.categoryFilter!.toLowerCase())
          .toList();
    } else {
      products = appState.filteredProducts;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF5),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 8, right: 24, top: 12, bottom: 8),
                child: Row(
                  children: [
                    // Show back button in filtered mode, otherwise show app name
                    if (isFilteredMode)
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_new,
                            color: colors.primary, size: 20),
                        onPressed: () => Navigator.pop(context),
                        tooltip: 'Back',
                      )
                    else
                      const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: isFilteredMode
                            ? CrossAxisAlignment.start
                            : CrossAxisAlignment.start,
                        children: [
                          if (!isFilteredMode) ...[
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                appState.appName.toUpperCase(),
                                style: GoogleFonts.ebGaramond(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 4.0,
                                  color: colors.primary,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 8, top: 4),
                              child: Text(
                                "SHOP APOTHECARY",
                                style: GoogleFonts.manrope(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.secondary,
                                  letterSpacing: 2.0,
                                ),
                              ),
                            ),
                          ] else ...[
                            Text(
                              (widget.brandFilter ?? widget.categoryFilter)!.toUpperCase(),
                              style: GoogleFonts.ebGaramond(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2.0,
                                color: colors.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${products.length} ${products.length == 1 ? 'PRODUCT' : 'PRODUCTS'}',
                              style: GoogleFonts.manrope(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.secondary,
                                  letterSpacing: 1.5,
                                ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Divider
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const Divider(height: 24, thickness: 0.8),
                    if (isFilteredMode) const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            if (!appState.catalogEnabled)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  child: Card(
                    color: Color(0xFFF2F4F0),
                    elevation: 0,
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Icon(Icons.lock_outline, size: 32, color: Color(0xFF7E807C)),
                          SizedBox(height: 12),
                          Text(
                            'Catalog is unavailable',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'This store has disabled customer catalog browsing.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else ...[
              // Only show filter chips when NOT in filtered mode
              if (!isFilteredMode) ...[
                // Categories Section Filter
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'COLLECTIONS',
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.secondary,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 48,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: categories.length,
                            itemBuilder: (context, index) {
                              final cat = categories[index];
                              final isSelected = appState.selectedCategory == cat;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ChoiceChip(
                                  label: Text(cat),
                                  selected: isSelected,
                                  onSelected: (_) => appState.setCategory(cat),
                                  backgroundColor: Colors.transparent,
                                  selectedColor: const Color(0xFFEBECE8),
                                  showCheckmark: false,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  labelPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                                  padding: const EdgeInsets.all(4),
                                  labelStyle: GoogleFonts.manrope(
                                    color: isSelected ? const Color(0xFF070F0A) : const Color(0xFF7E807C),
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: isSelected ? const Color(0xFF070F0A) : const Color(0xFFD2D7D4),
                                      width: 1.0,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],

              // Dynamic Product Grid
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: products.isEmpty
                    ? SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 60),
                          child: Column(
                            children: [
                              Icon(Icons.spa_outlined, size: 40, color: AppTheme.border),
                              const SizedBox(height: 12),
                              Text(
                                isBrandMode
                                    ? 'No products found for this brand.'
                                    : isCategoryMode
                                        ? 'No products found for this category.'
                                        : 'No matching formulas found.',
                                style: GoogleFonts.ebGaramond(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isFilteredMode
                                    ? 'Check back soon for new arrivals.'
                                    : 'Try resetting your skin filters.',
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  color: AppTheme.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final product = products[index];
                            return ProductCard(product: product);
                          },
                          childCount: products.length,
                        ),
                      ),
              ),
            ],

            // Add bottom spacing to prevent products from being hidden behind the floating bottom bar
            const SliverToBoxAdapter(
              child: SizedBox(height: 120),
            ),
          ],
        ),
      ),
    );
  }
}
