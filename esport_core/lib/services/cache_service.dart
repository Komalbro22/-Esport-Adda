import 'dart:async';

class CacheEntry<T> {
  final T data;
  final DateTime expiry;

  CacheEntry(this.data, this.expiry);

  bool get isExpired => DateTime.now().isAfter(expiry);
}

class CacheService {
  static final Map<String, CacheEntry> _cache = {};

  /// Set data in cache with a specific key and duration
  static void set(String key, dynamic data, {Duration duration = const Duration(minutes: 5)}) {
    _cache[key] = CacheEntry(data, DateTime.now().add(duration));
  }

  /// Get data from cache. Returns null if not found or expired.
  static T? get<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    
    if (entry.isExpired) {
      _cache.remove(key);
      return null;
    }
    
    return entry.data as T?;
  }

  /// Remove specific key from cache
  static void invalidate(String key) {
    _cache.remove(key);
  }

  /// Clear all cache
  static void clear() {
    _cache.clear();
  }
}
