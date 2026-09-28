final class SearchBudget {
  SearchBudget({this.maxNodes, this.maxDepth, this.maxDuration}) {
    if (maxNodes == null && maxDepth == null && maxDuration == null) {
      throw ArgumentError('At least one search limit is required.');
    }
    if (maxNodes case final value? when value <= 0) {
      throw ArgumentError.value(value, 'maxNodes', 'Must be positive.');
    }
    if (maxDepth case final value? when value <= 0) {
      throw ArgumentError.value(value, 'maxDepth', 'Must be positive.');
    }
    if (maxDuration case final value? when value <= Duration.zero) {
      throw ArgumentError.value(value, 'maxDuration', 'Must be positive.');
    }
  }

  final int? maxNodes;
  final int? maxDepth;
  final Duration? maxDuration;
}
