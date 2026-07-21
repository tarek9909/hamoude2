import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/top_toast.dart';
import 'login_screen.dart';
import 'policies_webview_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();

  bool _isLoading = false;
  bool _agreedToPolicies = false;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    final name = _nameController.text;
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final passwordConfirmation = _passwordConfirmationController.text;

    if (name.trim().isEmpty || username.isEmpty || password.isEmpty) {
      showTopToast(context, 'Please fill out all required fields.');
      return;
    }

    try {
      normalizeFullName(name);
      normalizeUsername(username);
    } on ArgumentError catch (error) {
      showTopToast(context, error.message?.toString() ?? 'Enter a valid name.');
      return;
    }

    if (password.length < 8) {
      showTopToast(context, 'Password must be at least 8 characters long.');
      return;
    }
    if (password != passwordConfirmation) {
      showTopToast(context, 'Passwords do not match.');
      return;
    }

    if (!_agreedToPolicies) {
      showTopToast(
          context, 'You must agree to the Privacy Policy and Terms of Use.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      await appState.registerWithPassword(
        name: name,
        username: username,
        password: password,
      );
      if (mounted) {
        showTopToast(context, 'Welcome to ${appState.appName}, $name!');
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData prefixIcon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12.0, bottom: 6.0),
          child: Text(
            labelText,
            style: GoogleFonts.manrope(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.primary,
              letterSpacing: 1.5,
            ),
          ),
        ),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: AppTheme.primary,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(prefixIcon,
                size: 18, color: AppTheme.primary.withValues(alpha: 0.55)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.55),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(
                  color: AppTheme.primary.withValues(alpha: 0.25), width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
            ),
            hintStyle: GoogleFonts.manrope(
              color: AppTheme.secondary.withValues(alpha: 0.5),
              fontSize: 12.5,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final appState = Provider.of<AppState>(context);

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
              filter: ImageFilter.blur(sigmaX: 75.0, sigmaY: 75.0),
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
                  pinned: false,
                  leading: Padding(
                    padding: const EdgeInsets.only(left: 16.0, top: 8.0),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.6),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.8),
                            width: 1.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(Icons.arrow_back_ios_new,
                            color: colors.primary, size: 16),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24.0, vertical: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.025),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
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
                                              size: 40),
                                    ),
                                  )
                                : Icon(Icons.storefront_outlined,
                                    color: AppTheme.primary, size: 40),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Center(
                          child: Column(
                            children: [
                              Text(
                                'CREATE YOUR ACCOUNT',
                                style: GoogleFonts.ebGaramond(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2.2,
                                  color: AppTheme.primary,
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                        const SizedBox(height: 36),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: BackdropFilter(
                            filter:
                                ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(
                                    color: AppTheme.primary
                                        .withValues(alpha: 0.15),
                                    width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Colors.black.withValues(alpha: 0.015),
                                    blurRadius: 24,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildTextField(
                                    controller: _nameController,
                                    labelText: 'FULL NAME',
                                    hintText: 'e.g. Hamoude Saleh',
                                    prefixIcon: Icons.badge_outlined,
                                    keyboardType: TextInputType.name,
                                  ),
                                  const SizedBox(height: 20),
                                  _buildTextField(
                                    controller: _usernameController,
                                    labelText: 'USERNAME',
                                    hintText: 'e.g. hamoude.saleh',
                                    prefixIcon: Icons.alternate_email,
                                  ),
                                  const SizedBox(height: 20),
                                  _buildTextField(
                                    controller: _passwordController,
                                    labelText: 'CREATE PASSWORD',
                                    hintText: 'Enter a secure password',
                                    prefixIcon: Icons.lock_outline,
                                    obscureText: true,
                                  ),
                                  const SizedBox(height: 20),
                                  _buildTextField(
                                    controller: _passwordConfirmationController,
                                    labelText: 'CONFIRM PASSWORD',
                                    hintText: 'Re-enter your password',
                                    prefixIcon: Icons.lock_outline,
                                    obscureText: true,
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: Checkbox(
                                          value: _agreedToPolicies,
                                          activeColor: AppTheme.primary,
                                          checkColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          side: BorderSide(
                                            color: AppTheme.primary
                                                .withValues(alpha: 0.6),
                                            width: 1.5,
                                          ),
                                          onChanged: (val) {
                                            setState(() {
                                              _agreedToPolicies = val ?? false;
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: RichText(
                                          text: TextSpan(
                                            style: GoogleFonts.manrope(
                                              fontSize: 12.5,
                                              color: AppTheme.secondary
                                                  .withValues(alpha: 0.8),
                                              height: 1.4,
                                            ),
                                            children: [
                                              const TextSpan(
                                                  text: 'I agree to the '),
                                              TextSpan(
                                                text:
                                                    'Privacy Policy & Terms of Use',
                                                style: GoogleFonts.manrope(
                                                  color: AppTheme.primary,
                                                  fontWeight: FontWeight.bold,
                                                  decoration:
                                                      TextDecoration.underline,
                                                ),
                                                recognizer:
                                                    TapGestureRecognizer()
                                                      ..onTap = () {
                                                        final url = appState.api
                                                            .getLegalPolicyUrl(
                                                                'privacy-policy-and-terms-of-use');
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (context) =>
                                                                PoliciesWebViewScreen(
                                                              url: url,
                                                              title:
                                                                  'Terms & Policies',
                                                            ),
                                                          ),
                                                        );
                                                      },
                                              ),
                                              const TextSpan(text: '.'),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 28),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: ElevatedButton(
                                      onPressed:
                                          _isLoading ? () {} : _handleSignUp,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primary,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(30),
                                        ),
                                        elevation: 3,
                                        shadowColor: AppTheme.primary
                                            .withValues(alpha: 0.25),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2),
                                            )
                                          : Text(
                                              'CREATE ACCOUNT',
                                              style: GoogleFonts.manrope(
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.5,
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Already have an account? ",
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                color:
                                    AppTheme.secondary.withValues(alpha: 0.8),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                if (Navigator.canPop(context)) {
                                  Navigator.pop(context);
                                } else {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const LoginScreen()),
                                  );
                                }
                              },
                              child: Text(
                                "Log In",
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
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
