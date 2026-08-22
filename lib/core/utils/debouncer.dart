import 'dart:async';

import 'package:flutter/foundation.dart' show VoidCallback;

/// Debounces rapid successive calls, keeping only the latest.
class Debouncer {
  Debouncer(this.duration);

  final Duration duration;
  Timer? _timer;

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => cancel();
}
