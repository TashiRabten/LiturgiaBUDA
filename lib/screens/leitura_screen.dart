import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_html/flutter_html.dart';
import '../services/database_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Cores BUDA
// ─────────────────────────────────────────────────────────────────────────────
class _BC {
  static const mainBlue    = Color(0xFF88A9CC);
  static const bgMid       = Color(0xFF3A5A7C);
  static const bgDeep      = Color(0xFF2E4A6A);
  static const darkBlue    = Color(0xFF3E7EBE);
  static const pramanaRing = Color(0xFFCC3300);
  static const cardBege    = Color(0xFFF5EDD8);
  static const cardBorda   = Color(0xFF8B7355);
  static const textoEscuro = Color(0xFF2C3252);
  static const textoMedio  = Color(0xFF5A6080);
  static const textoOuro   = Color(0xFFB8860B);
  static const gold        = Color(0xFFD4A843);
  static const white20     = Color(0x33FFFFFF);
  static const white40     = Color(0x66FFFFFF);
}

// ─────────────────────────────────────────────────────────────────────────────
// Modelo de secção de navegação
// ─────────────────────────────────────────────────────────────────────────────
/// Garante que o conteúdo seja HTML válido pra render com flutter_html.
/// Se já parece HTML (tem tags conhecidas), sanitiza Markdown residual e retorna.
/// Se for texto plano (ex: conteúdo antigo em Markdown ou texto cru),
/// converte para HTML básico envolvendo cada parágrafo em `<p>`.
String _ensureHtml(String raw) {
  final trim = raw.trim();
  if (trim.isEmpty) {
    return '<p><em>— texto ainda não disponível —</em></p>';
  }

  // Detecta se já é HTML pela presença de qualquer tag HTML em qualquer posição.
  // Inclui tags inline como <strong>, <em>, bem como blocos como <p>, <h1>, etc.
  final pareceHtml = RegExp(
    r'<(p|h[1-6]|ul|ol|li|div|span|strong|b|em|i|u|s|br|blockquote|a)\b',
    caseSensitive: false,
  ).hasMatch(trim);

  if (pareceHtml) {
    // Conteúdo já é HTML, mas pode ter Markdown residual misturado
    // (ex: *palavra* ou **texto** fora de tags). Converte os asteriscos
    // que ficaram fora de tags HTML antes de renderizar.
    // Também substitui &emsp; por <doctab> para renderização nativa no leitor
    // (flutter_html v3 ignora width em spans inline).
    return _sanitizarMarkdownResidual(trim)
        .replaceAll('&emsp;', '<doctab></doctab>');
  }

  // Texto plano (ou Markdown legado): converte em parágrafos HTML.
  // Mantém marcação simples de Markdown que sobreviveu (negrito/itálico) —
  // best-effort sem dependência adicional.
  var html = trim
  // **negrito** → <strong>
      .replaceAllMapped(
      RegExp(r'\*\*([^*]+)\*\*'), (m) => '<strong>${m[1]}</strong>')
  // *italico* → <em>  (depois do negrito pra não dar conflito)
      .replaceAllMapped(RegExp(r'(?<![*])\*([^*\n]+)\*(?![*])'),
          (m) => '<em>${m[1]}</em>');

  // Divide parágrafos por quebra dupla; se não tiver, por quebra simples.
  var partes = html
      .split(RegExp(r'\n\s*\n+'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  if (partes.length <= 1 && html.contains('\n')) {
    partes = html
        .split('\n')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
  }

  return partes.map((p) => '<p>$p</p>').join();
}

/// Converte Markdown residual (`**negrito**`, `*itálico*`) que ficou misturado
/// em conteúdo HTML — típico de textos inseridos manualmente no campo de texto
/// antes de passarem pelo editor do admin. Processa apenas fora de tags HTML.
String _sanitizarMarkdownResidual(String html) {
  // Opera segmento a segmento, pulando o interior das tags <...>
  final buf = StringBuffer();
  int i = 0;
  while (i < html.length) {
    if (html[i] == '<') {
      // Copia tag inteira sem tocar
      final end = html.indexOf('>', i);
      if (end == -1) {
        buf.write(html.substring(i));
        break;
      }
      buf.write(html.substring(i, end + 1));
      i = end + 1;
    } else {
      // Coleta texto até a próxima tag
      final next = html.indexOf('<', i);
      final segmento =
      next == -1 ? html.substring(i) : html.substring(i, next);
      // **negrito** → <strong>
      var s = segmento.replaceAllMapped(
          RegExp(r'\*\*([^*]+)\*\*'), (m) => '<strong>${m[1]}</strong>');
      // *itálico* (não cercado de outros *)
      s = s.replaceAllMapped(RegExp(r'(?<!\*)\*([^*\n]+)\*(?!\*)'),
              (m) => '<em>${m[1]}</em>');
      buf.write(s);
      if (next == -1) break;
      i = next;
    }
  }
  return buf.toString();
}

class _Seccao {
  final String titulo;
  final String conteudo;
  final bool destaque;
  final bool isSutra;
  const _Seccao({
    required this.titulo,
    required this.conteudo,
    this.destaque = false,
    this.isSutra = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// LeituraScreen
// ─────────────────────────────────────────────────────────────────────────────
class LeituraScreen extends StatefulWidget {
  final int fluxoId;
  final int dia;
  final String sessao;
  final int? periodo;

  const LeituraScreen({
    super.key,
    required this.fluxoId,
    required this.dia,
    required this.sessao,
    this.periodo,
  });

  static Future<void> mostrar(
      BuildContext context, {
        required int fluxoId,
        required int dia,
        required String sessao,
        int? periodo,
      }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.40),
      builder: (_) => LeituraScreen(
        fluxoId: fluxoId,
        dia: dia,
        sessao: sessao,
        periodo: periodo,
      ),
    );
  }

  @override
  State<LeituraScreen> createState() => _LeituraScreenState();
}

class _LeituraScreenState extends State<LeituraScreen> {
  bool _loading = true;
  bool _mostrarSadhana = false;
  int _seccaoAtual = 0;

  // Conteúdo carregado
  Map<String, dynamic>? _refugio;
  Map<String, dynamic>? _dedicatoria;
  List<Map<String, dynamic>> _invitatorios = [];
  Map<String, dynamic>? _invitatorioSelecionado;
  Map<String, dynamic>? _textoDia;
  Map<String, dynamic>? _sadhana;
  List<Map<String, dynamic>> _sutras = [];

  // Secções montadas após carregamento
  List<_Seccao> _seccoes = [];

  final _pageCtrl = PageController();
  final _navScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _carregarTextos();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _navScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregarTextos() async {
    final db = context.read<DatabaseService>();

    final refugios     = await db.getTextosFixosPorTipo('refugio');
    final dedicatorias = await db.getTextosFixosPorTipo('dedicatoria');
    final invitatorios = await db.getTextosFixosPorTipo('invitatório');
    final sadhanas     = await db.getTextosFixosPorTipo('sadhana');
    final sutras       = await db.getTextosFixosPorTipo('sutra');
    final textoDia     = await db.getTexto(
      fluxoId: widget.fluxoId,
      dia: widget.dia,
      sessao: widget.sessao,
      periodo: widget.periodo,
    );

    setState(() {
      _refugio                = refugios.isNotEmpty ? refugios.first : null;
      _dedicatoria            = dedicatorias.isNotEmpty ? dedicatorias.first : null;
      _invitatorios           = invitatorios;
      _invitatorioSelecionado = invitatorios.isNotEmpty ? invitatorios.first : null;
      _textoDia               = textoDia;
      _sadhana                = sadhanas.isNotEmpty ? sadhanas.first : null;
      _sutras                 = sutras;
      _loading                = false;
      _montarSeccoes();
    });
  }

  void _montarSeccoes() {
    final lista = <_Seccao>[];

    // 1. Refúgio
    lista.add(_Seccao(
      titulo: 'Prece de Refúgio',
      conteudo: _refugio?['conteudo'] ?? '— texto ainda não disponível —',
      destaque: true,
    ));

    // 2. Invitatório (primeiro da lista; seletor fica dentro da página)
    if (_invitatorios.isNotEmpty) {
      lista.add(_Seccao(
        titulo: _invitatorioSelecionado?['nome'] ?? 'Invitatório',
        conteudo: _invitatorioSelecionado?['conteudo'] ?? '',
      ));
    }

    // 3. Sutras — todos os cadastrados, ordenados pelo campo `ordem`
    final sutrasOrdenados = List<Map<String, dynamic>>.from(_sutras)
      ..sort((a, b) => ((a['ordem'] as int?) ?? 0)
          .compareTo((b['ordem'] as int?) ?? 0));

    for (final s in sutrasOrdenados) {
      lista.add(_Seccao(
        titulo: _bonitarNome((s['nome'] as String?) ?? 'Sutra'),
        conteudo: (s['conteudo'] as String? ?? '— texto ainda não disponível —'),
        isSutra: true,
      ));
    }

    // Fallback: garante pelo menos um slot de sutra se o banco estiver vazio
    if (sutrasOrdenados.isEmpty) {
      lista.add(const _Seccao(
        titulo: 'Sutra',
        conteudo: '— texto ainda não disponível —',
        isSutra: true,
      ));
    }

    // 4. Leitura do dia
    lista.add(_Seccao(
      titulo: 'Leitura · Dia ${widget.dia}',
      conteudo: _textoDia?['conteudo'] ??
          '— leitura ainda não disponível para esta sessão —',
    ));

    // 5. Sadhana (só se ativa) — sempre adiciona a secção quando o botão está
    // ligado, mesmo sem texto cadastrado, usando o mesmo placeholder de
    // Refúgio/Dedicatória. Antes a secção só aparecia se `_sadhana != null`,
    // então alternar o botão sem uma sadhana cadastrada não fazia nada visível.
    if (_mostrarSadhana) {
      lista.add(_Seccao(
        titulo: 'Sadhana',
        conteudo: (_sadhana?['conteudo'] as String?) ??
            '— texto ainda não disponível —',
        destaque: true,
      ));
    }

    // 6. Dedicatória
    lista.add(_Seccao(
      titulo: 'Prece Dedicatória',
      conteudo: _dedicatoria?['conteudo'] ?? '— texto ainda não disponível —',
      destaque: true,
    ));

    _seccoes = lista;
    // Garante que a secção actual é válida após reconstrução
    if (_seccaoAtual >= _seccoes.length) _seccaoAtual = 0;
  }

  void _irPara(int idx) {
    if (idx < 0 || idx >= _seccoes.length) return;
    setState(() => _seccaoAtual = idx);
    _pageCtrl.animateToPage(
      idx,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
    // Rola a barra de abas para mostrar a aba activa
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_navScrollCtrl.hasClients) {
        final itemW = 90.0;
        final offset = (idx * itemW) -
            (_navScrollCtrl.position.viewportDimension / 2 - itemW / 2);
        _navScrollCtrl.animateTo(
          offset.clamp(0, _navScrollCtrl.position.maxScrollExtent),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _toggleSadhana() {
    setState(() {
      _mostrarSadhana = !_mostrarSadhana;
      final anteriorIdx = _seccaoAtual;
      _montarSeccoes();
      // Mantém posição relativa
      _seccaoAtual = anteriorIdx.clamp(0, _seccoes.length - 1);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageCtrl.hasClients) {
        _pageCtrl.jumpToPage(_seccaoAtual);
      }
    });
  }

  /// Transforma um nome possivelmente em forma de slug (`sutra_tres_montes`)
  /// num label amigável (`Sutra dos Três Montes`). Se já tem espaço, devolve
  /// como está. Conhece os títulos mais comuns para preservar acentos.
  String _bonitarNome(String raw) {
    final trim = raw.trim();
    if (trim.contains(' ')) return trim;

    const conhecidos = {
      'sutra_coracao':        'Sutra do Coração',
      'coracao':              'Sutra do Coração',
      'sutra_tres_joias':     'Sutra das Três Joias',
      'tres_joias':           'Sutra das Três Joias',
      'sutra_tres_montes':    'Sutra dos Três Montes',
      'tres_montes':          'Sutra dos Três Montes',
      'sutra_triskandha':     'Sutra dos Três Montes',
      'triskandha':           'Sutra dos Três Montes',
      'dhammacakka':          'Dhammacakkappavattanasutta',
      'sadhana_gandenlhagyalma': 'Ganden Lha Gyalma',
      'gandenlhagyalma':      'Ganden Lha Gyalma',
    };
    final chave = trim.toLowerCase();
    if (conhecidos.containsKey(chave)) return conhecidos[chave]!;

    // Fallback genérico: title-case do slug
    return trim
        .split(RegExp(r'[_-]'))
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  String get _sessaoLabel {
    switch (widget.sessao) {
      case 'manha':     return 'Manhã';
      case 'tarde':     return 'Tarde';
      case 'noite':     return 'Noite';
      case 'madrugada': return 'Madrugada';
      default:          return widget.sessao;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.50,
      maxChildSize: 0.97,
      snap: true,
      snapSizes: const [0.50, 0.92, 0.97],
      builder: (_, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: _BC.bgDeep,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            children: [

              // ── Cabeçalho ───────────────────────────
              _Cabecalho(
                sessaoLabel: _sessaoLabel,
                dia: widget.dia,
                mostrarSadhana: _mostrarSadhana,
                onToggleSadhana: _toggleSadhana,
                onFechar: () => Navigator.of(context).pop(),
              ),

              // ── Linha pramana ────────────────────────
              Container(height: 2, color: _BC.pramanaRing.withOpacity(0.70)),

              if (_loading) ...[
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(
                        color: _BC.gold, strokeWidth: 2),
                  ),
                ),
              ] else ...[

                // ── Barra de navegação de secções ────────
                _BarraNavegacao(
                  seccoes: _seccoes,
                  actual: _seccaoAtual,
                  scrollCtrl: _navScrollCtrl,
                  onTap: _irPara,
                ),

                // ── Linha pramana abaixo da barra ────────
                Container(
                  height: 1,
                  color: _BC.pramanaRing.withOpacity(0.40),
                ),

                // ── Conteúdo paginado ────────────────────
                Expanded(
                  child: PageView.builder(
                    controller: _pageCtrl,
                    itemCount: _seccoes.length,
                    onPageChanged: (i) => setState(() => _seccaoAtual = i),
                    itemBuilder: (_, i) {
                      final s = _seccoes[i];
                      // Página especial do invitatório com seletor
                      final isInvitatorio = _invitatorios.isNotEmpty &&
                          i == 1;
                      return _PaginaSeccao(
                        seccao: s,
                        scrollCtrl: i == _seccaoAtual ? scrollCtrl : null,
                        invitatorios: isInvitatorio ? _invitatorios : null,
                        invitatorioSelecionado:
                        isInvitatorio ? _invitatorioSelecionado : null,
                        onInvitatorioChanged: isInvitatorio
                            ? (val) => setState(() {
                          _invitatorioSelecionado = val;
                          _montarSeccoes();
                        })
                            : null,
                      );
                    },
                  ),
                ),

                // ── Barra de sutras (rodapé) ──────────────
                _BarraSutras(
                  seccoes: _seccoes,
                  actual: _seccaoAtual,
                  onTap: _irPara,
                ),

                // ── Barra inferior: setas de navegação ───
                _BarraInferior(
                  actual: _seccaoAtual,
                  total: _seccoes.length,
                  onAnterior: () => _irPara(_seccaoAtual - 1),
                  onProximo: () => _irPara(_seccaoAtual + 1),
                  labelActual: _seccoes[_seccaoAtual].titulo,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cabeçalho
// ─────────────────────────────────────────────────────────────────────────────
class _Cabecalho extends StatelessWidget {
  final String sessaoLabel;
  final int dia;
  final bool mostrarSadhana;
  final VoidCallback onToggleSadhana;
  final VoidCallback onFechar;

  const _Cabecalho({
    required this.sessaoLabel,
    required this.dia,
    required this.mostrarSadhana,
    required this.onToggleSadhana,
    required this.onFechar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _BC.bgMid,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 14),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: _BC.white40,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              // Pramana
              Image.asset(
                'assets/images/pramana.png',
                width: 28, height: 28,
                errorBuilder: (_, __, ___) => const Icon(
                    Icons.self_improvement, color: _BC.gold, size: 24),
              ),
              const SizedBox(width: 10),
              // Título
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sessaoLabel,
                        style: const TextStyle(
                          fontSize: 17, color: Colors.white,
                          fontWeight: FontWeight.w600, letterSpacing: 0.3,
                        )),
                    Text('Dia $dia',
                        style: TextStyle(
                          fontSize: 11,
                          color: _BC.gold.withOpacity(0.80),
                          letterSpacing: 0.5,
                        )),
                  ],
                ),
              ),
              // Toggle Sadhana
              GestureDetector(
                onTap: onToggleSadhana,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: mostrarSadhana
                        ? _BC.pramanaRing.withOpacity(0.25)
                        : _BC.white20,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: mostrarSadhana ? _BC.pramanaRing : _BC.white40,
                      width: 1,
                    ),
                  ),
                  child: Text('Sadhana',
                      style: TextStyle(
                        fontSize: 11,
                        color: mostrarSadhana ? _BC.pramanaRing : _BC.gold,
                        fontWeight: FontWeight.w600,
                      )),
                ),
              ),
              const SizedBox(width: 8),
              // Fechar
              GestureDetector(
                onTap: onFechar,
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _BC.white20,
                    border: Border.all(color: _BC.white40, width: 1),
                  ),
                  child: const Icon(Icons.close, color: _BC.gold, size: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Barra de navegação (abas horizontais roláveis)
// ─────────────────────────────────────────────────────────────────────────────
class _BarraNavegacao extends StatelessWidget {
  final List<_Seccao> seccoes;
  final int actual;
  final ScrollController scrollCtrl;
  final void Function(int) onTap;

  const _BarraNavegacao({
    required this.seccoes,
    required this.actual,
    required this.scrollCtrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Filtra sutras — eles aparecem no rodapé, não no topo
    final visiveis = <(int, _Seccao)>[];
    for (int i = 0; i < seccoes.length; i++) {
      if (!seccoes[i].isSutra) visiveis.add((i, seccoes[i]));
    }

    return Container(
      height: 44,
      color: _BC.bgMid,
      child: ListView.builder(
        controller: scrollCtrl,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: visiveis.length,
        itemBuilder: (_, j) {
          final (origIdx, s) = visiveis[j];
          final activo = origIdx == actual;
          return GestureDetector(
            onTap: () => onTap(origIdx),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: activo
                    ? _BC.pramanaRing
                    : _BC.white20,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: activo ? _BC.pramanaRing : _BC.white40,
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                s.titulo,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: activo ? FontWeight.w700 : FontWeight.w400,
                  color: activo ? Colors.white : _BC.gold,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Barra inferior — setas + label da secção actual
// ─────────────────────────────────────────────────────────────────────────────
class _BarraInferior extends StatelessWidget {
  final int actual;
  final int total;
  final VoidCallback onAnterior;
  final VoidCallback onProximo;
  final String labelActual;

  const _BarraInferior({
    required this.actual,
    required this.total,
    required this.onAnterior,
    required this.onProximo,
    required this.labelActual,
  });

  @override
  Widget build(BuildContext context) {
    final temAnterior = actual > 0;
    final temProximo  = actual < total - 1;

    return Container(
      height: 52,
      color: _BC.bgMid,
      child: Row(
        children: [
          // Seta anterior
          _BotaoSeta(
            icone: Icons.chevron_left,
            activo: temAnterior,
            onTap: temAnterior ? onAnterior : null,
          ),

          // Label central
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  labelActual,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _BC.gold,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 3),
                // Dots indicador
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(total, (i) {
                    final a = i == actual;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: a ? 16 : 5,
                      height: 4,
                      decoration: BoxDecoration(
                        color: a
                            ? _BC.pramanaRing
                            : _BC.white40,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),

          // Seta próximo
          _BotaoSeta(
            icone: Icons.chevron_right,
            activo: temProximo,
            onTap: temProximo ? onProximo : null,
          ),
        ],
      ),
    );
  }
}

class _BotaoSeta extends StatelessWidget {
  final IconData icone;
  final bool activo;
  final VoidCallback? onTap;

  const _BotaoSeta({
    required this.icone,
    required this.activo,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: double.infinity,
        alignment: Alignment.center,
        child: Icon(
          icone,
          size: 28,
          color: activo ? _BC.gold : _BC.white40,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Barra de sutras (rodapé) — botões com nome completo dos sutras
// ─────────────────────────────────────────────────────────────────────────────
class _BarraSutras extends StatelessWidget {
  final List<_Seccao> seccoes;
  final int actual;
  final void Function(int) onTap;

  const _BarraSutras({
    required this.seccoes,
    required this.actual,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Recolhe sutras com seus índices originais
    final sutras = <(int, _Seccao)>[];
    for (int i = 0; i < seccoes.length; i++) {
      if (seccoes[i].isSutra) sutras.add((i, seccoes[i]));
    }
    if (sutras.isEmpty) return const SizedBox.shrink();

    return Container(
      color: _BC.bgMid,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Row(
        children: sutras.map((entry) {
          final (origIdx, s) = entry;
          final activo = origIdx == actual;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(origIdx),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: activo ? _BC.pramanaRing : _BC.white20,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: activo ? _BC.pramanaRing : _BC.white40,
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  s.titulo,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                    color: activo ? Colors.white : _BC.gold,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Página de uma secção — card bege com estrutura BUDA
// ─────────────────────────────────────────────────────────────────────────────
class _PaginaSeccao extends StatelessWidget {
  final _Seccao seccao;
  final ScrollController? scrollCtrl;
  final List<Map<String, dynamic>>? invitatorios;
  final Map<String, dynamic>? invitatorioSelecionado;
  final ValueChanged<Map<String, dynamic>?>? onInvitatorioChanged;

  const _PaginaSeccao({
    required this.seccao,
    this.scrollCtrl,
    this.invitatorios,
    this.invitatorioSelecionado,
    this.onInvitatorioChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Center(
        child: Container(
          // Camada 1: azul
          decoration: BoxDecoration(
            color: _BC.bgMid,
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.all(5),
          child: Container(
            // Camada 2: anel pramana
            decoration: BoxDecoration(
              color: seccao.destaque
                  ? _BC.pramanaRing
                  : _BC.cardBorda.withOpacity(0.85),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(2),
            child: Container(
              // Camada 3: card bege
              decoration: BoxDecoration(
                color: _BC.cardBege,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Título do card
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                    child: Row(
                      children: [
                        if (seccao.destaque) ...[
                          Container(
                            width: 3, height: 16,
                            decoration: BoxDecoration(
                              color: _BC.pramanaRing,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            seccao.titulo,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: seccao.destaque
                                  ? _BC.pramanaRing
                                  : _BC.textoOuro,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Seletor de invitatório (só nessa página)
                  if (invitatorios != null &&
                      invitatorios!.length > 1) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          color: _BC.bgMid.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _BC.cardBorda.withOpacity(0.35),
                            width: 1,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<Map<String, dynamic>>(
                            value: invitatorioSelecionado,
                            isExpanded: true,
                            dropdownColor: _BC.cardBege,
                            style: const TextStyle(
                              fontSize: 13,
                              color: _BC.textoEscuro,
                            ),
                            icon: const Icon(Icons.expand_more,
                                color: _BC.textoOuro, size: 20),
                            items: invitatorios!.map((inv) {
                              return DropdownMenuItem(
                                value: inv,
                                child: Text(inv['nome'] ?? ''),
                              );
                            }).toList(),
                            onChanged: onInvitatorioChanged,
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Divisor
                  Divider(
                    height: 1,
                    color: _BC.cardBorda.withOpacity(0.25),
                    indent: 16,
                    endIndent: 16,
                  ),

                  // Conteúdo — HTML completo (bold, italic, listas, headings,
                  // alinhamento, etc.) via flutter_html.
                  // <blockquote> é renderizado via extensão nativa Flutter porque
                  // flutter_html v3 ignora border/padding no Style de blockquote.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    child: Html(
                      data: _ensureHtml(seccao.conteudo),
                      extensions: [
                        TagExtension(
                          tagsToExtend: {'blockquote'},
                          builder: (extensionContext) {
                            // flutter_html 3.0.0 não expõe os filhos renderizados
                            // via builder. Reprocessamos o innerHtml com um Html
                            // aninhado dentro do Container de indentação.
                            final inner = extensionContext.innerHtml;
                            return Container(
                              margin: const EdgeInsets.only(
                                  top: 6, bottom: 10),
                              padding: const EdgeInsets.only(left: 12),
                              decoration: const BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                      color: _BC.pramanaRing, width: 3),
                                ),
                              ),
                              child: Html(
                                data: inner,
                                style: {
                                  'body': Style(
                                    fontSize: FontSize(15),
                                    color: _BC.textoMedio,
                                    fontStyle: FontStyle.italic,
                                    lineHeight: const LineHeight(1.65),
                                    letterSpacing: 0.2,
                                    margin: Margins.zero,
                                    padding: HtmlPaddings.zero,
                                  ),
                                  'p': Style(
                                    margin: Margins.only(bottom: 8),
                                    padding: HtmlPaddings.zero,
                                  ),
                                  'strong': Style(fontWeight: FontWeight.w700),
                                  'em': Style(fontStyle: FontStyle.italic),
                                },
                              ),
                            );
                          },
                        ),
                        // <doctab> → tab visual de 2em (SizedBox inline)
                        // flutter_html v3 ignora display:inline-block em spans,
                        // então usamos uma tag customizada com widget nativo.
                        TagExtension(
                          tagsToExtend: {'doctab'},
                          child: const SizedBox(width: 28),
                        ),
                      ],
                      style: {
                        'body': Style(
                          fontSize: FontSize(15),
                          color: _BC.textoEscuro,
                          lineHeight: const LineHeight(1.65),
                          letterSpacing: 0.2,
                          margin: Margins.zero,
                          padding: HtmlPaddings.zero,
                        ),
                        'p': Style(
                          margin: Margins.only(bottom: 12),
                          padding: HtmlPaddings.zero,
                        ),
                        'h1': Style(
                          fontSize: FontSize(22),
                          fontWeight: FontWeight.w700,
                          color: _BC.textoOuro,
                          margin: Margins.only(top: 12, bottom: 10),
                        ),
                        'h2': Style(
                          fontSize: FontSize(18),
                          fontWeight: FontWeight.w700,
                          color: _BC.textoOuro,
                          margin: Margins.only(top: 12, bottom: 8),
                        ),
                        'h3': Style(
                          fontSize: FontSize(16),
                          fontWeight: FontWeight.w600,
                          color: _BC.textoOuro,
                          margin: Margins.only(top: 10, bottom: 6),
                        ),
                        'strong': Style(fontWeight: FontWeight.w700),
                        'em': Style(fontStyle: FontStyle.italic),
                        'u': Style(textDecoration: TextDecoration.underline),
                        's': Style(textDecoration: TextDecoration.lineThrough),
                        'sub': Style(fontSize: FontSize(11)),
                        'sup': Style(fontSize: FontSize(11)),
                        'a': Style(
                          color: _BC.darkBlue,
                          textDecoration: TextDecoration.underline,
                        ),
                        'ul': Style(margin: Margins.only(bottom: 12, left: 0)),
                        'ol': Style(margin: Margins.only(bottom: 12, left: 0)),
                        'li': Style(margin: Margins.only(bottom: 4)),
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}