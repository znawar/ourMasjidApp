import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/auth_provider.dart';
import '../utils/admin_theme.dart';

class TvDisplayScreen extends StatefulWidget {
  const TvDisplayScreen({super.key});

  @override
  State<TvDisplayScreen> createState() => _TvDisplayScreenState();
}

class _TvDisplayScreenState extends State<TvDisplayScreen> {
  final TextEditingController _pairingCodeController = TextEditingController();
  bool _pairingBusy = false;

  @override
  void dispose() {
    _pairingCodeController.dispose();
    super.dispose();
  }

  Future<void> _claimTvPairingCode(BuildContext context,
      {required String masjidId}) async {
    final raw = _pairingCodeController.text;
    final code = raw.replaceAll(RegExp(r'\s+'), '').trim();

    if (masjidId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to pair TV'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      );
      return;
    }

    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 6-digit pairing code'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      );
      return;
    }

    setState(() {
      _pairingBusy = true;
    });

    try {
      final ref = FirebaseFirestore.instance.collection('tv_pairs').doc(code);
      final snap = await ref.get();

      final data = snap.data() as Map<String, dynamic>?;
      final existingMasjidId = (data?['masjidId'] ?? '').toString().trim();
      if (existingMasjidId.isNotEmpty && existingMasjidId != masjidId.trim()) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This code is already claimed by another masjid'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
        );
        return;
      }

      await ref.set({
        'code': code,
        'masjidId': masjidId.trim(),
        'claimed': true,
        'claimedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('TV paired successfully'),
          backgroundColor: AdminTheme.primaryBlue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      );

      _pairingCodeController.clear();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pair TV: $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _pairingBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final masjidId = auth.userId;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Modern Header
          const PageHeader(
            icon: Icons.tv,
            title: 'TV Display Manager',
            subtitle: 'Connect and manage TV displays for your masjid',
          ),

          // Connected TVs Section
          _buildConnectedTvsSection(masjidId),

          const SizedBox(height: 20),

          // Pairing Section Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.add_circle_outline,
                      color: AdminTheme.primaryBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Pair New TV',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AdminTheme.primaryNavy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Open the TV display URL on your TV browser. A 6-digit pairing code will appear. Enter that code below to link the TV to your masjid.',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),

                // Pairing Code Input with Button
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AdminTheme.backgroundSection,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _pairingCodeController,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                        ),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          labelText: 'TV Pairing Code',
                          labelStyle: const TextStyle(
                            color: AdminTheme.primaryBlue,
                            fontSize: 14,
                          ),
                          hintText: '123456',
                          hintStyle: const TextStyle(
                            fontSize: 16,
                            letterSpacing: 2,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade400),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade400),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AdminTheme.primaryBlue,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          prefixIcon: const Icon(
                            Icons.qr_code_scanner,
                            color: AdminTheme.primaryBlue,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (_pairingBusy ||
                                  masjidId == null ||
                                  masjidId.isEmpty)
                              ? null
                              : () => _claimTvPairingCode(context,
                                  masjidId: masjidId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AdminTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                          ),
                          child: _pairingBusy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.link, size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      'Pair TV Display',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Help/Info Section
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AdminTheme.backgroundBlueLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AdminTheme.borderBlueLight),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AdminTheme.primaryBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.info_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quick Tips',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AdminTheme.primaryBlueDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '• Open the TV Display URL on your TV browser\n• Enter the 6-digit code shown on the TV screen\n• Once paired, the TV will automatically connect',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedTvsSection(String? masjidId) {
    if (masjidId == null || masjidId.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.connected_tv,
                color: AdminTheme.primaryBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Connected TVs',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AdminTheme.primaryNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tv_pairs')
                .where('masjidId', isEqualTo: masjidId)
                .where('claimed', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              final totalTvs = docs.length;
              
              // Count active TVs (those with lastSeen within last 5 minutes)
              final now = DateTime.now();
              int activeTvs = 0;
              for (final doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                final lastSeen = data['lastSeen'];
                if (lastSeen is Timestamp) {
                  final lastSeenDate = lastSeen.toDate();
                  if (now.difference(lastSeenDate).inMinutes < 5) {
                    activeTvs++;
                  }
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats Row
                  Row(
                    children: [
                      _buildStatCard(
                        icon: Icons.tv,
                        label: 'Total TVs',
                        value: totalTvs.toString(),
                        color: AdminTheme.primaryBlue,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        icon: Icons.circle,
                        label: 'Active Now',
                        value: activeTvs.toString(),
                        color: AdminTheme.accentEmerald,
                      ),
                    ],
                  ),
                  
                  if (docs.isEmpty) ...[
                    const SizedBox(height: 20),
                    Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.tv_off,
                            size: 48,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No TVs connected yet',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                    ...docs.map((doc) => _buildTvListItem(doc, now)),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTvListItem(DocumentSnapshot doc, DateTime now) {
    final data = doc.data() as Map<String, dynamic>;
    final code = data['code']?.toString() ?? doc.id;
    final claimedAt = data['claimedAt'];
    final lastSeen = data['lastSeen'];
    
    String connectedTime = 'Unknown';
    if (claimedAt is Timestamp) {
      connectedTime = DateFormat('MMM d, yyyy h:mm a').format(claimedAt.toDate());
    }
    
    bool isActive = false;
    String lastSeenText = 'Never';
    if (lastSeen is Timestamp) {
      final lastSeenDate = lastSeen.toDate();
      final diff = now.difference(lastSeenDate);
      isActive = diff.inMinutes < 5;
      if (diff.inMinutes < 1) {
        lastSeenText = 'Just now';
      } else if (diff.inMinutes < 60) {
        lastSeenText = '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        lastSeenText = '${diff.inHours}h ago';
      } else {
        lastSeenText = DateFormat('MMM d').format(lastSeenDate);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminTheme.backgroundSection,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive ? AdminTheme.accentEmerald.withOpacity(0.5) : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? AdminTheme.accentEmerald : Colors.grey.shade400,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TV #$code',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AdminTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Connected: $connectedTime',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive 
                      ? AdminTheme.accentEmerald.withOpacity(0.1) 
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isActive ? 'Active' : 'Offline',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isActive ? AdminTheme.accentEmerald : Colors.grey[600],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                lastSeenText,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _confirmRemoveTv(context, doc.id),
            icon: const Icon(Icons.delete_outline, size: 20),
            color: AdminTheme.accentRed,
            tooltip: 'Remove TV',
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemoveTv(BuildContext context, String tvId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove TV'),
        content: const Text(
          'Are you sure you want to remove this TV? It will need to be paired again to reconnect.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.accentRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('tv_pairs')
            .doc(tvId)
            .delete();
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('TV removed successfully'),
              backgroundColor: AdminTheme.primaryBlue,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to remove TV: $e'),
              backgroundColor: AdminTheme.accentRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }
}

