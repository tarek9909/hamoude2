import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'track_order_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _deliveryType = "Delivery"; // "Delivery" or "Pickup"
  late String _selectedAddress;

  final _nameController = TextEditingController();
  final _cardController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  bool _addressSubmitting = false;

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    _selectedAddress = appState.savedAddresses.isNotEmpty
        ? appState.savedAddresses.first
        : appState.selectedBranch;
    _nameController.text = appState.profileName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cardController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final deliveryEnabled = appState.deliveryEnabled;
    final effectiveDeliveryType = deliveryEnabled ? _deliveryType : "Pickup";
    final addressOptions = appState.savedAddresses.isNotEmpty
        ? appState.savedAddresses
        : [appState.selectedBranch];
    if (!addressOptions.contains(_selectedAddress)) {
      _selectedAddress = addressOptions.first;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('CHECKOUT'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          // Order Summary Brief
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border, width: 0.8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order total (${appState.cart.length} formulas)',
                  style: GoogleFonts.manrope(
                      fontSize: 13, color: AppTheme.secondary),
                ),
                Text(
                  '\$${appState.cartTotal.toStringAsFixed(2)}',
                  style: GoogleFonts.manrope(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Fulfillment Choice Toggle
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text("Home Delivery")),
                  selected: effectiveDeliveryType == "Delivery",
                  onSelected: deliveryEnabled
                      ? (_) => setState(() => _deliveryType = "Delivery")
                      : null,
                  backgroundColor: Colors.white,
                  selectedColor: AppTheme.primary,
                  labelStyle: GoogleFonts.manrope(
                    color: effectiveDeliveryType == "Delivery"
                        ? Colors.white
                        : AppTheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                        color: effectiveDeliveryType == "Delivery"
                            ? Colors.transparent
                            : AppTheme.border,
                        width: 0.8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text("Boutique Pickup")),
                  selected: effectiveDeliveryType == "Pickup",
                  onSelected: (_) => setState(() => _deliveryType = "Pickup"),
                  backgroundColor: Colors.white,
                  selectedColor: AppTheme.primary,
                  labelStyle: GoogleFonts.manrope(
                    color: effectiveDeliveryType == "Pickup"
                        ? Colors.white
                        : AppTheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                        color: effectiveDeliveryType == "Pickup"
                            ? Colors.transparent
                            : AppTheme.border,
                        width: 0.8),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Dynamic Address Selector vs Branch location panel
          if (effectiveDeliveryType == "Delivery") ...[
            Text(
              'DELIVERY ADDRESS',
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppTheme.secondary,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border, width: 0.8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedAddress,
                  isExpanded: true,
                  items: addressOptions.map((addr) {
                    return DropdownMenuItem(
                      value: addr,
                      child: Text(
                        addr,
                        style: GoogleFonts.manrope(
                            fontSize: 13, color: AppTheme.primary),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedAddress = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _showAddressDialog(context, appState),
                  icon: const Icon(Icons.add_location_alt_outlined, size: 16),
                  label: const Text('ADD'),
                ),
                const SizedBox(width: 8),
                if (appState.customerAddresses.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      final address = _selectedCustomerAddress(appState);
                      if (address != null) {
                        _showAddressDialog(context, appState,
                            existing: address);
                      }
                    },
                    icon:
                        const Icon(Icons.edit_location_alt_outlined, size: 16),
                    label: const Text('EDIT'),
                  ),
                const Spacer(),
                if (appState.customerAddresses.isNotEmpty)
                  TextButton.icon(
                    onPressed: () async {
                      final address = _selectedCustomerAddress(appState);
                      if (address == null) return;
                      await appState.deleteCustomerAddress(address);
                      if (mounted) {
                        setState(() {
                          _selectedAddress = appState.savedAddresses.isNotEmpty
                              ? appState.savedAddresses.first
                              : appState.selectedBranch;
                        });
                      }
                    },
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('DELETE'),
                  ),
              ],
            ),
            if (!appState.isCustomerSignedIn)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Sign in from Profile to sync addresses across devices.',
                  style: GoogleFonts.manrope(
                      fontSize: 11, color: AppTheme.secondary),
                ),
              ),
          ] else ...[
            Text(
              'PICKUP STORE LOCATION',
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppTheme.secondary,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border, width: 0.8),
              ),
              child: Row(
                children: [
                  Icon(Icons.storefront_outlined, color: AppTheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appState.selectedBranch,
                          style: GoogleFonts.manrope(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Apothecary hours: 9:00 AM - 10:00 PM',
                          style: GoogleFonts.manrope(
                              fontSize: 11, color: AppTheme.secondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),

          // Payment details matching checkout.html
          Text(
            'SECURE PAYMENT INFORMATION',
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppTheme.secondary,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _nameController,
            style: GoogleFonts.manrope(fontSize: 13),
            decoration: const InputDecoration(
              hintText: "Cardholder Name",
              prefixIcon: Icon(Icons.person_outline, size: 18),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _cardController,
            keyboardType: TextInputType.number,
            style: GoogleFonts.manrope(fontSize: 13),
            decoration: const InputDecoration(
              hintText: "Card Number (16 Digits)",
              prefixIcon: Icon(Icons.credit_card, size: 18),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _expiryController,
                  style: GoogleFonts.manrope(fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: "MM/YY",
                    prefixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _cvvController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  style: GoogleFonts.manrope(fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: "CVV Code",
                    prefixIcon: Icon(Icons.lock_outline, size: 18),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 48),

          // Complete Order checkout button
          ElevatedButton(
            onPressed: appState.isCheckingOut
                ? null
                : () async {
                    if (_cardController.text.trim().isEmpty ||
                        _cvvController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Please complete secure payment credentials.')),
                      );
                      return;
                    }
                    final dest = effectiveDeliveryType == "Delivery"
                        ? _selectedAddress
                        : appState.selectedBranch;
                    try {
                      final order =
                          await appState.checkout(effectiveDeliveryType, dest);
                      if (!context.mounted) return;
                      _showSuccessDialog(context, order?.id ?? "SC-8921");
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(e.toString()),
                          backgroundColor: AppTheme.primary,
                        ),
                      );
                    }
                  },
            child: Text(appState.isCheckingOut
                ? 'PLACING ORDER...'
                : 'PLACE ORDER - \$${appState.cartTotal.toStringAsFixed(2)}'),
          ),
        ],
      ),
    );
  }

  CustomerAddress? _selectedCustomerAddress(AppState appState) {
    for (final address in appState.customerAddresses) {
      if (address.displayLabel == _selectedAddress) {
        return address;
      }
    }
    return null;
  }

  void _showAddressDialog(
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
    final postalController =
        TextEditingController(text: existing?.postalCode ?? '');
    final countryController =
        TextEditingController(text: existing?.country ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text(
                existing == null ? 'Add Delivery Address' : 'Edit Address',
                style: GoogleFonts.ebGaramond(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _addressField(labelController, 'Label'),
                    _addressField(nameController, 'Recipient name'),
                    _addressField(phoneController, 'Recipient phone',
                        keyboardType: TextInputType.phone),
                    _addressField(line1Controller, 'Address line 1'),
                    _addressField(line2Controller, 'Address line 2'),
                    _addressField(cityController, 'City'),
                    _addressField(stateController, 'State'),
                    _addressField(postalController, 'Postal code'),
                    _addressField(countryController, 'Country'),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _addressSubmitting
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: _addressSubmitting
                      ? null
                      : () async {
                          if (line1Controller.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Address line 1 is required.')),
                            );
                            return;
                          }
                          setDialogState(() => _addressSubmitting = true);
                          try {
                            final address = CustomerAddress(
                              id: existing?.id ?? '',
                              label: labelController.text.trim().isEmpty
                                  ? 'Address'
                                  : labelController.text.trim(),
                              recipientName: nameController.text.trim(),
                              recipientPhone: phoneController.text.trim(),
                              addressLine1: line1Controller.text.trim(),
                              addressLine2: line2Controller.text.trim(),
                              city: cityController.text.trim(),
                              state: stateController.text.trim(),
                              postalCode: postalController.text.trim(),
                              country: countryController.text.trim(),
                            );
                            await appState.saveCustomerAddress(address);
                            if (!mounted) return;
                            setState(() {
                              _selectedAddress = appState.savedAddresses.last;
                            });
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          } finally {
                            if (dialogContext.mounted) {
                              setDialogState(() => _addressSubmitting = false);
                            }
                          }
                        },
                  child: Text(existing == null ? 'SAVE' : 'UPDATE'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      labelController.dispose();
      nameController.dispose();
      phoneController.dispose();
      line1Controller.dispose();
      line2Controller.dispose();
      cityController.dispose();
      stateController.dispose();
      postalController.dispose();
      countryController.dispose();
      _addressSubmitting = false;
    });
  }

  Widget _addressField(
    TextEditingController controller,
    String hint, {
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: GoogleFonts.manrope(fontSize: 12),
        decoration: InputDecoration(
          hintText: hint,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, String orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  'Order Confirmed!',
                  style: GoogleFonts.ebGaramond(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your order has been placed successfully. The store is preparing it with care.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: AppTheme.secondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(180, 44)),
                  onPressed: () {
                    Navigator.pop(ctx); // Close dialog
                    Navigator.pop(context); // Pop checkout screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            TrackOrderScreen(orderId: orderId),
                      ),
                    );
                  },
                  child: const Text('TRACK REGIMEN PROGRESS'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
