import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../utils/admin_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

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

                  TextFormField(
                    decoration: AdminTheme.inputDecoration(
                      labelText: 'Masjid Name',
                      prefixIcon: Icons.mosque,
                    ),
                    initialValue: auth.masjidName,
                  ),
                  const SizedBox(height: 15),

                  TextFormField(
                    decoration: AdminTheme.inputDecoration(
                      labelText: 'Address',
                      prefixIcon: Icons.location_on,
                    ),
                  ),
                  const SizedBox(height: 15),

                  TextFormField(
                    decoration: AdminTheme.inputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: Icons.phone,
                    ),
                  ),
                  const SizedBox(height: 15),

                  TextFormField(
                    decoration: AdminTheme.inputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icons.email,
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
                    onTap: () {},
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.lock, color: AdminTheme.primaryBlue),
                    title: const Text('Change Password'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.notifications, color: AdminTheme.primaryBlue),
                    title: const Text('Notification Settings'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
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
                    onPressed: () {},
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
                    onPressed: () {},
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
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Settings saved successfully'),
                    backgroundColor: AdminTheme.primaryBlue,
                  ),
                );
              },
              style: AdminTheme.primaryButtonStyle,
              child: const Text('Save All Changes'),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
