import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/model/server_config.dart';

final serverRepositoryProvider = Provider<ServerRepository>((ref) {
  return ServerRepository();
});

class ServerRepository {
  List<ServerConfig> _servers = [];
  bool _loaded = false;

  List<ServerConfig> get servers => List.unmodifiable(_servers);

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    await load();
  }

  Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/servers.json');
  }

  Future<void> load() async {
    try {
      final file = await _file;
      if (await file.exists()) {
        final json = await file.readAsString();
        final list = jsonDecode(json) as List;
        _servers =
            list.map((e) => ServerConfig.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {
      _servers = [];
    }
    _loaded = true;
  }

  Future<void> _save() async {
    final file = await _file;
    await file.writeAsString(jsonEncode(_servers.map((s) => s.toJson()).toList()));
  }

  Future<List<ServerConfig>> getAll() async {
    await _ensureLoaded();
    return servers;
  }

  Future<List<ServerConfig>> getBySubscription(String subscriptionId) async {
    await _ensureLoaded();
    return _servers.where((s) => s.subscriptionId == subscriptionId).toList();
  }

  Future<ServerConfig?> getById(String id) async {
    await _ensureLoaded();
    try {
      return _servers.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> add(ServerConfig server) async {
    await _ensureLoaded();
    _servers.add(server);
    await _save();
  }

  Future<void> addAll(List<ServerConfig> newServers) async {
    await _ensureLoaded();
    _servers.addAll(newServers);
    await _save();
  }

  Future<void> update(ServerConfig server) async {
    await _ensureLoaded();
    final index = _servers.indexWhere((s) => s.id == server.id);
    if (index >= 0) {
      _servers[index] = server;
      await _save();
    }
  }

  Future<void> remove(String id) async {
    await _ensureLoaded();
    _servers.removeWhere((s) => s.id == id);
    await _save();
  }

  Future<void> removeBySubscription(String subscriptionId) async {
    await _ensureLoaded();
    _servers.removeWhere((s) => s.subscriptionId == subscriptionId);
    await _save();
  }

  Future<void> replaceForSubscription(
      String subscriptionId, List<ServerConfig> newServers) async {
    await _ensureLoaded();
    _servers.removeWhere((s) => s.subscriptionId == subscriptionId);
    _servers.addAll(newServers);
    await _save();
  }
}
