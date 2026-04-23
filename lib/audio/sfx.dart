import 'sfx_stub.dart' if (dart.library.html) 'sfx_web.dart' as impl;

class Sfx {
  /// Master volume, 0.0 – 1.0. Mute by setting to 0.
  static double volume = 0.8;
  static bool muted = false;

  static double get effectiveGain => muted ? 0 : volume;

  static void init() {
    try {
      impl.init();
    } catch (_) {}
  }

  static void resume() {
    try {
      impl.resume();
    } catch (_) {}
  }

  static void playDeal() {
    if (effectiveGain <= 0) return;
    try {
      impl.playDeal();
    } catch (_) {}
  }

  static void playTurn() {
    if (effectiveGain <= 0) return;
    try {
      impl.playTurn();
    } catch (_) {}
  }

  static void playFanfare() {
    if (effectiveGain <= 0) return;
    try {
      impl.playFanfare();
    } catch (_) {}
  }
}
