import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/top_toast.dart';

class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _refreshReviews();
  }

  Future<void> _refreshReviews() async {
    setState(() => _isLoading = true);
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      await Future.wait([
        appState.loadMyReviews(),
        appState.loadPublicReviews(),
      ]);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _deleteReview(
      AppState appState, Map<String, dynamic> review) async {
    final reviewId = review['id'];
    if (reviewId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Review',
          style: GoogleFonts.ebGaramond(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this review? This action cannot be undone.',
          style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.secondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.manrope(color: AppTheme.secondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: GoogleFonts.manrope(
                    color: const Color(0xFFBA1A1A),
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final parsedId = int.tryParse(reviewId.toString());
    if (parsedId == null) {
      if (mounted) {
        showTopToast(context, 'Invalid review ID');
      }
      return;
    }

    try {
      await appState.deleteReview(parsedId);
      if (mounted) {
        showTopToast(context, 'Review deleted successfully');
      }
    } catch (e) {
      if (mounted) {
        showTopToast(context, 'Failed to delete review');
      }
    }
  }

  List<Map<String, dynamic>> _combinedReviews(AppState appState) {
    final mergedByKey = <String, Map<String, dynamic>>{};

    for (final review in appState.reviews) {
      final copy = Map<String, dynamic>.from(review);
      copy['_is_mine'] = _isReviewOwnedByCurrentCustomer(appState, copy);
      mergedByKey[_reviewKey(copy)] = copy;
    }

    for (final review in appState.myReviews) {
      final copy = Map<String, dynamic>.from(review);
      copy['_is_mine'] = true;
      mergedByKey[_reviewKey(copy)] = copy;
    }

    final combined = mergedByKey.values.toList();
    combined.sort((left, right) {
      final leftDate =
          DateTime.tryParse(left['created_at']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
      final rightDate =
          DateTime.tryParse(right['created_at']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
      return rightDate.compareTo(leftDate);
    });
    return combined;
  }

  String _reviewKey(Map<String, dynamic> review) {
    final id = review['id']?.toString();
    if (id != null && id.isNotEmpty) {
      return 'id:$id';
    }
    return [
      review['customer_id']?.toString() ?? '',
      review['product_id']?.toString() ?? '',
      review['review_type']?.toString() ?? '',
      review['created_at']?.toString() ?? '',
    ].join('|');
  }

  bool _isReviewOwnedByCurrentCustomer(
    AppState appState,
    Map<String, dynamic> review,
  ) {
    if (review['_is_mine'] == true) return true;
    final customerId = appState.customerSession?.customerId;
    return customerId != null &&
        review['customer_id']?.toString() == customerId.toString();
  }

  bool _canDeleteReview(AppState appState, Map<String, dynamic> review) {
    final reviewId = review['id'];
    if (reviewId == null) return false;
    final isMine = _isReviewOwnedByCurrentCustomer(appState, review);
    final parsedId = int.tryParse(reviewId.toString());
    return isMine && parsedId != null;
  }

  Widget _buildStatusBadge(String? status, String? moderationStatus) {
    String label;
    Color bgColor;
    Color textColor;

    if (moderationStatus == 'hidden') {
      label = 'HIDDEN';
      bgColor = const Color(0xFFFFEBEE);
      textColor = const Color(0xFFC62828);
    } else if (status == 'published') {
      label = 'PUBLISHED';
      bgColor = const Color(0xFFE8F5E9);
      textColor = const Color(0xFF2E7D32);
    } else {
      label = (status ?? 'pending').toUpperCase();
      bgColor = const Color(0xFFFFF3E0);
      textColor = const Color(0xFFE65100);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final reviews = _combinedReviews(appState);
    final colors = Theme.of(context).colorScheme;
    final reviewsEnabled = appState.reviewsEnabled;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: colors.primary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'REVIEWS',
          style: GoogleFonts.ebGaramond(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            color: colors.primary,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: !reviewsEnabled
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(
                    'Reviews are unavailable for this store.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: AppTheme.secondary,
                      height: 1.5,
                    ),
                  ),
                ),
              )
            : _isLoading && reviews.isEmpty
                ? Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primary,
                      strokeWidth: 2,
                    ),
                  )
                : reviews.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color:
                                      AppTheme.primary.withValues(alpha: 0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.rate_review_outlined,
                                  color: AppTheme.secondary,
                                  size: 40,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'No Reviews Yet',
                                style: GoogleFonts.ebGaramond(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: colors.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Community reviews will appear here once customers share their experience.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  color: AppTheme.secondary,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: () {
                                  appState.goToShopTab();
                                  Navigator.pop(context);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                ),
                                child: Text(
                                  'EXPLORE SHOP',
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _refreshReviews,
                        color: AppTheme.primary,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(24),
                          itemCount: reviews.length,
                          itemBuilder: (context, index) {
                            final review = reviews[index];
                            final int rating =
                                (review['rating'] as num?)?.toInt() ?? 5;
                            final String? title = review['title']?.toString();
                            final String body =
                                review['body']?.toString() ?? '';
                            final String rawDate =
                                review['created_at']?.toString() ?? '';
                            final DateTime? parsedDate =
                                DateTime.tryParse(rawDate);
                            final String dateString = parsedDate != null
                                ? "${parsedDate.year}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')}"
                                : "Recent";

                            // Determine review type
                            final bool isStoreReview =
                                review['product_id'] == null ||
                                    review['review_type'] == 'store';
                            final String productName = isStoreReview
                                ? 'Store Review'
                                : review['product_name']?.toString() ??
                                    _getProductName(appState, review);
                            final String categoryLabel = isStoreReview
                                ? 'STORE'
                                : _getProductCategory(appState, review);
                            final bool isMine = _isReviewOwnedByCurrentCustomer(
                                appState, review);
                            final String reviewerName = isMine
                                ? 'Your review'
                                : review['reviewer_name']?.toString() ??
                                    'Customer';

                            final String? status = review['status']?.toString();
                            final String? moderationStatus =
                                review['moderation_status']?.toString();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color:
                                        AppTheme.border.withValues(alpha: 0.5),
                                    width: 0.8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isStoreReview
                                                  ? AppTheme.accent
                                                      .withValues(alpha: 0.3)
                                                  : AppTheme.primary
                                                      .withValues(alpha: 0.05),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              categoryLabel.toUpperCase(),
                                              style: GoogleFonts.manrope(
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.primary,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (isMine)
                                            _buildStatusBadge(
                                                status, moderationStatus),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            dateString,
                                            style: GoogleFonts.manrope(
                                              fontSize: 10,
                                              color: AppTheme.secondary,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (_canDeleteReview(
                                              appState, review))
                                            GestureDetector(
                                              onTap: () => _deleteReview(
                                                  appState, review),
                                              behavior: HitTestBehavior.opaque,
                                              child: const Padding(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 6, vertical: 4),
                                                child: Icon(
                                                  Icons.delete_outline,
                                                  size: 20,
                                                  color: Color(0xFFBA1A1A),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    productName,
                                    style: GoogleFonts.ebGaramond(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    reviewerName,
                                    style: GoogleFonts.manrope(
                                      fontSize: 10,
                                      color: AppTheme.secondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: List.generate(5, (starIdx) {
                                      return Icon(
                                        starIdx < rating
                                            ? Icons.star
                                            : Icons.star_border,
                                        color: const Color(0xFFD4AF37),
                                        size: 16,
                                      );
                                    }),
                                  ),
                                  const Divider(height: 20, thickness: 0.6),
                                  if (title != null && title.isNotEmpty) ...[
                                    Text(
                                      title,
                                      style: GoogleFonts.manrope(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                  ],
                                  if (body.isNotEmpty)
                                    Text(
                                      body,
                                      style: GoogleFonts.manrope(
                                        fontSize: 12,
                                        color: AppTheme.secondary,
                                        height: 1.4,
                                      ),
                                    ),
                                  // Admin reply
                                  if (review['admin_reply'] != null) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary
                                            .withValues(alpha: 0.04),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(Icons.storefront_outlined,
                                              size: 14,
                                              color: AppTheme.primary),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Store Reply',
                                                  style: GoogleFonts.manrope(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppTheme.primary,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  review['admin_reply']
                                                      .toString(),
                                                  style: GoogleFonts.manrope(
                                                    fontSize: 12,
                                                    color: AppTheme.primary,
                                                    height: 1.4,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ),
      ),
    );
  }

  String _getProductName(AppState appState, Map<String, dynamic> review) {
    if (review['product_name'] != null) {
      return review['product_name'].toString();
    }
    final prodId = review['product_id']?.toString() ?? '';
    final match = appState.products.where((p) => p.id == prodId).toList();
    return match.isNotEmpty ? match.first.name : 'Product';
  }

  String _getProductCategory(AppState appState, Map<String, dynamic> review) {
    final prodId = review['product_id']?.toString() ?? '';
    final match = appState.products.where((p) => p.id == prodId).toList();
    return match.isNotEmpty ? match.first.category : 'PRODUCT';
  }
}
