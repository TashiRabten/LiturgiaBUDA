import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class DatabaseService {
  static Database? _db;

  Future<Database> get db async {
    _db ??= await init();
    return _db!;
  }

  Future<Database> init() async {
    // Usa Documents/LiturgiaBUDA — funciona em Program Files sem precisar
    // de permissão de administrador, e evita o OneDrive.
    final docsPath = _getDocumentsPath();
    final appDir = Directory(p.join(docsPath, 'LiturgiaBUDA'));
    if (!appDir.existsSync()) {
      appDir.createSync(recursive: true);
    }
    final path = p.join(appDir.path, 'liturgiabuda.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
    );

    return _db!;
  }

  /// Retorna o caminho real de Documents do Windows sem depender do OneDrive.
  /// Usa a variável de ambiente USERPROFILE que sempre aponta para
  /// C:\Users\<usuario>, independente de redirecionamento do OneDrive.
  String _getDocumentsPath() {
    if (Platform.isWindows) {
      // USERPROFILE é sempre C:\Users\<usuario> — não segue o OneDrive
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        return p.join(userProfile, 'Documents');
      }
    }
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        return p.join(home, 'Documents');
      }
    }
    if (Platform.isLinux) {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        return p.join(home, 'Documents');
      }
    }
    // Fallback: usa o getDatabasesPath padrão do sqflite
    return '.';
  }

  Future<void> _createTables(Database db, int version) async {
    // Fluxos
    await db.execute('''
      CREATE TABLE fluxos (
        id INTEGER PRIMARY KEY,
        nome TEXT NOT NULL,
        descricao TEXT,
        total_dias INTEGER NOT NULL,
        total_periodos INTEGER NOT NULL DEFAULT 3,
        ativo INTEGER DEFAULT 1
      )
    ''');

    // Textos das sessões
    await db.execute('''
      CREATE TABLE textos (
        id INTEGER PRIMARY KEY,
        fluxo_id INTEGER NOT NULL,
        periodo INTEGER,
        dia INTEGER NOT NULL,
        sessao TEXT NOT NULL,
        conteudo TEXT NOT NULL,
        autor TEXT,
        fonte TEXT,
        updated_at TEXT,
        FOREIGN KEY (fluxo_id) REFERENCES fluxos(id)
      )
    ''');

    // Textos fixos (refúgio, dedicatória, sutras, sadhana)
    await db.execute('''
      CREATE TABLE textos_fixos (
        id INTEGER PRIMARY KEY,
        tipo TEXT NOT NULL,
        nome TEXT NOT NULL,
        conteudo TEXT NOT NULL,
        opcional INTEGER DEFAULT 0,
        ordem INTEGER DEFAULT 0,
        updated_at TEXT
      )
    ''');

    // Metadata de sync
    await db.execute('''
      CREATE TABLE sync_metadata (
        chave TEXT PRIMARY KEY,
        valor TEXT
      )
    ''');

    // Progresso do usuário
    await db.execute('''
      CREATE TABLE progresso (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fluxo_id INTEGER NOT NULL,
        dia_atual INTEGER DEFAULT 1,
        sessao_atual TEXT DEFAULT 'manha',
        data_inicio TEXT,
        FOREIGN KEY (fluxo_id) REFERENCES fluxos(id)
      )
    ''');

    // Insere fluxos iniciais
    await db.insert('fluxos', {
      'id': 1,
      'nome': 'principal',
      'descricao': 'Renúncia, Bodhicitta Aspirativa, Bodhicitta Última',
      'total_dias': 360,
      'total_periodos': 3,
      'ativo': 1,
    });

    await db.insert('fluxos', {
      'id': 2,
      'nome': 'prajnaparamita',
      'descricao': 'Prajnaparamita o ano todo',
      'total_dias': 365,
      'total_periodos': 1,
      'ativo': 1,
    });
  }

  // ── Textos ──────────────────────────────────────────

  Future<Map<String, dynamic>?> getTexto({
    required int fluxoId,
    required int dia,
    required String sessao,
    int? periodo,
  }) async {
    final database = await db;

    if (periodo != null) {
      final exact = await database.query(
        'textos',
        where: 'fluxo_id = ? AND dia = ? AND sessao = ? AND periodo = ?',
        whereArgs: [fluxoId, dia, sessao, periodo],
        limit: 1,
      );
      if (exact.isNotEmpty) return exact.first;
    }

    final result = await database.query(
      'textos',
      where: 'fluxo_id = ? AND dia = ? AND sessao = ? AND periodo IS NULL',
      whereArgs: [fluxoId, dia, sessao],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getTextosFixosPorTipo(String tipo) async {
    final database = await db;
    return database.query(
      'textos_fixos',
      where: 'tipo = ?',
      whereArgs: [tipo],
      orderBy: 'ordem ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getTodosTextosFixos() async {
    final database = await db;
    return database.query('textos_fixos', orderBy: 'tipo ASC, ordem ASC');
  }

  // ── Sync metadata ────────────────────────────────────

  Future<String?> getMetadata(String chave) async {
    final database = await db;
    final result = await database.query(
      'sync_metadata',
      where: 'chave = ?',
      whereArgs: [chave],
      limit: 1,
    );
    return result.isNotEmpty ? result.first['valor'] as String? : null;
  }

  Future<void> setMetadata(String chave, String valor) async {
    final database = await db;
    await database.insert(
      'sync_metadata',
      {'chave': chave, 'valor': valor},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── Progresso ────────────────────────────────────────

  Future<Map<String, dynamic>?> getProgresso(int fluxoId) async {
    final database = await db;
    final result = await database.query(
      'progresso',
      where: 'fluxo_id = ?',
      whereArgs: [fluxoId],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<void> upsertProgresso({
    required int fluxoId,
    required int dia,
    required String sessao,
  }) async {
    final database = await db;
    final existing = await getProgresso(fluxoId);
    if (existing == null) {
      await database.insert('progresso', {
        'fluxo_id': fluxoId,
        'dia_atual': dia,
        'sessao_atual': sessao,
        'data_inicio': DateTime.now().toIso8601String(),
      });
    } else {
      await database.update(
        'progresso',
        {'dia_atual': dia, 'sessao_atual': sessao},
        where: 'fluxo_id = ?',
        whereArgs: [fluxoId],
      );
    }
  }

  // ── Upsert textos (usado no sync) ────────────────────

  Map<String, Object?> _sanitizar(Map<String, dynamic> row) {
    final out = <String, Object?>{};
    for (final entry in row.entries) {
      final v = entry.value;
      if (v is bool) {
        out[entry.key] = v ? 1 : 0;
      } else if (v is DateTime) {
        out[entry.key] = v.toIso8601String();
      } else {
        out[entry.key] = v;
      }
    }
    return out;
  }

  Future<void> upsertTexto(Map<String, dynamic> texto) async {
    final database = await db;
    await database.insert(
      'textos',
      _sanitizar(texto),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertTextoFixo(Map<String, dynamic> textoFixo) async {
    final database = await db;
    await database.insert(
      'textos_fixos',
      _sanitizar(textoFixo),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── Reconciliação ────────────────────────────────────

  Future<int> _deletarForaDe(String tabela, Set<int> idsValidos) async {
    final database = await db;
    if (idsValidos.isEmpty) {
      return database.delete(tabela);
    }
    final placeholders = List.filled(idsValidos.length, '?').join(',');
    final args = idsValidos.toList();
    return database.rawDelete(
      'DELETE FROM $tabela WHERE id NOT IN ($placeholders)',
      args,
    );
  }

  Future<int> deletarTextosForaDe(Set<int> idsValidos) =>
      _deletarForaDe('textos', idsValidos);

  Future<int> deletarTextosFixosForaDe(Set<int> idsValidos) =>
      _deletarForaDe('textos_fixos', idsValidos);

  Future<void> deleteTexto(int id) async {
    final database = await db;
    await database.delete('textos', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteTextoFixo(int id) async {
    final database = await db;
    await database.delete('textos_fixos', where: 'id = ?', whereArgs: [id]);
  }
}