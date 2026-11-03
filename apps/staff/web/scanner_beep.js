// Original short success chirp. Unlock on the first genuine user gesture.
// Mobile Chrome forbids Web Audio playback until the user interacts with a page.
(() => {
  let context;
  function ensureContext() {
    if (context && context.state !== 'closed') return context;
    const AudioContextClass = window.AudioContext || window.webkitAudioContext;
    if (!AudioContextClass) return null;
    context = new AudioContextClass();
    return context;
  }
  function unlock() {
    try {
      const ctx = ensureContext();
      if (!ctx) return false;
      if (ctx.state === 'suspended') ctx.resume().catch(() => {});
      return true;
    } catch (_) {
      return false;
    }
  }
  function beep() {
    if (!context || context.state !== 'running') return false;
    const start = context.currentTime;
    const osc = context.createOscillator();
    const gain = context.createGain();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(1040, start);
    osc.frequency.exponentialRampToValueAtTime(870, start + 0.11);
    gain.gain.setValueAtTime(0.0001, start);
    gain.gain.exponentialRampToValueAtTime(0.16, start + 0.012);
    gain.gain.exponentialRampToValueAtTime(0.0001, start + 0.13);
    osc.connect(gain);
    gain.connect(context.destination);
    osc.onended = () => { osc.disconnect(); gain.disconnect(); };
    osc.start(start);
    osc.stop(start + 0.14);
    return true;
  }
  // Works for tapping the "new invoice" button as well as the sound test.
  document.addEventListener('pointerdown', unlock, { capture: true, passive: true });
  document.addEventListener('keydown', unlock, { capture: true });
  window.PharmaFlowScanBeep = {
    enable() {
      if (!unlock()) return false;
      // This method is called from the explicit test button; play a real sample.
      if (context.state === 'running') {
        beep();
      } else {
        context.resume().then(beep).catch(() => {});
      }
      return true;
    },
    play() { return beep(); },
  };
})();
