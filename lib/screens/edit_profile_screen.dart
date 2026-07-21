import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
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
  final _picker = ImagePicker();
  bool _isSaving = false;
  bool _isPickingImage = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = context.read<AppState>().profileName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    if (_isSaving) return;
    try {
      final name = normalizeFullName(_nameController.text);
      setState(() => _isSaving = true);
      await context.read<AppState>().updateProfileData(name: name);
      if (!mounted) {
        return;
      }
      showTopToast(context, 'Profile updated successfully.');
      Navigator.pop(context);
    } on ArgumentError catch (error) {
      if (mounted) {
        showTopToast(
            context, error.message?.toString() ?? 'Enter a valid name.');
      }
    } catch (_) {
      if (mounted) {
        showTopToast(
            context, 'Unable to update your profile. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isPickingImage) {
      return;
    }
    setState(() => _isPickingImage = true);
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null || !mounted) {
        return;
      }
      await context.read<AppState>().uploadProfileImage(picked.path);
      if (mounted) {
        showTopToast(context, 'Profile picture updated successfully.');
      }
    } catch (_) {
      if (mounted) {
        showTopToast(context, 'Unable to update your profile picture.');
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
  }

  Future<void> _showPhotoActions() async {
    if (_isPickingImage) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from library'),
              enabled: !_isPickingImage,
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              enabled: !_isPickingImage,
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.camera);
              },
            ),
            if (context.read<AppState>().profileImageUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove profile picture'),
                enabled: !_isPickingImage,
                onTap: () async {
                  Navigator.pop(sheetContext);
                  setState(() => _isPickingImage = true);
                  try {
                    await context.read<AppState>().removeProfileImage();
                  } catch (_) {
                    if (mounted) {
                      showTopToast(
                          context, 'Unable to remove your profile picture.');
                    }
                  } finally {
                    if (mounted) {
                      setState(() => _isPickingImage = false);
                    }
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text('My Profile'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 52,
                        backgroundColor:
                            AppTheme.primary.withValues(alpha: 0.1),
                        backgroundImage: appState.profileImageUrl == null
                            ? null
                            : (appState.profileImageUrl!.startsWith('http')
                                    ? NetworkImage(appState.profileImageUrl!)
                                    : FileImage(
                                        File(appState.profileImageUrl!)))
                                as ImageProvider?,
                        child: appState.profileImageUrl == null
                            ? Icon(Icons.person_outline,
                                size: 48, color: AppTheme.primary)
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: IconButton.filled(
                          tooltip: 'Update profile picture',
                          onPressed: _isPickingImage ? null : _showPhotoActions,
                          icon: _isPickingImage
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.camera_alt_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _isSaving ? null : _saveName,
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text('Save changes',
                          style:
                              GoogleFonts.manrope(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
