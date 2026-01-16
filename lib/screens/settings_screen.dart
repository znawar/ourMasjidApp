import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_provider.dart';
import '../providers/announcements_provider.dart';
import '../providers/prayer_times_provider.dart';
import '../utils/admin_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _masjidNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  bool _isLoadingMasjid = true;
  bool _isSaving = false;

  bool _notifyAnnouncements = true;
  bool _notifyEmail = true;
  bool _notificationsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadMasjidInfo();
    _loadNotificationPrefs();
  }

  @override
  void dispose() {
    _masjidNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadMasjidInfo() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.userId;

    // Start with whatever we already know from auth
    _masjidNameController.text = auth.masjidName;

    if (userId == null || userId.trim().isEmpty) {
      setState(() {
        _isLoadingMasjid = false;
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('masjids')
          .doc(userId)
          .get();

      final data = doc.data();
      if (data != null) {
        final name = (data['masjidName'] ?? data['name'] ?? auth.masjidName)
            .toString()
            .trim();
        final address = (data['address'] ?? '').toString();
        final phone = (data['phone'] ?? data['phoneNumber'] ?? '').toString();
        final email = (data['email'] ?? '').toString();

        _masjidNameController.text = name;
        _addressController.text = address;
        _phoneController.text = phone;
        _emailController.text = email;
      }
    } catch (e) {
      debugPrint('Failed to load masjid info: $e');
    }

    if (mounted) {
      setState(() {
        _isLoadingMasjid = false;
      });
    }
  }

  Future<void> _loadNotificationPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notifyAnnouncements = prefs.getBool('notify_announcements') ?? true;
      final notifyEmail = prefs.getBool('notify_email') ?? true;

      if (mounted) {
        setState(() {
          _notifyAnnouncements = notifyAnnouncements;
          _notifyEmail = notifyEmail;
          _notificationsLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _notificationsLoaded = true;
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    if (_isSaving) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    setState(() {
      _isSaving = true;
    });

    try {
      await auth.updateMasjidInfo(
        masjidName: _masjidNameController.text,
        address: _addressController.text,
        phone: _phoneController.text,
        email: _emailController.text,
      );

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully'),
          backgroundColor: AdminTheme.primaryBlue,
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to save settings: $e'),
          backgroundColor: AdminTheme.accentRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _confirmAndDeleteAllAnnouncements() async {
    final announcementsProvider =
        Provider.of<AnnouncementsProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Announcements'),
        content: const Text(
          'Are you sure you want to permanently delete all announcements for this masjid? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Delete All',
              style: TextStyle(color: AdminTheme.accentRed),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final ids = announcementsProvider.announcements.map((a) => a.id).toList();
      for (final id in ids) {
        await announcementsProvider.deleteAnnouncement(id);
      }

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('All announcements deleted.'),
          backgroundColor: AdminTheme.accentRed,
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to delete announcements: $e'),
          backgroundColor: AdminTheme.accentRed,
        ),
      );
    }
  }

  Future<void> _confirmAndResetAllSettings() async {
    final prayerProvider =
        Provider.of<PrayerTimesProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset All Settings'),
        content: const Text(
          'This will reset prayer times, location and related settings back to defaults for this masjid. This action cannot be undone. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Reset',
              style: TextStyle(color: AdminTheme.accentRed),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await prayerProvider.resetAllSettings();

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('All settings reset to defaults.'),
          backgroundColor: AdminTheme.accentRed,
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to reset settings: $e'),
          backgroundColor: AdminTheme.accentRed,
        ),
      );
    }
  }

  Future<void> _showEditProfileDialog() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final emailController = TextEditingController(text: auth.email ?? '');
    final passwordController = TextEditingController();

    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: AdminTheme.borderRadiusLarge,
            ),
            title: const Text('Edit Profile', style: AdminTheme.headingMedium),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: emailController,
                    decoration: AdminTheme.inputDecoration(
                      labelText: 'Login Email',
                      prefixIcon: Icons.email,
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    decoration: AdminTheme.inputDecoration(
                      labelText: 'Current Password',
                      prefixIcon: Icons.lock,
                    ),
                    obscureText: true,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () {
                        Navigator.of(context).pop();
                      },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final newEmail = emailController.text.trim();
                        final currentPassword = passwordController.text;

                        if (newEmail.isEmpty || !newEmail.contains('@')) {
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a valid email.'),
                              backgroundColor: AdminTheme.accentRed,
                            ),
                          );
                          return;
                        }

                        if (currentPassword.isEmpty) {
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Please enter your current password.'),
                              backgroundColor: AdminTheme.accentRed,
                            ),
                          );
                          return;
                        }

                        setDialogState(() {
                          isSubmitting = true;
                        });

                        try {
                          await auth.updateEmail(
                            newEmail: newEmail,
                            currentPassword: currentPassword,
                          );

                          if (mounted) {
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text('Email updated successfully'),
                                backgroundColor: AdminTheme.primaryBlue,
                              ),
                            );
                          }

                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
                        } catch (e) {
                          if (mounted) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(e.toString()),
                                backgroundColor: AdminTheme.accentRed,
                              ),
                            );
                          }
                        } finally {
                          setDialogState(() {
                            isSubmitting = false;
                          });
                        }
                      },
                child: Text(isSubmitting ? 'Saving...' : 'Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: AdminTheme.borderRadiusLarge,
            ),
            title:
                const Text('Change Password', style: AdminTheme.headingMedium),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: currentPasswordController,
                    decoration: AdminTheme.inputDecoration(
                      labelText: 'Current Password',
                      prefixIcon: Icons.lock_outline,
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: newPasswordController,
                    decoration: AdminTheme.inputDecoration(
                      labelText: 'New Password',
                      prefixIcon: Icons.lock,
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmPasswordController,
                    decoration: AdminTheme.inputDecoration(
                      labelText: 'Confirm New Password',
                      prefixIcon: Icons.lock,
                    ),
                    obscureText: true,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () {
                        Navigator.of(context).pop();
                      },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final currentPassword =
                            currentPasswordController.text.trim();
                        final newPassword =
                            newPasswordController.text.trim();
                        final confirmPassword =
                            confirmPasswordController.text.trim();

                        if (currentPassword.isEmpty || newPassword.isEmpty) {
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Please fill in current and new password.'),
                              backgroundColor: AdminTheme.accentRed,
                            ),
                          );
                          return;
                        }

                        if (newPassword.length < 6) {
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'New password should be at least 6 characters.'),
                              backgroundColor: AdminTheme.accentRed,
                            ),
                          );
                          return;
                        }

                        if (newPassword != confirmPassword) {
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content:
                                  Text('New passwords do not match.'),
                              backgroundColor: AdminTheme.accentRed,
                            ),
                          );
                          return;
                        }

                        setDialogState(() {
                          isSubmitting = true;
                        });

                        try {
                          await auth.changePassword(
                            currentPassword: currentPassword,
                            newPassword: newPassword,
                          );

                          if (mounted) {
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Password changed successfully'),
                                backgroundColor: AdminTheme.primaryBlue,
                              ),
                            );
                          }

                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
                        } catch (e) {
                          if (mounted) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(e.toString()),
                                backgroundColor: AdminTheme.accentRed,
                              ),
                            );
                          }
                        } finally {
                          setDialogState(() {
                            isSubmitting = false;
                          });
                        }
                      },
                child: Text(isSubmitting ? 'Saving...' : 'Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showNotificationSettingsSheet() async {
    if (!_notificationsLoaded) {
      await _loadNotificationPrefs();
    }

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        bool notifyAnnouncements = _notifyAnnouncements;
        bool notifyEmail = _notifyEmail;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Notification Settings',
                    style: AdminTheme.headingMedium,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show new announcements on TV'),
                    subtitle: const Text(
                        'When disabled, announcements stay hidden for this admin device.'),
                    value: notifyAnnouncements,
                    onChanged: (value) {
                      setSheetState(() {
                        notifyAnnouncements = value;
                      });
                    },
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Email me important updates'),
                    subtitle: const Text(
                        'Future feature: receive email alerts from the app.'),
                    value: notifyEmail,
                    onChanged: (value) {
                      setSheetState(() {
                        notifyEmail = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool(
                            'notify_announcements', notifyAnnouncements);
                        await prefs.setBool('notify_email', notifyEmail);

                        if (mounted) {
                          setState(() {
                            _notifyAnnouncements = notifyAnnouncements;
                            _notifyEmail = notifyEmail;
                            _notificationsLoaded = true;
                          });
                        }

                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            icon: Icons.settings,
            title: 'Settings',
            subtitle: 'Configure your masjid settings',
          ),

          // Masjid Information
          Container(
            decoration: AdminTheme.cardDecoration,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Masjid Information',
                    style: AdminTheme.headingMedium,
                  ),
                  const SizedBox(height: 20),
                  if (_isLoadingMasjid)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _masjidNameController,
                            decoration: AdminTheme.inputDecoration(
                              labelText: 'Masjid Name',
                              prefixIcon: Icons.mosque,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Masjid name is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 15),

                          TextFormField(
                            controller: _addressController,
                            decoration: AdminTheme.inputDecoration(
                              labelText: 'Address',
                              prefixIcon: Icons.location_on,
                            ),
                          ),
                          const SizedBox(height: 15),

                          TextFormField(
                            controller: _phoneController,
                            decoration: AdminTheme.inputDecoration(
                              labelText: 'Phone Number',
                              prefixIcon: Icons.phone,
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 15),

                          TextFormField(
                            controller: _emailController,
                            decoration: AdminTheme.inputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icons.email,
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) return null;
                              if (!text.contains('@') || !text.contains('.')) {
                                return 'Enter a valid email or leave blank';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 30),

          // Account Settings
          Container(
            decoration: AdminTheme.cardDecoration,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Account Settings',
                    style: AdminTheme.headingMedium,
                  ),
                  const SizedBox(height: 20),
                  ListTile(
                    leading: const Icon(Icons.person, color: AdminTheme.primaryBlue),
                    title: const Text('Edit Profile'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _showEditProfileDialog,
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.lock, color: AdminTheme.primaryBlue),
                    title: const Text('Change Password'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _showChangePasswordDialog,
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.notifications, color: AdminTheme.primaryBlue),
                    title: const Text('Notification Settings'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _showNotificationSettingsSheet,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 30),

          // Danger Zone
          Container(
            decoration: BoxDecoration(
              color: AdminTheme.backgroundCard,
              borderRadius: AdminTheme.borderRadiusMedium,
              border: Border.all(color: AdminTheme.accentRed, width: 1),
              boxShadow: AdminTheme.shadowLight,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Danger Zone',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AdminTheme.accentRed,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Irreversible actions',
                    style: AdminTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: _confirmAndDeleteAllAnnouncements,
                    icon: const Icon(Icons.delete, color: AdminTheme.accentRed),
                    label: const Text(
                      'Delete All Announcements',
                      style: TextStyle(color: AdminTheme.accentRed),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AdminTheme.accentRed),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _confirmAndResetAllSettings,
                    icon: const Icon(Icons.restore, color: AdminTheme.accentRed),
                    label: const Text(
                      'Reset All Settings',
                      style: TextStyle(color: AdminTheme.accentRed),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AdminTheme.accentRed),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 30),

          // Save Button
          Center(
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveSettings,
              style: AdminTheme.primaryButtonStyle,
              child: Text(_isSaving ? 'Saving...' : 'Save All Changes'),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
