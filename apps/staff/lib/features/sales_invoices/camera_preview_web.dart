import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

const String _viewType = 'pharmaflow-staff-camera-html-preview';

// A view factory is registered only in the web build. The video is injected
// only after the scanner's existing camera stream becomes live.
final bool _registered = ui_web.platformViewRegistry.registerViewFactory(
  _viewType,
  (int viewId) {
    final host = html.DivElement();
    host.id = 'pharmaflow-staff-camera-host-$viewId';
    host.setAttribute('data-pharmaflow-staff-camera-host', 'true');
    host.style
      ..width = '100%'
      ..height = '100%'
      ..overflow = 'hidden'
      ..pointerEvents = 'none'
      ..backgroundColor = 'transparent';
    return host;
  },
);

Widget buildCameraPreview() {
  if (!_registered) return const SizedBox.shrink();
  return const HtmlElementView(viewType: _viewType);
}
