import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../models/product.dart';
import '../widgets/top_toast.dart';
import 'product_detail_screen.dart';
import 'policies_webview_screen.dart';
import 'bundles_screen.dart';
import 'bundle_detail_screen.dart';
import 'catalog_screen.dart';
import 'browse_collection_screen.dart';
import 'offers_screen.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _handlePromotionProductAdd(
    BuildContext context,
    Product product,
  ) async {
    final state = Provider.of<AppState>(context, listen: false);
    var resolvedProduct = product;

    try {
      final liveProduct = await state.api.getProduct(
        product.id,
        branchId: state.selectedBranchId,
      );
      if (liveProduct != null) {
        resolvedProduct = liveProduct;
      }
    } catch (e) {
      debugPrint("Failed to fetch product before quick add: $e");
    }

    if (!context.mounted) return;

    if (resolvedProduct.variants.length > 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(
            product: resolvedProduct,
          ),
        ),
      );
      showTopToast(context, 'Select options before adding.');
      return;
    }

    final variant = resolvedProduct.variants.length == 1
        ? resolvedProduct.variants.first
        : null;
    final added = state.addToCart(resolvedProduct, variant: variant);
    final stockQuantity =
        variant?.stockQuantity ?? resolvedProduct.stockQuantity;
    showTopToast(
      context,
      added
          ? '${resolvedProduct.name} added to bag'
          : 'Only $stockQuantity items in stock.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isCompactHeader = MediaQuery.sizeOf(context).width < 380;

    final List<Map<String, dynamic>> displayBundles =
        appState.bundlesEnabled ? appState.bundles : [];

    final List<Map<String, dynamic>> displayBrands =
        appState.brandsEnabled ? appState.brands : [];

    final List<Map<String, String>> displayCategories =
        appState.categoriesEnabled
            ? appState.categoryRecords.map((category) {
                final rawImageUrl = category['image_url']?.toString() ??
                    category['image']?.toString() ??
                    '';
                return {
                  'id': category['id']?.toString() ?? '',
                  'name': category['name']?.toString() ?? '',
                  'image': appState.api.resolveMediaUrl(rawImageUrl),
                };
              }).where((category) {
                return (category['name'] ?? '').isNotEmpty;
              }).toList()
            : [];

    // Build promotions list dynamically
    final List<Map<String, dynamic>> displayPromotionsData = [];

    if (appState.promotionsEnabled && appState.promotions.isNotEmpty) {
      for (final promo in appState.promotions) {
        final promoId = promo['id']?.toString() ?? '';
        final title = promo['name']?.toString() ??
            promo['title']?.toString() ??
            'Special Offer';
        final description = promo['description']?.toString() ??
            promo['subtitle']?.toString() ??
            '';

        final discountType = promo['discount_type']?.toString() ?? 'percentage';
        final discountVal =
            (promo['discount_value'] as num?)?.toDouble() ?? 20.0;
        final discountLabel = promo['discount_label']?.toString() ??
            promo['badge']?.toString() ??
            (discountType == 'percentage'
                ? '-${discountVal.toStringAsFixed(0)}% OFF'
                : 'SPECIAL OFFER');

        final rawItems = promo['product_links'] as List? ?? [];
        final matchingProducts = <Product>[];
        if (rawItems.isNotEmpty) {
          for (final link in rawItems) {
            final prodId = link['product_id']?.toString();
            try {
              final p = appState.products
                  .firstWhere((prod) => Product.compareIds(prod.id, prodId));
              matchingProducts.add(p);
            } catch (_) {}
          }
        }
        if (matchingProducts.isEmpty) {
          try {
            final p = appState.products.firstWhere(
              (prod) => prod.name.toLowerCase() == title.toLowerCase(),
            );
            matchingProducts.add(p);
          } catch (_) {}
        }

        final List<Map<String, dynamic>> promoProducts = [];
        for (final product in matchingProducts) {
          double discPrice = product.price;
          final promoPriceStr = promo['price']?.toString();
          if (matchingProducts.length == 1 &&
              promoPriceStr != null &&
              double.tryParse(promoPriceStr) != null) {
            discPrice = double.parse(promoPriceStr);
          } else {
            if (discountType == 'percentage') {
              discPrice = product.price * (1 - discountVal / 100);
            } else {
              discPrice =
                  (product.price - discountVal).clamp(0.0, double.infinity);
            }
          }

          promoProducts.add({
            'product': product,
            'discountedPrice': discPrice,
            'originalPrice': product.price,
            'discountLabel': discountLabel,
          });
        }

        if (promoProducts.isNotEmpty) {
          displayPromotionsData.add({
            'id': promoId,
            'title': title,
            'description': description,
            'products': promoProducts,
            'rawPromo': promo,
          });
        }
      }
    }

    final List<Map<String, dynamic>> allStories = [];
    if (appState.contentEnabled) {
      for (final story in appState.stories) {
        final rawItems = story['items'] as List?;
        final List<Map<String, dynamic>> sFrames;
        if (rawItems != null && rawItems.isNotEmpty) {
          sFrames = rawItems
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .where((item) {
            final mediaUrl = item['media_url']?.toString() ??
                item['image_url']?.toString() ??
                '';
            return mediaUrl.isNotEmpty;
          }).toList();
        } else {
          final previewUrl = story['preview_media_url']?.toString() ?? '';
          sFrames = [
            if (previewUrl.isNotEmpty)
              {
                'media_url': previewUrl,
                'caption': story['title']?.toString() ?? '',
              }
          ];
        }

        if (sFrames.isNotEmpty) {
          allStories.add({
            'title': story['title']?.toString() ?? '',
            'imageUrl': sFrames.first['media_url']?.toString() ??
                sFrames.first['image_url']?.toString() ??
                '',
            'frames': sFrames,
          });
        }
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await appState.refreshAllData();
          },
          color: AppTheme.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            slivers: [
              // Boutique Header matching Stitch
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    'SKIN-CELLA',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.ebGaramond(
                                      fontSize: isCompactHeader ? 22 : 26,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing:
                                          isCompactHeader ? 1.2 : 3.0,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ),
                                if (appState.isWholesaleMode) ...[
                                  SizedBox(width: isCompactHeader ? 5 : 8),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isCompactHeader ? 6 : 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE8ECE5),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: AppTheme.primary, width: 0.5),
                                    ),
                                    child: Text(
                                      'WHOLESALE',
                                      style: GoogleFonts.manrope(
                                        fontSize: isCompactHeader ? 7 : 8,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primary,
                                        letterSpacing:
                                            isCompactHeader ? 0.2 : 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            GestureDetector(
                              onTap: () =>
                                  _showBranchSelector(context, appState),
                              child: Row(
                                children: [
                                  Icon(Icons.spa_outlined,
                                      size: 13, color: AppTheme.secondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    appState.selectedBranch,
                                    style: GoogleFonts.manrope(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.secondary,
                                    ),
                                  ),
                                  Icon(Icons.keyboard_arrow_down,
                                      size: 12, color: AppTheme.secondary),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (appState.productsEnabled) ...[
                            IconButton(
                              icon: Icon(Icons.search,
                                  color: AppTheme.primary, size: 24),
                              onPressed: () {
                                appState
                                    .setTabIndex(1); // Go to Search Screen tab
                              },
                              tooltip: 'Search',
                            ),
                            const SizedBox(width: 4),
                          ],
                          if (appState.notificationsEnabled)
                            Stack(
                              children: [
                                IconButton(
                                  icon: Icon(Icons.notifications_none_outlined,
                                      color: AppTheme.primary),
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const NotificationsScreen(),
                                    ),
                                  ),
                                  tooltip: 'Notifications',
                                ),
                                if (appState.notifications
                                    .any((n) => !n['isRead']))
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFBA1A1A),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              if (appState.contentEnabled && appState.banners.isNotEmpty)
                // Boutique Carousel at the top
                SliverToBoxAdapter(
                  child: BoutiqueCarousel(
                    banners: appState.banners,
                    onCategorySelected: (category) =>
                        appState.setCategory(category),
                    onSearchQuery: (query) => appState.setSearchQuery(query),
                  ),
                ),

              if (appState.contentEnabled && allStories.isNotEmpty)
                // Live marketing story strip.
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 88,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      itemCount: allStories.length,
                      itemBuilder: (context, index) {
                        final story = allStories[index];
                        return StoryItemWidget(
                          title: story['title'],
                          imageUrl:
                              appState.api.resolveMediaUrl(story['imageUrl']),
                          onTap: () {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder:
                                    (context, animation, secondaryAnimation) =>
                                        InstagramStoriesViewer(
                                  initialStoryIndex: index,
                                  allStories: allStories,
                                ),
                                transitionsBuilder: (context, animation,
                                    secondaryAnimation, child) {
                                  const begin = Offset(0.0, 1.0);
                                  const end = Offset.zero;
                                  const curve = Curves.easeInOut;
                                  var tween = Tween(begin: begin, end: end)
                                      .chain(CurveTween(curve: curve));
                                  return SlideTransition(
                                    position: animation.drive(tween),
                                    child: child,
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),

              if (!appState.isWholesaleMode &&
                  appState.bundlesEnabled &&
                  displayBundles.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: SizedBox(height: 24),
                ),

                // Curated bundles section.
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Curated Bundles',
                                    style: GoogleFonts.ebGaramond(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF070F0A),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const BundlesScreen(),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Color(0xFF070F0A),
                                          width: 1.0,
                                        ),
                                      ),
                                    ),
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Text(
                                      'VIEW ALL',
                                      style: GoogleFonts.manrope(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                        color: const Color(0xFF070F0A),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Thoughtfully paired botanical essentials for targeted results.',
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                color: const Color(0xFF5E5E5B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 415,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: displayBundles.length,
                          itemBuilder: (context, index) {
                            final bundle = displayBundles[index];
                            final imageUrl = bundle['image_url']?.toString() ??
                                bundle['media_url']?.toString() ??
                                '';

                            final tag = bundle['subtitle']?.toString() ??
                                bundle['tag']?.toString() ??
                                '';

                            final title = bundle['name']?.toString() ??
                                bundle['title']?.toString() ??
                                "Bundle";

                            final description =
                                bundle['description']?.toString() ??
                                    bundle['summary']?.toString() ??
                                    "";

                            final rawItems = bundle['items'] as List? ?? [];
                            final itemsList = rawItems
                                .whereType<Map<String, dynamic>>()
                                .toList();

                            double computedOriginalPrice = 0.0;
                            for (final item in itemsList) {
                              final prodId =
                                  item['product_id']?.toString() ?? '';
                              final qty =
                                  (item['quantity'] as num?)?.toDouble() ?? 1.0;
                              Product? p;
                              try {
                                p = appState.products.firstWhere((entry) =>
                                    Product.compareIds(entry.id, prodId));
                              } catch (_) {}
                              final itemPrice = p?.price ??
                                  (item['unit_price_snapshot'] as num?)
                                      ?.toDouble() ??
                                  0.0;
                              computedOriginalPrice += itemPrice * qty;
                            }

                            final bundlePriceVal =
                                (bundle['bundle_price'] as num?)?.toDouble() ??
                                    double.tryParse(
                                        bundle['price']?.toString() ?? '') ??
                                    110.0;

                            final price = bundlePriceVal.toStringAsFixed(
                                bundlePriceVal % 1 == 0 ? 0 : 2);
                            final originalPrice = computedOriginalPrice > 0
                                ? computedOriginalPrice.toStringAsFixed(
                                    computedOriginalPrice % 1 == 0 ? 0 : 2)
                                : (bundlePriceVal * 1.27).toStringAsFixed(0);

                            return Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          BundleDetailScreen(bundle: bundle),
                                    ),
                                  );
                                },
                                child: Container(
                                  width: 290,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF4F5F2),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: AspectRatio(
                                          aspectRatio: 1.15,
                                          child: Image.network(
                                            imageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                              color: Colors.white,
                                              child: Icon(
                                                Icons.spa_outlined,
                                                color: AppTheme.secondary,
                                                size: 40,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        tag.toUpperCase(),
                                        style: GoogleFonts.manrope(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF7E807C),
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        title,
                                        style: GoogleFonts.ebGaramond(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF070F0A),
                                          height: 1.2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.manrope(
                                          fontSize: 12.5,
                                          color: const Color(0xFF5E5E5B),
                                          height: 1.4,
                                        ),
                                      ),
                                      const Spacer(),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.baseline,
                                            textBaseline:
                                                TextBaseline.alphabetic,
                                            children: [
                                              Text(
                                                '\$$price',
                                                style: GoogleFonts.manrope(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      const Color(0xFF070F0A),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '\$$originalPrice',
                                                style: GoogleFonts.manrope(
                                                  fontSize: 13,
                                                  color:
                                                      const Color(0xFF9E9E9E),
                                                  decoration: TextDecoration
                                                      .lineThrough,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Container(
                                            decoration: const BoxDecoration(
                                              border: Border(
                                                bottom: BorderSide(
                                                  color: Color(0xFF070F0A),
                                                  width: 1.0,
                                                ),
                                              ),
                                            ),
                                            padding: const EdgeInsets.only(
                                                bottom: 2),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'EXPLORE',
                                                  style: GoogleFonts.manrope(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 1.5,
                                                    color:
                                                        const Color(0xFF070F0A),
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                const Icon(
                                                  Icons.arrow_forward,
                                                  size: 11,
                                                  color: Color(0xFF070F0A),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 24),
                ),
              ],

              if (appState.brandsEnabled && displayBrands.isNotEmpty)
                // Shop by brand section.
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                'Shop by Brand',
                                style: GoogleFonts.ebGaramond(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF070F0A),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const BrowseCollectionScreen(
                                            mode: BrowseMode.brands),
                                  ),
                                );
                              },
                              child: Container(
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Color(0xFF070F0A),
                                      width: 1.0,
                                    ),
                                  ),
                                ),
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  'VIEW ALL',
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                    color: const Color(0xFF070F0A),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 145,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: displayBrands.length,
                          itemBuilder: (context, index) {
                            final brand = displayBrands[index];
                            final rawUrl = brand['logo_url']?.toString() ??
                                brand['image_url']?.toString() ??
                                brand['image']?.toString() ??
                                '';
                            final imageUrl =
                                appState.api.resolveMediaUrl(rawUrl);
                            final name = brand['name']?.toString() ?? 'BRAND';

                            return Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ShopCatalogScreen(
                                        brandFilter: name,
                                      ),
                                    ),
                                  );
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 100,
                                      height: 100,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE4E6E2),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: imageUrl.isNotEmpty
                                            ? Image.network(
                                                imageUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    Container(
                                                  color: Colors.white,
                                                  child: Icon(
                                                    Icons.business,
                                                    color: AppTheme.secondary,
                                                    size: 28,
                                                  ),
                                                ),
                                              )
                                            : Container(
                                                color: Colors.white,
                                                child: Icon(
                                                  Icons.business,
                                                  color: AppTheme.secondary,
                                                  size: 28,
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      name.toUpperCase(),
                                      style: GoogleFonts.manrope(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF070F0A),
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

              if (appState.categoriesEnabled &&
                  displayCategories.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: SizedBox(height: 24),
                ),
                // Shop by category section.
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                'Shop by Category',
                                style: GoogleFonts.ebGaramond(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF070F0A),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const BrowseCollectionScreen(
                                            mode: BrowseMode.categories),
                                  ),
                                );
                              },
                              child: Container(
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Color(0xFF070F0A),
                                      width: 1.0,
                                    ),
                                  ),
                                ),
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  'VIEW ALL',
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                    color: const Color(0xFF070F0A),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: displayCategories.length,
                          itemBuilder: (context, index) {
                            final cat = displayCategories[index];
                            final name = cat['name'] ?? '';
                            final imageUrl = cat['image'] ?? '';

                            return Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ShopCatalogScreen(
                                        categoryFilter: name,
                                      ),
                                    ),
                                  );
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 145,
                                      height: 165,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF4F5F2),
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(24),
                                        child: imageUrl.isNotEmpty
                                            ? Image.network(
                                                imageUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    Container(
                                                  color: Colors.white,
                                                  child: Icon(
                                                    Icons.spa_outlined,
                                                    color: AppTheme.secondary,
                                                    size: 32,
                                                  ),
                                                ),
                                              )
                                            : Container(
                                                color: Colors.white,
                                                child: Icon(
                                                  Icons.spa_outlined,
                                                  color: AppTheme.secondary,
                                                  size: 32,
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: Text(
                                        name,
                                        style: GoogleFonts.ebGaramond(
                                          fontSize: 16.5,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF070F0A),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (!appState.isWholesaleMode &&
                  appState.promotionsEnabled &&
                  displayPromotionsData.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: SizedBox(height: 24),
                ),

                // Dynamic promotion sections from live backend data.
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: displayPromotionsData.map((promoSection) {
                      final String promoId = promoSection['id'] ?? '';
                      final String title = promoSection['title'] ?? '';
                      final String description =
                          promoSection['description'] ?? '';
                      final List<Map<String, dynamic>> promoProducts =
                          promoSection['products'] ?? [];

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: GoogleFonts.ebGaramond(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF070F0A),
                                          height: 1.15,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => OffersScreen(
                                              selectedPromoId: promoId,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Color(0xFF070F0A),
                                              width: 1.0,
                                            ),
                                          ),
                                        ),
                                        padding:
                                            const EdgeInsets.only(bottom: 2),
                                        child: Text(
                                          'VIEW ALL',
                                          style: GoogleFonts.manrope(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.5,
                                            color: const Color(0xFF070F0A),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (description.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    description,
                                    style: GoogleFonts.manrope(
                                      fontSize: 13,
                                      color: const Color(0xFF5E5E5B),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 415,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              itemCount: promoProducts.length,
                              itemBuilder: (context, index) {
                                final item = promoProducts[index];
                                final product = item['product'] as Product;
                                final discountedPriceVal =
                                    (item['discountedPrice'] as num).toDouble();
                                final originalPriceVal =
                                    item['originalPrice'] != null
                                        ? (item['originalPrice'] as num)
                                            .toDouble()
                                        : product.price;

                                final imageUrl = product.imageUrl;
                                final name = product.name;
                                final shortDesc = product
                                        .shortDescription.isNotEmpty
                                    ? product.shortDescription
                                    : '${product.volume} ${product.category}';
                                final discountLabel =
                                    item['discountLabel']?.toString() ??
                                        '-15% OFF';

                                final price =
                                    discountedPriceVal.toStringAsFixed(
                                        discountedPriceVal % 1 == 0 ? 0 : 2);
                                final originalPrice =
                                    originalPriceVal.toStringAsFixed(
                                        originalPriceVal % 1 == 0 ? 0 : 2);

                                return Padding(
                                  padding: const EdgeInsets.only(right: 16),
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ProductDetailScreen(
                                              product: product),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      width: 290,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(28),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            child: AspectRatio(
                                              aspectRatio: 0.95,
                                              child: Stack(
                                                children: [
                                                  Positioned.fill(
                                                    child: imageUrl.isNotEmpty
                                                        ? Image.network(
                                                            imageUrl,
                                                            fit: BoxFit.cover,
                                                            errorBuilder:
                                                                (_, __, ___) =>
                                                                    Container(
                                                              color: const Color(
                                                                  0xFFF2F4F0),
                                                              child: Icon(
                                                                Icons
                                                                    .spa_outlined,
                                                                color: AppTheme
                                                                    .secondary,
                                                                size: 40,
                                                              ),
                                                            ),
                                                          )
                                                        : Container(
                                                            color: const Color(
                                                                0xFFF2F4F0),
                                                            child: Icon(
                                                              Icons
                                                                  .spa_outlined,
                                                              color: AppTheme
                                                                  .secondary,
                                                              size: 40,
                                                            ),
                                                          ),
                                                  ),
                                                  Positioned(
                                                    top: 12,
                                                    left: 12,
                                                    child: Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 12,
                                                          vertical: 6),
                                                      decoration: BoxDecoration(
                                                        color: Colors.black,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(100),
                                                      ),
                                                      child: Text(
                                                        discountLabel,
                                                        style:
                                                            GoogleFonts.manrope(
                                                          color: Colors.white,
                                                          fontSize: 9,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          letterSpacing: 1.0,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  if (product
                                                          .availableStockQuantity >
                                                      0)
                                                    Positioned(
                                                      bottom: 12,
                                                      right: 12,
                                                      child: GestureDetector(
                                                        onTap: () =>
                                                            _handlePromotionProductAdd(
                                                                context,
                                                                product),
                                                        child: Container(
                                                          width: 36,
                                                          height: 36,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors.white
                                                                .withValues(
                                                                    alpha:
                                                                        0.95),
                                                            shape:
                                                                BoxShape.circle,
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: Colors
                                                                    .black
                                                                    .withValues(
                                                                        alpha:
                                                                            0.08),
                                                                blurRadius: 4,
                                                                offset:
                                                                    const Offset(
                                                                        0, 2),
                                                              ),
                                                            ],
                                                          ),
                                                          child: const Icon(
                                                            Icons.add,
                                                            size: 20,
                                                            color: Color(
                                                                0xFF070F0A),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  name,
                                                  style: GoogleFonts.ebGaramond(
                                                    fontSize: 18.5,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        const Color(0xFF070F0A),
                                                    height: 1.2,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  shortDesc,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: GoogleFonts.manrope(
                                                    fontSize: 12,
                                                    color:
                                                        const Color(0xFF7E807C),
                                                  ),
                                                ),
                                                const SizedBox(height: 10),
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .baseline,
                                                  textBaseline:
                                                      TextBaseline.alphabetic,
                                                  children: [
                                                    Text(
                                                      '\$$price',
                                                      style:
                                                          GoogleFonts.manrope(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: const Color(
                                                            0xFF070F0A),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      '\$$originalPrice',
                                                      style:
                                                          GoogleFonts.manrope(
                                                        fontSize: 12,
                                                        color: const Color(
                                                            0xFF9E9E9E),
                                                        decoration:
                                                            TextDecoration
                                                                .lineThrough,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      );
                    }).toList(),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 120),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Branch Selector Modal
  void _showBranchSelector(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Boutique Branch',
                style: GoogleFonts.ebGaramond(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Skincare routine collections vary slightly depending on branch locations.',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: AppTheme.secondary,
                ),
              ),
              const SizedBox(height: 20),
              Column(
                children: state.branches.map((branch) {
                  final isSelected = state.selectedBranch == branch;
                  return InkWell(
                    onTap: () {
                      state.setBranch(branch);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 12),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.background
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              isSelected ? AppTheme.primary : AppTheme.border,
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.storefront_outlined,
                                color: isSelected
                                    ? AppTheme.primary
                                    : AppTheme.secondary,
                                size: 18,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                branch,
                                style: GoogleFonts.manrope(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: AppTheme.primary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          if (isSelected)
                            Icon(Icons.check_circle,
                                color: AppTheme.primary, size: 16),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class BoutiqueCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> banners;
  final Function(String category) onCategorySelected;
  final Function(String query) onSearchQuery;

  const BoutiqueCarousel({
    super.key,
    required this.banners,
    required this.onCategorySelected,
    required this.onSearchQuery,
  });

  @override
  State<BoutiqueCarousel> createState() => _BoutiqueCarouselState();
}

class _BoutiqueCarouselState extends State<BoutiqueCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _autoPlayTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _startAutoPlay();
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final totalSlides = widget.banners.length;
      if (totalSlides <= 1) return;

      setState(() {
        _currentPage = (_currentPage + 1) % totalSlides;
      });

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
    _startAutoPlay();
  }

  void _handleBannerTap(Map<String, dynamic> banner, BuildContext context) {
    final title = banner['title']?.toString() ?? '';
    final appState = Provider.of<AppState>(context, listen: false);
    final targets = banner['targets'] as List?;
    if (targets == null || targets.isEmpty) {
      final targetType = banner['target_type']?.toString();
      final targetValue = banner['target_value']?.toString();

      if (targetType == 'category' &&
          targetValue != null &&
          appState.categoriesEnabled) {
        widget.onCategorySelected(targetValue);
      }
      return;
    }

    final firstTarget = targets.first as Map;
    final targetType = firstTarget['target_type']?.toString() ?? '';
    final targetId = firstTarget['target_id']?.toString() ?? '';
    final externalUrl = firstTarget['external_url']?.toString() ?? '';

    if (targetType == 'product' &&
        targetId.isNotEmpty &&
        appState.productsEnabled) {
      final productIndex =
          appState.products.indexWhere((p) => p.id.toString() == targetId);
      if (productIndex != -1) {
        final product = appState.products[productIndex];
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(product: product),
          ),
        );
      }
    } else if (targetType == 'category' &&
        targetId.isNotEmpty &&
        appState.categoriesEnabled) {
      appState.api
          .listCategories(branchId: appState.selectedBranchId)
          .then((liveCategories) {
        final categoryIndex =
            liveCategories.indexWhere((c) => c['id'].toString() == targetId);
        if (categoryIndex != -1) {
          final category = liveCategories[categoryIndex];
          widget.onCategorySelected(category['name']?.toString() ?? 'All');
        }
      }).catchError((e) {
        debugPrint("Error resolving category banner target: $e");
      });
    } else if (targetType == 'external_url' && externalUrl.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PoliciesWebViewScreen(
            url: externalUrl,
            title: title.isNotEmpty ? title : 'Boutique Offer',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalSlides = widget.banners.length;
    if (totalSlides == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      height: 420, // Tall, premium lookbook layout
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Stack(
        children: [
          // PageView slides
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: totalSlides,
            itemBuilder: (context, index) {
              final String title;
              final String buttonText;
              final String imageUrl;
              Map<String, dynamic> rawBanner = {};

              final banner = widget.banners[index];
              rawBanner = banner;
              title = banner['title']?.toString() ?? '';
              buttonText = banner['button_text']?.toString() ?? 'View';
              final rawUrl =
                  (banner['mobile_image_url'] ?? banner['image_url'] ?? '')
                      .toString();
              imageUrl = Provider.of<AppState>(context, listen: false)
                  .api
                  .resolveMediaUrl(rawUrl);

              return GestureDetector(
                onTap: () => _handleBannerTap(rawBanner, context),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => Container(
                              color: AppTheme.primary,
                              alignment: Alignment.center,
                              child: Icon(Icons.spa_outlined,
                                  color: AppTheme.accent, size: 40),
                            ),
                          )
                        : Container(color: AppTheme.primary),

                    // Breathtaking warm white bottom-up gradient blending overlay (pixel-perfect lookup)
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.95),
                            Colors.white.withValues(alpha: 0.7),
                            Colors.white.withValues(alpha: 0.1),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.35, 0.7, 1.0],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ),

                    // Text overlay contents.
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(32.0, 24.0, 32.0, 48.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Huge dark luxury serif title
                          Text(
                            title,
                            style: GoogleFonts.ebGaramond(
                              fontSize: 38,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.normal,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Black luxury capsule action button
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              buttonText.toUpperCase(),
                              style: GoogleFonts.manrope(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Horizontal dark dashes indicators at bottom center
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(totalSlides, (index) {
                final isSelected = _currentPage == index;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 36,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primary
                        : AppTheme.primary.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class StoryItemWidget extends StatelessWidget {
  final String title;
  final String imageUrl;
  final VoidCallback onTap;

  const StoryItemWidget({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 76,
          height: 76,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD4D6D0), width: 1.0),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) => Container(
                color: AppTheme.primary.withValues(alpha: 0.1),
                child:
                    Icon(Icons.spa_outlined, color: AppTheme.primary, size: 24),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class InstagramStoriesViewer extends StatefulWidget {
  final int initialStoryIndex;
  final List<Map<String, dynamic>> allStories;

  const InstagramStoriesViewer({
    super.key,
    required this.initialStoryIndex,
    required this.allStories,
  });

  @override
  State<InstagramStoriesViewer> createState() => _InstagramStoriesViewerState();
}

class _InstagramStoriesViewerState extends State<InstagramStoriesViewer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late int _currentStoryIndex;
  int _currentFrameIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentStoryIndex = widget.initialStoryIndex;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5), // 5 seconds per story frame
    );

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextFrame();
      }
    });

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _nextFrame() {
    final currentStory = widget.allStories[_currentStoryIndex];
    final frames = currentStory['frames'] as List;
    if (_currentFrameIndex < frames.length - 1) {
      setState(() {
        _currentFrameIndex++;
      });
      _animationController.reset();
      _animationController.forward();
    } else {
      // Last frame of current story: try to go to the next story in sequence!
      if (_currentStoryIndex < widget.allStories.length - 1) {
        setState(() {
          _currentStoryIndex++;
          _currentFrameIndex = 0;
        });
        _animationController.reset();
        _animationController.forward();
      } else {
        Navigator.pop(context); // Close viewer when all stories finish
      }
    }
  }

  void _previousFrame() {
    if (_currentFrameIndex > 0) {
      setState(() {
        _currentFrameIndex--;
      });
      _animationController.reset();
      _animationController.forward();
    } else {
      // First frame of current story: try to go to the previous story in sequence!
      if (_currentStoryIndex > 0) {
        setState(() {
          _currentStoryIndex--;
          final prevStory = widget.allStories[_currentStoryIndex];
          final prevFrames = prevStory['frames'] as List;
          _currentFrameIndex = prevFrames.length - 1;
        });
        _animationController.reset();
        _animationController.forward();
      } else {
        // First frame of first story: restart the frame
        _animationController.reset();
        _animationController.forward();
      }
    }
  }

  void _pause() {
    _animationController.stop();
  }

  void _resume() {
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);
    final currentStory = widget.allStories[_currentStoryIndex];
    final storyTitle = currentStory['title']?.toString() ?? '';
    final List<Map<String, dynamic>> frames =
        List<Map<String, dynamic>>.from(currentStory['frames'] as List);

    final frame = frames[_currentFrameIndex];
    final imageUrl =
        frame['media_url']?.toString() ?? frame['image_url']?.toString() ?? '';
    final caption = frame['caption']?.toString() ?? '';
    final resolvedUrl = appState.api.resolveMediaUrl(imageUrl);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPressStart: (_) => _pause(),
        onLongPressEnd: (_) => _resume(),
        onTapUp: (details) {
          final screenWidth = MediaQuery.of(context).size.width;
          final tapPositionX = details.globalPosition.dx;
          if (tapPositionX < screenWidth * 0.3) {
            _previousFrame(); // Left 30% goes back to previous frame/story
          } else {
            _nextFrame(); // Right 70% goes forward to next frame/story
          }
        },
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity < -150) {
            // Swiped left (negative velocity) -> Next frame/story
            _nextFrame();
          } else if (velocity > 150) {
            // Swiped right (positive velocity) -> Previous frame/story
            _previousFrame();
          }
        },
        onVerticalDragUpdate: (details) {
          if (details.delta.dy > 10) {
            // Close story viewer on swipe down
            Navigator.pop(context);
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image
            resolvedUrl.isNotEmpty
                ? Image.network(
                    resolvedUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(Icons.broken_image_outlined,
                            color: Colors.white54, size: 48),
                      );
                    },
                  )
                : Container(color: AppTheme.primary),

            // Top Vignette Overlay
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black54, Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.4],
                ),
              ),
            ),

            // Bottom Vignette Overlay
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black87],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.6, 1.0],
                ),
              ),
            ),

            // Main Header Content
            SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Progress Bars indicator
                    Row(
                      children: List.generate(frames.length, (index) {
                        return Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 2.0),
                            child: index < _currentFrameIndex
                                ? Container(
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  )
                                : index == _currentFrameIndex
                                    ? AnimatedBuilder(
                                        animation: _animationController,
                                        builder: (context, child) {
                                          return LinearProgressIndicator(
                                            value: _animationController.value,
                                            backgroundColor: Colors.white30,
                                            color: Colors.white,
                                            minHeight: 3,
                                            borderRadius:
                                                BorderRadius.circular(2),
                                          );
                                        },
                                      )
                                    : Container(
                                        height: 3,
                                        decoration: BoxDecoration(
                                          color: Colors.white30,
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),

                    // Title and App Logo
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.15),
                                border: Border.all(
                                    color: Colors.white30, width: 0.8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: appState.logoUrl != null &&
                                        appState.logoUrl!.isNotEmpty
                                    ? Image.network(
                                        appState.api
                                            .resolveMediaUrl(appState.logoUrl!),
                                        fit: BoxFit.cover,
                                        errorBuilder: (ctx, err, stack) =>
                                            const Icon(Icons.spa,
                                                color: Colors.white, size: 16),
                                      )
                                    : const Icon(Icons.spa,
                                        color: Colors.white, size: 16),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  storyTitle.toUpperCase(),
                                  style: GoogleFonts.manrope(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_currentFrameIndex + 1} of ${frames.length}',
                                  style: GoogleFonts.manrope(
                                    color: Colors.white70,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Caption Text Overlay centered at the bottom
            Positioned(
              bottom: 48,
              left: 24,
              right: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (caption.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 0.8),
                      ),
                      child: Text(
                        caption,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
