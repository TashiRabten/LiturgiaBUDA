import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_html/flutter_html.dart';
import '../../services/text_extractor.dart';
import '../../services/auth_admin_service.dart';
import '../../services/sync_service.dart';
import '../../theme/buda_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AdminScreen — Painel da Secretaria
// Tabs: Inserir | Upload | Editar | Progresso
// ─────────────────────────────────────────────────────────────────────────────

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _tabIndex = 0;

  final _tabs = const [
    _InserirTab(),
    _UploadTab(),
    _EditarTab(),
    _ProgressoTab(),
    _AutorizadosTab(),
  ];

  Future<void> _sair() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sair do painel'),
        content: const Text('Deseja encerrar a sessão de administrador?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sair')),
        ],
      ),
    );
    if (confirmar == true) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: budaTheme(),
      child: Builder(builder: _buildScaffold),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final email =
        Supabase.instance.client.auth.currentUser?.email ?? 'admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel da Secretaria'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _sair,
              style: TextButton.styleFrom(foregroundColor: BudaPalette.gold),
              icon: const Icon(Icons.logout, size: 18),
              label: Text(
                email.split('@').first,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _tabIndex, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.add_box_outlined),
            selectedIcon: Icon(Icons.add_box),
            label: 'Inserir',
          ),
          NavigationDestination(
            icon: Icon(Icons.upload_file_outlined),
            selectedIcon: Icon(Icons.upload_file),
            label: 'Upload',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_note_outlined),
            selectedIcon: Icon(Icons.edit_note),
            label: 'Editar',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Progresso',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Autorizados',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers compartilhados
// ─────────────────────────────────────────────────────────────────────────────

final _supabase = Supabase.instance.client;

const _fluxos = [
  {'id': 1, 'nome': 'Fluxo Principal (360 dias)'},
  {'id': 2, 'nome': 'Fluxo Prajnaparamita (365 dias)'},
];

const _periodos = [
  {'id': 1, 'nome': '1º — Espírito da Renúncia'},
  {'id': 2, 'nome': '2º — Bodhicitta Aspirativa'},
  {'id': 3, 'nome': '3º — Bodhicitta Última'},
];

const _sessoes = ['manha', 'tarde', 'noite', 'madrugada'];
const _sessoesLabel = {
  'manha': '🌅 Manhã',
  'tarde': '☀️ Tarde',
  'noite': '🌙 Noite',
  'madrugada': '🌑 Madrugada',
};

Widget _snackErro(BuildContext ctx, String msg) {
  ScaffoldMessenger.of(ctx).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: Theme.of(ctx).colorScheme.error,
    ),
  );
  return const SizedBox.shrink();
}

void _snackOk(BuildContext ctx, String msg) {
  ScaffoldMessenger.of(ctx).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: Colors.green.shade700,
    ),
  );
}

/// Dispara sync em background após uma ação de admin (save/edit/delete).
/// Fire-and-forget — não bloqueia UX, mas o SQLite local fica em dia
/// sem o usuário precisar tocar o botão de sync manualmente.
void _disparaSync(BuildContext ctx) {
  try {
    ctx.read<SyncService>().sync();
  } catch (_) {/* sem provider acessível, ignora */}
}

// ─────────────────────────────────────────────────────────────────────────────
// Conversão HTML ↔ texto editável (Markdown-leve)
// O editor mostra texto limpo (sem tag soup). Internamente converte de volta
// pra HTML antes de salvar. Preserva *itálico*, **negrito**, # headings,
// - listas e parágrafos por linha em branco.
// ─────────────────────────────────────────────────────────────────────────────

String _htmlParaEditor(String html) {
  if (html.trim().isEmpty) return '';

  var s = html
  // Listas
      .replaceAllMapped(
      RegExp(r'<li[^>]*>(.*?)</li>', dotAll: true, caseSensitive: false),
          (m) => '- ${m[1]}\n')
      .replaceAll(
      RegExp(r'</?(ul|ol)[^>]*>', caseSensitive: false), '')

  // Headings
      .replaceAllMapped(
      RegExp(r'<h([1-6])[^>]*>(.*?)</h[1-6]>',
          dotAll: true, caseSensitive: false),
          (m) {
        final n = int.parse(m[1]!);
        return '${'#' * n} ${m[2]}\n\n';
      })

  // Blockquotes → prefixo "> " (Markdown-like, preserva a indentação)
      .replaceAllMapped(
      RegExp(r'<blockquote>(.*?)</blockquote>', dotAll: true, caseSensitive: false),
          (m) {
        // Conta o nível (blockquotes aninhados já foram expandidos no HTML)
        return m[1]!.split('\n').map((l) => '> $l').join('\n');
      })

  // Inline
      .replaceAllMapped(
      RegExp(r'<(strong|b)[^>]*>(.*?)</\1>',
          dotAll: true, caseSensitive: false),
          (m) => '**${m[2]}**')
      .replaceAllMapped(
      RegExp(r'<(em|i)[^>]*>(.*?)</\1>',
          dotAll: true, caseSensitive: false),
          (m) => '*${m[2]}*')
      .replaceAll(
      RegExp(r'</?(u|s|sub|sup|span)[^>]*>', caseSensitive: false), '')

  // Parágrafos vazios → linha em branco
      .replaceAll(
      RegExp(r'<p[^>]*>\s*(?:&nbsp;)?\s*</p>', caseSensitive: false),
      '\n')

  // Parágrafos com conteúdo
      .replaceAllMapped(
      RegExp(r'<p[^>]*>(.*?)</p>', dotAll: true, caseSensitive: false),
          (m) => '${m[1]}\n\n')

  // Breaks
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')

  // Outras tags genéricas — remove
      .replaceAll(RegExp(r'<[^>]+>'), '')

  // Entidades HTML
      .replaceAll('&emsp;', '    ')
      .replaceAll('&ensp;', '  ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&ldquo;', '\u201c')
      .replaceAll('&rdquo;', '\u201d');

  // Normaliza espaços e quebras — NÃO remove indentação de início de linha
  // (linhas com "> " ou "    " representam blockquotes/recuos intencionais).
  s = s.replaceAll(RegExp(r'[ \t]+$', multiLine: true), ''); // só trailing
  s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');

  return s.trim();
}

String _editorParaHtml(String texto) {
  final trim = texto.trim();
  if (trim.isEmpty) return '';

  final blocos = trim
      .split(RegExp(r'\n\s*\n+'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty);

  return blocos.map(_blocoParaHtml).join();
}

String _blocoParaHtml(String bloco) {
  // Heading
  final hMatch = RegExp(r'^(#{1,6})\s+(.+)$').firstMatch(bloco);
  if (hMatch != null) {
    final level = hMatch[1]!.length;
    return '<h$level>${_aplicaInline(hMatch[2]!)}</h$level>';
  }

  final linhas = bloco.split('\n');

  // Blockquote — linhas todas começando com "> "
  final ehBlockquote = linhas.every((l) => l.startsWith('> '));
  if (ehBlockquote) {
    final inner = linhas
        .map((l) => l.substring(2))
        .map(_aplicaInline)
        .join('<br>');
    return '<blockquote><p>$inner</p></blockquote>';
  }

  // Lista (linhas todas começando com "- " ou "* ")
  final ehLista = linhas.every((l) => RegExp(r'^\s*[-*]\s+').hasMatch(l));
  if (ehLista) {
    final items = linhas
        .map((l) => l.replaceFirst(RegExp(r'^\s*[-*]\s+'), ''))
        .map((l) => '<li>${_aplicaInline(l)}</li>')
        .join();
    return '<ul>$items</ul>';
  }

  // Parágrafo normal — quebras simples viram <br>
  final comBr = linhas.map(_aplicaInline).join('<br>');
  return '<p>$comBr</p>';
}

String _aplicaInline(String s) {
  // Escapa caracteres HTML antes de inserir tags reais
  String r = s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  // **bold** (precisa vir antes de *italic* pra não confundir)
  r = r.replaceAllMapped(
      RegExp(r'\*\*([^*]+)\*\*'), (m) => '<strong>${m[1]}</strong>');

  // *italic* — não pode estar imediatamente cercado de *
  r = r.replaceAllMapped(
      RegExp(r'(?<!\*)\*([^*\n]+)\*(?!\*)'), (m) => '<em>${m[1]}</em>');

  return r;
}

/// Abre um dialog que mostra como o HTML será renderizado no leitor,
/// com tabs pra alternar entre Preview e HTML cru (copiável).
Future<void> _mostrarPreviewHtml(
    BuildContext ctx, String html, String titulo) async {
  await showDialog<void>(
    context: ctx,
    builder: (dialogCtx) => DefaultTabController(
      length: 2,
      child: AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(titulo, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            const TabBar(
              labelStyle: TextStyle(fontSize: 12),
              tabs: [
                Tab(icon: Icon(Icons.preview_outlined, size: 18), text: 'Render'),
                Tab(icon: Icon(Icons.code, size: 18), text: 'HTML cru'),
              ],
            ),
          ],
        ),
        content: SizedBox(
          width: 600,
          height: 480,
          child: TabBarView(
            children: [
              // ── Tab 1: render como aparece no leitor ──
              SingleChildScrollView(
                padding: const EdgeInsets.all(8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5EDD8), // cardBege
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF8B7355).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Html(
                    data: html.trim().isEmpty
                        ? '<p><em>— sem conteúdo —</em></p>'
                        : html,
                    extensions: [
                      TagExtension(
                        tagsToExtend: {'blockquote'},
                        builder: (extensionContext) {
                          final inner = extensionContext.innerHtml;
                          return Container(
                            margin: const EdgeInsets.only(top: 4, bottom: 4),
                            padding: const EdgeInsets.only(left: 12),
                            decoration: const BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                    color: Color(0xFFB8860B), width: 3),
                              ),
                            ),
                            child: Html(
                              data: inner,
                              style: {
                                'body': Style(
                                  fontSize: FontSize(14),
                                  color: const Color(0xFF5A6080),
                                  fontStyle: FontStyle.italic,
                                  margin: Margins.zero,
                                  padding: HtmlPaddings.zero,
                                ),
                                'p': Style(
                                  margin: Margins.only(bottom: 6),
                                  padding: HtmlPaddings.zero,
                                ),
                              },
                            ),
                          );
                        },
                      ),
                      TagExtension(
                        tagsToExtend: {'doctab'},
                        child: const SizedBox(width: 28),
                      ),
                    ],
                    style: {
                      'body': Style(
                        fontSize: FontSize(14),
                        color: const Color(0xFF2C3252),
                        lineHeight: const LineHeight(1.65),
                        margin: Margins.zero,
                        padding: HtmlPaddings.zero,
                      ),
                      'p': Style(margin: Margins.only(bottom: 12)),
                      'h1': Style(
                        fontSize: FontSize(20),
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFB8860B),
                      ),
                      'h2': Style(
                        fontSize: FontSize(17),
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFB8860B),
                      ),
                      'h3': Style(
                        fontSize: FontSize(15),
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFB8860B),
                      ),
                      'strong': Style(fontWeight: FontWeight.w700),
                      'em': Style(fontStyle: FontStyle.italic),
                      'u': Style(textDecoration: TextDecoration.underline),
                      's': Style(textDecoration: TextDecoration.lineThrough),
                    },
                  ),
                ),
              ),

              // ── Tab 2: HTML cru, monospaçado, copiável ──
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${html.length} chars',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(dialogCtx)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                                ClipboardData(text: html));
                            if (dialogCtx.mounted) {
                              ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                const SnackBar(
                                  content: Text('HTML copiado.'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.copy_outlined, size: 14),
                          label: const Text('Copiar',
                              style: TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            minimumSize: const Size(0, 28),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      decoration: BoxDecoration(
                        color: Theme.of(dialogCtx)
                            .colorScheme
                            .surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          html.isEmpty ? '(vazio)' : html,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1 — Inserir texto
// ─────────────────────────────────────────────────────────────────────────────

// Tipos de conteúdo disponíveis na aba Inserir
enum _TipoConteudo { leitura, sutra, refugio, dedicatoria }

const _tipoConteudoLabel = {
  _TipoConteudo.leitura: '📖 Texto Principal',
  _TipoConteudo.sutra: '📿 Sutra',
  _TipoConteudo.refugio: '🙏 Refúgio',
  _TipoConteudo.dedicatoria: '✨ Dedicatória',
};

class _InserirTab extends StatefulWidget {
  const _InserirTab();

  @override
  State<_InserirTab> createState() => _InserirTabState();
}

class _InserirTabState extends State<_InserirTab> {
  final _formKey = GlobalKey<FormState>();
  final _conteudoController = TextEditingController();
  final _nomeFixoController = TextEditingController();
  // Campos de range de dias
  final _diaInicioCtrl = TextEditingController(text: '1');
  final _diaFimCtrl    = TextEditingController(text: '1');

  _TipoConteudo _tipo  = _TipoConteudo.leitura;
  int _fluxoId         = 1;

  // Períodos selecionados (multi)
  final Set<int> _periodosSel = {1};
  // Sessões selecionadas (multi)
  final Set<String> _sessoesSel = {'manha'};

  bool _loading = false;
  String? _ultimoResumo;

  bool get _fluxoPrincipal => _fluxoId == 1;
  bool get _isLeitura     => _tipo == _TipoConteudo.leitura;
  bool get _isTextoFixo   => !_isLeitura;

  @override
  void dispose() {
    _conteudoController.dispose();
    _nomeFixoController.dispose();
    _diaInicioCtrl.dispose();
    _diaFimCtrl.dispose();
    super.dispose();
  }

  /// Gera a lista de todas as combinações (periodo, dia, sessao) selecionadas.
  List<Map<String, dynamic>> _combinacoes() {
    final diaInicio = int.tryParse(_diaInicioCtrl.text) ?? 1;
    final diaFim    = int.tryParse(_diaFimCtrl.text)    ?? diaInicio;
    final dias      = List.generate(
        (diaFim - diaInicio).abs() + 1,
            (i) => diaInicio <= diaFim ? diaInicio + i : diaInicio - i);

    final periodos = _fluxoPrincipal
        ? (_periodosSel.isEmpty ? [null] : _periodosSel.toList()..sort())
        : [null]; // Prajnaparamita não tem período

    final sessoes = _sessoesSel.isEmpty
        ? _sessoes
        : _sessoes.where(_sessoesSel.contains).toList();

    final lista = <Map<String, dynamic>>[];
    for (final per in periodos) {
      for (final dia in dias) {
        for (final ses in sessoes) {
          lista.add({'periodo': per, 'dia': dia, 'sessao': ses});
        }
      }
    }
    return lista;
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLeitura && _sessoesSel.isEmpty) {
      _snackErro(context, 'Selecione ao menos uma sessão.');
      return;
    }
    setState(() { _loading = true; _ultimoResumo = null; });

    try {
      if (_isLeitura) {
        final conteudo = _conteudoController.text.trim();
        final combos   = _combinacoes();
        final now      = DateTime.now().toIso8601String();

        for (final c in combos) {
          await _supabase.from('textos').upsert({
            'fluxo_id': _fluxoId,
            'periodo' : c['periodo'],
            'dia'     : c['dia'],
            'sessao'  : c['sessao'],
            'conteudo': conteudo,
            'updated_at': now,
          }, onConflict: 'fluxo_id,periodo,dia,sessao');
        }
        if (!mounted) return;
        final resumo = '${combos.length} entrada(s) salva(s) — '
            'dias ${_diaInicioCtrl.text}–${_diaFimCtrl.text} · '
            '${_sessoesSel.map((s) => _sessoesLabel[s]).join(', ')}';
        setState(() => _ultimoResumo = resumo);
        _snackOk(context, resumo);
        _disparaSync(context);
      } else {
        final tipoStr = _tipo.name;
        final nome    = _nomeFixoController.text.trim().isEmpty
            ? _tipoConteudoLabel[_tipo]!.split(' ').last
            : _nomeFixoController.text.trim();
        final conteudoFixo = _conteudoController.text.trim();
        final now          = DateTime.now().toIso8601String();
        final updated = await _supabase
            .from('textos_fixos')
            .update({'conteudo': conteudoFixo, 'updated_at': now})
            .eq('tipo', tipoStr)
            .eq('nome', nome)
            .select('id');
        if ((updated as List).isEmpty) {
          await _supabase.from('textos_fixos').insert({
            'tipo'      : tipoStr,
            'nome'      : nome,
            'conteudo'  : conteudoFixo,
            'ordem'     : 0,
            'updated_at': now,
          });
        }
        if (!mounted) return;
        _snackOk(context, '${_tipoConteudoLabel[_tipo]} "$nome" salvo.');
        _disparaSync(context);
      }
      _conteudoController.clear();
    } catch (e) {
      if (mounted) _snackErro(context, 'Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxDia      = _fluxoPrincipal ? 360 : 365;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Inserir Texto',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('O mesmo conteúdo é salvo para todas as combinações selecionadas.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),

            // ── Tipo ─────────────────────────────────────
            _label('Tipo'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: _TipoConteudo.values.map((t) {
                final sel = _tipo == t;
                return ChoiceChip(
                  label: Text(_tipoConteudoLabel[t]!,
                      style: TextStyle(fontSize: 12,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
                  selected: sel,
                  onSelected: (_) => setState(() {
                    _tipo = t;
                    _conteudoController.clear();
                    _nomeFixoController.clear();
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // ── Campos de Leitura ─────────────────────────
            if (_isLeitura) ...[

              // Fluxo
              _label('Fluxo'),
              const SizedBox(height: 6),
              SegmentedButton<int>(
                segments: _fluxos.map((f) => ButtonSegment<int>(
                  value: f['id'] as int,
                  label: Text(f['nome'] as String,
                      style: const TextStyle(fontSize: 12)),
                )).toList(),
                selected: {_fluxoId},
                onSelectionChanged: (s) => setState(() {
                  _fluxoId = s.first;
                  _periodosSel
                    ..clear()
                    ..add(1);
                }),
              ),
              const SizedBox(height: 14),

              // ── Períodos (multi-select, só fluxo principal) ──
              if (_fluxoPrincipal) ...[
                Row(
                  children: [
                    _label('Períodos'),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => setState(() => _periodosSel
                        ..clear()
                        ..addAll([1, 2, 3])),
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 0),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      child: const Text('Todos', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: _periodos.map((p) {
                    final id  = p['id'] as int;
                    final sel = _periodosSel.contains(id);
                    return FilterChip(
                      label: Text(p['nome'] as String,
                          style: TextStyle(fontSize: 11,
                              fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
                      selected: sel,
                      onSelected: (v) => setState(() {
                        if (v) _periodosSel.add(id);
                        else   _periodosSel.remove(id);
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
              ],

              // ── Dias (range de–até) ───────────────────────
              Row(
                children: [
                  _label('Dias'),
                  const SizedBox(width: 8),
                  Text('(range inclusivo)',
                      style: TextStyle(
                          fontSize: 11, color: colorScheme.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: TextFormField(
                      controller: _diaInicioCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecorationSm('De').copyWith(isDense: true),
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n < 1) return 'Inválido';
                        if (n > maxDia) return 'Máx $maxDia';
                        return null;
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('até', style: TextStyle(fontSize: 13)),
                  ),
                  SizedBox(
                    width: 80,
                    child: TextFormField(
                      controller: _diaFimCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecorationSm('Até').copyWith(isDense: true),
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n < 1) return 'Inválido';
                        if (n > maxDia) return 'Máx $maxDia';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Preview da contagem
                  Builder(builder: (ctx) {
                    final ini = int.tryParse(_diaInicioCtrl.text) ?? 1;
                    final fim = int.tryParse(_diaFimCtrl.text) ?? ini;
                    final qtd = (fim - ini).abs() + 1;
                    return Text('$qtd dia(s)',
                        style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant));
                  }),
                ],
              ),
              const SizedBox(height: 14),

              // ── Sessões (multi-select) ────────────────────
              Row(
                children: [
                  _label('Sessões'),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => setState(
                            () => _sessoesSel
                          ..clear()
                          ..addAll(_sessoes)),
                    style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 0),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: const Text('Todos', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: _sessoes.map((s) {
                  final sel = _sessoesSel.contains(s);
                  return FilterChip(
                    label: Text(_sessoesLabel[s]!,
                        style: TextStyle(fontSize: 12,
                            fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
                    selected: sel,
                    onSelected: (v) => setState(() {
                      if (v) _sessoesSel.add(s);
                      else   _sessoesSel.remove(s);
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 6),

              // Resumo das combinações
              Builder(builder: (_) {
                if (_sessoesSel.isEmpty) return const SizedBox.shrink();
                final combos = _combinacoes();
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${combos.length} entrada(s) serão salvas',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSecondaryContainer),
                  ),
                );
              }),
              const SizedBox(height: 14),
            ],

            // ── Campos de Texto Fixo ──────────────────────
            if (_isTextoFixo) ...[
              _label('Nome (opcional)'),
              const SizedBox(height: 4),
              TextFormField(
                controller: _nomeFixoController,
                decoration: _inputDecorationSm(
                    'Ex: Sutra do Coração, Prece de Refúgio...')
                    .copyWith(isDense: true),
              ),
              const SizedBox(height: 14),
            ],

            // ── Conteúdo ─────────────────────────────────
            _label('Conteúdo'),
            const SizedBox(height: 4),
            TextFormField(
              controller: _conteudoController,
              maxLines: 16,
              decoration: _inputDecoration('Digite ou cole o texto aqui...')
                  .copyWith(alignLabelWithHint: true),
              validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Conteúdo obrigatório.' : null,
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _salvar,
                icon: _loading
                    ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
                    : const Icon(Icons.save_outlined, size: 18),
                label: Text(_loading ? 'Salvando...' : 'Salvar'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            // Resumo do último envio
            if (_ultimoResumo != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(_ultimoResumo!,
                    style: TextStyle(
                        fontSize: 12, color: Colors.green.shade800)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2 — Upload em lote
// ─────────────────────────────────────────────────────────────────────────────

class _UploadTab extends StatefulWidget {
  const _UploadTab();

  @override
  State<_UploadTab> createState() => _UploadTabState();
}

enum _Destino { leituras, textosFixos }

class _UploadTabState extends State<_UploadTab> {
  _Destino _destino = _Destino.leituras;

  // ── Config Leituras ────────────────────────────────
  int _fluxoId              = 1;
  bool get _fluxoPrincipal  => _fluxoId == 1;
  final Set<int>    _periodosSel = {1};
  final Set<String> _sessoesSel  = {'manha'};
  final _diaInicioCtrl = TextEditingController(text: '1');
  final _diaFimCtrl    = TextEditingController(text: '1');

  // ── Estado comum ───────────────────────────────────
  List<_ArquivoPendente> _arquivos = [];
  bool _processando = false;
  int _enviados = 0;
  int _erros = 0;
  final List<String> _log = [];

  @override
  void dispose() {
    _diaInicioCtrl.dispose();
    _diaFimCtrl.dispose();
    super.dispose();
  }

  /// Gera todas as combinações (periodo, dia, sessao) para o upload de leituras.
  List<Map<String, dynamic>> _combinacoes() {
    final ini  = int.tryParse(_diaInicioCtrl.text) ?? 1;
    final fim  = int.tryParse(_diaFimCtrl.text)    ?? ini;
    final dias = List.generate(
        (fim - ini).abs() + 1,
            (i) => ini <= fim ? ini + i : ini - i);

    final periodos = _fluxoPrincipal
        ? (_periodosSel.isEmpty ? [null] : _periodosSel.toList()..sort())
        : [null];

    final sessoes = _sessoesSel.isEmpty
        ? _sessoes
        : _sessoes.where(_sessoesSel.contains).toList();

    final lista = <Map<String, dynamic>>[];
    for (final per in periodos) {
      for (final dia in dias) {
        for (final ses in sessoes) {
          lista.add({'periodo': per, 'dia': dia, 'sessao': ses});
        }
      }
    }
    return lista;
  }

  Future<void> _selecionarArquivos() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'txt'],
    );
    if (result == null) return;

    final novos = result.files
        .where((f) => f.path != null)
        .map((f) => _destino == _Destino.leituras
        ? _ArquivoPendente(path: f.path!, nome: f.name) // dia/sessao vem dos seletores
        : _parseNomeTextoFixo(f.path!, f.name))
        .toList();

    setState(() => _arquivos = novos);
  }

  // Chamado pelo botão "Enviar" — extrai o texto e abre o popup de confirmação
  // para cada arquivo em sequência.
  Future<void> _enviar() async {
    if (_arquivos.isEmpty) return;
    if (_destino == _Destino.leituras && _sessoesSel.isEmpty) {
      _snackErro(context, 'Selecione ao menos uma sessão.');
      return;
    }
    setState(() { _processando = true; _enviados = 0; _erros = 0; _log.clear(); });

    for (final arq in _arquivos) {
      // 1. Extrai o conteúdo do arquivo (pode ser lento — mostra progresso)
      String conteudo;
      bool hasFormatting;
      try {
        final extracted = await extractFile(arq.path);
        conteudo       = extracted.markdown;
        hasFormatting  = extracted.hasFormatting;
      } catch (e) {
        setState(() { _erros++; _log.add('❌ ${arq.nome} — Erro ao ler: $e'); });
        continue;
      }

      // 2. Abre o popup de confirmação/edição
      if (!mounted) break;
      final ok = await _mostrarPopupConfirmacao(arq, conteudo, hasFormatting);
      if (ok == null) break; // usuário cancelou toda a fila

      if (!ok) {
        setState(() { _log.add('⏭️ ${arq.nome} — ignorado pelo usuário.'); });
        continue;
      }

      // 3. Salva (o popup já atualizou arq.nomeTexto / arq.tipo / arq.ordem)
      setState(() {
        _enviados++;
        final fmt = hasFormatting ? ' (formatado)' : '';
        if (_destino == _Destino.leituras) {
          _log.add('✅ ${arq.nome} → ${_combinacoes().length} combinação(ões)$fmt');
        } else {
          _log.add('✅ ${arq.nome} → ${arq.tipo} · ${arq.nomeTexto}$fmt');
        }
      });
    }

    setState(() => _processando = false);
    if (mounted) {
      _snackOk(context, '$_enviados arquivo(s) enviado(s), $_erros erro(s).');
      if (_enviados > 0) _disparaSync(context);
    }
  }

  /// Abre o dialog de confirmação/edição para um arquivo.
  /// Retorna true = salvo, false = ignorar, null = cancelar tudo.
  Future<bool?> _mostrarPopupConfirmacao(
      _ArquivoPendente arq, String conteudo, bool hasFormatting) {
    return showDialog<bool?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ConfirmacaoUploadDialog(
        arq: arq,
        conteudo: conteudo,
        hasFormatting: hasFormatting,
        isLeitura: _destino == _Destino.leituras,
        resumoCombinacoes: _destino == _Destino.leituras
            ? _resumoCombinacoes()
            : null,
        fluxoId: _fluxoId,
        combinacoes: _destino == _Destino.leituras ? _combinacoes() : null,
      ),
    );
  }

  String _resumoCombinacoes() {
    final ini      = int.tryParse(_diaInicioCtrl.text) ?? 1;
    final fim      = int.tryParse(_diaFimCtrl.text)    ?? ini;
    final nDias    = (fim - ini).abs() + 1;
    final nPer     = _fluxoPrincipal ? _periodosSel.length : 1;
    final nSes     = _sessoesSel.length;
    final total    = nDias * nPer * nSes;
    final perLabel = _fluxoPrincipal && _periodosSel.isNotEmpty
        ? 'Período(s) ${_periodosSel.toList()..sort()} · '
        : '';
    final sesLabel = _sessoesSel.map((s) => _sessoesLabel[s]).join(', ');
    return '${perLabel}Dias $ini–$fim · $sesLabel\n→ $total entrada(s) no banco';
  }

  // ── Parsers de convenção de nome ───────────────────

  _ArquivoPendente _parseNomeLeitura(
      String path, String nomeArquivo, String sessaoFallback) {
    // ex: 001_manha.pdf, 045_noite.docx, 230_madrugada.txt
    final sem = nomeArquivo.replaceAll(RegExp(r'\.(pdf|docx|txt)$'), '');
    final partes = sem.split('_');
    final dia = int.tryParse(partes.first) ?? 0;
    final sessao = partes.length > 1 && _sessoes.contains(partes[1])
        ? partes[1]
        : sessaoFallback;
    return _ArquivoPendente(
      path: path,
      nome: nomeArquivo,
      dia: dia,
      sessao: sessao,
    );
  }

  _ArquivoPendente _parseNomeTextoFixo(String path, String nomeArquivo) {
    // ex: sutra_coracao.pdf, refugio_principal.docx, dedicatoria_padrao.pdf
    final sem = nomeArquivo.replaceAll(RegExp(r'\.(pdf|docx|txt)$'), '');
    final partes = sem.split('_');
    final tipo = partes.isNotEmpty ? partes.first.toLowerCase() : 'sutra';
    final slug = partes.length > 1 ? partes.sublist(1).join('_') : 'principal';
    return _ArquivoPendente(
      path: path,
      nome: nomeArquivo,
      tipo: _tiposValidos.contains(tipo) ? tipo : 'sutra',
      nomeTexto: _formatarNomeTextoFixo(tipo, slug),
      ordem: _ordemPadrao[tipo] ?? 0,
    );
  }

  static const _tiposValidos = [
    'refugio',
    'dedicatoria',
    'invitatório',
    'sutra',
    'sadhana'
  ];

  static const _ordemPadrao = {
    'refugio': 0,
    'invitatório': 0,
    'sutra': 1,
    'sadhana': 0,
    'dedicatoria': 0,
  };

  static const _nomesConhecidos = {
    'sutra': {
      'coracao': 'Sutra do Coração',
      'coração': 'Sutra do Coração',
      'tresjoias': 'Sutra das Três Joias',
      'tres_joias': 'Sutra das Três Joias',
      'três_joias': 'Sutra das Três Joias',
      'dhammacakka': 'Dhammacakkappavattanasutta',
    },
    'refugio': {
      'principal': 'Prece de Refúgio',
      'padrao': 'Prece de Refúgio',
    },
    'dedicatoria': {
      'principal': 'Prece Dedicatória',
      'padrao': 'Prece Dedicatória',
    },
    'sadhana': {
      'gandenlhagyalma': 'Ganden Lha Gyalma',
      'ganden': 'Ganden Lha Gyalma',
    },
  };

  String _formatarNomeTextoFixo(String tipo, String slug) {
    final mapa = _nomesConhecidos[tipo];
    final lower = slug.toLowerCase();
    if (mapa != null && mapa.containsKey(lower)) return mapa[lower]!;
    // Fallback: title-case do slug
    return slug
        .split(RegExp(r'[_-]'))
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final isLeitura = _destino == _Destino.leituras;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Upload em Lote',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            'Aceita .pdf, .docx e .txt. DOCX preserva formatação (Markdown); PDF extrai texto puro.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),

          // Destino
          _label('Destino'),
          const SizedBox(height: 8),
          SegmentedButton<_Destino>(
            segments: const [
              ButtonSegment(
                value: _Destino.leituras,
                icon: Icon(Icons.menu_book_outlined, size: 18),
                label: Text('Leituras', style: TextStyle(fontSize: 12)),
              ),
              ButtonSegment(
                value: _Destino.textosFixos,
                icon: Icon(Icons.bookmark_outline, size: 18),
                label: Text('Textos Fixos', style: TextStyle(fontSize: 12)),
              ),
            ],
            selected: {_destino},
            onSelectionChanged: (s) => setState(() {
              _destino = s.first;
              _arquivos = [];
              _log.clear();
            }),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Text(
              isLeitura
                  ? 'Convenção: {dia}_{sessao}.{ext}\nExemplo: 001_manha.pdf, 045_noite.docx'
                  : 'Convenção: {tipo}_{nome}.{ext}\nTipos: refugio, dedicatoria, sutra, sadhana, invitatório\nExemplos: sutra_coracao.pdf, refugio_principal.docx',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Config específica de Leituras
          if (isLeitura) ...[

            // ── Fluxo ─────────────────────────────────
            _label('Fluxo'),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: _fluxos.map((f) => ButtonSegment<int>(
                value: f['id'] as int,
                label: Text(f['nome'] as String,
                    style: const TextStyle(fontSize: 12)),
              )).toList(),
              selected: {_fluxoId},
              onSelectionChanged: (s) => setState(() {
                _fluxoId = s.first;
                _periodosSel..clear()..add(1);
              }),
            ),

            // ── Períodos (multi-select, só fluxo principal) ──
            if (_fluxoPrincipal) ...[
              const SizedBox(height: 14),
              Row(children: [
                _label('Períodos'),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => setState(() =>
                  _periodosSel..clear()..addAll([1, 2, 3])),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: const Text('Todos', style: TextStyle(fontSize: 11)),
                ),
              ]),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: _periodos.map((p) {
                  final id  = p['id'] as int;
                  final sel = _periodosSel.contains(id);
                  return FilterChip(
                    label: Text(p['nome'] as String,
                        style: TextStyle(fontSize: 11,
                            fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
                    selected: sel,
                    onSelected: (v) => setState(() {
                      if (v) _periodosSel.add(id);
                      else   _periodosSel.remove(id);
                    }),
                  );
                }).toList(),
              ),
            ],

            // ── Dias (range De–Até) ───────────────────
            const SizedBox(height: 14),
            Row(children: [
              _label('Dias'),
              const SizedBox(width: 8),
              Text('(range inclusivo)',
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              SizedBox(
                width: 80,
                child: StatefulBuilder(builder: (ctx, setSt) =>
                    TextFormField(
                      controller: _diaInicioCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: _inputDecorationSm('De').copyWith(isDense: true),
                    )),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('até', style: TextStyle(fontSize: 13)),
              ),
              SizedBox(
                width: 80,
                child: TextFormField(
                  controller: _diaFimCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: _inputDecorationSm('Até').copyWith(isDense: true),
                ),
              ),
              const SizedBox(width: 12),
              Builder(builder: (_) {
                final ini = int.tryParse(_diaInicioCtrl.text) ?? 1;
                final fim = int.tryParse(_diaFimCtrl.text)    ?? ini;
                return Text('${(fim - ini).abs() + 1} dia(s)',
                    style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant));
              }),
            ]),

            // ── Sessões (multi-select) ────────────────
            const SizedBox(height: 14),
            Row(children: [
              _label('Sessões'),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() =>
                _sessoesSel..clear()..addAll(_sessoes)),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: const Text('Todas', style: TextStyle(fontSize: 11)),
              ),
            ]),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: _sessoes.map((s) {
                final sel = _sessoesSel.contains(s);
                return FilterChip(
                  label: Text(_sessoesLabel[s]!,
                      style: TextStyle(fontSize: 12,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
                  selected: sel,
                  onSelected: (v) => setState(() {
                    if (v) _sessoesSel.add(s);
                    else   _sessoesSel.remove(s);
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 6),

            // Resumo combinações
            Builder(builder: (_) {
              if (_sessoesSel.isEmpty) return const SizedBox.shrink();
              final n = _combinacoes().length;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Cada arquivo será salvo em $n combinação(ões)',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSecondaryContainer),
                ),
              );
            }),
            const SizedBox(height: 24),
          ],

          // Botão selecionar
          OutlinedButton.icon(
            onPressed: _processando ? null : _selecionarArquivos,
            icon: const Icon(Icons.folder_open_outlined),
            label: const Text('Selecionar Arquivos (.pdf / .docx / .txt)'),
            style: OutlinedButton.styleFrom(
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
          ),

          // Lista de arquivos selecionados
          if (_arquivos.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('${_arquivos.length} arquivo(s) selecionado(s):',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _arquivos.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: colorScheme.outlineVariant),
                itemBuilder: (_, i) {
                  final arq = _arquivos[i];

                  // Leituras: tile simples
                  if (isLeitura) {
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.description_outlined, size: 18),
                      title: Text(arq.nome,
                          style: const TextStyle(fontSize: 13)),
                      trailing: Text(
                        'dia ${arq.dia} · ${_sessoesLabel[arq.sessao] ?? arq.sessao}',
                        style: TextStyle(
                            fontSize: 12, color: colorScheme.onSurfaceVariant),
                      ),
                    );
                  }

                  // Textos fixos: nome editável + campo de ordem para sutras
                  final nomeCtrl = TextEditingController(text: arq.nomeTexto ?? arq.nome);
                  final ordemCtrl = TextEditingController(
                      text: (arq.ordem ?? 0).toString());

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.description_outlined, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(arq.nome,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(arq.tipo ?? '',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: colorScheme.onSecondaryContainer)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            // Nome (editável)
                            Expanded(
                              child: TextFormField(
                                controller: nomeCtrl,
                                style: const TextStyle(fontSize: 13),
                                decoration: InputDecoration(
                                  labelText: 'Nome',
                                  isDense: true,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                ),
                                onChanged: (v) => arq.nomeTexto = v,
                              ),
                            ),
                            // Ordem (só para sutras)
                            if (arq.tipo == 'sutra') ...[
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 72,
                                child: TextFormField(
                                  controller: ordemCtrl,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 13),
                                  decoration: InputDecoration(
                                    labelText: 'Ordem',
                                    isDense: true,
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                    contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                  ),
                                  onChanged: (v) =>
                                  arq.ordem = int.tryParse(v) ?? 0,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _processando ? null : _enviar,
                icon: _processando
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(_processando
                    ? 'Enviando... $_enviados/${_arquivos.length}'
                    : 'Enviar para Supabase'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],

          // Log de resultados
          if (_log.isNotEmpty) ...[
            const SizedBox(height: 24),
            _label('Resultado'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _log
                    .map((l) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(l,
                      style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace')),
                ))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialog de confirmação/edição antes de enviar ao Supabase
// ─────────────────────────────────────────────────────────────────────────────

class _ConfirmacaoUploadDialog extends StatefulWidget {
  final _ArquivoPendente arq;
  final String conteudo;
  final bool hasFormatting;
  final bool isLeitura;
  final String? resumoCombinacoes; // só para leituras
  final int fluxoId;
  final List<Map<String, dynamic>>? combinacoes; // só para leituras

  const _ConfirmacaoUploadDialog({
    required this.arq,
    required this.conteudo,
    required this.hasFormatting,
    required this.isLeitura,
    required this.fluxoId,
    this.resumoCombinacoes,
    this.combinacoes,
  });

  @override
  State<_ConfirmacaoUploadDialog> createState() =>
      _ConfirmacaoUploadDialogState();
}

class _ConfirmacaoUploadDialogState
    extends State<_ConfirmacaoUploadDialog> {
  late final TextEditingController _nomeCtrl;
  late final TextEditingController _ordemCtrl;
  late String _tipoSel;

  bool _salvando = false;
  String? _erro;

  static const _tiposFixos = [
    'sutra', 'refugio', 'dedicatoria', 'invitatório', 'sadhana'
  ];

  @override
  void initState() {
    super.initState();
    _nomeCtrl  = TextEditingController(
        text: widget.arq.nomeTexto ?? widget.arq.nome);
    _ordemCtrl = TextEditingController(
        text: (widget.arq.ordem ?? 0).toString());
    _tipoSel   = widget.arq.tipo ?? 'sutra';
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _ordemCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final nome = _nomeCtrl.text.trim();
    if (nome.isEmpty) {
      setState(() => _erro = 'O nome não pode estar vazio.');
      return;
    }
    setState(() { _salvando = true; _erro = null; });

    // Persiste as edições de volta no objeto
    widget.arq.nomeTexto = nome;
    widget.arq.tipo      = _tipoSel;
    widget.arq.ordem     = int.tryParse(_ordemCtrl.text) ?? 0;

    try {
      final now = DateTime.now().toIso8601String();

      if (widget.isLeitura) {
        for (final c in widget.combinacoes!) {
          await _supabase.from('textos').upsert({
            'fluxo_id'  : widget.fluxoId,
            'periodo'   : c['periodo'],
            'dia'       : c['dia'],
            'sessao'    : c['sessao'],
            'conteudo'  : widget.conteudo,
            'updated_at': now,
          }, onConflict: 'fluxo_id,periodo,dia,sessao');
        }
      } else {
        final updated = await _supabase
            .from('textos_fixos')
            .update({
          'conteudo'  : widget.conteudo,
          'ordem'     : widget.arq.ordem,
          'updated_at': now,
        })
            .eq('tipo', _tipoSel)
            .eq('nome', nome)
            .select('id');

        if ((updated as List).isEmpty) {
          await _supabase.from('textos_fixos').insert({
            'tipo'      : _tipoSel,
            'nome'      : nome,
            'conteudo'  : widget.conteudo,
            'ordem'     : widget.arq.ordem ?? 0,
            'updated_at': now,
          });
        }
      }

      if (mounted) Navigator.of(context).pop(true); // salvo com sucesso
    } catch (e) {
      // Mostra o erro inline — usuário pode editar e tentar de novo
      String msg = e.toString();
      // Simplifica mensagens comuns do Postgres/Supabase
      if (msg.contains('duplicate key') || msg.contains('unique constraint')) {
        msg = 'Já existe um texto com este tipo e nome. '
            'Altere o nome ou o tipo para salvar como novo, '
            'ou mantenha igual para sobrescrever (o sistema tentará update).';
      } else if (msg.contains('violates')) {
        msg = 'O banco recusou: $msg\nVerifique o nome e o tipo.';
      }
      setState(() { _salvando = false; _erro = msg; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isFixo      = !widget.isLeitura;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.cloud_upload_outlined, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Confirmar envio',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [

              // ── Nome do arquivo (informativo) ─────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.insert_drive_file_outlined, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.arq.nome,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.hasFormatting)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('DOCX',
                            style: TextStyle(
                                fontSize: 10,
                                color: colorScheme.onTertiaryContainer,
                                fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Campos de Leitura ─────────────────────
              if (widget.isLeitura) ...[
                Text(
                  'Destino no banco:',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: colorScheme.secondaryContainer),
                  ),
                  child: Text(
                    widget.resumoCombinacoes ?? '',
                    style: const TextStyle(
                        fontSize: 13, height: 1.6),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'O conteúdo será salvo em todas as combinações acima. '
                      'Se já existir uma entrada para aquela combinação, ela será substituída.',
                  style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant),
                ),
              ],

              // ── Campos de Texto Fixo ──────────────────
              if (isFixo) ...[
                // Instrução
                Text(
                  'O nome identifica o texto no banco e na tela de leitura. '
                      'Use algo descritivo e único para o tipo escolhido.',
                  style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5),
                ),
                const SizedBox(height: 14),

                // Tipo
                Text('Tipo',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: _tiposFixos.map((t) {
                    final sel = _tipoSel == t;
                    return ChoiceChip(
                      label: Text(t, style: TextStyle(fontSize: 11,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.normal)),
                      selected: sel,
                      onSelected: (_salvando) ? null : (_) =>
                          setState(() => _tipoSel = t),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Nome
                Text('Nome no banco *',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                TextField(
                  controller: _nomeCtrl,
                  enabled: !_salvando,
                  decoration: InputDecoration(
                    hintText: 'Ex: Sutra do Coração',
                    helperText: 'Aparece como título na tela de leitura',
                    helperMaxLines: 2,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  onChanged: (_) {
                    if (_erro != null) setState(() => _erro = null);
                  },
                ),
                const SizedBox(height: 12),

                // Ordem (só para sutra)
                if (_tipoSel == 'sutra') ...[
                  Text('Ordem de exibição',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _ordemCtrl,
                      enabled: !_salvando,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '0, 1, 2…',
                        helperText: 'Menor = aparece primeiro',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ],

              // ── Erro inline ───────────────────────────
              if (_erro != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline,
                          size: 18, color: colorScheme.onErrorContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _erro!,
                          style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onErrorContainer,
                              height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        // Ignorar este arquivo e passar para o próximo
        TextButton(
          onPressed: _salvando
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Ignorar'),
        ),
        // Cancelar toda a fila
        TextButton(
          onPressed: _salvando
              ? null
              : () => Navigator.of(context).pop(null),
          style: TextButton.styleFrom(
              foregroundColor: colorScheme.error),
          child: const Text('Cancelar tudo'),
        ),
        // Salvar
        FilledButton.icon(
          onPressed: _salvando ? null : _salvar,
          icon: _salvando
              ? const SizedBox(
            width: 14, height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white),
          )
              : const Icon(Icons.cloud_upload_outlined, size: 16),
          label: Text(_salvando ? 'Salvando...' : 'Salvar no Supabase'),
        ),
      ],
    );
  }
}


class _ArquivoPendente {
  final String path;
  final String nome;

  // Leitura
  final int? dia;
  final String? sessao;

  // Texto fixo — todos mutáveis (admin pode ajustar no diálogo antes de enviar)
  String? tipo;
  String? nomeTexto;
  int? ordem;

  _ArquivoPendente({
    required this.path,
    required this.nome,
    this.dia,
    this.sessao,
    this.tipo,
    this.nomeTexto,
    this.ordem,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 3 — Editar / Remover textos
// ─────────────────────────────────────────────────────────────────────────────

class _EditarTab extends StatefulWidget {
  const _EditarTab();

  @override
  State<_EditarTab> createState() => _EditarTabState();
}

class _EditarTabState extends State<_EditarTab> {
  _Destino _destino = _Destino.leituras;

  // Filtros Leituras
  int _fluxoId = 1;
  String? _sessaoFiltro;

  // Filtros Textos Fixos
  String? _tipoFiltro;

  List<Map<String, dynamic>> _textos = [];
  bool _loading = false;
  bool _buscado = false;

  // Seleção múltipla: ids marcados + se o modo de seleção está ativo.
  final Set<int> _selecionados = {};
  bool _modoSelecao = false;

  bool get _isLeitura => _destino == _Destino.leituras;
  String get _tabela => _isLeitura ? 'textos' : 'textos_fixos';

  @override
  void initState() {
    super.initState();
    // Mostra resultados de imediato (leituras do fluxo principal) — sem exigir
    // um clique em "Buscar". A busca também roda ao mudar qualquer filtro.
    WidgetsBinding.instance.addPostFrameCallback((_) => _buscar());
  }

  Future<void> _buscar() async {
    setState(() {
      _loading = true;
      _buscado = false;
      _selecionados.clear();
    });
    try {
      List<dynamic> data;

      if (_isLeitura) {
        data = _sessaoFiltro != null
            ? await _supabase
            .from('textos')
            .select()
            .eq('fluxo_id', _fluxoId)
            .eq('sessao', _sessaoFiltro!)
            .order('dia')
            .order('sessao')
            : await _supabase
            .from('textos')
            .select()
            .eq('fluxo_id', _fluxoId)
            .order('dia')
            .order('sessao');
      } else {
        data = _tipoFiltro != null
            ? await _supabase
            .from('textos_fixos')
            .select()
            .eq('tipo', _tipoFiltro!)
            .order('tipo')
            .order('ordem')
            .order('nome')
            : await _supabase
            .from('textos_fixos')
            .select()
            .order('tipo')
            .order('ordem')
            .order('nome');
      }

      setState(() {
        _textos = List<Map<String, dynamic>>.from(data);
        _buscado = true;
      });
    } catch (e) {
      if (mounted) _snackErro(context, 'Erro ao buscar: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editar(Map<String, dynamic> registro) async {
    if (_isLeitura) {
      await _editarLeitura(registro);
    } else {
      await _editarTextoFixo(registro);
    }
  }

  Future<void> _editarLeitura(Map<String, dynamic> registro) async {
    // Mostra texto limpo no editor; converte de volta pra HTML ao salvar
    final conteudoCtrl = TextEditingController(
        text: _htmlParaEditor(registro['conteudo'] as String? ?? ''));
    final diaCtrl =
    TextEditingController(text: (registro['dia'] ?? 1).toString());

    int fluxoId = (registro['fluxo_id'] as int?) ?? 1;
    int? periodo = registro['periodo'] as int?;
    String sessao = (registro['sessao'] as String?) ?? 'manha';
    bool salvando = false;
    String? erro;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final fluxoPrincipal = fluxoId == 1;
          final maxDia = fluxoPrincipal ? 360 : 365;

          Future<void> salvar() async {
            final dia = int.tryParse(diaCtrl.text);
            if (dia == null || dia < 1 || dia > maxDia) {
              setSt(() => erro = 'Dia inválido (1–$maxDia).');
              return;
            }
            setSt(() {
              salvando = true;
              erro = null;
            });
            try {
              await _supabase.from('textos').update({
                'fluxo_id': fluxoId,
                'periodo': fluxoPrincipal ? periodo : null,
                'dia': dia,
                'sessao': sessao,
                'conteudo': _editorParaHtml(conteudoCtrl.text),
                'updated_at': DateTime.now().toIso8601String(),
              }).eq('id', registro['id'] as int);
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (mounted) {
                _snackOk(context, 'Leitura atualizada.');
                _disparaSync(context);
                _buscar();
              }
            } catch (e) {
              final msg = e.toString().contains('duplicate key') ||
                  e.toString().contains('unique constraint')
                  ? 'Já existe uma leitura com esse fluxo/período/dia/sessão. '
                  'Mude um dos campos.'
                  : 'Erro: $e';
              setSt(() {
                salvando = false;
                erro = msg;
              });
            }
          }

          return AlertDialog(
            title: const Text('Editar Leitura'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Fluxo
                    const Text('Fluxo',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    SegmentedButton<int>(
                      segments: _fluxos
                          .map((f) => ButtonSegment<int>(
                          value: f['id'] as int,
                          label: Text(f['nome'] as String,
                              style: const TextStyle(fontSize: 11))))
                          .toList(),
                      selected: {fluxoId},
                      onSelectionChanged: salvando
                          ? null
                          : (s) => setSt(() {
                        fluxoId = s.first;
                        if (fluxoId != 1) periodo = null;
                        if (fluxoId == 1 && periodo == null) {
                          periodo = 1;
                        }
                      }),
                    ),
                    const SizedBox(height: 14),

                    // Período (só fluxo principal)
                    if (fluxoPrincipal) ...[
                      const Text('Período',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        value: periodo ?? 1,
                        decoration:
                        _inputDecorationSm('Período').copyWith(isDense: true),
                        items: _periodos
                            .map((p) => DropdownMenuItem(
                          value: p['id'] as int,
                          child: Text(p['nome'] as String,
                              style: const TextStyle(fontSize: 12)),
                        ))
                            .toList(),
                        onChanged: salvando
                            ? null
                            : (v) => setSt(() => periodo = v),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Dia + Sessão
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Dia',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: diaCtrl,
                                enabled: !salvando,
                                keyboardType: TextInputType.number,
                                decoration: _inputDecorationSm('1–$maxDia')
                                    .copyWith(isDense: true),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Sessão',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: sessao,
                                decoration: _inputDecorationSm('Sessão')
                                    .copyWith(isDense: true),
                                items: _sessoes
                                    .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(_sessoesLabel[s]!,
                                      style:
                                      const TextStyle(fontSize: 12)),
                                ))
                                    .toList(),
                                onChanged: salvando
                                    ? null
                                    : (v) =>
                                    setSt(() => sessao = v ?? sessao),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Conteúdo
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Conteúdo',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '*itálico*  **negrito**  # heading  - lista',
                            style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                              color: Theme.of(ctx)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: conteudoCtrl,
                      enabled: !salvando,
                      maxLines: 14,
                      minLines: 8,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),

                    // Erro inline
                    if (erro != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(ctx).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(erro!,
                            style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(ctx)
                                    .colorScheme
                                    .onErrorContainer)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: salvando
                    ? null
                    : () => _mostrarPreviewHtml(
                  ctx,
                  _editorParaHtml(conteudoCtrl.text),
                  'Pré-visualização — Leitura',
                ),
                icon: const Icon(Icons.preview_outlined, size: 16),
                label: const Text('Pré-visualizar'),
              ),
              TextButton(
                onPressed: salvando ? null : () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: salvando ? null : salvar,
                icon: salvando
                    ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined, size: 16),
                label: Text(salvando ? 'Salvando...' : 'Salvar'),
              ),
            ],
          );
        },
      ),
    );

    conteudoCtrl.dispose();
    diaCtrl.dispose();
  }

  Future<void> _editarTextoFixo(Map<String, dynamic> registro) async {
    // Mostra texto limpo no editor; converte de volta pra HTML ao salvar
    final conteudoCtrl = TextEditingController(
        text: _htmlParaEditor(registro['conteudo'] as String? ?? ''));
    final nomeCtrl =
    TextEditingController(text: registro['nome'] as String? ?? '');
    final ordemCtrl =
    TextEditingController(text: (registro['ordem'] ?? 0).toString());

    String tipoSel = (registro['tipo'] as String?) ?? 'sutra';
    bool salvando = false;
    String? erro;

    const tiposFixos = [
      'sutra',
      'refugio',
      'dedicatoria',
      'invitatório',
      'sadhana'
    ];

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          Future<void> salvar() async {
            final nome = nomeCtrl.text.trim();
            if (nome.isEmpty) {
              setSt(() => erro = 'Nome obrigatório.');
              return;
            }
            setSt(() {
              salvando = true;
              erro = null;
            });
            try {
              await _supabase.from('textos_fixos').update({
                'tipo': tipoSel,
                'nome': nome,
                'conteudo': _editorParaHtml(conteudoCtrl.text),
                'ordem': int.tryParse(ordemCtrl.text) ?? 0,
                'updated_at': DateTime.now().toIso8601String(),
              }).eq('id', registro['id'] as int);
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (mounted) {
                _snackOk(context, 'Texto fixo atualizado.');
                _disparaSync(context);
                _buscar();
              }
            } catch (e) {
              final msg = e.toString().contains('duplicate key') ||
                  e.toString().contains('unique constraint')
                  ? 'Já existe outro texto fixo com esse tipo e nome.'
                  : 'Erro: $e';
              setSt(() {
                salvando = false;
                erro = msg;
              });
            }
          }

          return AlertDialog(
            title: const Text('Editar Texto Fixo'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tipo
                    const Text('Tipo',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: tiposFixos.map((t) {
                        final sel = tipoSel == t;
                        return ChoiceChip(
                          label: Text(t,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: sel
                                      ? FontWeight.w700
                                      : FontWeight.normal)),
                          selected: sel,
                          onSelected: salvando
                              ? null
                              : (_) => setSt(() => tipoSel = t),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Nome
                    const Text('Nome',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nomeCtrl,
                      enabled: !salvando,
                      decoration: _inputDecorationSm('Nome único pra esse tipo')
                          .copyWith(isDense: true),
                    ),
                    const SizedBox(height: 14),

                    // Ordem (só sutra)
                    if (tipoSel == 'sutra') ...[
                      const Text('Ordem',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: ordemCtrl,
                          enabled: !salvando,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecorationSm('0, 1, 2…')
                              .copyWith(isDense: true),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Conteúdo
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Conteúdo',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '*itálico*  **negrito**  # heading  - lista',
                            style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                              color: Theme.of(ctx)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: conteudoCtrl,
                      enabled: !salvando,
                      maxLines: 14,
                      minLines: 8,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),

                    if (erro != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(ctx).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(erro!,
                            style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(ctx)
                                    .colorScheme
                                    .onErrorContainer)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: salvando
                    ? null
                    : () => _mostrarPreviewHtml(
                  ctx,
                  _editorParaHtml(conteudoCtrl.text),
                  'Pré-visualização — ${nomeCtrl.text.trim().isEmpty ? tipoSel : nomeCtrl.text.trim()}',
                ),
                icon: const Icon(Icons.preview_outlined, size: 16),
                label: const Text('Pré-visualizar'),
              ),
              TextButton(
                onPressed: salvando ? null : () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: salvando ? null : salvar,
                icon: salvando
                    ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined, size: 16),
                label: Text(salvando ? 'Salvando...' : 'Salvar'),
              ),
            ],
          );
        },
      ),
    );

    conteudoCtrl.dispose();
    nomeCtrl.dispose();
    ordemCtrl.dispose();
  }

  Future<void> _remover(Map<String, dynamic> registro) async {
    final desc = _isLeitura
        ? 'leitura do Dia ${registro['dia']} · ${_sessoesLabel[registro['sessao']] ?? registro['sessao']}'
        : '${registro['tipo']} · ${registro['nome']}';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover texto'),
        content: Text(
            'Remover $desc?\n\nEsta ação não pode ser desfeita.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style:
            FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await _supabase
            .from(_tabela)
            .delete()
            .eq('id', registro['id'] as int);
        if (mounted) {
          _snackOk(context, 'Texto removido.');
          _disparaSync(context);
        }
        _buscar();
      } catch (e) {
        if (mounted) _snackErro(context, 'Erro ao remover: $e');
      }
    }
  }

  // Remove TODOS os registros atualmente listados — usa exatamente o mesmo
  // filtro da busca (fluxo + sessão para leituras; tipo para textos fixos),
  // então o que é apagado é precisamente o que está visível na lista.
  Future<void> _removerTodos() async {
    final n = _textos.length;
    if (n == 0) return;

    final String filtroDesc;
    if (_isLeitura) {
      final nomeFluxo = _fluxos.firstWhere(
        (f) => f['id'] == _fluxoId,
        orElse: () => {'nome': 'Fluxo $_fluxoId'},
      )['nome'] as String;
      final sessaoDesc = _sessaoFiltro != null
          ? 'sessão ${_sessoesLabel[_sessaoFiltro] ?? _sessaoFiltro}'
          : 'todas as sessões';
      filtroDesc = '$nomeFluxo · $sessaoDesc';
    } else {
      filtroDesc = _tipoFiltro != null ? 'tipo "$_tipoFiltro"' : 'todos os tipos';
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover todos os listados'),
        content: Text(
            'Remover os $n texto(s) atualmente listados\n($filtroDesc)?\n\n'
            'Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: Text('Remover $n'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _loading = true);
    try {
      if (_isLeitura) {
        var q = _supabase.from('textos').delete().eq('fluxo_id', _fluxoId);
        if (_sessaoFiltro != null) q = q.eq('sessao', _sessaoFiltro!);
        await q;
      } else {
        if (_tipoFiltro != null) {
          await _supabase
              .from('textos_fixos')
              .delete()
              .eq('tipo', _tipoFiltro!);
        } else {
          // Sem filtro de tipo: apaga todos os textos fixos. O Supabase exige
          // um filtro no delete, então usamos um sempre-verdadeiro (id >= 0).
          await _supabase.from('textos_fixos').delete().gte('id', 0);
        }
      }
      if (mounted) {
        _snackOk(context, '$n texto(s) removido(s).');
        _disparaSync(context);
        _buscar();
      }
    } catch (e) {
      if (mounted) _snackErro(context, 'Erro ao remover todos: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Remove apenas os itens marcados (seleção múltipla).
  Future<void> _removerSelecionados() async {
    final ids = _selecionados.toList();
    if (ids.isEmpty) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover selecionados'),
        content: Text(
            'Remover os ${ids.length} texto(s) selecionado(s)?\n\n'
            'Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: Text('Remover ${ids.length}'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _loading = true);
    try {
      await _supabase.from(_tabela).delete().inFilter('id', ids);
      if (mounted) {
        _snackOk(context, '${ids.length} texto(s) removido(s).');
        _selecionados.clear();
        _modoSelecao = false;
        _disparaSync(context);
        _buscar();
      }
    } catch (e) {
      if (mounted) _snackErro(context, 'Erro ao remover selecionados: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Barra acima da lista: contagem de resultados + ações (selecionar /
  // remover selecionados / remover todos).
  Widget _barraResultados(ColorScheme cs) {
    final total = _textos.length;
    final selN = _selecionados.length;
    final todosMarcados = total > 0 && selN == total;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          Text(
            _modoSelecao ? '$selN selecionado(s)' : '$total resultado(s)',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant),
          ),
          const Spacer(),
          if (_modoSelecao) ...[
            TextButton(
              onPressed: () => setState(() {
                if (todosMarcados) {
                  _selecionados.clear();
                } else {
                  _selecionados
                    ..clear()
                    ..addAll(_textos.map((t) => t['id'] as int));
                }
              }),
              child: Text(todosMarcados ? 'Limpar' : 'Todos'),
            ),
            TextButton.icon(
              onPressed: (selN == 0 || _loading) ? null : _removerSelecionados,
              icon: Icon(Icons.delete_outline,
                  size: 18, color: selN == 0 ? cs.onSurfaceVariant : cs.error),
              label: Text('Remover ($selN)',
                  style: TextStyle(
                      color: selN == 0 ? cs.onSurfaceVariant : cs.error)),
            ),
            IconButton(
              tooltip: 'Sair da seleção',
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => setState(() {
                _modoSelecao = false;
                _selecionados.clear();
              }),
            ),
          ] else ...[
            TextButton.icon(
              onPressed: () => setState(() => _modoSelecao = true),
              icon: const Icon(Icons.checklist, size: 18),
              label: const Text('Selecionar'),
            ),
            TextButton.icon(
              onPressed: _loading ? null : _removerTodos,
              icon: Icon(Icons.delete_sweep_outlined, size: 18, color: cs.error),
              label:
                  Text('Remover todos', style: TextStyle(color: cs.error)),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // ── Destino ──
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            border: Border(
                bottom: BorderSide(color: colorScheme.outlineVariant)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<_Destino>(
                segments: const [
                  ButtonSegment(
                    value: _Destino.leituras,
                    icon: Icon(Icons.menu_book_outlined, size: 18),
                    label: Text('Leituras', style: TextStyle(fontSize: 12)),
                  ),
                  ButtonSegment(
                    value: _Destino.textosFixos,
                    icon: Icon(Icons.bookmark_outline, size: 18),
                    label: Text('Textos Fixos', style: TextStyle(fontSize: 12)),
                  ),
                ],
                selected: {_destino},
                onSelectionChanged: (s) {
                  setState(() {
                    _destino = s.first;
                    _textos = [];
                    _buscado = false;
                    _selecionados.clear();
                    _modoSelecao = false;
                  });
                  _buscar();
                },
              ),
              const SizedBox(height: 12),

              // Filtros específicos por destino
              if (_isLeitura)
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _fluxoId,
                        decoration:
                        _inputDecoration('Fluxo').copyWith(isDense: true),
                        items: _fluxos
                            .map((f) => DropdownMenuItem(
                          value: f['id'] as int,
                          child: Text(f['nome'] as String,
                              style: const TextStyle(fontSize: 13)),
                        ))
                            .toList(),
                        onChanged: (v) {
                          setState(() => _fluxoId = v!);
                          _buscar();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: _sessaoFiltro,
                        decoration:
                        _inputDecoration('Sessão').copyWith(isDense: true),
                        items: [
                          const DropdownMenuItem(
                              value: null,
                              child: Text('Todas',
                                  style: TextStyle(fontSize: 13))),
                          ..._sessoes.map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(_sessoesLabel[s]!,
                                style: const TextStyle(fontSize: 13)),
                          )),
                        ],
                        onChanged: (v) {
                          setState(() => _sessaoFiltro = v);
                          _buscar();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _loading ? null : _buscar,
                      style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14)),
                      child: _loading
                          ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                          : const Text('Buscar'),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: _tipoFiltro,
                        decoration:
                        _inputDecoration('Tipo').copyWith(isDense: true),
                        items: const [
                          DropdownMenuItem(
                              value: null,
                              child: Text('Todos',
                                  style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(
                              value: 'sutra',
                              child: Text('Sutra',
                                  style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(
                              value: 'refugio',
                              child: Text('Refúgio',
                                  style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(
                              value: 'dedicatoria',
                              child: Text('Dedicatória',
                                  style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(
                              value: 'invitatório',
                              child: Text('Invitatório',
                                  style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(
                              value: 'sadhana',
                              child: Text('Sadhana',
                                  style: TextStyle(fontSize: 13))),
                        ],
                        onChanged: (v) {
                          setState(() => _tipoFiltro = v);
                          _buscar();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _loading ? null : _buscar,
                      style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14)),
                      child: _loading
                          ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                          : const Text('Buscar'),
                    ),
                  ],
                ),
            ],
          ),
        ),

        if (_buscado && _textos.isNotEmpty) _barraResultados(colorScheme),

        // Lista
        Expanded(
          child: !_buscado
              ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search,
                    size: 48, color: colorScheme.onSurfaceVariant),
                const SizedBox(height: 12),
                Text('Use os filtros acima para listar os textos.',
                    style: TextStyle(
                        color: colorScheme.onSurfaceVariant)),
              ],
            ),
          )
              : _textos.isEmpty
              ? Center(
            child: Text('Nenhum texto encontrado.',
                style: TextStyle(
                    color: colorScheme.onSurfaceVariant)),
          )
              : ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: _textos.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (_, i) {
              final t = _textos[i];
              final preview = (t['conteudo'] as String? ?? '').trim();
              final previewShort = preview.length > 80
                  ? '${preview.substring(0, 80)}…'
                  : preview;

              final String leadingLabel;
              final String tituloItem;

              if (_isLeitura) {
                leadingLabel = '${t['dia']}';
                tituloItem =
                '${_sessoesLabel[t['sessao']] ?? t['sessao']}  ·  ${t['periodo'] != null ? 'Período ${t['periodo']}' : 'Prajnaparamita'}';
              } else {
                final tipo = (t['tipo'] as String? ?? '').toUpperCase();
                leadingLabel = tipo.isNotEmpty ? tipo[0] : '?';
                tituloItem =
                '${t['nome']}  ·  ${(t['tipo'] as String? ?? '').toUpperCase()}';
              }

              final id = t['id'] as int;
              final sel = _selecionados.contains(id);
              void alternarSel() => setState(() {
                    if (sel) {
                      _selecionados.remove(id);
                    } else {
                      _selecionados.add(id);
                    }
                  });

              return Card(
                margin: EdgeInsets.zero,
                color: (_modoSelecao && sel)
                    ? colorScheme.primaryContainer.withOpacity(0.45)
                    : null,
                child: ListTile(
                  // Em modo seleção: toca para marcar. Fora dele: toca para editar.
                  onTap: _modoSelecao ? alternarSel : () => _editar(t),
                  onLongPress: _modoSelecao
                      ? null
                      : () => setState(() {
                            _modoSelecao = true;
                            _selecionados.add(id);
                          }),
                  leading: _modoSelecao
                      ? Checkbox(
                          value: sel,
                          onChanged: (_) => alternarSel(),
                        )
                      : CircleAvatar(
                          backgroundColor: colorScheme.primaryContainer,
                          child: Text(
                            leadingLabel,
                            style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                  title: Text(
                    tituloItem,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(previewShort,
                      style: const TextStyle(fontSize: 12)),
                  trailing: _modoSelecao
                      ? null
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon:
                                  const Icon(Icons.edit_outlined, size: 20),
                              tooltip: 'Editar',
                              onPressed: () => _editar(t),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline,
                                  size: 20, color: colorScheme.error),
                              tooltip: 'Remover',
                              onPressed: () => _remover(t),
                            ),
                          ],
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 4 — Progresso do conteúdo
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressoTab extends StatefulWidget {
  const _ProgressoTab();

  @override
  State<_ProgressoTab> createState() => _ProgressoTabState();
}

class _ProgressoTabState extends State<_ProgressoTab> {
  bool _loading = false;
  bool _syncing = false;
  Map<String, _ProgressoFluxo>? _dados;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    try {
      // Conta textos inseridos por fluxo e sessão
      final data = await _supabase
          .from('textos')
          .select('fluxo_id, sessao, dia');

      final Map<String, _ProgressoFluxo> resultado = {};

      for (final row in data as List) {
        final fluxoId = row['fluxo_id'] as int;
        final sessao = row['sessao'] as String;
        final key = 'fluxo_$fluxoId';

        resultado.putIfAbsent(
            key,
                () => _ProgressoFluxo(
              fluxoId: fluxoId,
              totalDias: fluxoId == 1 ? 360 : 365,
            ));
        resultado[key]!.adicionarSessao(sessao);
      }

      setState(() => _dados = resultado);
    } catch (e) {
      if (mounted) _snackErro(context, 'Erro ao carregar progresso: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Força sync imediato no SyncService (ignora cache de 1 hora).
  /// Usado para propagar conteúdo novo para o SQLite local sem esperar.
  Future<void> _forcaSync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final sync = context.read<SyncService>();
      await sync.sync();
      if (mounted) {
        final erro = sync.erro;
        if (erro != null) {
          _snackErro(context, erro);
        } else {
          _snackOk(context, 'Sincronização concluída.');
        }
      }
    } catch (e) {
      if (mounted) _snackErro(context, 'Erro no sync: $e');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _carregar,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _dados == null
          ? const Center(child: Text('Nenhum dado disponível.'))
          : ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Progresso do Conteúdo',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _carregar,
                tooltip: 'Atualizar',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Arraste para baixo para atualizar.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),

          // ── Botão forçar sync ─────────────────────────
          OutlinedButton.icon(
            onPressed: _syncing ? null : _forcaSync,
            icon: _syncing
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.sync, size: 18),
            label: Text(
              _syncing ? 'Sincronizando…' : 'Forçar sincronização',
              style: const TextStyle(fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Propaga o conteúdo do Supabase para o banco local de todos os dispositivos. '
                'Use após um upload para ver as mudanças imediatamente.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),

          for (final entry in _dados!.entries) ...[
            _CardProgressoFluxo(
                fluxo: entry.value,
                colorScheme: colorScheme),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _ProgressoFluxo {
  final int fluxoId;
  final int totalDias;
  final Map<String, int> porSessao = {};

  _ProgressoFluxo({required this.fluxoId, required this.totalDias});

  void adicionarSessao(String sessao) {
    porSessao[sessao] = (porSessao[sessao] ?? 0) + 1;
  }

  int get totalInserido => porSessao.values.fold(0, (a, b) => a + b);
  int get totalEsperado => totalDias * 4; // 4 sessões por dia
  double get pct => totalEsperado > 0 ? totalInserido / totalEsperado : 0;
}

class _CardProgressoFluxo extends StatelessWidget {
  final _ProgressoFluxo fluxo;
  final ColorScheme colorScheme;

  const _CardProgressoFluxo(
      {required this.fluxo, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final nomeFluxo = fluxo.fluxoId == 1
        ? 'Fluxo Principal (360 dias)'
        : 'Fluxo Prajnaparamita (365 dias)';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(nomeFluxo,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              '${fluxo.totalInserido} de ${fluxo.totalEsperado} sessões inseridas',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fluxo.pct,
                minHeight: 8,
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(fluxo.pct * 100).toStringAsFixed(1)}% completo',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            // Por sessão
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _sessoes.map((s) {
                final count = fluxo.porSessao[s] ?? 0;
                final pct = fluxo.totalDias > 0
                    ? count / fluxo.totalDias
                    : 0.0;
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(_sessoesLabel[s]!,
                          style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        '$count / ${fluxo.totalDias}',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary),
                      ),
                      Text(
                        '${(pct * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 5 — Emails autorizados (gerenciar allowlist)
// ─────────────────────────────────────────────────────────────────────────────

class _AutorizadosTab extends StatefulWidget {
  const _AutorizadosTab();

  @override
  State<_AutorizadosTab> createState() => _AutorizadosTabState();
}

class _AutorizadosTabState extends State<_AutorizadosTab> {
  List<Map<String, dynamic>> _emails = [];
  bool _loading = false;
  bool _adicionando = false;

  final _emailCtrl = TextEditingController();
  final _nomeCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _authAdmin = AuthAdminService();

  String get _meuEmail =>
      _supabase.auth.currentUser?.email?.toLowerCase() ?? '';

  // ── Ações sobre cada email ─────────────────────────

  Future<void> _convidar(String email) async {
    try {
      await _authAdmin.inviteUser(email);
      if (mounted) _snackOk(context, 'Convite enviado para $email.');
    } catch (e) {
      if (mounted) _snackErro(context, _traduzirErroAuth(e));
    }
  }

  Future<void> _enviarMagicLink(String email) async {
    try {
      await _authAdmin.sendMagicLink(email);
      if (mounted) _snackOk(context, 'Magic link enviado para $email.');
    } catch (e) {
      if (mounted) _snackErro(context, _traduzirErroAuth(e));
    }
  }

  Future<void> _reenviarConfirmacao(String email) async {
    try {
      await _authAdmin.resendSignupConfirmation(email);
      if (mounted) {
        _snackOk(context, 'Email de confirmação reenviado para $email.');
      }
    } catch (e) {
      if (mounted) _snackErro(context, _traduzirErroAuth(e));
    }
  }

  Future<void> _trocarEmail(String emailAntigo) async {
    final novoCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final novoEmail = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Trocar email'),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Email atual: $emailAntigo',
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  'O Supabase enviará confirmação pro novo email.',
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: novoCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  autofocus: true,
                  decoration: _inputDecoration('novo@email.com'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Obrigatório';
                    if (!v.contains('@') || !v.contains('.')) {
                      return 'Email inválido';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, novoCtrl.text.trim().toLowerCase());
              }
            },
            child: const Text('Trocar'),
          ),
        ],
      ),
    );

    novoCtrl.dispose();
    if (novoEmail == null || novoEmail == emailAntigo.toLowerCase()) return;

    try {
      // 1. Atualiza em auth.users via admin
      await _authAdmin.changeUserEmail(
        emailAntigo: emailAntigo,
        emailNovo: novoEmail,
      );
      // 2. Atualiza também na allowlist pra manter consistente
      await _supabase
          .from('admins_autorizados')
          .update({'email': novoEmail}).eq('email', emailAntigo);

      if (mounted) {
        _snackOk(context,
            'Email atualizado. Confirmação enviada para $novoEmail.');
      }
      await _carregar();
    } catch (e) {
      if (mounted) _snackErro(context, _traduzirErroAuth(e));
    }
  }

  String _traduzirErroAuth(Object e) {
    final msg = e.toString();
    if (msg.contains('User already registered') ||
        msg.contains('already been registered')) {
      return 'Este email já tem conta cadastrada.';
    }
    if (msg.contains('not found') || msg.contains('não encontrado')) {
      return 'Usuário não encontrado — talvez ainda não tenha se cadastrado.';
    }
    if (msg.contains('Email não autorizado')) {
      return 'Email não está na lista de autorizados.';
    }
    if (msg.contains('rate limit') || msg.contains('Too many')) {
      return 'Muitas requisições. Aguarde alguns minutos.';
    }
    return 'Erro: $msg';
  }

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nomeCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    try {
      final data = await _supabase
          .from('admins_autorizados')
          .select()
          .order('criado_em');
      setState(() => _emails = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      if (mounted) _snackErro(context, 'Erro ao carregar: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _adicionar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _adicionando = true);

    final email = _emailCtrl.text.trim().toLowerCase();
    final nome = _nomeCtrl.text.trim();

    try {
      await _supabase.from('admins_autorizados').insert({
        'email': email,
        'nome': nome.isEmpty ? null : nome,
      });
      _emailCtrl.clear();
      _nomeCtrl.clear();
      if (mounted) _snackOk(context, 'Email $email autorizado.');
      await _carregar();
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('duplicate key')
            ? 'Este email já está autorizado.'
            : 'Erro ao adicionar: $e';
        _snackErro(context, msg);
      }
    } finally {
      if (mounted) setState(() => _adicionando = false);
    }
  }

  Future<void> _remover(Map<String, dynamic> entry) async {
    final email = (entry['email'] as String).toLowerCase();

    if (email == _meuEmail) {
      _snackErro(context,
          'Você não pode remover seu próprio email — peça pra outro admin.');
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover autorização'),
        content: Text(
            'Remover $email da lista de admins autorizados?\n\nEla não poderá mais entrar nem fazer upload. A conta dela em auth.users continua existindo (você pode deletá-la pelo Supabase Dashboard se quiser).'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style:
            FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await _supabase
          .from('admins_autorizados')
          .delete()
          .eq('email', email);
      if (mounted) _snackOk(context, '$email removido da lista.');
      await _carregar();
    } catch (e) {
      if (mounted) _snackErro(context, 'Erro ao remover: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // ── Cabeçalho ──────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Emails Autorizados',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      'Quem pode criar conta e acessar o painel admin.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loading ? null : _carregar,
                tooltip: 'Atualizar',
              ),
            ],
          ),
        ),

        // ── Form de adicionar ──────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Form(
            key: _formKey,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Adicionar novo'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          decoration: _inputDecoration('email@exemplo.com'),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Email obrigatório';
                            }
                            if (!v.contains('@') || !v.contains('.')) {
                              return 'Email inválido';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _nomeCtrl,
                          decoration: _inputDecoration('Nome (opcional)'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _adicionando ? null : _adicionar,
                        icon: _adicionando
                            ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.add, size: 18),
                        label: const Text('Autorizar'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Lista ──────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _emails.isEmpty
              ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people_outline,
                    size: 48,
                    color: colorScheme.onSurfaceVariant),
                const SizedBox(height: 12),
                Text('Nenhum email autorizado ainda.',
                    style: TextStyle(
                        color: colorScheme.onSurfaceVariant)),
              ],
            ),
          )
              : ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            itemCount: _emails.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, i) {
              final entry = _emails[i];
              final email = entry['email'] as String;
              final nome = entry['nome'] as String?;
              final criadoEm = entry['criado_em'] as String?;
              final ehEu = email.toLowerCase() == _meuEmail;

              return Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: ehEu
                        ? colorScheme.primary
                        : colorScheme.primaryContainer,
                    child: Icon(
                      Icons.person,
                      size: 18,
                      color: ehEu
                          ? Colors.white
                          : colorScheme.primary,
                    ),
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(email,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                      ),
                      if (ehEu) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('você',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.primary)),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    [
                      if (nome != null && nome.isNotEmpty) nome,
                      if (criadoEm != null)
                        'desde ${criadoEm.substring(0, 10)}',
                    ].join('  ·  '),
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    tooltip: 'Ações',
                    onSelected: (acao) {
                      switch (acao) {
                        case 'convite':
                          _convidar(email);
                          break;
                        case 'magic':
                          _enviarMagicLink(email);
                          break;
                        case 'reenviar':
                          _reenviarConfirmacao(email);
                          break;
                        case 'trocar':
                          _trocarEmail(email);
                          break;
                        case 'remover':
                          _remover(entry);
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'convite',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.mail_outline, size: 20),
                          title: Text('Enviar convite',
                              style: TextStyle(fontSize: 13)),
                          subtitle: Text(
                              'Cria conta + envia link p/ definir senha',
                              style: TextStyle(fontSize: 10)),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'magic',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.auto_awesome_outlined,
                              size: 20),
                          title: Text('Magic link',
                              style: TextStyle(fontSize: 13)),
                          subtitle: Text(
                              'Login sem senha (conta já existente)',
                              style: TextStyle(fontSize: 10)),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'reenviar',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.refresh, size: 20),
                          title: Text('Reenviar confirmação',
                              style: TextStyle(fontSize: 13)),
                          subtitle: Text(
                              'Para quem não confirmou ainda',
                              style: TextStyle(fontSize: 10)),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'trocar',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.edit_outlined, size: 20),
                          title: Text('Trocar email',
                              style: TextStyle(fontSize: 13)),
                          subtitle: Text(
                              'Atualiza email da conta + allowlist',
                              style: TextStyle(fontSize: 10)),
                        ),
                      ),
                      if (!ehEu) ...[
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'remover',
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.delete_outline,
                                size: 20,
                                color: colorScheme.error),
                            title: Text('Remover autorização',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: colorScheme.error)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers de UI reutilizáveis (fora das classes para acesso global no arquivo)
// ─────────────────────────────────────────────────────────────────────────────

Widget _label(String text) => Text(
  text,
  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
);

InputDecoration _inputDecoration(String hint) => InputDecoration(
  hintText: hint,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
  contentPadding:
  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
);

// Versão compacta para campos pequenos (dia, sessão, fluxo, período)
InputDecoration _inputDecorationSm(String hint) => InputDecoration(
  hintText: hint,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
  contentPadding:
  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
);