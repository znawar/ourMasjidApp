import 'dart:html' as html;

import 'dart:async';

class WebLocation {
  static void assign(String url) {
    html.window.location.assign(url);
  }

  static Future<Uri?> probeLocalhostForTv({
    required int currentPort,
    int forwardPortsToCheck = 25,
    int backwardPortsToCheck = 5,
    bool wideScan = true,
    int wideScanStartPort = 49152,
    int wideScanEndPort = 65535,
    int concurrency = 64,
    Duration timeoutPerPort = const Duration(milliseconds: 200),
  }) async {
    final ports = <int>[];

    for (var i = 1; i <= forwardPortsToCheck; i++) {
      ports.add(currentPort + i);
    }
    for (var i = 1; i <= backwardPortsToCheck; i++) {
      final candidate = currentPort - i;
      if (candidate > 0) ports.add(candidate);
    }

    // Add a few common dev ports as fallbacks.
    ports.addAll(const <int>[5051, 5050, 8080, 3000]);

    final nearby = await _scanPorts(
      ports,
      currentPort: currentPort,
      timeoutPerPort: timeoutPerPort,
      concurrency: concurrency,
    );
    if (nearby != null) return nearby;

    if (!wideScan) return null;

    // Wide scan for random Flutter dev-server ports (Chrome/Edge often pick
    // ephemeral ports). Keep the range bounded so the button remains usable.
    final widePorts = <int>[];
    for (var port = wideScanStartPort; port <= wideScanEndPort; port++) {
      widePorts.add(port);
    }

    return _scanPorts(
      widePorts,
      currentPort: currentPort,
      timeoutPerPort: timeoutPerPort,
      concurrency: concurrency,
    );
  }

  static Future<Uri?> _scanPorts(
    List<int> ports, {
    required int currentPort,
    required Duration timeoutPerPort,
    required int concurrency,
  }) async {
    final seen = <int>{};
    final filtered = <int>[];
    for (final port in ports) {
      if (port <= 0) continue;
      if (port == currentPort) continue;
      if (!seen.add(port)) continue;
      filtered.add(port);
    }

    final found = Completer<Uri?>();
    var nextIndex = 0;
    var inFlight = 0;
    var stopped = false;

    Future<void> launchNext() async {
      if (stopped) return;
      if (found.isCompleted) return;

      while (
          !stopped && inFlight < concurrency && nextIndex < filtered.length) {
        final port = filtered[nextIndex++];
        inFlight++;

        () async {
          final origin = 'http://localhost:$port';
          final ok =
              await _probeFlutterWebOrigin(origin, timeout: timeoutPerPort);
          if (ok && !found.isCompleted) {
            stopped = true;
            found.complete(Uri.parse(origin));
          }
        }()
            .whenComplete(() {
          inFlight--;
          if (!found.isCompleted &&
              nextIndex >= filtered.length &&
              inFlight == 0) {
            found.complete(null);
          } else {
            // Keep pumping.
            // ignore: unawaited_futures
            launchNext();
          }
        });
      }
    }

    // Start the initial pool.
    await launchNext();
    return found.future;
  }

  static Future<bool> _probeFlutterWebOrigin(
    String origin, {
    required Duration timeout,
  }) async {
    // The main (TV) app includes a dedicated probe asset. Use that to reliably
    // distinguish it from the admin app when both are running on localhost.
    final tvProbeOk =
        await _probeImage(origin, path: '/tv_probe.svg', timeout: timeout);
    if (tvProbeOk) return true;

    // Fallback: generic Flutter assets.
    final iconOk = await _probeImage(origin,
        path: '/icons/Icon-192.png', timeout: timeout);
    if (iconOk) return true;
    return _probeImage(origin, path: '/favicon.png', timeout: timeout);
  }

  static Future<bool> _probeImage(
    String origin, {
    required String path,
    required Duration timeout,
  }) async {
    final completer = Completer<bool>();
    final probe =
        '${origin.replaceAll(RegExp(r"/+$"), '')}$path?probe=${DateTime.now().microsecondsSinceEpoch}';

    final img = html.ImageElement();
    late StreamSubscription<html.Event> loadSub;
    late StreamSubscription<html.Event> errorSub;

    Timer? timer;

    void finish(bool result) {
      if (completer.isCompleted) return;
      timer?.cancel();
      loadSub.cancel();
      errorSub.cancel();
      completer.complete(result);
    }

    loadSub = img.onLoad.listen((_) => finish(true));
    errorSub = img.onError.listen((_) => finish(false));

    img.src = probe;

    // Timeout: treat as not reachable.
    timer = Timer(timeout, () => finish(false));

    return completer.future;
  }
}
