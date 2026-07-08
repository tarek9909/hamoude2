import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/top_toast.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String? identifier;

  const ForgotPasswordScreen({super.key, this.identifier});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _identifierController;
  bool _isLoading = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _identifierController =
        TextEditingController(text: widget.identifier?.trim() ?? '');
  }

  @override
  void dispose() {
    _identifierController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      showTopToast(context, 'Please enter your phone or account identifier.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await context.read<AppState>().requestPasswordReset(identifier);
      if (!mounted) return;
      setState(() => _submitted = true);
      showTopToast(
        context,
        'Request received. An administrator will review it.',
      );
    } catch (e) {
      if (mounted) {
        showTopToast(context, e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildIdentifierField() {
    return TextField(
      controller: _identifierController,
      keyboardType: TextInputType.phone,
      enabled: !_isLoading && !_submitted,
      cursorColor: AppTheme.primary,
      style: GoogleFonts.manrope(
        fontSize: 13,
        color: AppTheme.primary,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: 'PHONE OR ACCOUNT ID',
        hintText: 'Enter your registered phone number',
        prefixIcon: Icon(
          Icons.badge_outlined,
          size: 18,
          color: AppTheme.primary.withValues(alpha: 0.7),
        ),
        filled: true,
        fillColor: AppTheme.surface.withValues(alpha: 0.78),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        labelStyle: GoogleFonts.manrope(
          color: AppTheme.primary,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
        hintStyle: GoogleFonts.manrope(
          color: AppTheme.secondary.withValues(alpha: 0.55),
          fontSize: 12.5,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(
            color: AppTheme.primary.withValues(alpha: 0.22),
            width: 1.2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(
            color: AppTheme.primary.withValues(alpha: 0.12),
            width: 1.0,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -80,
            width: 320,
            height: 320,
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFE9E2D0),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: -100,
            width: 280,
            height: 280,
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFE1E8DE),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 75, sigmaY: 75),
              child: Container(color: Colors.transparent),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  leading: Padding(
                    padding: const EdgeInsets.only(left: 16, top: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.6),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new,
                          color: colors.primary,
                          size: 16,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 12),
                        Center(
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: Colors.white.withValues(alpha: 0.65),
                              border:
                                  Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: appState.logoUrl != null &&
                                    appState.logoUrl!.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.network(
                                      appState.logoUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) => Icon(
                                        Icons.storefront_outlined,
                                        color: AppTheme.primary,
                                        size: 40,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    Icons.storefront_outlined,
                                    color: AppTheme.primary,
                                    size: 40,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          _submitted
                              ? 'REQUEST SUBMITTED'
                              : 'PASSWORD RESET REQUEST',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.ebGaramond(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.8,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _submitted
                              ? 'A store administrator will review your request and contact you through the approved store channel.'
                              : 'Send a reset request for admin approval. This keeps account access changes reviewed by the store team.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: 12.5,
                            color: AppTheme.secondary.withValues(alpha: 0.85),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 36),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color:
                                      AppTheme.primary.withValues(alpha: 0.15),
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_submitted)
                                    Icon(
                                      Icons.verified_user_outlined,
                                      color: AppTheme.primary,
                                      size: 42,
                                    )
                                  else
                                    _buildIdentifierField(),
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    height: 52,
                                    child: ElevatedButton(
                                      onPressed: _isLoading
                                          ? null
                                          : _submitted
                                              ? () => Navigator.pop(context)
                                              : _submitRequest,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primary,
                                        foregroundColor: Colors.white,
                                        disabledBackgroundColor: AppTheme
                                            .primary
                                            .withValues(alpha: 0.45),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(28),
                                        ),
                                        elevation: 2,
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Text(
                                              _submitted
                                                  ? 'BACK TO SIGN IN'
                                                  : 'REQUEST REVIEW',
                                              style: GoogleFonts.manrope(
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.2,
                                                fontSize: 12.5,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
