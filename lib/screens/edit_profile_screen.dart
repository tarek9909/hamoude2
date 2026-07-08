import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/top_toast.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  String? _selectedGender;
  bool _isSaving = false;

  // Double OTP state variables for secure email edits
  bool _isDoubleOtpMode = false;
  int _otpStage = 1; // 1 = verifying old email, 2 = verifying new email
  String _oldOtpChallenge = '';
  String _newOtpChallenge = '';
  final _otpController = TextEditingController();
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    _nameController.text = appState.profileName;
    _emailController.text = appState.profileEmail;
    _phoneController.text = appState.profilePhone;
    _dobController.text = appState.profileDob;
    _selectedGender =
        appState.profileGender.isEmpty ? null : appState.profileGender;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _otpController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")
        .hasMatch(email);
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds > 0) {
        setState(() => _cooldownSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _handleSendStage1Otp() async {
    final appState = Provider.of<AppState>(context, listen: false);
    setState(() => _isSaving = true);
    try {
      final response = await appState.requestCustomerOtp(appState.profileEmail,
          checkExists: true);
      setState(() {
        _oldOtpChallenge = response['challenge'].toString();
        _isDoubleOtpMode = true;
        _otpStage = 1;
        _otpController.clear();
      });
      _startCooldownTimer();
      if (mounted) {
        showTopToast(context, 'Verification code sent to your current email.');
      }
    } catch (e) {
      if (mounted) {
        showTopToast(context, e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _handleVerifyStage1() async {
    final appState = Provider.of<AppState>(context, listen: false);
    final otp = _otpController.text.trim();
    final newEmail = _emailController.text.trim();

    if (otp.isEmpty) {
      showTopToast(context, 'Please enter verification code.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await appState.verifyCustomerOtp(
        identifier: appState.profileEmail,
        challenge: _oldOtpChallenge,
        code: otp,
      );

      // Verify success! Proceed to send Stage 2 OTP to the new email
      final response =
          await appState.requestCustomerOtp(newEmail, checkNotExists: true);
      setState(() {
        _newOtpChallenge = response['challenge'].toString();
        _otpStage = 2;
        _otpController.clear();
      });
      _startCooldownTimer();
      if (mounted) {
        showTopToast(
            context, 'Current email verified. Code sent to your new email.');
      }
    } catch (e) {
      if (mounted) {
        showTopToast(context, e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _handleVerifyStage2() async {
    final appState = Provider.of<AppState>(context, listen: false);
    final otp = _otpController.text.trim();
    final name = _nameController.text.trim();
    final newEmail = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    if (otp.isEmpty) {
      showTopToast(context, 'Please enter verification code.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await appState.verifyCustomerOtp(
        identifier: newEmail,
        challenge: _newOtpChallenge,
        code: otp,
      );

      // Verify success! Complete profile updates
      final dob = _dobController.text.trim();
      final gender = _selectedGender ?? 'Prefer not to say';
      await appState.updateProfileData(
        name: name,
        email: newEmail,
        phone: phone,
        skinConcern: appState.profileSkinConcern,
        dob: dob,
        gender: gender,
      );

      if (mounted) {
        showTopToast(context, 'Profile and email updated successfully!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showTopToast(context, e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _handleSave() async {
    final appState = Provider.of<AppState>(context, listen: false);
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || email.isEmpty) {
      showTopToast(context, 'Name and Email are required.');
      return;
    }

    if (!_isValidEmail(email)) {
      showTopToast(context, 'Please enter a valid email address.');
      return;
    }

    // Check if email changed
    if (email.toLowerCase() != appState.profileEmail.toLowerCase()) {
      // Trigger the double verification challenge
      await _handleSendStage1Otp();
    } else {
      // Normal direct save
      setState(() => _isSaving = true);
      try {
        final dob = _dobController.text.trim();
        final gender = _selectedGender ?? 'Prefer not to say';
        await appState.updateProfileData(
          name: name,
          email: email,
          phone: phone,
          skinConcern: appState.profileSkinConcern,
          dob: dob,
          gender: gender,
        );
        if (mounted) {
          showTopToast(context, 'Profile updated successfully!');
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          showTopToast(context, 'Failed to save profile: $e');
        }
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    }
  }

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

  Future<void> _pickImage(ImageSource source, AppState appState) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        appState.updateProfileImage(pickedFile.path);
        if (mounted) {
          showTopToast(context, 'Profile picture updated successfully!');
        }
      }
    } catch (e) {
      if (mounted) {
        showTopToast(context, 'Failed to pick image: $e');
      }
    }
  }

  void _showImagePickerDialog(AppState appState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'UPDATE PROFILE PICTURE',
                style: GoogleFonts.ebGaramond(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select an action to upload or take a new picture from your device.',
                style: GoogleFonts.manrope(
                  fontSize: 12.5,
                  color: AppTheme.secondary,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppTheme.primary, width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        await _pickImage(ImageSource.gallery, appState);
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_library_outlined,
                              color: AppTheme.primary, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'GALLERY',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                              letterSpacing: 1.0,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _pickImage(ImageSource.camera, appState);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.camera_alt_outlined,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'CAMERA',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.0,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData prefixIcon,
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
                  color: AppTheme.primary.withValues(alpha: 0.2), width: 1.2),
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
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.6),
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back_ios_new,
                  color: colors.primary, size: 16),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text(
          'MY PROFILE',
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
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_isDoubleOtpMode) ...[
                // Profile Avatar Photo Selector
                Center(
                  child: Stack(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppTheme.primary.withValues(alpha: 0.25),
                              width: 1.5),
                        ),
                        child: ClipOval(
                          child: _buildAvatarWidget(appState.profileImageUrl,
                              iconSize: 40),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => _showImagePickerDialog(appState),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primary,
                            ),
                            child: const Icon(Icons.camera_alt_outlined,
                                color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Form details (No border box container!)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildField(
                      controller: _nameController,
                      labelText: 'FULL NAME',
                      hintText: 'Full Name',
                      prefixIcon: Icons.person_outline,
                    ),
                    const SizedBox(height: 20),
                    _buildField(
                      controller: _emailController,
                      labelText: 'EMAIL ADDRESS',
                      hintText: 'Email Address',
                      prefixIcon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 20),
                    _buildField(
                      controller: _phoneController,
                      labelText: 'PHONE NUMBER',
                      hintText: 'e.g. +1234567890',
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _dobController.text.isNotEmpty
                              ? (DateTime.tryParse(_dobController.text) ??
                                  DateTime.now()
                                      .subtract(const Duration(days: 365 * 18)))
                              : DateTime.now()
                                  .subtract(const Duration(days: 365 * 18)),
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                          builder: (context, child) => Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.light(
                                primary: AppTheme.primary,
                                onPrimary: Colors.white,
                                surface: Colors.white,
                                onSurface: AppTheme.primary,
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (date != null) {
                          setState(() {
                            _dobController.text =
                                "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
                          });
                        }
                      },
                      child: AbsorbPointer(
                        child: _buildField(
                          controller: _dobController,
                          labelText: 'DATE OF BIRTH',
                          hintText: 'Select Date of Birth',
                          prefixIcon: Icons.calendar_today_outlined,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding:
                              const EdgeInsets.only(left: 12.0, bottom: 6.0),
                          child: Text(
                            'GENDER',
                            style: GoogleFonts.manrope(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedGender,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.55),
                            prefixIcon: Icon(Icons.people_outline,
                                size: 18,
                                color:
                                    AppTheme.primary.withValues(alpha: 0.55)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 16),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide(
                                  color:
                                      AppTheme.primary.withValues(alpha: 0.2),
                                  width: 1.2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide(
                                  color: AppTheme.primary, width: 1.5),
                            ),
                            hintText: 'Select Gender',
                            hintStyle: GoogleFonts.manrope(
                              color: AppTheme.secondary.withValues(alpha: 0.5),
                              fontSize: 12.5,
                            ),
                          ),
                          dropdownColor: AppTheme.background,
                          items: [
                            'Female',
                            'Male',
                            'Non-binary',
                            'Prefer not to say'
                          ]
                              .map((g) => DropdownMenuItem(
                                    value: g,
                                    child: Text(g),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedGender = val;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSaving ? () {} : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 3,
                          shadowColor: AppTheme.primary.withValues(alpha: 0.25),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                'SAVE CHANGES',
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
              ] else ...[
                // Dual stage OTP verification card (No border box container!)
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.shield_outlined,
                          color: AppTheme.primary, size: 56),
                      const SizedBox(height: 16),
                      Text(
                        _otpStage == 1
                            ? 'VERIFY CURRENT EMAIL'
                            : 'VERIFY NEW EMAIL',
                        style: GoogleFonts.ebGaramond(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          _otpStage == 1
                              ? 'To update your email address, we must first verify your identity. Enter the code sent to your old address: ${appState.profileEmail}.'
                              : 'Secure step 2 of 2. Enter the validation code sent to your proposed new address: ${_emailController.text.trim()}.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: 12.5,
                            color: AppTheme.secondary.withValues(alpha: 0.85),
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),
                      _buildField(
                        controller: _otpController,
                        labelText: 'VERIFICATION CODE',
                        hintText: 'Enter OTP code',
                        prefixIcon: Icons.key_outlined,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 10),
                      if (_cooldownSeconds > 0)
                        Padding(
                          padding:
                              const EdgeInsets.only(left: 12.0, bottom: 4.0),
                          child: Text(
                            'Resend code in $_cooldownSeconds seconds',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              color: AppTheme.secondary.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      else
                        TextButton(
                          onPressed: _isSaving
                              ? () {}
                              : () async {
                                  if (_otpStage == 1) {
                                    await _handleSendStage1Otp();
                                  } else {
                                    setState(() => _isSaving = true);
                                    try {
                                      final response =
                                          await appState.requestCustomerOtp(
                                        _emailController.text.trim(),
                                        checkNotExists: true,
                                      );
                                      setState(() {
                                        _newOtpChallenge =
                                            response['challenge'].toString();
                                      });
                                      _startCooldownTimer();
                                      if (context.mounted) {
                                        showTopToast(context,
                                            'New verification code sent to your proposed email.');
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        showTopToast(
                                            context,
                                            e
                                                .toString()
                                                .replaceAll('Exception: ', ''));
                                      }
                                    } finally {
                                      if (mounted) {
                                        setState(() => _isSaving = false);
                                      }
                                    }
                                  }
                                },
                          child: Text(
                            'Resend verification code',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isSaving
                              ? () {}
                              : (_otpStage == 1
                                  ? _handleVerifyStage1
                                  : _handleVerifyStage2),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 3,
                            shadowColor:
                                AppTheme.primary.withValues(alpha: 0.25),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : Text(
                                  _otpStage == 1
                                      ? 'VERIFY CURRENT EMAIL'
                                      : 'VERIFY & UPDATE EMAIL',
                                  style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                    fontSize: 12.5,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isDoubleOtpMode = false;
                            _otpController.clear();
                            _isSaving = false;
                          });
                        },
                        child: Text(
                          'Cancel Verification / Go Back',
                          style: GoogleFonts.manrope(
                            fontSize: 12.5,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
