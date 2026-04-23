import 'package:web/web.dart' as web;

import 'sfx.dart' as sfx;

web.AudioContext? _ctx;

web.AudioContext _getCtx() => _ctx ??= web.AudioContext();

void init() {
  try {
    _getCtx();
  } catch (_) {
    // May throw if browser blocks AudioContext creation before gesture; safe to ignore.
  }
}

void resume() {
  final ctx = _ctx;
  if (ctx == null) return;
  if (ctx.state == 'suspended') {
    ctx.resume();
  }
}

void playTurn() {
  _playTone(freq: 784, duration: 0.16, delay: 0, gain: 0.2);
  _playTone(freq: 523, duration: 0.26, delay: 0.15, gain: 0.2);
}

void playDeal() {
  for (var i = 0; i < 5; i++) {
    _playTone(
      freq: 880 + i * 40.0,
      duration: 0.05,
      delay: i * 0.06,
      gain: 0.12,
    );
  }
}

void playFanfare() {
  // Trumpet-style rising bugle call, arpeggio, then sustained chord.
  const wave = 'triangle';
  const g = 0.24;

  // Phrase 1: short triplet "다-다-다-따-아"
  _playTone(freq: 523, duration: 0.12, delay: 0.00, gain: g, type: wave);
  _playTone(freq: 659, duration: 0.12, delay: 0.14, gain: g, type: wave);
  _playTone(freq: 784, duration: 0.12, delay: 0.28, gain: g, type: wave);
  _playTone(freq: 1046, duration: 0.40, delay: 0.42, gain: 0.28, type: wave);

  // Phrase 2: rising arpeggio through two octaves
  _playTone(freq: 523, duration: 0.10, delay: 0.95, gain: g, type: wave);
  _playTone(freq: 659, duration: 0.10, delay: 1.05, gain: g, type: wave);
  _playTone(freq: 784, duration: 0.10, delay: 1.15, gain: g, type: wave);
  _playTone(freq: 1046, duration: 0.10, delay: 1.25, gain: g, type: wave);
  _playTone(freq: 1319, duration: 0.10, delay: 1.35, gain: g, type: wave);
  _playTone(freq: 1568, duration: 0.30, delay: 1.45, gain: 0.28, type: wave);

  // Phrase 3: sustained C major chord (3 octaves layered)
  const chordStart = 1.80;
  const chordDur = 0.9;
  _playTone(freq: 262, duration: chordDur, delay: chordStart, gain: 0.12, type: wave);
  _playTone(freq: 523, duration: chordDur, delay: chordStart, gain: 0.14, type: wave);
  _playTone(freq: 659, duration: chordDur, delay: chordStart, gain: 0.14, type: wave);
  _playTone(freq: 784, duration: chordDur, delay: chordStart, gain: 0.14, type: wave);
  _playTone(freq: 1046, duration: chordDur, delay: chordStart, gain: 0.16, type: wave);

  // Tag: a sparkle at the very end
  _playTone(freq: 2093, duration: 0.18, delay: 2.7, gain: 0.20, type: 'sine');
  _playTone(freq: 2637, duration: 0.22, delay: 2.85, gain: 0.20, type: 'sine');
}

void _playTone({
  required double freq,
  required double duration,
  required double delay,
  required double gain,
  String type = 'sine',
}) {
  final ctx = _getCtx();
  final now = ctx.currentTime;
  final startAt = now + delay;
  final endAt = startAt + duration;

  final osc = ctx.createOscillator();
  osc.type = type;
  osc.frequency.value = freq;

  final effective = gain * sfx.Sfx.effectiveGain;
  final g = ctx.createGain();
  g.gain.setValueAtTime(0, startAt);
  g.gain.linearRampToValueAtTime(effective, startAt + 0.01);
  g.gain.linearRampToValueAtTime(0, endAt);

  osc.connect(g);
  g.connect(ctx.destination);

  osc.start(startAt);
  osc.stop(endAt + 0.02);
}
