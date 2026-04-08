import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/model/subscription.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository();
});

class SubscriptionRepository {
  List<Subscription> _subscriptions = [];
  bool _loaded = false;

  List<Subscription> get subscriptions => List.unmodifiable(_subscriptions);

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    await load();
  }

  Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/subscriptions.json');
  }

  Future<void> load() async {
    try {
      final file = await _file;
      if (await file.exists()) {
        final json = await file.readAsString();
        final list = jsonDecode(json) as List;
        _subscriptions = list
            .map((e) => Subscription.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      _subscriptions = [];
    }
    _loaded = true;
  }

  Future<void> _save() async {
    final file = await _file;
    await file.writeAsString(
        jsonEncode(_subscriptions.map((s) => s.toJson()).toList()));
  }

  Future<List<Subscription>> getAll() async {
    await _ensureLoaded();
    return subscriptions;
  }

  Future<Subscription?> getById(String id) async {
    await _ensureLoaded();
    try {
      return _subscriptions.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<Subscription?> getByUrl(String url) async {
    await _ensureLoaded();
    try {
      return _subscriptions.firstWhere((s) => s.url == url);
    } catch (_) {
      return null;
    }
  }

  Future<void> add(Subscription sub) async {
    await _ensureLoaded();
    // Duplicate check
    final existing = _subscriptions.where((s) => s.url == sub.url);
    if (existing.isNotEmpty) {
      // Update existing instead
      final index = _subscriptions.indexOf(existing.first);
      _subscriptions[index] = sub.copyWith(id: existing.first.id);
    } else {
      _subscriptions.add(sub);
    }
    await _save();
  }

  Future<void> update(Subscription sub) async {
    await _ensureLoaded();
    final index = _subscriptions.indexWhere((s) => s.id == sub.id);
    if (index >= 0) {
      _subscriptions[index] = sub;
      await _save();
    }
  }

  Future<void> remove(String id) async {
    await _ensureLoaded();
    _subscriptions.removeWhere((s) => s.id == id);
    await _save();
  }
}
