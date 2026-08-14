enum CircuitState { closed, open, halfOpen }

class ProxyCircuitBreaker {
  final int maxFailures;
  final Duration cooldownDuration;

  int _failureCount = 0;
  CircuitState _state = CircuitState.closed;
  DateTime? _lastStateChange;

  ProxyCircuitBreaker({
    this.maxFailures = 3,
    this.cooldownDuration = const Duration(minutes: 5),
  });

  CircuitState get state {
    if (_state == CircuitState.open && _lastStateChange != null) {
      if (DateTime.now().difference(_lastStateChange!) > cooldownDuration) {
        _state = CircuitState.halfOpen;
        _lastStateChange = DateTime.now();
      }
    }
    return _state;
  }

  bool get isAvailable => state != CircuitState.open;

  void onSuccess() {
    _failureCount = 0;
    _state = CircuitState.closed;
    _lastStateChange = DateTime.now();
  }

  void onFailure() {
    _failureCount++;
    if (_failureCount >= maxFailures) {
      _state = CircuitState.open;
      _lastStateChange = DateTime.now();
    }
  }

  void reset() {
    _failureCount = 0;
    _state = CircuitState.closed;
    _lastStateChange = DateTime.now();
  }
}
