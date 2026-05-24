import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_service.dart';

class SyncService extends ChangeNotifier {
  final DatabaseService _db;
  final _supabase = Supabase.instance.client;

  bool _syncing = false;
  String? _erro;
  DateTime? _ultimoSync;

  bool get syncing => _syncing;
  String? get erro => _erro;
  DateTime? get ultimoSync => _ultimoSync;

  SyncService(this._db) {
    syncIfNeeded();
  }

  Future<void> syncIfNeeded() async {
    final ultimoSyncStr = await _db.getMetadata('ultimo_sync');
    if (ultimoSyncStr != null) {
      final ultimo = DateTime.parse(ultimoSyncStr);
      // Só sincroniza se passou mais de 1 hora
      if (DateTime.now().difference(ultimo).inHours < 1) return;
    }
    await sync();
  }

  Future<void> sync() async {
    if (_syncing) return;
    _syncing = true;
    _erro = null;
    notifyListeners();

    try {
      await _syncTextosFixos();
      await _syncTextos();

      _ultimoSync = DateTime.now();
      await _db.setMetadata('ultimo_sync', _ultimoSync!.toIso8601String());
    } catch (e) {
      _erro = 'Erro ao sincronizar: $e';
      debugPrint('[SyncService] $_erro');
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  /// Sync completo de `textos_fixos`: faz upsert de todos os registros
  /// que existem no Supabase e DELETA localmente os que não existem mais lá.
  /// Detecta deletions sem precisar de tombstones / soft delete.
  Future<void> _syncTextosFixos() async {
    final data = await _supabase.from('textos_fixos').select();
    final lista = List<Map<String, dynamic>>.from(data);

    final idsRemotos = <int>{};
    for (final item in lista) {
      final id = item['id'];
      if (id is int) idsRemotos.add(id);
      await _db.upsertTextoFixo(item);
    }

    final removidos = await _db.deletarTextosFixosForaDe(idsRemotos);

    await _db.setMetadata(
        'ultimo_sync_fixos', DateTime.now().toIso8601String());
    debugPrint(
        '[SyncService] textos_fixos: ${lista.length} sincronizados, $removidos removidos');
  }

  /// Sync completo de `textos` (leituras). Mesmo padrão dos textos_fixos.
  Future<void> _syncTextos() async {
    final data = await _supabase.from('textos').select();
    final lista = List<Map<String, dynamic>>.from(data);

    final idsRemotos = <int>{};
    for (final item in lista) {
      final id = item['id'];
      if (id is int) idsRemotos.add(id);
      await _db.upsertTexto(item);
    }

    final removidos = await _db.deletarTextosForaDe(idsRemotos);

    await _db.setMetadata(
        'ultimo_sync_textos', DateTime.now().toIso8601String());
    debugPrint(
        '[SyncService] textos: ${lista.length} sincronizados, $removidos removidos');
  }
}