// A short original scanner confirmation tone. No extra Flutter dependency.
(() => {
  let context;
  window.PharmaFlowScanBeep = {
    enable() {
      try {
        const AudioContextClass = window.AudioContext || window.webkitAudioContext;
        if (!AudioContextClass) return false;
        context ||= new AudioContextClass();
        if (context.state === 'suspended') {
          // Called directly from the sound button's user-initiated tap.
          context.resume().catch(() => {});
        }
        return true;
      } catch (_) {
        return false;
      }
    },
    play() {
      if (!context || context.state !== 'running') return;
      const start = context.currentTime;
      const oscillator = context.createOscillator();
      const gain = context.createGain();
      oscillator.type = 'sine';
      oscillator.frequency.setValueAtTime(960, start);
      gain.gain.setValueAtTime(0.0001, start);
      gain.gain.exponentialRampToValueAtTime(0.11, start + 0.012);
      gain.gain.exponentialRampToValueAtTime(0.0001, start + 0.11);
      oscillator.connect(gain);
      gain.connect(context.destination);
      oscillator.onended = () => { oscillator.disconnect(); gain.disconnect(); };
      oscillator.start(start);
      oscillator.stop(start + 0.12);
    },
  };
})();
