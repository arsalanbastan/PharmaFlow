/* PharmaFlow Staff Web - iOS-only MediaStream inline preview compatibility.
 * Loaded before flutter_bootstrap.js so MobileScanner's detached <video>
 * gets playsinline/muted before its first play() call.
 * No changes to camera selection, stream acquisition, or barcode decoding.
 */
(() => {
  'use strict';

  const iosDevice = /iPad|iPhone|iPod/.test(navigator.userAgent || '') ||
    (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  if (!iosDevice || !window.HTMLMediaElement || !window.HTMLVideoElement) return;

  const prototype = window.HTMLMediaElement.prototype;
  const originalPlay = prototype.play;
  if (typeof originalPlay !== 'function' || originalPlay.__pharmaflowIosPreview) return;

  function playWithInlineCameraPreview(...args) {
    // Patch ONLY camera MediaStreams on iOS. Ordinary audio/video is unchanged.
    const cameraStream = this instanceof window.HTMLVideoElement &&
      this.srcObject && typeof this.srcObject.getVideoTracks === 'function' &&
      this.srcObject.getVideoTracks().length > 0;

    if (cameraStream) {
      // Safari requires these BEFORE the first play(), even if the video
      // element is still detached from the page (as it is in mobile_scanner).
      this.playsInline = true;
      this.setAttribute('playsinline', '');
      this.setAttribute('webkit-playsinline', '');
      this.muted = true;
      this.defaultMuted = true;
      this.setAttribute('muted', '');
      this.autoplay = true;
      this.setAttribute('autoplay', '');
    }
    return originalPlay.apply(this, args);
  }

  Object.defineProperty(playWithInlineCameraPreview, '__pharmaflowIosPreview', {
    value: true,
  });
  prototype.play = playWithInlineCameraPreview;
})();
