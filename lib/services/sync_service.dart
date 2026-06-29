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

  RealtimeChannel? _textosChannel;
  RealtimeChannel? _textosFixosChannel;

  SyncService(this._db) {
    syncIfNeeded();
    _subscribeRealtime();
  }

  Future<void> _upsertTextoById(int id) async {
    final data = await _supabase
        .from('textos')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (data != null && data['conteudo'] != null) {
      await _db.upsertTexto(data);
      notifyListeners();
    }
  }

  Future<void> _upsertTextoFixoById(int id) async {
    final data = await _supabase
        .from('textos_fixos')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (data != null && data['conteudo'] != null) {
      await _db.upsertTextoFixo(data);
      notifyListeners();
    }
  }

  void _subscribeRealtime() {
    _textosChannel = _supabase
        .channel('textos_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'textos',
          callback: (payload) {
            final id = payload.newRecord['id'];
            if (id is int) _upsertTextoById(id);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'textos',
          callback: (payload) {
            final id = payload.newRecord['id'];
            if (id is int) _upsertTextoById(id);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'textos',
          callback: (payload) async {
            final id = payload.oldRecord['id'];
            if (id is int) {
              await _db.deleteTexto(id);
              notifyListeners();
            }
          },
        )
        .subscribe();

    _textosFixosChannel = _supabase
        .channel('textos_fixos_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'textos_fixos',
          callback: (payload) {
            final id = payload.newRecord['id'];
            if (id is int) _upsertTextoFixoById(id);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'textos_fixos',
          callback: (payload) {
            final id = payload.newRecord['id'];
            if (id is int) _upsertTextoFixoById(id);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'textos_fixos',
          callback: (payload) async {
            final id = payload.oldRecord['id'];
            if (id is int) {
              await _db.deleteTextoFixo(id);
              notifyListeners();
            }
          },
        )

        .subscribe();
  }

  Future<void> syncIfNeeded() async {
    final ultimoSyncStr = await _db.getMetadata('ultimo_sync');
    if (ultimoSyncStr != null) {
      final ultimo = DateTime.parse(ultimoSyncStr);
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

  @override
  void dispose() {
    _textosChannel?.unsubscribe();
    _textosFixosChannel?.unsubscribe();
    super.dispose();
  }
}
