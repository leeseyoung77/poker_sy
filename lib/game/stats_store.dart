import 'storage_stub.dart' if (dart.library.html) 'storage_web.dart' as store;

class StatsStore {
  static const _key = 'poker5.stats.v1';

  static String? load() {
    try {
      return store.read(_key);
    } catch (_) {
      return null;
    }
  }

  static void save(String jsonString) {
    try {
      store.write(_key, jsonString);
    } catch (_) {
      // ignore storage failures (private browsing, etc.)
    }
  }
}
