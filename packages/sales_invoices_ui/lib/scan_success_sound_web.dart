import 'dart:js_interop';

@JS('PharmaFlowScanBeep.enable')
external JSBoolean _enableWebBeep();

@JS('PharmaFlowScanBeep.play')
external JSBoolean _playWebBeep();

@JS('PharmaFlowScanBeep.error')
external JSBoolean _playWebErrorBeep();

/// Must be called from a user's tap to satisfy mobile browser audio policies.
bool enableScanSuccessSound() {
  try {
    return _enableWebBeep().toDart;
  } catch (_) {
    return false;
  }
}

bool playScanSuccessSound() {
  try {
    return _playWebBeep().toDart;
  } catch (_) {
    // Sound is optional; it must never prevent an invoice item being added.
    return false;
  }
}

bool playScanErrorSound() {
  try {
    return _playWebErrorBeep().toDart;
  } catch (_) {
    // Sound is optional; it must never block scanning or lookup feedback.
    return false;
  }
}
