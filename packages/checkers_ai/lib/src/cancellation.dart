abstract interface class AiCancellationToken {
  bool get isCancelled;
}

final class NoCancellationToken implements AiCancellationToken {
  const NoCancellationToken();

  @override
  bool get isCancelled => false;
}

final class AiCancellationController {
  final _MutableCancellationToken _token = _MutableCancellationToken();

  AiCancellationToken get token => _token;

  void cancel() {
    _token._cancelled = true;
  }
}

final class _MutableCancellationToken implements AiCancellationToken {
  bool _cancelled = false;

  @override
  bool get isCancelled => _cancelled;
}

final class AiSearchCancelledException implements Exception {
  const AiSearchCancelledException();

  @override
  String toString() => 'AI search was cancelled.';
}
