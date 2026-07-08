import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/top_toast.dart';
import 'forgot_password_screen.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentPasswordController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final appState = Provider.of<AppState>(context, listen: false);
    final hasCurrentPassword = appState.accountPassword != null &&
        appState.accountPassword!.isNotEmpty;
    final currentPassword = _currentPasswordController.text;
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (hasCurrentPassword) {
      if (currentPassword.isEmpty) {
        showTopToast(context, 'Please enter your current password.');
        return;
      }
      if (currentPassword != appState.accountPassword) {
        showTopToast(context, 'Incorrect current password.');
        return;
      }
    }

    if (password.isEmpty) {
      showTopToast(context, 'Please enter a new password / PIN.');
      return;
    }

    if (password.length < 8) {
      showTopToast(context, 'New password must be at least 8 characters.');
      return;
    }

    if (password != confirm) {
      showTopToast(context, 'Passwords do not match.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await appState.updatePassword(password);
      if (mounted) {
        showTopToast(context, 'Account password updated successfully!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showTopToast(context, 'Failed to update password: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final appState = Provider.of<AppState>(context);
    final hasCurrentPassword = appState.accountPassword != null &&
        appState.accountPassword!.isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: colors.primary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'SECURITY & PASSWORD',
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Intro
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.security_outlined,
                    color: AppTheme.primary,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Inputs card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppTheme.border.withValues(alpha: 0.5),
                      width: 0.8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasCurrentPassword) ...[
                      Text(
                        'CURRENT PASSWORD',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _currentPasswordController,
                        obscureText: true,
                        style: GoogleFonts.manrope(
                            fontSize: 13, color: AppTheme.primary),
                        decoration: InputDecoration(
                          hintText: 'Enter current password',
                          prefixIcon: Icon(Icons.lock_open_outlined,
                              size: 18, color: AppTheme.secondary),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ForgotPasswordScreen(
                                  identifier: appState.profilePhone.isNotEmpty
                                      ? appState.profilePhone
                                      : null,
                                ),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Forgot Password?',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    Text(
                      'NEW ACCOUNT PASSWORD',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      style: GoogleFonts.manrope(
                          fontSize: 13, color: AppTheme.primary),
                      decoration: InputDecoration(
                        hintText: 'Enter new password',
                        prefixIcon: Icon(Icons.lock_outline,
                            size: 18, color: AppTheme.secondary),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'CONFIRM NEW PASSWORD',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      style: GoogleFonts.manrope(
                          fontSize: 13, color: AppTheme.primary),
                      decoration: InputDecoration(
                        hintText: 'Confirm new password',
                        prefixIcon: Icon(Icons.lock_clock_outlined,
                            size: 18, color: AppTheme.secondary),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                'UPDATE PASSWORD',
                                style: GoogleFonts.manrope(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                  fontSize: 12,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
