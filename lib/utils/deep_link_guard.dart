class DeepLinkGuard {
  DeepLinkGuard({this.deduplicationWindow = const Duration(seconds: 2)});

  final Duration deduplicationWindow;
  String? _lastUri;
  DateTime? _lastHandledAt;
  bool _navigationInProgress = false;

  bool tryBegin(Uri uri, {DateTime? now}) {
    final timestamp = now ?? DateTime.now();
    final duplicate =
        _lastUri == uri.toString() &&
        _lastHandledAt != null &&
        timestamp.difference(_lastHandledAt!) < deduplicationWindow;
    if (_navigationInProgress || duplicate) return false;
    _navigationInProgress = true;
    _lastUri = uri.toString();
    _lastHandledAt = timestamp;
    return true;
  }

  void finish() => _navigationInProgress = false;
}
