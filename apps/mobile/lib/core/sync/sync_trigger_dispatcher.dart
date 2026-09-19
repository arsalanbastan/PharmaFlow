import 'dart:async';
import 'package:flutter/foundation.dart';

import 'sync_trigger.dart';

class SyncTriggerDispatcher {
  SyncTriggerDispatcher._();

  static final SyncTriggerDispatcher instance = SyncTriggerDispatcher._();

  final StreamController<SyncTrigger> _controller =
      StreamController<SyncTrigger>.broadcast();

  Stream<SyncTrigger> get stream => _controller.stream;

  void request(SyncTrigger trigger) {
    debugPrint('ENTER: sync_trigger_dispatcher.dart -> request');
    if (_controller.isClosed) {
      debugPrint('EXIT: sync_trigger_dispatcher.dart -> request');
      return;
    }

    _controller.add(trigger);
    debugPrint('EXIT: sync_trigger_dispatcher.dart -> request');
  }
}
