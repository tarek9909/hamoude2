import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'browse_collection_screen.dart';
import 'catalog_screen.dart';
import 'notifications_screen.dart';
import 'offers_screen.dart';
import 'bundles_screen.dart';
import 'bundle_detail_screen.dart';
import '../models/product.dart';
import 'product_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final PageController _pageController;
  late final ScrollController _scrollController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final colors = Theme.of(context).colorScheme;

    final stories = appState.stories.map(_storyFromPayload).toList();

    // Resolve dynamic promotional products list
    final List<Map<String, dynamic>> promoProducts = [];
    if (appState.promotionsEnabled && appState.promotions.isNotEmpty) {
      for (final promo in appState.promotions) {
        final title = promo['name']?.toString() ?? promo['title']?.toString() ?? '';
        final discountType = promo['discount_type']?.toString() ?? 'percentage';
        final discountVal = (promo['discount_value'] as num?)?.toDouble() ?? 20.0;
        final discountLabel = promo['discount_label']?.toString() ?? 
            promo['badge']?.toString() ?? 
            (discountType == 'percentage' ? '-${discountVal.toStringAsFixed(0)}% OFF' : 'SPECIAL OFFER');

        final rawItems = promo['product_links'] as List? ?? [];
        final matchingProducts = <Product>[];
        if (rawItems.isNotEmpty) {
          for (final link in rawItems) {
            final prodId = link['product_id']?.toString();
            try {
              final p = appState.products.firstWhere((prod) => prod.id == prodId);
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

        for (final product in matchingProducts) {
          // Calculate discounted price
          double discPrice = product.price;
          final promoPriceStr = promo['price']?.toString();
          if (matchingProducts.length == 1 && promoPriceStr != null && double.tryParse(promoPriceStr) != null) {
            discPrice = double.parse(promoPriceStr);
          } else {
            if (discountType == 'percentage') {
              discPrice = product.price * (1 - discountVal / 100);
            } else {
              discPrice = (product.price - discountVal).clamp(0.0, double.infinity);
            }
          }

          // Check if product is already added (e.g. from another promotion)
          final exists = promoProducts.any((item) => item['product'].id == product.id);
          if (!exists) {
            promoProducts.add({
              'product': product,
              'discountedPrice': discPrice,
              'discountLabel': discountLabel,
              'promotion': promo,
            });
          }
        }
      }
    }
    // Curated brand mock list mapping real database items
    final displayBrands = appState.brands.map((b) => {
          'name': b['name']?.toString() ?? 'Brand',
          'image': b['logo_url']?.toString() ?? b['image_url']?.toString() ?? 'https://images.unsplash.com/photo-1594035910387-fea47794261f?q=80&w=300&auto=format&fit=crop',
        }).toList();

    // Curated category mock list mapping real database items
    final displayCategories = appState.categories.where((c) => c != 'All').map((c) {
          String img = 'https://images.unsplash.com/photo-1608248597279-f99d160bfcbc?q=80&w=400&auto=format&fit=crop';
          if (c.toLowerCase().contains('cleanser')) {
            img = 'https://images.unsplash.com/photo-1556228578-0d85b1a4d571?q=80&w=400&auto=format&fit=crop';
          } else if (c.toLowerCase().contains('serum')) {
            img = 'https://images.unsplash.com/photo-1620916566398-39f1143ab7be?q=80&w=400&auto=format&fit=crop';
          } else if (c.toLowerCase().contains('toner')) {
            img = 'https://images.unsplash.com/photo-1601049541289-9b1b7bbbfe19?q=80&w=400&auto=format&fit=crop';
          }
          return {
            'name': c,
            'image': img,
          };
        }).toList();

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Boutique Minimal Header matching premium brand
            SliverToBoxAdapter(
              child: Builder(
                builder: (scaffoldContext) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: SizedBox(
                      height: 56,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            left: 12,
                            child: GestureDetector(
                              onTap: () => _showBranchSelector(context, appState),
                              behavior: HitTestBehavior.opaque,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    appState.appName.toUpperCase(),
                                    style: GoogleFonts.ebGaramond(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 4.0,
                                      color: colors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.location_on_outlined,
                                        size: 10,
                                        color: AppTheme.secondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        appState.selectedBranch.toUpperCase(),
                                        style: GoogleFonts.manrope(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.secondary,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Icon(
                                        Icons.keyboard_arrow_down,
                                        size: 12,
                                        color: AppTheme.secondary,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            right: 12,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (appState.isFeatureEnabled('notifications') &&
                                    appState.isFeatureEnabled('admin_marketing_campaigns'))
                                  Stack(
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.notifications_none_outlined,
                                            color: colors.primary, size: 22),
                                        onPressed: () =>
                                            _showNotifications(context, appState),
                                        tooltip: 'Notifications',
                                      ),
                                      if (appState.notifications.any((n) => !n['isRead']))
                                        Positioned(
                                          top: 10,
                                          right: 10,
                                          child: Container(
                                            width: 6,
                                            height: 6,
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
                          ),
                        ],
                      ),
                    ),
                  );
                }
              ),
            ),

            // Swipeable PageView Hero Carousel
            if (appState.marketingContentEnabled && appState.banners.isNotEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 420,
                  child: Stack(
                    children: [
                      PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() {
                            _currentPage = index;
                          });
                        },
                        itemCount: appState.banners.length,
                        itemBuilder: (context, index) {
                          final banner = appState.banners[index];
                          final imageUrl = banner['mobile_image_url']?.toString() ??
                              banner['image_url']?.toString() ??
                              "https://images.unsplash.com/photo-1616683693504-3ea7e9ad6fec?q=80&w=800&auto=format&fit=crop";

                          // Premium title processing
                          final rawTitle = banner['title']?.toString() ?? 'Rooted in Nature';
                          String title = rawTitle;

                          if (rawTitle.contains(':')) {
                            final parts = rawTitle.split(':');
                            title = parts.sublist(1).join(':').trim();
                          } else if (rawTitle.contains('|')) {
                            final parts = rawTitle.split('|');
                            title = parts.sublist(1).join('|').trim();
                          }

                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              // Full-bleed Background image
                              Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Image.network(
                                  "https://images.unsplash.com/photo-1616683693504-3ea7e9ad6fec?q=80&w=800&auto=format&fit=crop",
                                  fit: BoxFit.cover,
                                ),
                              ),
                              // Subtle elegant gradient overlay for perfect readability
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0.0),
                                      Colors.white.withValues(alpha: 0.4),
                                      Colors.white.withValues(alpha: 0.85),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    stops: const [0.0, 0.45, 1.0],
                                  ),
                                ),
                              ),
                              // Content aligned bottom-left
                              Positioned.fill(
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                      left: 28, right: 28, top: 40, bottom: 44),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Spacer(),
                                      // Main Serif Title wrapping beautifully
                                      Text(
                                        title,
                                        style: GoogleFonts.ebGaramond(
                                          fontSize: 38,
                                          height: 1.15,
                                          color: const Color(0xFF1E2620),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      // Premium Pill Button "SHOP COLLECTION"
                                      ElevatedButton(
                                        onPressed: () {
                                          _scrollController.animateTo(
                                            620, // Scroll down past hero/stories to show boutique filters
                                            duration: const Duration(milliseconds: 600),
                                            curve: Curves.easeInOutCubic,
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF070F0A),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 28, vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(100),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: Text(
                                          'SHOP COLLECTION',
                                          style: GoogleFonts.manrope(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      // Linear horizontal indicators centered at the bottom
                      if (appState.banners.length > 1)
                        Positioned(
                          bottom: 24,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(appState.banners.length, (idx) {
                                final isActive = idx == _currentPage;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  width: 48,
                                  height: isActive ? 3.0 : 1.2,
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? const Color(0xFF070F0A)
                                        : const Color(0xFFC2C7C4),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

            if (appState.marketingContentEnabled && stories.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.only(top: 42, bottom: 20), // Premium generous spacing from the carousel
                  height: 144, // Expanded container to prevent overflow with larger cards and labels
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: stories.length,
                    itemBuilder: (context, index) {
                      final story = stories[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0), // Premium wider spacing
                        child: GestureDetector(
                          onTap: () => _showStoryDialog(context, story),
                          child: SizedBox(
                            width: 96,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Nested luxury rounded square frame with elegant spacing
                                Container(
                                  width: 96,
                                  height: 96,
                                  padding: const EdgeInsets.all(5.0),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(0xFFD2D7D4), // Soft silver-grey border
                                      width: 1.0,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(15), // Parallel concentric corner radius (20 - 5)
                                    child: Image.network(
                                      story['image']!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: AppTheme.border.withValues(alpha: 0.35),
                                        child: Icon(Icons.spa_outlined, color: AppTheme.secondary),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Capitalized, spaced, premium sans-serif typography
                                Text(
                                  story['title']!.toUpperCase(),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.manrope(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0A1C2A), // Premium dark tone
                                    letterSpacing: 2.0,
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
              ),

            // Weekly Deals Promotions Section matching mockup exactly
            // Curated Bundles – Full-width PageView Slider (1 per view)
            if (appState.bundlesEnabled && appState.bundles.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Curated Bundles',
                            style: GoogleFonts.ebGaramond(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF070F0A),
                              letterSpacing: 0.5,
                            ),
                          ),
                          InkWell(
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
                                  fontSize: 10,
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
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 500,
                  child: PageView.builder(
                    controller: PageController(viewportFraction: 0.88),
                    physics: const BouncingScrollPhysics(),
                    itemCount: appState.bundles.length,
                    itemBuilder: (context, index) {
                      final bundle = appState.bundles[index];
                      final imageUrl = bundle['image_url']?.toString() ??
                          bundle['media_url']?.toString() ??
                          "https://images.unsplash.com/photo-1608248597279-f99d160bfcbc?q=80&w=600&auto=format&fit=crop";
                      
                      final tag = bundle['subtitle']?.toString() ??
                          bundle['tag']?.toString() ??
                          (index % 2 == 0 ? "SIGNATURE COLLECTION" : "SEASONAL RECOVERY");
                      
                      final title = bundle['name']?.toString() ??
                          bundle['title']?.toString() ??
                          "The Glow Essentials";
                      
                      final description = bundle['description']?.toString() ??
                          bundle['summary']?.toString() ??
                          "Our signature 3-step ritual meticulously crafted to deliver radiant, deeply hydrated skin through Alpine botanicals.";
                      
                      final rawItems = bundle['items'] as List? ?? [];
                      final itemsList = rawItems.whereType<Map<String, dynamic>>().toList();
                      
                      double computedOriginalPrice = 0.0;
                      for (final item in itemsList) {
                        final prodId = item['product_id']?.toString() ?? '';
                        final qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
                        Product? p;
                        try {
                          p = appState.products.firstWhere((entry) => entry.id == prodId);
                        } catch (_) {}
                        final itemPrice = p?.price ?? (item['unit_price_snapshot'] as num?)?.toDouble() ?? 0.0;
                        computedOriginalPrice += itemPrice * qty;
                      }

                      final bundlePriceVal = (bundle['bundle_price'] as num?)?.toDouble() ?? 
                          double.tryParse(bundle['price']?.toString() ?? '') ?? 120.0;
                      
                      final price = bundlePriceVal.toStringAsFixed(bundlePriceVal % 1 == 0 ? 0 : 2);
                      final originalPrice = computedOriginalPrice > 0 
                          ? computedOriginalPrice.toStringAsFixed(computedOriginalPrice % 1 == 0 ? 0 : 2)
                          : "148";

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16, top: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F4F0),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Bundle Image
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: AspectRatio(
                                  aspectRatio: 1.0,
                                  child: Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: Colors.white,
                                      child: Icon(
                                        Icons.spa_outlined,
                                        color: AppTheme.secondary.withValues(alpha: 0.5),
                                        size: 48,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              // Tag
                              Text(
                                tag.toUpperCase(),
                                style: GoogleFonts.manrope(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF7E807C),
                                  letterSpacing: 2.0,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Title
                              Text(
                                title,
                                style: GoogleFonts.ebGaramond(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF070F0A),
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Description
                              Text(
                                description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.manrope(
                                  fontSize: 12.5,
                                  color: const Color(0xFF4A554A),
                                  height: 1.5,
                                ),
                              ),
                              const Spacer(),
                              // Price Row + Action
                              Row(
                                children: [
                                  Text(
                                    '\$$price',
                                    style: GoogleFonts.manrope(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF070F0A),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '\$$originalPrice',
                                    style: GoogleFonts.manrope(
                                      fontSize: 13,
                                      color: const Color(0xFF9E9E9E),
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                  const Spacer(),
                                  InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => BundleDetailScreen(bundle: bundle),
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
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'EXPLORE',
                                            style: GoogleFonts.manrope(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.5,
                                              color: const Color(0xFF070F0A),
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
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],

            // Shop by Brand Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Shop by Brand',
                      style: GoogleFonts.ebGaramond(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF070F0A),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BrowseCollectionScreen(
                              mode: BrowseMode.brands,
                            ),
                          ),
                        );
                      },
                      child: Text(
                        'View All',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF5E5E5B),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 150,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: displayBrands.length,
                  itemBuilder: (context, index) {
                    final brand = displayBrands[index];
                    final brandName = brand['name'] ?? 'Brand';
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ShopCatalogScreen(
                                brandFilter: brandName,
                              ),
                            ),
                          );
                        },
                        child: Column(
                          children: [
                            Container(
                              width: 104,
                              height: 104,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEBECE8),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  brand['image'] ?? '',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.white,
                                    child: const Icon(
                                      Icons.business,
                                      color: Color(0xFF7E807C),
                                      size: 32,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              brandName.toUpperCase(),
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
            ),

            // Shop by Category Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 24, right: 24, top: 28, bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Shop by Category',
                      style: GoogleFonts.ebGaramond(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF070F0A),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BrowseCollectionScreen(
                              mode: BrowseMode.categories,
                            ),
                          ),
                        );
                      },
                      child: Text(
                        'View All',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF5E5E5B),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 216,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: displayCategories.length,
                  itemBuilder: (context, index) {
                    final cat = displayCategories[index];
                    final catName = cat['name'] ?? '';
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ShopCatalogScreen(
                                categoryFilter: catName,
                              ),
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: SizedBox(
                                width: 130,
                                height: 160,
                                child: Image.network(
                                  cat['image'] ?? '',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: const Color(0xFFEBECE8),
                                    child: const Icon(
                                      Icons.spa_outlined,
                                      color: Color(0xFF7E807C),
                                      size: 32,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.only(left: 4.0),
                              child: Text(
                                catName,
                                style: GoogleFonts.ebGaramond(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
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
            ),

            // Weekly Deals Promotions – Full-width PageView Slider displaying promotional products
            if (appState.promotionsEnabled && promoProducts.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(left: 24, right: 24, top: 32, bottom: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Weekly Deals',
                              style: GoogleFonts.ebGaramond(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF070F0A),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const OffersScreen(),
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
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                  color: const Color(0xFF070F0A),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Exclusive botanical essentials for your seasonal ritual.',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          color: const Color(0xFF5E5E5B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 450,
                  child: PageView.builder(
                    controller: PageController(viewportFraction: 0.85),
                    physics: const BouncingScrollPhysics(),
                    itemCount: promoProducts.length,
                    itemBuilder: (context, index) {
                      final item = promoProducts[index];
                      final product = item['product'] as Product;
                      final discPrice = item['discountedPrice'] as double;
                      final originalPriceVal = product.price;
                      final discount = item['discountLabel'] as String;

                      final price = discPrice.toStringAsFixed(discPrice % 1 == 0 ? 0 : 2);
                      final originalPrice = originalPriceVal.toStringAsFixed(originalPriceVal % 1 == 0 ? 0 : 2);

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProductDetailScreen(product: product),
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Full-width Image with Badge (equally square, no padding)
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                                  child: AspectRatio(
                                    aspectRatio: 1.0,
                                    child: Container(
                                      color: const Color(0xFFF2F4F0),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          product.imageUrl.isNotEmpty
                                              ? Image.network(
                                                  product.imageUrl,
                                                  fit: BoxFit.cover,
                                                  width: double.infinity,
                                                  height: double.infinity,
                                                  errorBuilder: (_, __, ___) => const Center(
                                                    child: Icon(
                                                      Icons.spa_outlined,
                                                      color: Color(0xFF7E807C),
                                                      size: 36,
                                                    ),
                                                  ),
                                                )
                                              : const Center(
                                                  child: Icon(
                                                    Icons.spa_outlined,
                                                    color: Color(0xFF7E807C),
                                                    size: 36,
                                                  ),
                                                ),
                                          // Discount Badge
                                          Positioned(
                                            top: 12,
                                            left: 12,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF070F0A),
                                                borderRadius: BorderRadius.circular(100),
                                              ),
                                              child: Text(
                                                discount.toUpperCase(),
                                                style: GoogleFonts.manrope(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                  letterSpacing: 1.0,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                // Product Details (Title, Subtitle, Price)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.ebGaramond(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF070F0A),
                                          height: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        product.subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.manrope(
                                          fontSize: 12,
                                          color: const Color(0xFF7E807C),
                                        ),
                                      ),
                                       const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Text(
                                            '\$$price',
                                            style: GoogleFonts.manrope(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF070F0A),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '\$$originalPrice',
                                            style: GoogleFonts.manrope(
                                              fontSize: 12,
                                              color: const Color(0xFF9E9E9E),
                                              decoration: TextDecoration.lineThrough,
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
              ),
            ],

            const SliverToBoxAdapter(
              child: SizedBox(height: 120),
            ),
          ],
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

  // Daily Wellness Story Instagram-style Fullscreen Viewer
  void _showStoryDialog(BuildContext context, Map<String, String> story) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, _, __) => FullscreenStoryViewer(story: story),
        transitionsBuilder: (context, animation, _, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;
          final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  // Navigate to Notifications Screen
  void _showNotifications(BuildContext context, AppState state) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NotificationsScreen(),
      ),
    );
  }
}

Map<String, String> _storyFromPayload(Map<String, dynamic> story) {
  final items = (story['items'] as List?)?.whereType<Map<String, dynamic>>();
  final firstItem = items?.isNotEmpty == true ? items!.first : null;
  return {
    'title': story['title']?.toString() ?? 'Story',
    'image': firstItem?['media_url']?.toString() ??
        'https://images.unsplash.com/photo-1556228578-0d85b1a4d571?q=80&w=150&auto=format&fit=crop',
    'tip': firstItem?['caption']?.toString() ??
        story['description']?.toString() ??
        'Explore the latest from this store.',
  };
}




// Premium Full-Screen Instagram-style Story Viewer
class FullscreenStoryViewer extends StatefulWidget {
  final Map<String, String> story;
  const FullscreenStoryViewer({super.key, required this.story});

  @override
  State<FullscreenStoryViewer> createState() => _FullscreenStoryViewerState();
}

class _FullscreenStoryViewerState extends State<FullscreenStoryViewer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    // 6-second timer duration for luxurious slow reading
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );

    _animationController.addListener(() {
      setState(() {});
    });

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted && !_isDismissed) {
          Navigator.of(context).pop();
        }
      }
    });

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) {
      return const SizedBox.shrink();
    }
    return Dismissible(
      key: const Key('fullscreen_story_viewer'),
      direction: DismissDirection.down, // Swipe down to close
      onDismissed: (_) {
        setState(() {
          _isDismissed = true;
        });
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          // Hold to pause, release to resume
          onTapDown: (_) {
            _animationController.stop(canceled: false);
          },
          onTapUp: (_) {
            _animationController.forward();
          },
          onTapCancel: () {
            _animationController.forward();
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Edge-to-Edge Full Screen Image
              Image.network(
                widget.story['image']!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF0F1E36),
                  child: const Center(
                    child: Icon(
                      Icons.spa_outlined,
                      color: Colors.white24,
                      size: 64,
                    ),
                  ),
                ),
              ),
              // Double Vignette Gradient Overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.65),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.85),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.3, 1.0],
                    ),
                  ),
                ),
              ),
              // Content Layers
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Linear Timer Slider Bar
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(1.5),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: _animationController.value,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(1.5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Top Navigation Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.spa_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.story['title']!.toUpperCase(),
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 24),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Bottom Wellness Tips Glassmorphic Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 0.8,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "DAILY WELLNESS RITUAL",
                              style: GoogleFonts.manrope(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accent.withValues(alpha: 0.95),
                                letterSpacing: 2.5,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              widget.story['tip']!,
                              style: GoogleFonts.manrope(
                                fontSize: 14.5,
                                color: Colors.white,
                                height: 1.6,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
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
