import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../services/storefront_api.dart';
import '../widgets/top_toast.dart';
import 'track_order_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _deliveryType = "Delivery"; // "Delivery" or "Pickup"
  // Display label of a real saved CustomerAddress (see addressForLabel).
  // Null when the customer has no saved address yet.
  String? _selectedAddress;

  // Pickup Scheduling state
  DateTime? _selectedPickupDate;
  String? _selectedPickupTimeSlot;

  // Guards against double submit while the checkout request is in flight.
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    _selectedAddress = appState.savedAddresses.isNotEmpty
        ? appState.savedAddresses.first
        : null;

    // Default pickup date: the first upcoming day that still has slots.
    _initializeDefaultPickupDate(appState);
  }

  void _initializeDefaultPickupDate(AppState appState) {
    final activeBranch = _getActiveBranch(appState);
    final now = DateTime.now();
    _selectedPickupDate = null;
    _selectedPickupTimeSlot = null;
    for (int i = 0; i < 7; i++) {
      final date = now.add(Duration(days: i));
      if (_isBranchClosedOnDate(activeBranch, date)) continue;
      final day = DateTime(date.year, date.month, date.day);
      final slots = _generateTimeSlotsForDate(activeBranch, day);
      if (slots.isEmpty) continue;
      _selectedPickupDate = day;
      _selectedPickupTimeSlot = slots.first;
      break;
    }
  }

  bool _fulfillmentSyncScheduled = false;

  /// Keeps AppState's quote fulfillment in step with what this screen shows,
  /// so the cart quote is priced for delivery or pickup correctly.
  void _syncFulfillmentType(AppState appState, String effectiveDeliveryType) {
    final wanted = effectiveDeliveryType.toLowerCase();
    if (appState.fulfillmentType == wanted || _fulfillmentSyncScheduled) {
      return;
    }
    _fulfillmentSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fulfillmentSyncScheduled = false;
      if (!mounted) return;
      appState.setFulfillmentType(wanted);
    });
  }

  static String _errorMessage(Object error) {
    if (error is StorefrontApiException) return error.message;
    if (error is StateError) return error.message;
    return error.toString().replaceAll('Exception: ', '');
  }

  StorefrontBranch _getActiveBranch(AppState appState) {
    try {
      return appState.branchRecords.firstWhere(
        (b) => b.name == appState.selectedBranch,
      );
    } catch (_) {
      return StorefrontBranch(
        id: appState.selectedBranchId,
        name: appState.selectedBranch,
        hours: const [],
      );
    }
  }

  bool _isBranchClosedOnDate(StorefrontBranch branch, DateTime date) {
    // Map DateTime weekday (Monday = 1, Sunday = 7) to MySQL store_hours day_of_week
    // MySQL standard store_hours table: Sunday = 0, Monday = 1, ..., Saturday = 6
    final int dayOfWeek = date.weekday == 7 ? 0 : date.weekday;

    if (branch.hours.isEmpty) {
      return false; // Default open
    }

    try {
      final hourConfig =
          branch.hours.firstWhere((h) => h.dayOfWeek == dayOfWeek);
      return hourConfig.isClosed;
    } catch (_) {
      return false; // Default open if config missing for day
    }
  }

  List<String> _generateTimeSlotsForDate(
      StorefrontBranch branch, DateTime date) {
    final int dayOfWeek = date.weekday == 7 ? 0 : date.weekday;

    // Default hours: 9:00 AM - 10:00 PM if configs are empty
    TimeOfDay open = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay close = const TimeOfDay(hour: 22, minute: 0);

    if (branch.hours.isNotEmpty) {
      try {
        final hourConfig =
            branch.hours.firstWhere((h) => h.dayOfWeek == dayOfWeek);
        if (hourConfig.isClosed) return const [];

        final parsedOpen = _parseTimeString(hourConfig.openTime);
        final parsedClose = _parseTimeString(hourConfig.closeTime);
        if (parsedOpen != null) open = parsedOpen;
        if (parsedClose != null) close = parsedClose;
      } catch (_) {}
    }

    final List<String> slots = [];
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    var current = open;
    while (_isBefore(current, close)) {
      if (isToday) {
        // Today: slots must be at least 30 minutes in the future
        final slotDateTime = DateTime(
            date.year, date.month, date.day, current.hour, current.minute);
        if (slotDateTime.isAfter(now.add(const Duration(minutes: 30)))) {
          slots.add(_formatTimeOfDay(current));
        }
      } else {
        slots.add(_formatTimeOfDay(current));
      }

      // Increment by 30 mins
      var nextMin = current.minute + 30;
      var nextHour = current.hour;
      if (nextMin >= 60) {
        nextMin -= 60;
        nextHour += 1;
      }
      current = TimeOfDay(hour: nextHour, minute: nextMin);
    }

    return slots;
  }

  TimeOfDay? _parseTimeString(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;
    final parts = timeStr.split(':');
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour != null && minute != null) {
        return TimeOfDay(hour: hour, minute: minute);
      }
    }
    return null;
  }

  bool _isBefore(TimeOfDay t1, TimeOfDay t2) {
    if (t1.hour < t2.hour) return true;
    if (t1.hour == t2.hour && t1.minute < t2.minute) return true;
    return false;
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    final minuteStr = time.minute.toString().padLeft(2, '0');
    return '${hour.toString().padLeft(2, '0')}:$minuteStr $period';
  }

  String _getWeekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return "Mon";
      case DateTime.tuesday:
        return "Tue";
      case DateTime.wednesday:
        return "Wed";
      case DateTime.thursday:
        return "Thu";
      case DateTime.friday:
        return "Fri";
      case DateTime.saturday:
        return "Sat";
      case DateTime.sunday:
        return "Sun";
      default:
        return "";
    }
  }

  String _getMonthLabel(int month) {
    switch (month) {
      case 1:
        return "Jan";
      case 2:
        return "Feb";
      case 3:
        return "Mar";
      case 4:
        return "Apr";
      case 5:
        return "May";
      case 6:
        return "Jun";
      case 7:
        return "Jul";
      case 8:
        return "Aug";
      case 9:
        return "Sep";
      case 10:
        return "Oct";
      case 11:
        return "Nov";
      case 12:
        return "Dec";
      default:
        return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final colors = Theme.of(context).colorScheme;
    if (!appState.checkoutEnabled) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(backgroundColor: AppTheme.background, elevation: 0),
        body: Center(
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
        ),
      );
    }
    // Pre-orders are collected in store once the stock arrives: no delivery
    // and no pickup slot until the store confirms it is ready.
    final isPreorderCart = appState.cartHasPreorder;
    // Delivery needs the feature, a non-preorder cart and at least one zone.
    final deliveryUnavailableNoZones = appState.deliveryEnabled &&
        !isPreorderCart &&
        !appState.deliveryAvailable;
    final deliveryEnabled = appState.deliveryEnabled &&
        !isPreorderCart &&
        appState.deliveryAvailable;
    final effectiveDeliveryType = deliveryEnabled ? _deliveryType : "Pickup";
    final isDelivery = effectiveDeliveryType == "Delivery";

    // Totals: prefer the backend quote (promotions, bundles, tax), fall back
    // to local math while no quote is available.
    final quote = appState.cartQuote;
    final orderSubtotal = quote?.subtotal ?? appState.cartSubtotal;
    final orderDiscount = quote?.discount ?? appState.cartDiscount;
    final orderTax = quote?.tax ?? 0.0;
    // Both are quote-aware in AppState (quote priced for fulfillmentType).
    final orderDeliveryFee = appState.cartDeliveryFeeFor(effectiveDeliveryType);
    final orderTotal = appState.cartTotalFor(effectiveDeliveryType);
    _syncFulfillmentType(appState, effectiveDeliveryType);
    final appliedLabels = (quote?.appliedLabels ?? const <String>[])
        .where((label) => label.trim().isNotEmpty)
        .toList();

    final addressOptions = appState.savedAddresses;
    if (_selectedAddress != null &&
        !addressOptions.contains(_selectedAddress)) {
      _selectedAddress =
          addressOptions.isNotEmpty ? addressOptions.first : null;
    } else if (_selectedAddress == null && addressOptions.isNotEmpty) {
      _selectedAddress = addressOptions.first;
    }
    final selectedCustomerAddress = _selectedAddress == null
        ? null
        : appState.addressForLabel(_selectedAddress!);
    final missingDeliveryAddress =
        isDelivery && selectedCustomerAddress == null;

    final deliveryZones = appState.deliveryZones;
    final selectedZoneId = appState.selectedDeliveryZoneId;

    final activeBranch = _getActiveBranch(appState);

    return Scaffold(
      backgroundColor: AppTheme.background, // Premium light sage backdrop
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          'CHECKOUT',
          style: GoogleFonts.ebGaramond(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 3.0,
            color: colors.primary,
          ),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Order Summary Brief Header Card with Cart Preview
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.border, width: 0.8),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ORDER SUMMARY',
                                  style: GoogleFonts.manrope(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                    color: AppTheme.secondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${appState.cart.length} item${appState.cart.length == 1 ? "" : "s"}',
                                  style: GoogleFonts.ebGaramond(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FontStyle.italic,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '\$${orderSubtotal.toStringAsFixed(2)}',
                              style: GoogleFonts.manrope(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(
                            height: 1,
                            thickness: 0.6,
                            color: Color(0xFFE5E7E2)),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 72,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: appState.cart.length,
                            itemBuilder: (context, index) {
                              final item = appState.cart[index];
                              final showRetailPrice = appState
                                      .isWholesaleMode &&
                                  item.product.retailPrice != null &&
                                  item.product.retailPrice! > item.unitPrice;
                              final itemName = item.displayName;
                              return Container(
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFBFBF9),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: AppTheme.border
                                          .withValues(alpha: 0.5),
                                      width: 0.6),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        appState.api
                                            .resolveMediaUrl(item.imageUrl),
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 44,
                                          height: 44,
                                          color: const Color(0xFFF2F4F0),
                                          child: Icon(Icons.spa_outlined,
                                              color: AppTheme.primary,
                                              size: 18),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          itemName.length > 20
                                              ? '${itemName.substring(0, 18)}...'
                                              : itemName,
                                          style: GoogleFonts.manrope(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        RichText(
                                          text: TextSpan(
                                            style: GoogleFonts.manrope(
                                              fontSize: 10,
                                              color: AppTheme.secondary,
                                            ),
                                            children: [
                                              TextSpan(
                                                text:
                                                    'Qty: ${item.quantity} - ',
                                              ),
                                              if (showRetailPrice)
                                                TextSpan(
                                                  text:
                                                      '\$${item.product.retailPrice!.toStringAsFixed(2)} ',
                                                  style: const TextStyle(
                                                    decoration: TextDecoration
                                                        .lineThrough,
                                                  ),
                                                ),
                                              TextSpan(
                                                text:
                                                    '\$${item.unitPrice.toStringAsFixed(2)}',
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 2. Fulfillment Selector (Custom Premium Buttons with Icons)
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: deliveryEnabled
                              ? () => setState(() => _deliveryType = "Delivery")
                              : null,
                          child: Container(
                            height: 54,
                            decoration: BoxDecoration(
                              color: effectiveDeliveryType == "Delivery"
                                  ? AppTheme.primary
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: effectiveDeliveryType == "Delivery"
                                    ? AppTheme.primary
                                    : AppTheme.border,
                                width: 0.8,
                              ),
                              boxShadow: [
                                if (effectiveDeliveryType == "Delivery")
                                  BoxShadow(
                                    color: AppTheme.primary
                                        .withValues(alpha: 0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.local_shipping_outlined,
                                  size: 18,
                                  color: effectiveDeliveryType == "Delivery"
                                      ? Colors.white
                                      : AppTheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Courier Delivery",
                                  style: GoogleFonts.manrope(
                                    color: effectiveDeliveryType == "Delivery"
                                        ? Colors.white
                                        : AppTheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _deliveryType = "Pickup"),
                          child: Container(
                            height: 54,
                            decoration: BoxDecoration(
                              color: effectiveDeliveryType == "Pickup"
                                  ? AppTheme.primary
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: effectiveDeliveryType == "Pickup"
                                    ? AppTheme.primary
                                    : AppTheme.border,
                                width: 0.8,
                              ),
                              boxShadow: [
                                if (effectiveDeliveryType == "Pickup")
                                  BoxShadow(
                                    color: AppTheme.primary
                                        .withValues(alpha: 0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.storefront_outlined,
                                  size: 18,
                                  color: effectiveDeliveryType == "Pickup"
                                      ? Colors.white
                                      : AppTheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Pickup",
                                  style: GoogleFonts.manrope(
                                    color: effectiveDeliveryType == "Pickup"
                                        ? Colors.white
                                        : AppTheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (deliveryUnavailableNoZones) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        'Delivery is not available from this branch yet. Please choose pickup.',
                        style: GoogleFonts.manrope(
                            fontSize: 11,
                            color: AppTheme.secondary,
                            fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // 3. Dynamic Section: Address Selector (Courier) vs Branch hours picker (Bespoke Pickup)
                  if (effectiveDeliveryType == "Delivery") ...[
                    if (deliveryZones.length > 1) ...[
                      Text(
                        'DELIVERY ZONE',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondary,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: deliveryZones.map<Widget>((zone) {
                          final zoneId = zone.id;
                          final isSelected = zoneId == selectedZoneId;
                          return GestureDetector(
                            onTap: () => appState.selectDeliveryZone(zoneId),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primary
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.primary
                                      : const Color(0xFFE5E7E2),
                                  width: isSelected ? 1.2 : 0.8,
                                ),
                              ),
                              child: Text(
                                zone.name.isNotEmpty
                                    ? zone.name
                                    : 'Zone ${zone.id}',
                                style: GoogleFonts.manrope(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : AppTheme.primary,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'DELIVERY DESTINATION',
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.secondary,
                            letterSpacing: 1.5,
                          ),
                        ),
                        GestureDetector(
                          onTap: () =>
                              _showAddressBottomSheet(context, appState),
                          child: Text(
                            '+ ADD NEW',
                            style: GoogleFonts.manrope(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                              letterSpacing: 1.0,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => addressOptions.isEmpty
                          ? _showAddressBottomSheet(context, appState)
                          : _showAddressSelectorBottomSheet(context, appState),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: AppTheme.border, width: 0.8),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.location_on_outlined,
                                    color: AppTheme.primary, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'SHIPPING ADDRESS',
                                        style: GoogleFonts.manrope(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.0,
                                          color: AppTheme.secondary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        selectedCustomerAddress?.displayLabel ??
                                            'Add a delivery address to continue',
                                        style: GoogleFonts.manrope(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: selectedCustomerAddress == null
                                              ? const Color(0xFFBA1A1A)
                                              : AppTheme.primary,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(Icons.keyboard_arrow_right,
                                    color: AppTheme.secondary, size: 20),
                              ],
                            ),
                            if (selectedCustomerAddress != null) ...[
                              const SizedBox(height: 12),
                              const Divider(
                                  height: 1,
                                  thickness: 0.6,
                                  color: Color(0xFFE5E7E2)),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () {
                                      final address =
                                          _selectedCustomerAddress(appState);
                                      if (address != null) {
                                        _showAddressBottomSheet(
                                            context, appState,
                                            existing: address);
                                      }
                                    },
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 14, color: Color(0xFF5E5E5B)),
                                    label: Text(
                                      'EDIT',
                                      style: GoogleFonts.manrope(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF5E5E5B)),
                                    ),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  TextButton.icon(
                                    onPressed: () async {
                                      final address =
                                          _selectedCustomerAddress(appState);
                                      if (address == null) return;
                                      try {
                                        await appState
                                            .deleteCustomerAddress(address);
                                      } catch (e) {
                                        if (context.mounted) {
                                          showTopToast(context,
                                              'Could not delete address: ${_errorMessage(e)}');
                                        }
                                        return;
                                      }
                                      if (mounted) {
                                        setState(() {
                                          _selectedAddress = appState
                                                  .savedAddresses.isNotEmpty
                                              ? appState.savedAddresses.first
                                              : null;
                                        });
                                      }
                                    },
                                    icon: const Icon(Icons.delete_outline,
                                        size: 14, color: Color(0xFFBA1A1A)),
                                    label: Text(
                                      'DELETE',
                                      style: GoogleFonts.manrope(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFFBA1A1A)),
                                    ),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (!appState.isCustomerSignedIn) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          'Sign in on the Profile tab to save addresses in your account.',
                          style: GoogleFonts.manrope(
                              fontSize: 11,
                              color: AppTheme.secondary,
                              fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ] else ...[
                    // Pickup Branch Location Details
                    Text(
                      'PICKUP STORE LOCATION',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.secondary,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.border, width: 0.8),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF2F4F0),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.storefront_outlined,
                                color: AppTheme.primary, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activeBranch.name,
                                  style: GoogleFonts.ebGaramond(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  activeBranch.address ??
                                      'At Selected Boutique Branch Location',
                                  style: GoogleFonts.manrope(
                                    fontSize: 12.5,
                                    color: AppTheme.secondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Divider(
                                    height: 1,
                                    thickness: 0.6,
                                    color: Color(0xFFE5E7E2)),
                                const SizedBox(height: 8),
                                Text(
                                  'Operating Hours:',
                                  style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: AppTheme.primary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ..._buildWorkingHoursDisplay(activeBranch),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Pickup Scheduler Component (in-stock orders only)
                    if (isPreorderCart)
                      _buildPreorderPickupNotice(appState)
                    else ...[
                      Text(
                        'CHOOSE PICKUP SCHEDULE',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondary,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: AppTheme.border, width: 0.8),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Date',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 72,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                itemCount: 7,
                                itemBuilder: (ctx, idx) {
                                  final now = DateTime.now();
                                  final date = now.add(Duration(days: idx));
                                  final formattedDate =
                                      DateTime(date.year, date.month, date.day);
                                  final isClosed =
                                      _isBranchClosedOnDate(activeBranch, date);
                                  final isSelected =
                                      _selectedPickupDate == formattedDate;

                                  return Padding(
                                    padding: const EdgeInsets.only(
                                        right: 10, bottom: 4),
                                    child: GestureDetector(
                                      onTap: isClosed
                                          ? null
                                          : () {
                                              setState(() {
                                                _selectedPickupDate =
                                                    formattedDate;
                                                final slots =
                                                    _generateTimeSlotsForDate(
                                                        activeBranch,
                                                        formattedDate);
                                                if (slots.isNotEmpty) {
                                                  _selectedPickupTimeSlot =
                                                      slots.first;
                                                } else {
                                                  _selectedPickupTimeSlot =
                                                      null;
                                                }
                                              });
                                            },
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        width: 64,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? AppTheme.primary
                                              : isClosed
                                                  ? const Color(0xFFF3F4F1)
                                                  : Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                            color: isSelected
                                                ? AppTheme.primary
                                                : const Color(0xFFE5E7E2),
                                            width: isSelected ? 1.5 : 0.8,
                                          ),
                                          boxShadow: [
                                            if (isSelected)
                                              BoxShadow(
                                                color: AppTheme.primary
                                                    .withValues(alpha: 0.15),
                                                blurRadius: 6,
                                                offset: const Offset(0, 3),
                                              ),
                                          ],
                                        ),
                                        child: Opacity(
                                          opacity: isClosed ? 0.4 : 1.0,
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                _getWeekdayLabel(date.weekday),
                                                style: GoogleFonts.manrope(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: isSelected
                                                      ? Colors.white70
                                                      : AppTheme.secondary,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                date.day.toString(),
                                                style: GoogleFonts.manrope(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
                                                  color: isSelected
                                                      ? Colors.white
                                                      : AppTheme.primary,
                                                ),
                                              ),
                                              const SizedBox(height: 1),
                                              Text(
                                                isClosed
                                                    ? 'Closed'
                                                    : _getMonthLabel(
                                                        date.month),
                                                style: GoogleFonts.manrope(
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.bold,
                                                  color: isSelected
                                                      ? Colors.white70
                                                      : AppTheme.secondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Select Time Window',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_selectedPickupDate == null)
                              Center(
                                child: Text(
                                  'Select a pickup date first.',
                                  style: GoogleFonts.manrope(
                                      fontSize: 12, color: AppTheme.secondary),
                                ),
                              )
                            else ...[
                              (() {
                                final slots = _generateTimeSlotsForDate(
                                    activeBranch, _selectedPickupDate!);
                                if (slots.isEmpty) {
                                  return Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFAFBF9),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'No pickup slots available for this day.',
                                      style: GoogleFonts.manrope(
                                          fontSize: 12,
                                          color: AppTheme.secondary,
                                          fontStyle: FontStyle.italic),
                                    ),
                                  );
                                }
                                return Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: slots.map((slot) {
                                    final isSelected =
                                        _selectedPickupTimeSlot == slot;
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedPickupTimeSlot = slot;
                                        });
                                      },
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 150),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? AppTheme.primary
                                              : Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isSelected
                                                ? AppTheme.primary
                                                : const Color(0xFFE5E7E2),
                                            width: isSelected ? 1.2 : 0.8,
                                          ),
                                        ),
                                        child: Text(
                                          slot,
                                          style: GoogleFonts.manrope(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected
                                                ? Colors.white
                                                : AppTheme.primary,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                );
                              }()),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],

                  const SizedBox(height: 32),

                  // 4. Payment Details Card
                  Text(
                    'PAYMENT METHOD',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.border, width: 0.8),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF2F4F0),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.payments_outlined,
                              color: AppTheme.primary, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isPreorderCart
                                    ? 'Pay on Collection'
                                    : 'Cash on Delivery / Collection',
                                style: GoogleFonts.manrope(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppTheme.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isPreorderCart
                                    ? 'Nothing to pay now. Pay in store when you collect your pre-order.'
                                    : effectiveDeliveryType == "Delivery"
                                        ? 'Pay in cash directly to our courier agent upon shipment arrival.'
                                        : 'Pay in cash when you arrive at our boutique to collect your orders.',
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  color: AppTheme.secondary,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // 5. Billing Receipt Breakdown Card
                  Text(
                    'BILLING RECEIPT',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.border, width: 0.8),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildBillingRow(
                          label: 'Subtotal',
                          value: '\$${orderSubtotal.toStringAsFixed(2)}',
                        ),
                        const SizedBox(height: 12),
                        if (orderDiscount > 0) ...[
                          _buildBillingRow(
                            label: appliedLabels.isEmpty
                                ? 'Discount'
                                : 'Discount (${appliedLabels.join(', ')})',
                            value: '-\$${orderDiscount.toStringAsFixed(2)}',
                            isHighlight: true,
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (effectiveDeliveryType == "Delivery") ...[
                          _buildBillingRow(
                            label: 'Courier Delivery Fee',
                            value: orderDeliveryFee > 0
                                ? '\$${orderDeliveryFee.toStringAsFixed(2)}'
                                : 'Complimentary',
                            isHighlight: orderDeliveryFee == 0,
                          ),
                        ] else ...[
                          _buildBillingRow(
                            label: 'Collection & Prep',
                            value: 'Complimentary',
                            isHighlight: true,
                          ),
                        ],
                        if (orderTax > 0) ...[
                          const SizedBox(height: 12),
                          _buildBillingRow(
                            label: 'Tax',
                            value: '\$${orderTax.toStringAsFixed(2)}',
                          ),
                        ],
                        const SizedBox(height: 16),
                        const Divider(
                            height: 1,
                            thickness: 0.6,
                            color: Color(0xFFE5E7E2)),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'TOTAL DUE',
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                if (appState.isQuotingCart) ...[
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: AppTheme.secondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              '\$${orderTotal.toStringAsFixed(2)}',
                              style: GoogleFonts.ebGaramond(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),

                  // 6. Complete checkout button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(27),
                        ),
                      ),
                      onPressed: (appState.isCheckingOut ||
                              _isSubmitting ||
                              appState.cart.isEmpty ||
                              missingDeliveryAddress ||
                              (effectiveDeliveryType == "Pickup" &&
                                  !isPreorderCart &&
                                  _selectedPickupTimeSlot == null))
                          ? null
                          : () async {
                              if (_isSubmitting) return;
                              if (appState.cart.isEmpty) {
                                showTopToast(context, 'Your bag is empty.');
                                return;
                              }
                              final deliveryAddress = isDelivery &&
                                      _selectedAddress != null
                                  ? appState.addressForLabel(_selectedAddress!)
                                  : null;
                              if (isDelivery && deliveryAddress == null) {
                                showTopToast(context,
                                    'Please add a delivery address first.');
                                return;
                              }
                              final dest = isDelivery
                                  ? deliveryAddress!.displayLabel
                                  : appState.selectedBranch;

                              String? formattedPickupTime;
                              if (effectiveDeliveryType == "Pickup" &&
                                  !isPreorderCart) {
                                // Re-validate the slot: it may have passed
                                // while the screen was open.
                                final date = _selectedPickupDate;
                                final slot = _selectedPickupTimeSlot;
                                final stillValid = date != null &&
                                    slot != null &&
                                    _generateTimeSlotsForDate(
                                            _getActiveBranch(appState), date)
                                        .contains(slot);
                                if (!stillValid) {
                                  setState(() =>
                                      _initializeDefaultPickupDate(appState));
                                  showTopToast(context,
                                      'That pickup time is no longer available. Please choose another slot.');
                                  return;
                                }
                                final dateStr =
                                    "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
                                formattedPickupTime = "$dateStr at $slot";
                              }

                              setState(() => _isSubmitting = true);
                              try {
                                // checkout() returns the order or throws.
                                final order = await appState.checkout(
                                  effectiveDeliveryType,
                                  dest,
                                  pickupTime: formattedPickupTime,
                                );
                                if (!context.mounted) return;
                                _showSuccessDialog(context, order.id);
                              } catch (e) {
                                if (!context.mounted) return;
                                showTopToast(context, _errorMessage(e));
                              } finally {
                                if (mounted) {
                                  setState(() => _isSubmitting = false);
                                }
                              }
                            },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (appState.isCheckingOut || _isSubmitting) ...[
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ] else ...[
                            const Icon(Icons.lock_outline,
                                size: 16, color: Colors.white),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            appState.isCheckingOut || _isSubmitting
                                ? 'PLACING ORDER...'
                                : 'PLACE ORDER - \$${orderTotal.toStringAsFixed(2)}',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
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

  Widget _buildPreorderPickupNotice(AppState appState) {
    final etaText = appState.cart
        .map((item) => item.product.preorderEtaText)
        .firstWhere((text) => text.isNotEmpty, orElse: () => '');
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.schedule_outlined, color: AppTheme.primary, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PRE-ORDER · STORE PICKUP ONLY',
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: AppTheme.secondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "We'll notify you as soon as your items arrive and are ready to collect${etaText.isNotEmpty ? ' ($etaText)' : ''}. No delivery or pickup slot is needed now.",
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    color: AppTheme.primary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillingRow({
    required String label,
    required String value,
    bool isHighlight = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12.5,
            color: AppTheme.secondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 12.5,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
            color: isHighlight ? const Color(0xFF556156) : AppTheme.primary,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildWorkingHoursDisplay(StorefrontBranch branch) {
    if (branch.hours.isEmpty) {
      return [
        Text(
          'Mon - Sun: 9:00 AM - 10:00 PM',
          style: GoogleFonts.manrope(fontSize: 12, color: AppTheme.secondary),
        )
      ];
    }

    final List<Widget> list = [];
    for (final hour in branch.hours) {
      final String dayName;
      switch (hour.dayOfWeek) {
        case 0:
          dayName = "Sunday";
          break;
        case 1:
          dayName = "Monday";
          break;
        case 2:
          dayName = "Tuesday";
          break;
        case 3:
          dayName = "Wednesday";
          break;
        case 4:
          dayName = "Thursday";
          break;
        case 5:
          dayName = "Friday";
          break;
        case 6:
          dayName = "Saturday";
          break;
        default:
          dayName = "Day";
      }

      final String timeLabel = hour.isClosed
          ? 'Closed'
          : '${_formatRawTime(hour.openTime)} - ${_formatRawTime(hour.closeTime)}';

      list.add(
        Padding(
          padding: const EdgeInsets.only(top: 2.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dayName,
                style: GoogleFonts.manrope(
                    fontSize: 11.5, color: AppTheme.secondary),
              ),
              Text(
                timeLabel,
                style: GoogleFonts.manrope(
                  fontSize: 11.5,
                  fontWeight:
                      hour.isClosed ? FontWeight.normal : FontWeight.w600,
                  color: hour.isClosed
                      ? const Color(0xFFBA1A1A)
                      : AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return list;
  }

  String _formatRawTime(String? timeStr) {
    final parsed = _parseTimeString(timeStr);
    if (parsed == null) return timeStr ?? '';
    return _formatTimeOfDay(parsed);
  }

  CustomerAddress? _selectedCustomerAddress(AppState appState) {
    for (final address in appState.customerAddresses) {
      if (address.displayLabel == _selectedAddress) {
        return address;
      }
    }
    return null;
  }

  void _showAddressBottomSheet(
    BuildContext context,
    AppState appState, {
    CustomerAddress? existing,
  }) {
    final labelController =
        TextEditingController(text: existing?.label ?? 'Home');
    final nameController =
        TextEditingController(text: existing?.recipientName ?? '');
    final phoneController =
        TextEditingController(text: existing?.recipientPhone ?? '');
    final line1Controller =
        TextEditingController(text: existing?.addressLine1 ?? '');
    final line2Controller =
        TextEditingController(text: existing?.addressLine2 ?? '');
    final cityController = TextEditingController(text: existing?.city ?? '');
    final stateController = TextEditingController(text: existing?.state ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        // Local flag scoped to this sheet instance — never touches the parent
        // widget's state, so there's no risk of calling setState on a disposed
        // element after Navigator.pop removes the sheet from the tree.
        bool submitting = false;
        String? formError;

        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24,
                  MediaQuery.of(sheetContext).viewInsets.bottom + 24),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.border.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          color: AppTheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          existing == null ? 'NEW ADDRESS' : 'EDIT ADDRESS',
                          style: GoogleFonts.ebGaramond(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppTheme.primary,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _addressField(
                        labelController, 'Address Label (e.g. Home, Office)'),
                    _addressField(nameController, 'Recipient Name'),
                    _addressField(phoneController, 'Recipient Phone',
                        keyboardType: TextInputType.phone),
                    _addressField(
                        line1Controller, 'Address Line 1 (Street, Building)'),
                    _addressField(line2Controller,
                        'Address Line 2 (Apartment, Suite - Optional)'),
                    _addressField(cityController, 'City'),
                    _addressField(stateController, 'State / Region'),
                    if (formError != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        formError!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFBA1A1A),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: submitting
                                ? null
                                : () => Navigator.pop(sheetContext),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                  color: AppTheme.primary, width: 1.0),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Text(
                              'CANCEL',
                              style: GoogleFonts.manrope(
                                color: AppTheme.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: submitting
                                ? null
                                : () async {
                                    final validationError =
                                        _validateAddressForm(
                                      name: nameController.text,
                                      phone: phoneController.text,
                                      line1: line1Controller.text,
                                      city: cityController.text,
                                    );
                                    if (validationError != null) {
                                      setSheetState(
                                          () => formError = validationError);
                                      return;
                                    }
                                    setSheetState(() {
                                      formError = null;
                                      submitting = true;
                                    });
                                    try {
                                      final address = CustomerAddress(
                                        id: existing?.id ?? '',
                                        label:
                                            labelController.text.trim().isEmpty
                                                ? 'Address'
                                                : labelController.text.trim(),
                                        recipientName:
                                            nameController.text.trim(),
                                        recipientPhone:
                                            phoneController.text.trim(),
                                        addressLine1:
                                            line1Controller.text.trim(),
                                        addressLine2:
                                            line2Controller.text.trim(),
                                        city: cityController.text.trim(),
                                        state: stateController.text.trim(),
                                        postalCode: '',
                                        country: '',
                                      );
                                      // Close the bottom sheet FIRST, before the
                                      // async save that triggers notifyListeners.
                                      // This avoids the rebuild-while-sheet-is-open
                                      // assertion crash.
                                      if (sheetContext.mounted) {
                                        Navigator.pop(sheetContext);
                                      }
                                      final CustomerAddress saved =
                                          await appState
                                              .saveCustomerAddress(address);
                                      if (!mounted) return;
                                      setState(() {
                                        _selectedAddress = saved.displayLabel;
                                      });
                                    } catch (e) {
                                      if (context.mounted) {
                                        showTopToast(
                                          context,
                                          'Failed to save address: ${_errorMessage(e)}',
                                        );
                                      }
                                    }
                                    // NOTE: no finally block calling setSheetState —
                                    // the sheet is already dismissed at this point and
                                    // calling setState on its disposed element is what
                                    // caused the _dependents.isEmpty assertion crash.
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              elevation: 0,
                            ),
                            child: submitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : Text(
                                    existing == null ? 'SAVE' : 'UPDATE',
                                    style: GoogleFonts.manrope(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
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
        );
      },
    ).whenComplete(() {
      Future.delayed(const Duration(seconds: 1), () {
        labelController.dispose();
        nameController.dispose();
        phoneController.dispose();
        line1Controller.dispose();
        line2Controller.dispose();
        cityController.dispose();
        stateController.dispose();
      });
    });
  }

  void _showAddressSelectorBottomSheet(
      BuildContext context, AppState appState) {
    final addressOptions = appState.savedAddresses;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'SELECT DELIVERY ADDRESS',
                textAlign: TextAlign.center,
                style: GoogleFonts.ebGaramond(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppTheme.primary,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 20),
              if (addressOptions.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'You have no saved addresses yet.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                        fontSize: 12, color: AppTheme.secondary),
                  ),
                ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: addressOptions.length,
                  itemBuilder: (ctx, idx) {
                    final addr = addressOptions[idx];
                    final isSelected = _selectedAddress == addr;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedAddress = addr);
                        Navigator.pop(sheetContext);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primary.withValues(alpha: 0.04)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primary
                                : AppTheme.border.withValues(alpha: 0.5),
                            width: isSelected ? 1.5 : 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.radio_button_off_outlined,
                              color: isSelected
                                  ? AppTheme.primary
                                  : AppTheme.secondary,
                              size: 20,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                addr,
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: AppTheme.primary,
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
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _showAddressBottomSheet(context, appState);
                },
                icon: const Icon(Icons.add_location_alt_outlined,
                    size: 18, color: Colors.white),
                label: Text(
                  'ADD NEW ADDRESS',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String? _validateAddressForm({
    required String name,
    required String phone,
    required String line1,
    required String city,
  }) {
    if (name.trim().isEmpty) return 'Recipient name is required.';
    final trimmedPhone = phone.trim();
    if (trimmedPhone.isEmpty) return 'Recipient phone is required.';
    final digitCount = trimmedPhone.replaceAll(RegExp(r'\D'), '').length;
    if (!RegExp(r'^\+?[0-9 ()\-]+$').hasMatch(trimmedPhone) ||
        digitCount < 7 ||
        digitCount > 15) {
      return 'Enter a valid phone number.';
    }
    if (line1.trim().isEmpty) return 'Address line 1 is required.';
    if (city.trim().isEmpty) return 'City is required.';
    return null;
  }

  Widget _addressField(
    TextEditingController controller,
    String hint, {
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: GoogleFonts.manrope(fontSize: 12.5, color: AppTheme.primary),
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: AppTheme.background.withValues(alpha: 0.5),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: AppTheme.border.withValues(alpha: 0.6), width: 0.8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.primary, width: 1.0),
          ),
          hintStyle: GoogleFonts.manrope(
            fontSize: 12,
            color: AppTheme.secondary.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, String orderId) {
    // Capture the navigator now: the checkout route is replaced below, so its
    // context must not be used after the dialog closes.
    final navigator = Navigator.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: AppTheme.background,
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.success,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Order Placed!',
                  style: GoogleFonts.ebGaramond(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your order has been submitted. Our team is preparing it according to your schedules.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: AppTheme.secondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx); // Close dialog
                      // Replace the checkout screen with order tracking.
                      navigator.pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => TrackOrderScreen(orderId: orderId),
                        ),
                      );
                    },
                    child: const Text('TRACK ORDER'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
