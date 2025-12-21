import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_provider.dart';

class TvDisplayScreen extends StatefulWidget {
  const TvDisplayScreen({super.key});

  @override
  State<TvDisplayScreen> createState() => _TvDisplayScreenState();
}

class _TvDisplayScreenState extends State<TvDisplayScreen> {
  static const String _tvBaseUrlPrefsKey = 'tvDisplayBaseUrl';

  final TextEditingController _tvBaseUrlController = TextEditingController();
  final TextEditingController _pairingCodeController = TextEditingController();
  bool _loadingTvBaseUrl = true;
  bool _pairingBusy = false;

  @override
  void initState() {
    super.initState();
    _loadTvBaseUrl();
  }

  @override
  void dispose() {
    _tvBaseUrlController.dispose();
    _pairingCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadTvBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = (prefs.getString(_tvBaseUrlPrefsKey) ?? '').trim();
      if (saved.isNotEmpty) {
        _tvBaseUrlController.text = saved;
      } else {
        final current = Uri.base;
        final host = current.host.toLowerCase();
        if (host == 'localhost' || host == '127.0.0.1') {
          final guessedPort =
              (current.hasPort && current.port > 0) ? current.port + 1 : 5051;
          _tvBaseUrlController.text = current
              .replace(path: '/', query: '', fragment: '', port: guessedPort)
              .origin;
        } else {
          _tvBaseUrlController.text = Uri.base.origin;
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingTvBaseUrl = false;
        });
      }
    }
  }

  Future<void> _saveTvBaseUrl(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tvBaseUrlPrefsKey, value.trim());
  }

  String _buildTvLink({required String baseUrl, required String masjidId}) {
    final trimmed = baseUrl.trim();
    if (trimmed.isEmpty) return '';

    Uri base;
    try {
      base = Uri.parse(trimmed);
    } catch (_) {
      return '';
    }

    // If the admin typed "example.com" with no scheme, assume https.
    if (!base.hasScheme) {
      base = Uri.parse('https://$trimmed');
    }

    return base.replace(
      queryParameters: <String, String>{
        'mode': 'tv',
        'masjidId': masjidId,
      },
    ).toString();
  }

  String _buildTvPairingLink({required String baseUrl}) {
    final trimmed = baseUrl.trim();
    if (trimmed.isEmpty) return '';

    Uri base;
    try {
      base = Uri.parse(trimmed);
    } catch (_) {
      return '';
    }

    if (!base.hasScheme) {
      base = Uri.parse('https://$trimmed');
    }

    return base.replace(
      queryParameters: const <String, String>{
        'mode': 'tv',
      },
    ).toString();
  }

  Future<void> _copyToClipboard(BuildContext context, String text) async {
    if (text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        backgroundColor: Color(0xFF2196F3),
      ),
    );
  }

  Future<void> _claimTvPairingCode(BuildContext context,
      {required String masjidId}) async {
    final raw = _pairingCodeController.text;
    final code = raw.replaceAll(RegExp(r'\s+'), '').trim();

    if (masjidId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing masjid id (not signed in?)')),
      );
      return;
    }

    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 6-digit pairing code')),
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
              content: Text('This code is already claimed by another masjid.')),
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
          backgroundColor: Color(0xFF2196F3),
        ),
      );

      _pairingCodeController.clear();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pair TV: $e')),
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

    final tvLink = (masjidId == null || masjidId.isEmpty)
        ? ''
        : _buildTvLink(baseUrl: _tvBaseUrlController.text, masjidId: masjidId);

    final tvPairingLink =
        _buildTvPairingLink(baseUrl: _tvBaseUrlController.text);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TV Display',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pair and manage TV screens for your masjid',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 30),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TV Display Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Open a TV Display link on the TV browser. Pairing is recommended so you don\'t need to type long links on the TV.',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _tvBaseUrlController,
                    enabled: !_loadingTvBaseUrl,
                    decoration: const InputDecoration(
                      labelText: 'TV Display Base URL',
                      hintText: 'https://your-tv-display-site.com/',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.link),
                      helperText:
                          'This is the website where the TV display is hosted (main app web build).',
                    ),
                    onChanged: (value) {
                      _saveTvBaseUrl(value);
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: (masjidId == null || masjidId.isEmpty)
                              ? null
                              : () => _copyToClipboard(context, masjidId),
                          icon: const Icon(Icons.badge),
                          label: const Text('Copy Masjid ID'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: tvLink.trim().isEmpty
                              ? null
                              : () => _copyToClipboard(context, tvLink),
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy TV Link'),
                        ),
                      ),
                    ],
                  ),
                  if (tvLink.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'TV Link',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      tvLink,
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 14),
                  const Text(
                    'Pair a TV (recommended)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Open the TV display on the TV (base URL + ?mode=tv). The TV will show a 6-digit code. Enter it here to connect the TV to this masjid.',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _pairingCodeController,
                          decoration: const InputDecoration(
                            labelText: 'Pairing Code',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.lock_outline),
                            hintText: '123456',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: (_pairingBusy ||
                                masjidId == null ||
                                masjidId.isEmpty)
                            ? null
                            : () => _claimTvPairingCode(context,
                                masjidId: masjidId),
                        child: _pairingBusy
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Pair'),
                      ),
                    ],
                  ),
                  if (tvPairingLink.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'TV Pairing URL (open this on the TV)',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              _copyToClipboard(context, tvPairingLink),
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      tvPairingLink,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
