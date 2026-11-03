import 'package:flutter/services.dart';

bool enableScanSuccessSound() => true;

bool playScanSuccessSound() {
  // This branch is for the native Staff app, not Flutter Web.
  SystemSound.play(SystemSoundType.click);
  return true;
}
