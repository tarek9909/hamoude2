import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/top_toast.dart';
import '../widgets/app_refresh.dart';

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: colors.primary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'MY ADDRESSES',
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
        child: AppRefresh(
          child: appState.customerAddresses.isEmpty
              ? _buildEmptyState(context, appState)
              : _buildAddressList(context, appState),
        ),
      ),
      floatingActionButton: appState.customerAddresses.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showAddressBottomSheet(context, appState),
              backgroundColor: AppTheme.primary,
              icon: const Icon(Icons.add_location_alt_outlined,
                  color: Colors.white, size: 20),
              label: Text(
                'ADD ADDRESS',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.0,
                  color: Colors.white,
                ),
              ),
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppState appState) {
    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.location_off_outlined,
                      color: AppTheme.primary.withValues(alpha: 0.6),
                      size: 64,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No Saved Addresses',
                    style: GoogleFonts.ebGaramond(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Add your delivery addresses here to access them quickly during checkout.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 13.5,
                      color: AppTheme.secondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () => _showAddressBottomSheet(context, appState),
                    icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                    label: const Text('ADD FIRST ADDRESS'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildAddressList(BuildContext context, AppState appState) {
    return ListView.builder(
      physics:
          const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: appState.customerAddresses.length,
      itemBuilder: (context, index) {
        final address = appState.customerAddresses[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppTheme.border.withValues(alpha: 0.5), width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      address.label.toUpperCase(),
                      style: GoogleFonts.manrope(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.edit_outlined,
                        color: AppTheme.secondary, size: 18),
                    onPressed: () => _showAddressBottomSheet(context, appState,
                        existing: address),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Color(0xFFBA1A1A), size: 18),
                    onPressed: () => _confirmDelete(context, appState, address),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                address.recipientName,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: AppTheme.primary,
                ),
              ),
              if (address.recipientPhone.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  address.recipientPhone,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: AppTheme.secondary,
                  ),
                ),
              ],
              const Divider(
                  height: 20, thickness: 0.6, color: Color(0xFFE4E8E1)),
              Text(
                address.addressLine1,
                style: GoogleFonts.manrope(
                    fontSize: 12.5, color: AppTheme.primary),
              ),
              if (address.addressLine2.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  address.addressLine2,
                  style: GoogleFonts.manrope(
                      fontSize: 12.5, color: AppTheme.primary),
                ),
              ],
              const SizedBox(height: 2),
              Text(
                '${address.city}, ${address.state}'.trim(),
                style: GoogleFonts.manrope(
                    fontSize: 12.5, color: AppTheme.primary),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(
      BuildContext context, AppState appState, CustomerAddress address) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppTheme.border, width: 1.0),
          ),
          title: Text(
            'Delete Address?',
            style: GoogleFonts.ebGaramond(
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
          content: Text(
            'Are you sure you want to remove this address?',
            style:
                GoogleFonts.manrope(fontSize: 13.5, color: AppTheme.secondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
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
              onPressed: () async {
                Navigator.pop(ctx);
                await appState.deleteCustomerAddress(address);
                if (context.mounted) {
                  showTopToast(context, 'Address removed successfully.');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBA1A1A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Text(
                'DELETE',
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
        // Use a local submitting flag scoped to this bottom sheet instance,
        // instead of a class-level field that can conflict with parent rebuilds.
        bool submitting = false;

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
                                    if (line1Controller.text.trim().isEmpty) {
                                      showTopToast(sheetContext,
                                          'Address line 1 is required.');
                                      return;
                                    }
                                    if (nameController.text.trim().isEmpty) {
                                      showTopToast(sheetContext,
                                          'Recipient name is required.');
                                      return;
                                    }
                                    setSheetState(() => submitting = true);
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

                                      await appState
                                          .saveCustomerAddress(address);

                                      // Show success toast on the parent context.
                                      if (context.mounted) {
                                        showTopToast(
                                          context,
                                          existing == null
                                              ? 'Address saved successfully.'
                                              : 'Address updated successfully.',
                                        );
                                      }
                                    } catch (e) {
                                      // If the save fails, show the error toast
                                      // on the parent context.
                                      if (context.mounted) {
                                        showTopToast(context,
                                            'Failed to save address: $e');
                                      }
                                    }
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
}
