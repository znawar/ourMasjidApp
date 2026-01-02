import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/prayer_times_provider.dart';
import 'package:admin_web/providers/announcements_provider.dart';
import 'package:admin_web/utils/admin_theme.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isImportant = false;
  bool _isPermanent = true;
  int _durationDays = 7; // Default duration in days

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _addAnnouncement(BuildContext context) async {
    if (_titleController.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a title'),
          backgroundColor: AdminTheme.accentRed,
        ),
      );
      return;
    }

    final provider = Provider.of<AnnouncementsProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    // Calculate expiration date if not permanent (use masjid-local time)
    DateTime? expiresAt;
    if (!_isPermanent) {
      try {
        final p = Provider.of<PrayerTimesProvider>(context, listen: false);
        expiresAt = p.masjidNow.add(Duration(days: _durationDays));
      } catch (_) {
        expiresAt = DateTime.now().add(Duration(days: _durationDays));
      }
    }
    
    try {
      await provider.addAnnouncement(
        _titleController.text,
        _descriptionController.text,
        expiresAt: expiresAt,
      );
      
      _titleController.clear();
      _descriptionController.clear();
      _isImportant = false;
      _isPermanent = true;
      _durationDays = 7;
      
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Announcement added successfully'),
          backgroundColor: AdminTheme.primaryBlue,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AdminTheme.accentRed,
        ),
      );
    }
  }

  void _showAddDialog(BuildContext context) {
    // Reset to default values
    _isPermanent = true;
    _durationDays = 7;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: AdminTheme.borderRadiusLarge,
          ),
          title: const Text('New Announcement', style: AdminTheme.headingMedium),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: AdminTheme.inputDecoration(
                    labelText: 'Title',
                    hintText: 'Enter announcement title',
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: AdminTheme.inputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Enter announcement description',
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Checkbox(
                      value: _isImportant,
                      activeColor: AdminTheme.primaryBlue,
                      onChanged: (value) {
                        setDialogState(() {
                          _isImportant = value ?? false;
                        });
                        setState(() {});
                      },
                    ),
                    const Text('Mark as important'),
                  ],
                ),
                const SizedBox(height: 20),
                // Duration Section
                const Text(
                  'Announcement Duration',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AdminTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                // Permanent Option
                InkWell(
                  onTap: () {
                    setDialogState(() {
                      _isPermanent = true;
                    });
                    setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _isPermanent ? AdminTheme.primaryBlue : AdminTheme.borderLight,
                        width: _isPermanent ? 2 : 1,
                      ),
                      borderRadius: AdminTheme.borderRadiusSmall,
                      color: _isPermanent ? AdminTheme.primaryBlue.withOpacity(0.05) : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isPermanent ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: _isPermanent ? AdminTheme.primaryBlue : AdminTheme.textMuted,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Until Removed',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AdminTheme.textPrimary,
                                ),
                              ),
                              Text(
                                'Stays active until you delete it',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AdminTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Time-limited Option
                InkWell(
                  onTap: () {
                    setDialogState(() {
                      _isPermanent = false;
                    });
                    setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: !_isPermanent ? AdminTheme.primaryBlue : AdminTheme.borderLight,
                        width: !_isPermanent ? 2 : 1,
                      ),
                      borderRadius: AdminTheme.borderRadiusSmall,
                      color: !_isPermanent ? AdminTheme.primaryBlue.withOpacity(0.05) : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          !_isPermanent ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: !_isPermanent ? AdminTheme.primaryBlue : AdminTheme.textMuted,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Time-limited',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AdminTheme.textPrimary,
                                ),
                              ),
                              Text(
                                'Auto-expire after specified duration',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AdminTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Duration Picker (only show when time-limited is selected)
                if (!_isPermanent) ...[
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AdminTheme.backgroundSection,
                      borderRadius: AdminTheme.borderRadiusSmall,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Number of Days',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AdminTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            SizedBox(
                              width: 80,
                              child: TextField(
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  hintText: '7',
                                ),
                                controller: TextEditingController(text: _durationDays.toString()),
                                onChanged: (value) {
                                  final days = int.tryParse(value);
                                  if (days != null && days > 0) {
                                    setDialogState(() {
                                      _durationDays = days;
                                    });
                                    setState(() {});
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _durationDays == 1 ? 'day' : 'days',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AdminTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16, color: AdminTheme.textMuted),
                            const SizedBox(width: 8),
                            Text(
                              'Expires: ${_getExpirationDateText()}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AdminTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _addAnnouncement(context);
              },
              style: AdminTheme.primaryButtonStyle,
              child: const Text('Add Announcement'),
            ),
          ],
        ),
      ),
    );
  }
  
  String _getExpirationDateText() {
    DateTime expirationDate;
    try {
      final p = Provider.of<PrayerTimesProvider>(context, listen: false);
      expirationDate = p.masjidNow.add(Duration(days: _durationDays));
    } catch (_) {
      expirationDate = DateTime.now().add(Duration(days: _durationDays));
    }
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[expirationDate.month - 1]} ${expirationDate.day}, ${expirationDate.year}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AnnouncementsProvider>(context);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            icon: Icons.campaign,
            title: 'Announcements',
            subtitle: 'Manage announcements for TV display',
            trailing: ElevatedButton.icon(
              onPressed: () => _showAddDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('New Announcement'),
              style: AdminTheme.primaryButtonStyle,
            ),
          ),

          // Image Upload Section
          Container(
            decoration: AdminTheme.cardDecoration,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Upload Announcement Image',
                    style: AdminTheme.headingMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Upload an image for your announcement (Recommended: 1920x1080px for TV display)',
                    style: AdminTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),

                  GestureDetector(
                    onTap: () async {
                      await provider.uploadImage();
                    },
                    child: Container(
                      height: 300,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AdminTheme.backgroundSection,
                        borderRadius: AdminTheme.borderRadiusMedium,
                        border: Border.all(
                          color: AdminTheme.borderLight,
                          width: 2,
                        ),
                      ),
                      child: provider.uploadedImageUrl != null
                          ? ClipRRect(
                              borderRadius: AdminTheme.borderRadiusSmall,
                              child: Image.network(
                                provider.uploadedImageUrl!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.cloud_upload,
                                  size: 60,
                                  color: provider.isUploading 
                                      ? AdminTheme.borderLight 
                                      : AdminTheme.textMuted,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  provider.isUploading ? 'Uploading...' : 'Click to upload image',
                                  style: AdminTheme.bodyLarge,
                                ),
                                const SizedBox(height: 5),
                                const Text(
                                  'PNG, JPG up to 5MB',
                                  style: AdminTheme.bodySmall,
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (provider.uploadedImageUrl != null)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => provider.clearUploadedImage(),
                            style: AdminTheme.secondaryButtonStyle,
                            child: const Text('Remove Image'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _showAddDialog(context),
                            style: AdminTheme.primaryButtonStyle,
                            child: const Text('Add Announcement'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 30),

          // Active Announcements
          if (provider.announcements.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active Announcements (${provider.announcements.length})',
                  style: AdminTheme.headingMedium,
                ),
                const SizedBox(height: 15),

                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: provider.announcements.length,
                  itemBuilder: (context, index) {
                    final announcement = provider.announcements[index];
                    return _buildAnnouncementCard(announcement, provider);
                  },
                ),
              ],
            ),

          if (provider.announcements.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.announcement,
                    size: 80,
                    color: AdminTheme.borderLight,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'No announcements yet',
                    style: AdminTheme.headingSmall,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Upload an image and create your first announcement',
                    style: AdminTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementCard(Announcement announcement, AnnouncementsProvider provider) {
    final isExpired = announcement.isExpired;
    
    return Container(
      decoration: AdminTheme.cardDecoration.copyWith(
        color: isExpired ? Colors.grey.shade100 : null,
      ),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Image.network(
                    announcement.imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: AdminTheme.backgroundSection,
                        child: const Icon(Icons.broken_image, color: AdminTheme.textMuted),
                      );
                    },
                  ),
                ),
                // Expiration Badge
                if (announcement.expiresAt != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isExpired ? AdminTheme.accentRed : AdminTheme.accentAmber,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isExpired ? Icons.timer_off : Icons.timer,
                            size: 12,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isExpired ? 'Expired' : _getRemainingTime(announcement.expiresAt!),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (announcement.isPermanent)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AdminTheme.accentEmerald,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.check_circle, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Until removed',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  announcement.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: isExpired ? AdminTheme.textMuted : AdminTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Switch(
                      value: announcement.active,
                      activeColor: AdminTheme.primaryBlue,
                      onChanged: (_) {
                        provider.toggleAnnouncement(announcement.id);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 18, color: AdminTheme.accentRed),
                      onPressed: () {
                        provider.deleteAnnouncement(announcement.id);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  String _getRemainingTime(DateTime expiresAt) {
    DateTime now;
    try {
      final p = Provider.of<PrayerTimesProvider>(context, listen: false);
      now = p.masjidNow;
    } catch (_) {
      now = DateTime.now();
    }
    final difference = expiresAt.difference(now);
    
    if (difference.isNegative) return 'Expired';
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d left';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h left';
    } else {
      return '${difference.inMinutes}m left';
    }
  }
}