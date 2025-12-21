import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/web_location_stub.dart'
    if (dart.library.html) '../utils/web_location_web.dart';

class TVConnectionScreen extends StatefulWidget {
  const TVConnectionScreen({super.key});

  @override
  State<TVConnectionScreen> createState() => _TVConnectionScreenState();
}

class _TVConnectionScreenState extends State<TVConnectionScreen> {
  final _urlController = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // ignore: unawaited_futures
    _load();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = (prefs.getString('tvDisplayBaseUrl') ?? '').trim();

    final current = Uri.base;
    final currentHost = current.host.toLowerCase();
    final isLocalhost =
        currentHost == 'localhost' || currentHost == '127.0.0.1';

    String suggested = '';
    if (saved.isNotEmpty) {
      suggested = saved;
    } else if (isLocalhost && current.hasPort) {
      suggested = current
          .replace(
            path: '/',
            query: '',
            fragment: '',
            port: current.port + 1,
          )
          .origin;
    }

    if (!mounted) return;
    setState(() {
      _urlController.text = suggested;
      _loading = false;
    });
  }

  Future<void> _openTv() async {
    final prefs = await SharedPreferences.getInstance();

    final raw = _urlController.text.trim();
    if (raw.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the TV Display URL first.')),
      );
      return;
    }

    final withScheme = raw.contains('://') ? raw : 'http://$raw';

    Uri parsed;
    try {
      parsed = Uri.parse(withScheme);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid TV URL.')),
      );
      return;
    }

    // Normalize to origin + root path.
    final base = parsed.replace(
      path: '/',
      query: '',
      fragment: '',
    );

    await prefs.setString('tvDisplayBaseUrl', base.origin);

    final tvUrl = base.replace(
      path: '/',
      queryParameters: const <String, String>{
        'mode': 'tv',
        'reset': '1',
      },
    ).toString();

    if (kIsWeb) {
      WebLocation.assign(tvUrl);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Open this URL in a browser: $tvUrl')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect TV Display'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Enter the URL where the TV display app is running.',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _urlController,
                        decoration: const InputDecoration(
                          labelText: 'TV Display URL',
                          hintText: 'http://localhost:12345',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _openTv,
                        child: const Text('Open TV Pairing Screen'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
