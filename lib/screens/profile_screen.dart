import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';
import 'my_reviews_screen.dart';
import 'wishlist_screen.dart';
import 'addresses_screen.dart';
import 'live_support_screen.dart';
import 'orders_list_screen.dart';
import 'notifications_screen.dart';
import 'track_order_screen.dart';
import '../widgets/top_toast.dart';
import 'policies_webview_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Widget _buildAvatarWidget(String? path, {double iconSize = 44}) {
    if (path == null || path.isEmpty) {
      return Container(
        color: AppTheme.primary.withValues(alpha: 0.1),
        alignment: Alignment.center,
        child:
            Icon(Icons.person_outline, color: AppTheme.primary, size: iconSize),
      );
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: AppTheme.primary.withValues(alpha: 0.1),
          alignment: Alignment.center,
          child: Icon(Icons.person_outline,
              color: AppTheme.primary, size: iconSize),
        ),
      );
    }
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: AppTheme.primary.withValues(alpha: 0.1),
        alignment: Alignment.center,
        child:
            Icon(Icons.person_outline, color: AppTheme.primary, size: iconSize),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final appState = Provider.of<AppState>(context, listen: false);
        if (appState.isCustomerSignedIn) {
          appState.loadCustomerData();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final colors = Theme.of(context).colorScheme;

    if (!appState.profileEnabled) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Customer profile is unavailable for this store.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: AppTheme.secondary,
                height: 1.5,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          'Skin-Cella',
          style: GoogleFonts.ebGaramond(
            fontSize: 24,
            fontWeight: FontWeight.w500,
            fontStyle: FontStyle.italic,
            color: colors.primary,
          ),
        ),
        actions: const [
          SizedBox(width: 16),
        ],
      ),
      body: appState.isCustomerSignedIn
          ? _buildSignedInContent(context, appState)
          : _buildSignedOutContent(context),
    );
  }

  Widget _buildSignedInContent(BuildContext context, AppState appState) {
    return RefreshIndicator(
      onRefresh: () async {
        await appState.loadCustomerData();
      },
      color: AppTheme.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.only(
            left: 20.0, right: 20.0, top: 24.0, bottom: 120.0),
        children: [
          // 1. Profile Header
          Center(
            child: Column(
              children: [
                Container(
                  width: 112,
                  height: 112,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.25),
                        width: 1.0),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(56),
                    child: _buildAvatarWidget(appState.profileImageUrl,
                        iconSize: 44),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  appState.profileName,
                  style: GoogleFonts.ebGaramond(
                    fontSize: 28,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primary,
                  ),
                ),
                if (appState.profilePhone.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    appState.profilePhone,
                    style: GoogleFonts.manrope(
                      fontSize: 12.5,
                      color: AppTheme.secondary.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 48),

          if (appState.ordersEnabled &&
              appState.isCustomerSignedIn &&
              appState.orders.isNotEmpty) ...[
            // 2. My Orders
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildSectionHeader('My Orders'),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const TrackOrdersListScreen()),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'View All',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            SizedBox(
              height: 180,
              child: _buildLiveOrdersHorizontal(appState),
            ),

            const SizedBox(height: 48),
          ],

          // Store Reviews Section
          if (appState.reviewsEnabled) ...[
            _buildSectionHeader('Store Reviews'),
            const SizedBox(height: 20),
            _buildStoreReviewsSection(appState),
            const SizedBox(height: 48),
          ],

          // 3. Account & Support
          _buildSectionHeader('Account & Support'),
          const SizedBox(height: 20),

          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildMenuRow(
                  icon: Icons.person_outline,
                  title: 'My Profile',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const EditProfileScreen()),
                  ),
                ),
                const Divider(
                    height: 1, thickness: 0.8, color: Color(0xFFC4C8C1)),
                _buildMenuRow(
                  icon: Icons.location_on_outlined,
                  title: 'My Addresses',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AddressesScreen()),
                  ),
                ),
                const Divider(
                    height: 1, thickness: 0.8, color: Color(0xFFC4C8C1)),
                if (appState.ordersEnabled) ...[
                  const Divider(
                      height: 1, thickness: 0.8, color: Color(0xFFC4C8C1)),
                  _buildMenuRow(
                    icon: Icons.receipt_long_outlined,
                    title: 'Order History',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const TrackOrdersListScreen()),
                    ),
                  ),
                ],
                if (appState.supportEnabled) ...[
                  const Divider(
                      height: 1, thickness: 0.8, color: Color(0xFFC4C8C1)),
                  _buildMenuRow(
                    icon: Icons.support_agent_outlined,
                    title: 'Customer Support',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const LiveSupportScreen()),
                    ),
                  ),
                ],
                _buildMenuRow(
                  icon: Icons.settings_outlined,
                  title: 'Security & Password',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ChangePasswordScreen()),
                  ),
                ),
                const Divider(
                    height: 1, thickness: 0.8, color: Color(0xFFC4C8C1)),
                _buildMenuRow(
                  icon: Icons.favorite_outline_rounded,
                  title: 'My Wishlist',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const WishlistScreen()),
                  ),
                ),
                if (appState.reviewsEnabled) ...[
                  const Divider(
                      height: 1, thickness: 0.8, color: Color(0xFFC4C8C1)),
                  _buildMenuRow(
                    icon: Icons.star_outline_rounded,
                    title: 'My Reviews',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const MyReviewsScreen()),
                    ),
                  ),
                ],
                if (appState.notificationsEnabled) ...[
                  const Divider(
                      height: 1, thickness: 0.8, color: Color(0xFFC4C8C1)),
                  _buildMenuRow(
                    icon: Icons.notifications_none_outlined,
                    title: 'Notifications',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const NotificationsScreen()),
                    ),
                  ),
                ],
                if (appState.wholesaleEnabled || appState.isWholesaleMode) ...[
                  const Divider(
                      height: 1, thickness: 0.8, color: Color(0xFFC4C8C1)),
                  _buildMenuRow(
                    icon: Icons.business_center_outlined,
                    title: appState.isWholesaleMode
                        ? 'Wholesale Mode (Active)'
                        : 'Wholesale Portal',
                    iconColor: appState.isWholesaleMode
                        ? const Color(0xFF556156)
                        : AppTheme.primary,
                    textColor: appState.isWholesaleMode
                        ? const Color(0xFF556156)
                        : AppTheme.primary,
                    onTap: () {
                      if (appState.isWholesaleMode) {
                        _showExitWholesaleDialog(context, appState);
                      } else {
                        _showWholesalePasswordDialog(context, appState);
                      }
                    },
                  ),
                ],
                const Divider(
                    height: 1, thickness: 0.8, color: Color(0xFFC4C8C1)),
                _buildMenuRow(
                  icon: Icons.policy_outlined,
                  title: 'Terms & Policies',
                  onTap: () {
                    final url = appState.api
                        .getLegalPolicyUrl('privacy-policy-and-terms-of-use');
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PoliciesWebViewScreen(
                          url: url,
                          title: 'Terms & Policies',
                        ),
                      ),
                    );
                  },
                ),
                const Divider(
                    height: 1, thickness: 0.8, color: Color(0xFFC4C8C1)),
                _buildMenuRow(
                  icon: Icons.delete_forever_outlined,
                  title: 'Delete Account',
                  iconColor: const Color(0xFFBA1A1A),
                  textColor: const Color(0xFFBA1A1A),
                  onTap: () => _showDeleteAccountDialog(context, appState),
                ),
              ],
            ),
          ),

          const SizedBox(height: 36),

          // 4. Centered Bottom Underline Sign Out
          Center(
            child: InkWell(
              onTap: () {
                appState.signOutCustomer();
                showTopToast(context, 'Signed out successfully.');
              },
              child: Container(
                padding: const EdgeInsets.only(bottom: 2),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF5E5E5B), width: 1.0),
                  ),
                ),
                child: Text(
                  'SIGN OUT',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF5E5E5B),
                    letterSpacing: 2.0,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.only(bottom: 4),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFF061008), width: 2.0),
          ),
        ),
        child: Text(
          title,
          style: GoogleFonts.ebGaramond(
            fontSize: 22,
            fontWeight: FontWeight.w500,
            color: AppTheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildStoreReviewsSection(AppState appState) {
    final storeReviews = appState.storeReviews;
    final hasUserReviewedStore = appState.isCustomerSignedIn &&
        appState.myReviews
            .any((r) => r['product_id'] == null || r['review_type'] == 'store');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (appState.isCustomerSignedIn)
          hasUserReviewedStore
              ? Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border, width: 0.8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 16, color: AppTheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'YOU\'VE RATED THIS STORE',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                )
              : SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => _showStoreReviewSheet(context, appState),
                    icon: Icon(Icons.star_outline_rounded,
                        size: 18, color: AppTheme.primary),
                    label: Text(
                      'RATE THIS STORE',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.primary, width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
        if (storeReviews.isNotEmpty) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 135,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: storeReviews.length,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final review = storeReviews[index];
                final rating = (review['rating'] as num?)?.toInt() ?? 5;
                final name = review['reviewer_name']?.toString() ?? 'Customer';
                final body = review['body']?.toString() ?? '';
                final rawDate = review['created_at']?.toString() ?? '';
                final date = DateTime.tryParse(rawDate);
                final dateStr = date != null
                    ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
                    : '';

                return Container(
                  width: MediaQuery.of(context).size.width * 0.78,
                  margin: const EdgeInsets.only(right: 12, bottom: 4),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ],
                    border: Border.all(
                        color: AppTheme.border.withValues(alpha: 0.6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: List.generate(
                                    5,
                                    (i) => Icon(
                                          i < rating
                                              ? Icons.star_rounded
                                              : Icons.star_outline_rounded,
                                          color: i < rating
                                              ? const Color(0xFFD4AF37)
                                              : AppTheme.secondary
                                                  .withValues(alpha: 0.2),
                                          size: 14,
                                        )),
                              ),
                              if (dateStr.isNotEmpty)
                                Text(
                                  dateStr,
                                  style: GoogleFonts.manrope(
                                    fontSize: 10,
                                    color: AppTheme.secondary
                                        .withValues(alpha: 0.4),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (body.isNotEmpty)
                            Text(
                              body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: AppTheme.secondary,
                                height: 1.3,
                              ),
                            ),
                        ],
                      ),
                      Text(
                        '- $name',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ] else if (!appState.isCustomerSignedIn) ...[
          const SizedBox(height: 12),
          Text(
            'Sign in to rate this store and see what others think.',
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: AppTheme.secondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _showStoreReviewSheet(
      BuildContext context, AppState appState) async {
    int selectedRating = 5;
    final bodyController = TextEditingController();
    bool isSubmitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'RATE THIS STORE',
                      style: GoogleFonts.ebGaramond(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Share your overall experience with our store',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: AppTheme.secondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'YOUR RATING',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.secondary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(5, (i) {
                        return GestureDetector(
                          onTap: () =>
                              setSheetState(() => selectedRating = i + 1),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(
                              i < selectedRating
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: i < selectedRating
                                  ? const Color(0xFFE5B556)
                                  : AppTheme.secondary.withValues(alpha: 0.3),
                              size: 36,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: bodyController,
                      style: GoogleFonts.manrope(
                          fontSize: 14, color: AppTheme.primary),
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Tell us about your experience...',
                        hintStyle: GoogleFonts.manrope(
                            fontSize: 13, color: AppTheme.secondary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: AppTheme.primary, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                setSheetState(() => isSubmitting = true);
                                try {
                                  await appState.submitReview(
                                    rating: selectedRating,
                                    body: bodyController.text.trim().isEmpty
                                        ? null
                                        : bodyController.text.trim(),
                                  );
                                  if (!mounted || !context.mounted) return;
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  showTopToast(
                                      context, 'Store review submitted!');
                                  setState(() {});
                                } catch (e) {
                                  setSheetState(() => isSubmitting = false);
                                  if (ctx.mounted) {
                                    showTopToast(
                                      ctx,
                                      e
                                          .toString()
                                          .replaceAll('Exception: ', ''),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 0,
                        ),
                        child: isSubmitting
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              )
                            : Text(
                                'SUBMIT REVIEW',
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLiveOrdersHorizontal(AppState appState) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      itemCount: appState.orders.length,
      itemBuilder: (context, index) {
        final order = appState.orders[index];
        final productName =
            order.items.isNotEmpty ? order.items.first.product.name : 'Order';
        final details =
            'Qty: ${order.items.fold(0, (sum, i) => sum + i.quantity)} • \$${order.total.toStringAsFixed(2)}';
        final isDelivered = order.status.toLowerCase() == 'delivered';

        return Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: _buildOrderCard(
            orderNumber: order.id,
            status: order.status,
            isDelivered: isDelivered,
            productName: productName,
            details: details,
            buttonText: 'Track Order',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TrackOrderScreen(orderId: order.id),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderCard({
    required String orderNumber,
    required String status,
    required bool isDelivered,
    required String productName,
    required String details,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 290,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFC4C8C1), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      orderNumber,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.secondary,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDelivered
                          ? const Color(0xFF262318)
                          : const Color(0xFFE1E3DF),
                      borderRadius: BorderRadius.circular(4),
                      border: isDelivered
                          ? null
                          : Border.all(
                              color: const Color(0xFFC4C8C1), width: 0.8),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: GoogleFonts.manrope(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: isDelivered ? Colors.white : AppTheme.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                productName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.ebGaramond(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                details,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: AppTheme.secondary,
                ),
              ),
            ],
          ),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppTheme.primary, width: 1.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: Text(
                buttonText.toUpperCase(),
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuRow({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    final finalIconColor = iconColor ?? AppTheme.primary;
    final finalTextColor = textColor ?? AppTheme.primary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: finalIconColor, size: 22),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w500,
                    color: finalTextColor,
                  ),
                ),
              ],
            ),
            Icon(Icons.chevron_right,
                color: iconColor ?? AppTheme.secondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSignedOutContent(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppTheme.accent, AppTheme.background],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                    color: AppTheme.border.withValues(alpha: 0.6), width: 1.0),
              ),
              child: Icon(
                Icons.spa_outlined,
                color: AppTheme.primary,
                size: 44,
              ),
            ),
            const SizedBox(height: 36),
            Text(
              'YOUR BESPOKE RITUAL',
              style: GoogleFonts.ebGaramond(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '“Skincare is not a routine, it is a daily botanical sacrament.”',
              textAlign: TextAlign.center,
              style: GoogleFonts.ebGaramond(
                fontSize: 14.5,
                fontStyle: FontStyle.italic,
                color: AppTheme.secondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Sign in or curate a new account to sync your skincare consultation threads, track your orders, view saved addresses, and customize daily regimens.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 12.5,
                color: AppTheme.secondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LoginScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Text(
                  'SIGN IN',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SignUpScreen()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppTheme.primary, width: 1.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Text(
                  'CREATE AN ACCOUNT',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: AppTheme.primary,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteAccountDialog(
      BuildContext context, AppState appState) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.background,
        title: Text(
          'Delete Account',
          style: GoogleFonts.ebGaramond(
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
          ),
        ),
        content: Text(
          'Are you sure you want to permanently delete your account? This action cannot be undone and you will lose all order history.',
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: AppTheme.secondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'CANCEL',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.secondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'DELETE',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFBA1A1A),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await appState.deleteCustomerAccount();
        if (context.mounted) {
          showTopToast(context, 'Account deleted successfully.');
        }
      } catch (e) {
        if (context.mounted) {
          showTopToast(context, 'Failed to delete account: $e');
        }
      }
    }
  }

  void _showWholesalePasswordDialog(BuildContext context, AppState appState) {
    final passwordController = TextEditingController();
    bool isLoading = false;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppTheme.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: AppTheme.border, width: 1),
              ),
              title: Column(
                children: [
                  Icon(Icons.business_center_outlined,
                      color: AppTheme.primary, size: 36),
                  const SizedBox(height: 12),
                  Text(
                    'WHOLESALE PORTAL',
                    style: GoogleFonts.ebGaramond(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Enter your wholesale partner passcode to browse custom catalogs, wholesale pricing, and place commercial volume orders.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 12.5,
                      color: AppTheme.secondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    cursorColor: AppTheme.primary,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintStyle: GoogleFonts.manrope(
                        color: AppTheme.secondary.withValues(alpha: 0.65),
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: AppTheme.surface.withValues(alpha: 0.92),
                      prefixIcon: Icon(Icons.lock_outline,
                          color: AppTheme.primary.withValues(alpha: 0.72),
                          size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: AppTheme.border, width: 0.8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppTheme.primary.withValues(alpha: 0.18),
                          width: 0.9,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: AppTheme.primary, width: 1.2),
                      ),
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorMessage!,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: const Color(0xFFBA1A1A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                      isLoading ? null : () => Navigator.pop(dialogContext),
                  child: Text(
                    'CANCEL',
                    style: GoogleFonts.manrope(
                      color: AppTheme.secondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    elevation: 0,
                  ),
                  onPressed: isLoading
                      ? null
                      : () async {
                          final pass = passwordController.text.trim();
                          if (pass.isEmpty) {
                            setState(() {
                              errorMessage = "Passcode is required.";
                            });
                            return;
                          }
                          setState(() {
                            isLoading = true;
                            errorMessage = null;
                          });
                          try {
                            await appState.requestWholesaleAccess(pass);
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                              showTopToast(
                                  context, 'Wholesale access granted.');
                            }
                          } catch (e) {
                            setState(() {
                              isLoading = false;
                              errorMessage = e
                                  .toString()
                                  .replaceAll('Exception:', '')
                                  .trim();
                            });
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'ACCESS',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1.0,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showExitWholesaleDialog(BuildContext context, AppState appState) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppTheme.border, width: 1),
          ),
          title: Text(
            'EXIT WHOLESALE MODE',
            style: GoogleFonts.ebGaramond(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
              letterSpacing: 1.5,
            ),
          ),
          content: Text(
            'Are you sure you want to exit wholesale mode? This will revert products to retail pricing and empty your current wholesale bag.',
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: AppTheme.secondary,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'CANCEL',
                style: GoogleFonts.manrope(
                  color: AppTheme.secondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                elevation: 0,
              ),
              onPressed: () {
                appState.leaveWholesaleMode();
                Navigator.pop(dialogContext);
                showTopToast(context, 'Reverted to retail mode.');
              },
              child: Text(
                'CONFIRM',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Support Ticket Thread Details
class TicketThreadScreen extends StatefulWidget {
  final SupportTicket ticket;

  const TicketThreadScreen({super.key, required this.ticket});

  @override
  State<TicketThreadScreen> createState() => _TicketThreadScreenState();
}

class _TicketThreadScreenState extends State<TicketThreadScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _pollingTimer;
  final List<Map<String, dynamic>> _pickedAttachments = [];
  bool _isUploadingAttachment = false;

  Future<void> _pickAttachment() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (pickedFile == null || !mounted) return;

    setState(() {
      _isUploadingAttachment = true;
    });

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final response = await appState.uploadSupportAttachment(
          pickedFile.path, pickedFile.name);

      if (!mounted) return;
      if (response.isNotEmpty) {
        setState(() {
          _pickedAttachments.add({
            'path': response['path'],
            'filename': response['filename'],
            'original_name': response['original_name'],
            'mime_type': response['mime_type'],
            'size': response['size'],
          });
        });
      }
    } catch (e) {
      if (mounted) {
        showTopToast(context, 'Failed to upload attachment: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAttachment = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _startPolling();
    // Initial fetch to populate thread messages and scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        final appState = Provider.of<AppState>(context, listen: false);
        await appState.refreshTicketDetails(widget.ticket.id);
        _scrollToBottom();
      }
    });
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      try {
        final appState = Provider.of<AppState>(context, listen: false);
        final ticketId = widget.ticket.id;
        final currentMessagesCount = appState.tickets
            .firstWhere((t) => t.id == ticketId, orElse: () => widget.ticket)
            .messages
            .length;

        await appState.refreshTicketDetails(ticketId);

        if (mounted) {
          final ticket = appState.tickets
              .firstWhere((t) => t.id == ticketId, orElse: () => widget.ticket);
          final newMessagesCount = ticket.messages.length;
          if (newMessagesCount > currentMessagesCount) {
            final newMessages = ticket.messages.sublist(currentMessagesCount);
            for (final msg in newMessages) {
              if (msg.sender.toLowerCase() != 'customer' &&
                  msg.sender.toLowerCase() != 'user') {
                showTopToast(
                  context,
                  'Advisor: ${msg.content}',
                  actionLabel: 'VIEW',
                  onActionPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TicketThreadScreen(ticket: ticket),
                      ),
                    );
                  },
                );
                appState.addLocalNotification(
                  title: 'Support Reply: ${ticket.title}',
                  message: msg.content,
                  actionType: 'support_reply',
                  actionValue: ticket.id,
                );
              }
            }
          }
        }
      } catch (_) {
        // Widget may have been disposed during the async gap; swallow the error.
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _confirmCloseTicket(
      BuildContext context, AppState appState, SupportTicket ticket) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            'CLOSE INQUIRY?',
            style: GoogleFonts.ebGaramond(
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
          content: Text(
            'Are you sure you want to close this skincare consultation? You will not be able to send any further messages.',
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: AppTheme.secondary,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'CANCEL',
                style: GoogleFonts.manrope(
                  color: AppTheme.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext); // Close dialog
                try {
                  await appState.closeTicket(ticket.id);
                  if (context.mounted) {
                    showTopToast(context, 'Ticket closed successfully.');
                    // Show the rating bottom sheet after closing!
                    _showRatingBottomSheet(context, appState);
                  }
                } catch (e) {
                  if (context.mounted) {
                    showTopToast(context, 'Failed to close ticket: $e');
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'CLOSE TICKET',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showRatingBottomSheet(
      BuildContext context, AppState appState) async {
    int selectedRating = 5;
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    bool isSubmitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppTheme.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'RATE YOUR EXPERIENCE',
                        style: GoogleFonts.ebGaramond(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your feedback will help us improve our services.',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          color: AppTheme.secondary,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Star rating
                      Text(
                        'YOUR RATING',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondary,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: List.generate(5, (i) {
                          return GestureDetector(
                            onTap: () =>
                                setSheetState(() => selectedRating = i + 1),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Icon(
                                i < selectedRating
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: i < selectedRating
                                    ? const Color(0xFFE5B556)
                                    : AppTheme.secondary.withValues(alpha: 0.3),
                                size: 32,
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 20),

                      // Title
                      TextField(
                        controller: titleController,
                        style: GoogleFonts.manrope(
                            fontSize: 14, color: AppTheme.primary),
                        decoration: InputDecoration(
                          hintText: 'Review title (optional)',
                          hintStyle: GoogleFonts.manrope(
                              fontSize: 13, color: AppTheme.secondary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: AppTheme.primary, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Body
                      TextField(
                        controller: bodyController,
                        style: GoogleFonts.manrope(
                            fontSize: 14, color: AppTheme.primary),
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText:
                              'Tell us about the customer support experience...',
                          hintStyle: GoogleFonts.manrope(
                              fontSize: 13, color: AppTheme.secondary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: AppTheme.primary, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  setSheetState(() => isSubmitting = true);
                                  try {
                                    final comment = titleController.text
                                            .trim()
                                            .isNotEmpty
                                        ? "${titleController.text.trim()}\n${bodyController.text.trim()}"
                                            .trim()
                                        : bodyController.text.trim();
                                    await appState.submitTicketFeedback(
                                      widget.ticket.id,
                                      selectedRating,
                                      comment,
                                    );
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (context.mounted) {
                                      showTopToast(context,
                                          'Thank you! Your feedback on this consultation has been submitted.');
                                    }
                                  } catch (e) {
                                    setSheetState(() => isSubmitting = false);
                                    if (ctx.mounted) {
                                      showTopToast(
                                          ctx,
                                          e
                                              .toString()
                                              .replaceAll('Exception: ', ''));
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            elevation: 0,
                          ),
                          child: isSubmitting
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                )
                              : Text(
                                  'SUBMIT REVIEW',
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final ticket = appState.tickets.firstWhere((t) => t.id == widget.ticket.id,
        orElse: () => widget.ticket);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(ticket.title.toUpperCase()),
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon:
              Icon(Icons.arrow_back_ios_new, color: AppTheme.primary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (ticket.status.toLowerCase() != 'closed')
            TextButton(
              onPressed: () => _confirmCloseTicket(context, appState, ticket),
              child: Text(
                'CLOSE',
                style: GoogleFonts.manrope(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Elegant Subheader Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                  bottom: BorderSide(
                      color: AppTheme.border.withValues(alpha: 0.5),
                      width: 0.8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.assignment_outlined,
                        size: 16, color: AppTheme.secondary),
                    const SizedBox(width: 8),
                    Text(
                      'REFERENCE: ${ticket.id}',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        color: AppTheme.secondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    ticket.category.toUpperCase(),
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.bold,
                      fontSize: 8.5,
                      color: AppTheme.accent,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Chat messages body list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              physics: const BouncingScrollPhysics(),
              itemCount: ticket.messages.length,
              itemBuilder: (context, index) {
                final message = ticket.messages[index];
                final isCustomer = message.sender == "customer";

                return Align(
                  alignment:
                      isCustomer ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75),
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: isCustomer ? AppTheme.primary : Colors.white,
                      border: isCustomer
                          ? null
                          : Border.all(
                              color: AppTheme.border.withValues(alpha: 0.6),
                              width: 0.8),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: isCustomer
                            ? const Radius.circular(16)
                            : const Radius.circular(4),
                        bottomRight: isCustomer
                            ? const Radius.circular(4)
                            : const Radius.circular(16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCustomer
                              ? appState.profileName.toUpperCase()
                              : "STORE ADVISOR",
                          style: GoogleFonts.manrope(
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            color: isCustomer
                                ? AppTheme.accent
                                : AppTheme.secondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          message.content,
                          style: GoogleFonts.manrope(
                            fontSize: 12.5,
                            color: isCustomer ? Colors.white : AppTheme.primary,
                            height: 1.5,
                          ),
                        ),
                        if (message.attachments.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          ...message.attachments.map((att) {
                            final name = att['original_name'] ?? 'Attachment';
                            final filePath = att['file_path']?.toString() ?? '';
                            final mimeType =
                                att['mime_type']?.toString().toLowerCase() ??
                                    '';
                            final isImage = mimeType.startsWith('image/') ||
                                name.endsWith('.jpg') ||
                                name.endsWith('.jpeg') ||
                                name.endsWith('.png') ||
                                name.endsWith('.gif') ||
                                name.endsWith('.webp');
                            final resolvedUrl =
                                appState.api.resolveMediaUrl(filePath);

                            if (isImage) {
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          FullScreenImageViewer(
                                        imageUrl: resolvedUrl,
                                        title: name,
                                      ),
                                    ),
                                  );
                                },
                                child: Hero(
                                  tag: resolvedUrl,
                                  child: Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    constraints: const BoxConstraints(
                                      maxWidth: 240,
                                      maxHeight: 180,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isCustomer
                                            ? Colors.white
                                                .withValues(alpha: 0.2)
                                            : AppTheme.border
                                                .withValues(alpha: 0.5),
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.08),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(11),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Image.network(
                                            resolvedUrl,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: double.infinity,
                                            loadingBuilder: (context, child,
                                                loadingProgress) {
                                              if (loadingProgress == null) {
                                                return child;
                                              }
                                              return Container(
                                                color: isCustomer
                                                    ? Colors.white
                                                        .withValues(alpha: 0.05)
                                                    : AppTheme.background,
                                                alignment: Alignment.center,
                                                child: SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: isCustomer
                                                        ? Colors.white70
                                                        : AppTheme.primary,
                                                  ),
                                                ),
                                              );
                                            },
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return Container(
                                                color: isCustomer
                                                    ? Colors.white
                                                        .withValues(alpha: 0.05)
                                                    : AppTheme.background,
                                                padding:
                                                    const EdgeInsets.all(12),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .broken_image_outlined,
                                                      size: 16,
                                                      color: isCustomer
                                                          ? Colors.white70
                                                          : AppTheme.secondary,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Flexible(
                                                      child: Text(
                                                        'Error loading image',
                                                        style:
                                                            GoogleFonts.manrope(
                                                          fontSize: 11,
                                                          color: isCustomer
                                                              ? Colors.white70
                                                              : AppTheme
                                                                  .secondary,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                          Positioned(
                                            right: 8,
                                            bottom: 8,
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.black
                                                    .withValues(alpha: 0.5),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.zoom_out_map_rounded,
                                                size: 12,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }

                            // Non-image file attachments
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PoliciesWebViewScreen(
                                      url: resolvedUrl,
                                      title: name,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(top: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isCustomer
                                      ? Colors.white.withValues(alpha: 0.15)
                                      : AppTheme.background,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isCustomer
                                        ? Colors.white.withValues(alpha: 0.1)
                                        : AppTheme.border
                                            .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.insert_drive_file_outlined,
                                      size: 16,
                                      color: isCustomer
                                          ? Colors.white
                                          : AppTheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        name,
                                        style: GoogleFonts.manrope(
                                          fontSize: 11.5,
                                          color: isCustomer
                                              ? Colors.white
                                              : AppTheme.primary,
                                          decoration: TextDecoration.underline,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.open_in_new_rounded,
                                      size: 12,
                                      color: isCustomer
                                          ? Colors.white.withValues(alpha: 0.7)
                                          : AppTheme.secondary,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Selected attachments view
          if (_pickedAttachments.isNotEmpty || _isUploadingAttachment)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                    top: BorderSide(
                        color: AppTheme.border.withValues(alpha: 0.2),
                        width: 0.8)),
              ),
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [
                  ..._pickedAttachments.map((attachment) {
                    return Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppTheme.border.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.insert_drive_file_outlined,
                              size: 12, color: AppTheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            attachment['original_name'] ?? 'File',
                            style: GoogleFonts.manrope(
                                fontSize: 10,
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _pickedAttachments.remove(attachment);
                              });
                            },
                            child: Icon(Icons.close,
                                size: 12, color: AppTheme.secondary),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (_isUploadingAttachment)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(AppTheme.primary),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // Chat input field or closed status banner at bottom
          if (ticket.status.toLowerCase() == 'closed')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                    top: BorderSide(
                        color: AppTheme.border.withValues(alpha: 0.4),
                        width: 0.8)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'THIS CONSULTATION IS CLOSED',
                      style: GoogleFonts.manrope(
                        color: AppTheme.secondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () =>
                          _showRatingBottomSheet(context, appState),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.rate_review_outlined, size: 14),
                      label: Text(
                        'RATE & REVIEW EXPERIENCE',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  )
                ],
                border: Border(
                    top: BorderSide(
                        color: AppTheme.border.withValues(alpha: 0.4),
                        width: 0.8)),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.attach_file, color: AppTheme.secondary),
                      onPressed:
                          _isUploadingAttachment ? null : _pickAttachment,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: GoogleFonts.manrope(
                            fontSize: 13, color: AppTheme.primary),
                        decoration: InputDecoration(
                          hintText: "Type your message to the store advisor...",
                          filled: true,
                          fillColor: AppTheme.background,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                                color: AppTheme.border.withValues(alpha: 0.5),
                                width: 0.8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                                color: AppTheme.border.withValues(alpha: 0.5),
                                width: 0.8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide:
                                BorderSide(color: AppTheme.primary, width: 1.0),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () async {
                        final text = _messageController.text.trim();
                        if (text.isEmpty && _pickedAttachments.isEmpty) return;
                        _messageController.clear();

                        final List<Map<String, dynamic>> attachmentsToSend =
                            List.from(_pickedAttachments);
                        setState(() {
                          _pickedAttachments.clear();
                        });

                        try {
                          await appState.sendMessageToTicket(
                            ticket.id,
                            text.isEmpty ? "Sent an attachment" : text,
                            attachments: attachmentsToSend.isNotEmpty
                                ? attachmentsToSend
                                : null,
                          );
                          if (context.mounted) {
                            showTopToast(context, 'Reply sent successfully!');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            showTopToast(
                              context,
                              'Failed to send reply. Please try again.',
                            );
                          }
                        }
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
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

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String title;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F120D), // Premium deep dark theme
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            child: IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text(
          title.toUpperCase(),
          style: GoogleFonts.manrope(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          clipBehavior: Clip.none,
          child: Hero(
            tag: imageUrl,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.accent,
                    strokeWidth: 2,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.broken_image_outlined,
                        color: Colors.white54, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load image',
                      style: GoogleFonts.manrope(
                          color: Colors.white54, fontSize: 13),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
