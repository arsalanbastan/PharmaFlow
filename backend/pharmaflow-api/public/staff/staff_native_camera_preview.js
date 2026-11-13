/* PharmaFlow Staff: web-only camera preview fallback.
 * Mirrors the MediaStream already opened by mobile_scanner into an HTML video
 * in the invoice scanner's HtmlElementView. No getUserMedia, no network calls.
 * Does not alter barcode decoding, invoice processing or Android native builds.
 */
(() => {
  'use strict';
  if (!window.HTMLVideoElement || !window.HTMLMediaElement) return;
  if (window.__pharmaflowStaffCameraMirrorInstalled) return;
  window.__pharmaflowStaffCameraMirrorInstalled = true;

  const originalPlay = HTMLMediaElement.prototype.play;
  const HOST_SELECTOR = '[data-pharmaflow-staff-camera-host]';
  let host = null;
  let mirror = null;
  let source = null;

  function isLiveScannerVideo(v) {
    if (!(v instanceof HTMLVideoElement) || v === mirror) return false;
    const s = v.srcObject;
    return !!(s && typeof s.getVideoTracks === 'function' &&
      s.getVideoTracks().some(t => t.readyState === 'live'));
  }

  function visitRoots(root, visitor, depth = 0) {
    if (!root || !root.querySelectorAll || depth > 8) return null;
    const direct = visitor(root);
    if (direct) return direct;
    for (const element of root.querySelectorAll('*')) {
      if (element.shadowRoot) {
        const found = visitRoots(element.shadowRoot, visitor, depth + 1);
        if (found) return found;
      }
    }
    return null;
  }

  function findHost() {
    return visitRoots(document, root => root.querySelector(HOST_SELECTOR));
  }

  function findSource() {
    return visitRoots(document, root => {
      for (const video of root.querySelectorAll('video')) {
        if (isLiveScannerVideo(video)) return video;
      }
      return null;
    });
  }

  function cleanupMirror() {
    if (!mirror) return;
    mirror.pause();
    mirror.srcObject = null;
    mirror.remove();
    mirror = null;
  }

  function createMirror(target) {
    const v = document.createElement('video');
    v.id = 'pharmaflow-staff-camera-native-preview';
    v.setAttribute('playsinline', '');
    v.setAttribute('webkit-playsinline', '');
    v.setAttribute('autoplay', '');
    v.setAttribute('muted', '');
    v.autoplay = true;
    v.playsInline = true;
    v.muted = true;
    v.defaultMuted = true;
    // Hidden until playback actually starts: fall back to original scanner UI.
    v.style.cssText = 'display:none!important;width:100%!important;height:100%!important;object-fit:cover!important;background:transparent!important;pointer-events:none!important;';
    v.addEventListener('playing', () => {
      if (v === mirror) v.style.setProperty('display', 'block', 'important');
    });
    v.addEventListener('pause', () => {
      if (v === mirror) v.style.setProperty('display', 'none', 'important');
    });
    target.appendChild(v);
    return v;
  }

  function sync() {
    const nextHost = findHost();
    if (nextHost !== host) {
      cleanupMirror();
      host = nextHost;
    }
    if (!host) { source = null; return; }

    if (!isLiveScannerVideo(source)) source = findSource();
    if (!source) { cleanupMirror(); return; }
    const stream = source.srcObject;
    if (!mirror) mirror = createMirror(host);
    if (mirror.srcObject === stream) return;

    mirror.srcObject = stream;
    try {
      const result = originalPlay.call(mirror);
      if (result && typeof result.catch === 'function') {
        result.catch(() => {
          if (mirror) mirror.style.setProperty('display', 'none', 'important');
        });
      }
    } catch (_ignored) {
      mirror.style.setProperty('display', 'none', 'important');
    }
  }

  // Capture streams that are not visible in ordinary DOM (Flutter shadow roots).
  HTMLMediaElement.prototype.play = function(...args) {
    if (isLiveScannerVideo(this)) source = this;
    const result = originalPlay.apply(this, args);
    if (source === this && host) queueMicrotask(sync);
    return result;
  };

  // Keep the mirror in sync when Flutter mounts/removes the invoice camera.
  const poll = setInterval(sync, 650);
  window.addEventListener('pagehide', () => {
    clearInterval(poll);
    cleanupMirror();
    source = null;
  }, {once: true});
})();
