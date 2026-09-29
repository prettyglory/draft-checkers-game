final class AspirationWindowConfig {
  AspirationWindowConfig({
    this.initialHalfWidth = 50,
    this.wideningFactor = 2,
    this.maxWindowedAttempts = 4,
    this.enabled = true,
  }) {
    if (initialHalfWidth <= 0) {
      throw ArgumentError.value(
        initialHalfWidth,
        'initialHalfWidth',
        'Must be positive.',
      );
    }
    if (wideningFactor < 2) {
      throw ArgumentError.value(
        wideningFactor,
        'wideningFactor',
        'Must be at least two.',
      );
    }
    if (maxWindowedAttempts <= 0) {
      throw ArgumentError.value(
        maxWindowedAttempts,
        'maxWindowedAttempts',
        'Must be positive.',
      );
    }
  }

  factory AspirationWindowConfig.disabled() {
    return AspirationWindowConfig(enabled: false);
  }

  final int initialHalfWidth;
  final int wideningFactor;
  final int maxWindowedAttempts;
  final bool enabled;
}

final class AspirationDiagnostics {
  const AspirationDiagnostics({
    this.attempts = 0,
    this.failLow = 0,
    this.failHigh = 0,
    this.reSearches = 0,
    this.maximumWindowWidth = 0,
    this.fullWindowFallback = false,
  });

  final int attempts;
  final int failLow;
  final int failHigh;
  final int reSearches;
  final int maximumWindowWidth;
  final bool fullWindowFallback;
}
