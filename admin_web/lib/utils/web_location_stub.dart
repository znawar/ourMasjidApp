class WebLocation {
  static void assign(String url) {
    throw UnsupportedError('WebLocation.assign is only available on web');
  }

  static Future<Uri?> probeLocalhostForTv({
    required int currentPort,
    int forwardPortsToCheck = 25,
    int backwardPortsToCheck = 5,
    bool wideScan = true,
    int wideScanStartPort = 50000,
    int wideScanEndPort = 61000,
    int concurrency = 64,
    Duration timeoutPerPort = const Duration(milliseconds: 200),
  }) {
    throw UnsupportedError(
        'WebLocation.probeLocalhostForTv is only available on web');
  }
}
