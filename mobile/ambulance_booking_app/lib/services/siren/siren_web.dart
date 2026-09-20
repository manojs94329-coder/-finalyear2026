// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js' as js;

class PlatformSirenPlayer {
  bool _isPlaying = false;

  void start() {
    if (_isPlaying) return;
    try {
      js.context.callMethod('eval', [
        r'''
        (function() {
          try {
            if (window.__ambulanceSirenCtx) {
              try { window.__ambulanceSirenCtx.resume(); } catch(e) {}
              return;
            }
            var AudioCtx = window.AudioContext || window.webkitAudioContext;
            if (!AudioCtx) return;
            var ctx = new AudioCtx();
            if (ctx.state === 'suspended') {
              ctx.resume();
            }
            var osc = ctx.createOscillator();
            var gain = ctx.createGain();
            osc.type = 'sawtooth';
            gain.gain.value = 0.20;
            osc.connect(gain);
            gain.connect(ctx.destination);
            osc.start(0);
            window.__ambulanceSirenCtx = ctx;
            window.__ambulanceSirenOsc = osc;
            window.__ambulanceSirenGain = gain;
            var toggle = false;
            window.__ambulanceSirenTimer = setInterval(function() {
              toggle = !toggle;
              if (window.__ambulanceSirenOsc && window.__ambulanceSirenCtx) {
                try {
                  window.__ambulanceSirenOsc.frequency.setValueAtTime(toggle ? 960 : 660, window.__ambulanceSirenCtx.currentTime);
                } catch(e) {}
              }
            }, 450);
          } catch(e) {
            console.warn("Emergency siren audio error:", e);
          }
        })();
        '''
      ]);
      _isPlaying = true;
    } catch (_) {}
  }

  void stop() {
    try {
      _isPlaying = false;
      js.context.callMethod('eval', [
        r'''
        (function() {
          try {
            if (window.__ambulanceSirenTimer) {
              clearInterval(window.__ambulanceSirenTimer);
              window.__ambulanceSirenTimer = null;
            }
            if (window.__ambulanceSirenOsc) {
              try { window.__ambulanceSirenOsc.stop(); } catch(e) {}
              try { window.__ambulanceSirenOsc.disconnect(); } catch(e) {}
              window.__ambulanceSirenOsc = null;
            }
            if (window.__ambulanceSirenGain) {
              try { window.__ambulanceSirenGain.disconnect(); } catch(e) {}
              window.__ambulanceSirenGain = null;
            }
            if (window.__ambulanceSirenCtx) {
              try { window.__ambulanceSirenCtx.close(); } catch(e) {}
              window.__ambulanceSirenCtx = null;
            }
          } catch(e) {}
        })();
        '''
      ]);
    } catch (_) {}
  }
}

PlatformSirenPlayer getPlatformSirenPlayer() => PlatformSirenPlayer();
