import 'dart:collection';
import 'dart:convert';

import 'package:hive/hive.dart';

/// A cached HTTP response.
class CacheEntry {
  CacheEntry(this.bytes, this.storedAt, this.ttl);

  final List<int> bytes;
  final DateTime storedAt;
  final Duration ttl;

  bool get isFresh => DateTime.now().difference(storedAt) < ttl;
}

/// Time-based cache with an in-memory LRU layer and a persistent (Hive) layer.
/// Used for HTTP responses and metadata so the app stays fast and offline-
/// tolerant without re-hitting the network for every navigation.
class CacheStore {
  CacheStore(this._box, {this.maxMemory = 300});

  final Box<String> _box;
  final int maxMemory;
  final LinkedHashMap<String, CacheEntry> _memory = LinkedHashMap<String, CacheEntry>();

  int get size => _box.length;

  Future<CacheEntry?> getBytes(String key) async {
    final mem = _memory.remove(key);
    if (mem != null && mem.isFresh) {
      _memory[key] = mem;
      return mem;
    }
    final raw = _box.get('b:$key');
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final e = CacheEntry(
        base64Decode(m['data'] as String),
        DateTime.fromMillisecondsSinceEpoch(m['ts'] as int),
        Duration(seconds: m['ttl'] as int),
      );
      if (e.isFresh) {
        _memory[key] = e;
        return e;
      }
      await _box.delete('b:$key');
    } catch (_) {
      // ignore corrupt entries
    }
    return null;
  }

  Future<void> putBytes(String key, List<int> bytes, {Duration ttl = const Duration(hours: 6)}) async {
    final e = CacheEntry(bytes, DateTime.now(), ttl);
    _memory[key] = e;
    while (_memory.length > maxMemory) {
      _memory.remove(_memory.keys.first);
    }
    await _box.put(
      'b:$key',
      jsonEncode({'ts': e.storedAt.millisecondsSinceEpoch, 'ttl': e.ttl.inSeconds, 'data': base64Encode(bytes)}),
    );
  }

  Future<String?> getString(String key) async {
    final e = await getBytes(key);
    if (e == null) return null;
    return utf8.decode(e.bytes, allowMalformed: true);
  }

  Future<void> putString(String key, String value, {Duration ttl = const Duration(hours: 6)}) =>
      putBytes(key, utf8.encode(value), ttl: ttl);

  Future<void> remove(String key) async {
    _memory.remove(key);
    await _box.delete('b:$key');
  }

  Future<void> clear() async {
    _memory.clear();
    await _box.clear();
  }
}
