import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/sync_service.dart';
import '../services/database_service.dart';
import 'leitura_screen.dart';
import 'admin/login_screen.dart' show AdminLoginScreen;
import 'admin/admin_screen.dart' show AdminScreen;

// ─────────────────────────────────────────────────────────────────────────────
// Cores do brand BUDA
// ─────────────────────────────────────────────────────────────────────────────

class BudaColors {
  static const Color mainBlue      = Color(0xFF88A9CC);
  static const Color lightBlue     = Color(0xFFA8C4DC);
  static const Color slateBlue     = Color(0xFF5A7A9A);
  static const Color darkBlue      = Color(0xFF3E7EBE);
  static const Color bgDeep        = Color(0xFF2E4A6A);
  static const Color bgMid         = Color(0xFF3A5A7C);
  static const Color darkGoldenrod = Color(0xFFB8860B);
  static const Color gold          = Color(0xFFD4A843);
  static const Color goldSoft      = Color(0xFFE8C97A);
  static const Color goldenBrown   = Color(0xFF8B7355);
  static const Color buttonGold    = Color(0xFFBFAF7C);
  static const Color goldenKhaki   = Color(0xFFF0E68C);
  static const Color lightBeige    = Color(0xFFF5F5DC);
  static const Color textDark      = Color(0xFF2C3E50);
  static const Color textMedium    = Color(0xFF4A5A6A);
  static const Color textLight     = Color(0xFF7A8B9C);
  static const Color toolbarBorder = Color(0xFF1E375A);
  static const Color pramanaRing   = Color(0xFFCC3300);
  static const Color white70       = Color(0xB3FFFFFF);
  static const Color white40       = Color(0x66FFFFFF);
  static const Color white20       = Color(0x33FFFFFF);
}

// ─────────────────────────────────────────────────────────────────────────────
// Constantes
// ─────────────────────────────────────────────────────────────────────────────

const _diasSemana = [
  'Segunda', 'Terça', 'Quarta',
  'Quinta',  'Sexta', 'Sábado', 'Domingo',
];

const _diasSemanaCompleto = [
  'Segunda-feira', 'Terça-feira', 'Quarta-feira',
  'Quinta-feira',  'Sexta-feira', 'Sábado', 'Domingo',
];

const _meses = [
  'janeiro','fevereiro','março','abril','maio','junho',
  'julho','agosto','setembro','outubro','novembro','dezembro',
];

const _mesesCompleto = [
  'Janeiro','Fevereiro','Março','Abril','Maio','Junho',
  'Julho','Agosto','Setembro','Outubro','Novembro','Dezembro',
];

// ─────────────────────────────────────────────────────────────────────────────
// HomeScreen
// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {

  bool _painelAberto = false;
  late final AnimationController _painelCtrl;
  late final Animation<double> _painelAnim;
  static const double _painelLargura = 240;

  late final PageController _pageCtrl;
  late int _paginaAtual;
  late DateTime _dataBase;


  @override
  void initState() {
    super.initState();
    _painelCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _painelAnim = CurvedAnimation(parent: _painelCtrl, curve: Curves.easeInOut);

    final hoje = DateTime.now();
    _paginaAtual = hoje.weekday - 1;
    _dataBase = hoje.subtract(Duration(days: _paginaAtual));
    _pageCtrl = PageController(initialPage: _paginaAtual);
  }

  @override
  void dispose() {
    _painelCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  DateTime _dataParaPagina(int idx) => _dataBase.add(Duration(days: idx));

  int _diaDoAnoParaData(DateTime d) =>
      d.difference(DateTime(d.year, 1, 1)).inDays + 1;

  int _periodoParaData(DateTime d) {
    if (d.month <= 4) return 1;
    if (d.month <= 8) return 2;
    return 3;
  }

  String _sessaoAtual() {
    final h = DateTime.now().hour;
    if (h >= 4  && h < 12) return 'manha';
    if (h >= 12 && h < 18) return 'tarde';
    if (h >= 18 && h < 23) return 'noite';
    return 'madrugada';
  }

  void _togglePainel() {
    setState(() => _painelAberto = !_painelAberto);
    _painelAberto ? _painelCtrl.forward() : _painelCtrl.reverse();
  }

  void _irParaDia(int idx) {
    _togglePainel();
    _pageCtrl.animateToPage(idx,
        duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
  }

  void _abrirAdmin() {
    // Se já logou nesta sessão do app, vai direto pro painel
    final logado = Supabase.instance.client.auth.currentUser != null;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => logado ? const AdminScreen() : const AdminLoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();

    return Scaffold(
      backgroundColor: BudaColors.mainBlue,
      body: Stack(
        children: [

          // ── Conteúdo principal ──────────────────────
          SafeArea(
            child: Column(
              children: [

                // ── AppBar refinado ───────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 6),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _togglePainel,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: BudaColors.white20,
                            border: Border.all(
                              color: BudaColors.white40,
                              width: 1,
                            ),
                          ),
                          child: AnimatedBuilder(
                            animation: _painelAnim,
                            builder: (_, __) => Icon(
                              _painelAberto ? Icons.close : Icons.menu,
                              color: BudaColors.gold,
                              size: 18,
                            ),
                          ),
                        ),
                      ),

                      Expanded(
                        child: Center(
                          child: _DotsIndicador(
                              total: 7, atual: _paginaAtual),
                        ),
                      ),

                      GestureDetector(
                        onTap: () => context.read<SyncService>().sync(),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: BudaColors.white20,
                            border: Border.all(
                              color: BudaColors.white40,
                              width: 1,
                            ),
                          ),
                          child: sync.syncing
                              ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: BudaColors.gold,
                            ),
                          )
                              : const Icon(Icons.sync,
                              color: BudaColors.gold, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: PageView.builder(
                    controller: _pageCtrl,
                    onPageChanged: (i) =>
                        setState(() => _paginaAtual = i),
                    itemCount: 7,
                    itemBuilder: (_, idx) {
                      final data = _dataParaPagina(idx);
                      final eHoje = idx == DateTime.now().weekday - 1;
                      return _PaginaDia(
                        data: data,
                        eHoje: eHoje,
                        sessaoAtual: _sessaoAtual(),
                        diaDoAno: _diaDoAnoParaData(data),
                        periodo: _periodoParaData(data),
                        onLogoTap: _abrirAdmin,
                        onIniciarSessao: (sessao) {
                          LeituraScreen.mostrar(
                            context,
                            fluxoId: 1,
                            dia: _diaDoAnoParaData(data),
                            sessao: sessao,
                            periodo: _periodoParaData(data),
                          );
                        },
                      );
                    },
                  ),
                ),

                if (sync.erro != null)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(sync.erro!,
                        style: const TextStyle(
                            color: Color(0xFFFF6B6B), fontSize: 11)),
                  ),
              ],
            ),
          ),

          // ── Overlay ──────────────────────────────────
          AnimatedBuilder(
            animation: _painelAnim,
            builder: (_, __) => _painelAnim.value > 0
                ? GestureDetector(
              onTap: _togglePainel,
              child: Container(
                  color: Colors.black
                      .withOpacity(0.45 * _painelAnim.value)),
            )
                : const SizedBox.shrink(),
          ),

          // ── Painel lateral ────────────────────────────
          AnimatedBuilder(
            animation: _painelAnim,
            builder: (_, child) => Transform.translate(
              offset: Offset(_painelLargura * (_painelAnim.value - 1), 0),
              child: child,
            ),
            child: SafeArea(
              child: Container(
                width: _painelLargura,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: BudaColors.toolbarBorder,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 24,
                      offset: const Offset(6, 0),
                    ),
                  ],
                ),
                child: _PainelLateral(
                  diasSemana: _diasSemana,
                  paginaAtual: _paginaAtual,
                  dataBase: _dataBase,
                  sessaoAtual: _sessaoAtual(),
                  onDiaSelecionado: _irParaDia,
                  onSessaoSelecionada: (diaIdx, sessao) {
                    _togglePainel();
                    final data = _dataParaPagina(diaIdx);
                    LeituraScreen.mostrar(
                      context,
                      fluxoId: 1,
                      dia: _diaDoAnoParaData(data),
                      sessao: sessao,
                      periodo: _periodoParaData(data),
                    );
                  },
                ),
              ),
            ),
          ),

        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Painel lateral
// ─────────────────────────────────────────────────────────────────────────────

class _PainelLateral extends StatefulWidget {
  final List<String> diasSemana;
  final int paginaAtual;
  final DateTime dataBase;
  final String sessaoAtual;
  final void Function(int) onDiaSelecionado;
  final void Function(int diaIdx, String sessao) onSessaoSelecionada;

  const _PainelLateral({
    required this.diasSemana,
    required this.paginaAtual,
    required this.dataBase,
    required this.sessaoAtual,
    required this.onDiaSelecionado,
    required this.onSessaoSelecionada,
  });

  @override
  State<_PainelLateral> createState() => _PainelLateralState();
}

class _PainelLateralState extends State<_PainelLateral> {
  int _expandido = -1;

  static const _sessoes = [
    ('manha',     'Manhã'),
    ('tarde',     'Tarde'),
    ('noite',     'Noite'),
    ('madrugada', 'Madrugada'),
  ];

  @override
  void initState() {
    super.initState();
    _expandido = widget.paginaAtual;
  }

  @override
  Widget build(BuildContext context) {
    final hoje = DateTime.now().weekday - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 4),
          child: Row(
            children: [
              Image.asset(
                'assets/images/BUDA.png',
                width: 20,
                height: 20,
                errorBuilder: (_, __, ___) => const Icon(
                    Icons.self_improvement, size: 18, color: BudaColors.gold),
              ),
              const SizedBox(width: 8),
              const Text(
                'LiturgiaBUDA',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: BudaColors.gold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),

        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Divider(color: BudaColors.goldenBrown, height: 1),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: widget.diasSemana.length,
            itemBuilder: (_, i) {
              final data = widget.dataBase.add(Duration(days: i));
              final eHoje = i == hoje;
              final eSelecionado = i == widget.paginaAtual;
              final eExpandido = i == _expandido;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  InkWell(
                    onTap: () {
                      setState(() => _expandido = eExpandido ? -1 : i);
                      widget.onDiaSelecionado(i);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 11),
                      decoration: BoxDecoration(
                        color: eSelecionado
                            ? BudaColors.slateBlue.withOpacity(0.45)
                            : Colors.transparent,
                        border: eSelecionado
                            ? const Border(
                          left: BorderSide(
                            color: BudaColors.gold,
                            width: 3,
                          ),
                        )
                            : null,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      widget.diasSemana[i],
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: eSelecionado || eExpandido
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: eSelecionado || eExpandido
                                            ? BudaColors.gold
                                            : BudaColors.lightBlue,
                                      ),
                                    ),
                                    if (eHoje) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: BudaColors.gold,
                                          borderRadius:
                                          BorderRadius.circular(3),
                                        ),
                                        child: const Text(
                                          'hoje',
                                          style: TextStyle(
                                            fontSize: 8,
                                            color: BudaColors.toolbarBorder,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  '${data.day} de ${_meses[data.month - 1]}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: BudaColors.textLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedRotation(
                            turns: eExpandido ? 0.25 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: const Icon(
                              Icons.chevron_right,
                              color: BudaColors.goldenBrown,
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  AnimatedCrossFade(
                    firstChild: const SizedBox(width: double.infinity),
                    secondChild: Container(
                      color: BudaColors.toolbarBorder,
                      child: Column(
                        children: _sessoes.map((s) {
                          final (id, label) = s;
                          final eSessaoAtual = eHoje && id == widget.sessaoAtual;
                          return InkWell(
                            onTap: () => widget.onSessaoSelecionada(i, id),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 36, vertical: 10),
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: eSessaoAtual
                                        ? BudaColors.gold
                                        : BudaColors.slateBlue
                                        .withOpacity(0.4),
                                    width: eSessaoAtual ? 2 : 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: eSessaoAtual
                                          ? BudaColors.gold
                                          : BudaColors.lightBlue
                                          .withOpacity(0.85),
                                      fontWeight: eSessaoAtual
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                                  ),
                                  if (eSessaoAtual) ...[
                                    const Spacer(),
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: BudaColors.gold,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    crossFadeState: eExpandido
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 220),
                  ),

                ],
              );
            },
          ),
        ),

        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Text(
            '',
            style: TextStyle(
              fontSize: 10,
              color: BudaColors.goldenBrown,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Página de um dia — visual refinado, sem botões de sessão no corpo
// ─────────────────────────────────────────────────────────────────────────────

class _PaginaDia extends StatelessWidget {
  final DateTime data;
  final bool eHoje;
  final String sessaoAtual;
  final int diaDoAno;
  final int periodo;
  final void Function(String sessao) onIniciarSessao;
  final VoidCallback onLogoTap;

  const _PaginaDia({
    required this.data,
    required this.eHoje,
    required this.sessaoAtual,
    required this.diaDoAno,
    required this.periodo,
    required this.onIniciarSessao,
    required this.onLogoTap,
  });

  static const _periodoNome = {
    1: 'Espírito da Renúncia',
    2: 'Bodhicitta Aspirativa',
    3: 'Bodhicitta Última',
  };

  static const _periodoFluxo = {
    1: '1º Período · Fluxo Principal',
    2: '2º Período · Fluxo Principal',
    3: '3º Período · Fluxo Principal',
  };

  static const _sessaoNome = {
    'manha':     'Manhã',
    'tarde':     'Tarde',
    'noite':     'Noite',
    'madrugada': 'Madrugada',
  };

  static Widget _logoFallback(
      BuildContext ctx, Object err, StackTrace? st) =>
      const Icon(Icons.self_improvement, size: 90, color: BudaColors.gold);

  @override
  Widget build(BuildContext context) {
    final diaNome = _diasSemanaCompleto[data.weekday - 1].toUpperCase();
    final dataNome =
        '${data.day} de ${_mesesCompleto[data.month - 1]} de ${data.year}';
    final semana = ((diaDoAno - 1) ~/ 7) + 1;

    // ── Paleta interna do card ─────────────────────
    const cardBege       = Color(0xFFF5EDD8);
    const cardBordaBege  = Color(0xFF8B7355);  // goldenBrown
    const textoEscuro    = Color(0xFF2C3252);
    const textoMedio     = Color(0xFF5A6080);
    const textoOuro      = Color(0xFFB8860B);  // darkGoldenrod

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      child: Center(
        child: Container(
          width: 320,  // largura fixa — azul visível dos dois lados
          decoration: BoxDecoration(
            // Camada 1: fundo azul BUDA
            color: BudaColors.bgMid,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.22),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(6),
          child: Container(
            // Camada 2: anel pramana (vermelho)
            decoration: BoxDecoration(
              color: BudaColors.pramanaRing,
              borderRadius: BorderRadius.circular(17),
            ),
            padding: const EdgeInsets.all(3),
            child: Container(
              // Camada 3: card bege central
              decoration: BoxDecoration(
                color: cardBege,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [

                  // ── Topo: BUDA.png + data + subtítulo ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Column(
                      children: [

                        // Logo BUDA central — clicável (1 toque → painel admin)
                        GestureDetector(
                          onTap: onLogoTap,
                          child: SizedBox(
                            width: 100,
                            height: 100,
                            child: Image(
                              image: const AssetImage('assets/images/BUDA.png'),
                              fit: BoxFit.contain,
                              errorBuilder: _logoFallback,
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Data
                        Text(
                          dataNome,
                          style: const TextStyle(
                            fontSize: 13,
                            color: textoMedio,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.3,
                          ),
                        ),

                        const SizedBox(height: 4),

                        // Período · Dia
                        Text(
                          '${(_periodoNome[periodo] ?? '').toUpperCase()} · DIA $diaDoAno',
                          style: const TextStyle(
                            fontSize: 9,
                            color: textoOuro,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Nome do dia
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            diaNome,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: BudaColors.pramanaRing,
                              letterSpacing: 2.5,
                              height: 1,
                            ),
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          _periodoFluxo[periodo] ?? '',
                          style: const TextStyle(
                            fontSize: 11,
                            color: textoMedio,
                            fontStyle: FontStyle.italic,
                            letterSpacing: 0.3,
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Divisor decorativo
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(width: 36, height: 1,
                                color: cardBordaBege.withOpacity(0.35)),
                            const SizedBox(width: 8),
                            ...List.generate(3, (_) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: Container(
                                width: 5, height: 5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: cardBordaBege.withOpacity(0.5),
                                ),
                              ),
                            )),
                            const SizedBox(width: 8),
                            Container(width: 36, height: 1,
                                color: cardBordaBege.withOpacity(0.35)),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Período em ouro
                        Text(
                          (_periodoNome[periodo] ?? '').toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            color: textoOuro,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Botão sessão (hoje) ou aviso (outro dia)
                        if (eHoje) ...[
                          GestureDetector(
                            onTap: () => onIniciarSessao(sessaoAtual),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14, horizontal: 32),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: cardBordaBege.withOpacity(0.55),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Sessão da ${_sessaoNome[sessaoAtual] ?? sessaoAtual}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      color: textoEscuro,
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'TOQUE PARA INICIAR',
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: textoOuro.withOpacity(0.85),
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 2.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ] else ...[
                          Text(
                            'Selecione uma sessão no menu',
                            style: TextStyle(
                              fontSize: 12,
                              color: textoMedio.withOpacity(0.7),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),

                  // ── Divisória horizontal ──────────────
                  Divider(height: 1, color: cardBordaBege.withOpacity(0.30)),

                  // ── Painel de informações ─────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 16, 28, 20),
                    child: Column(
                      children: [
                        _InfoLinhaCreme(
                          label: 'Fluxo Principal',
                          valor: '${periodo}º Período',
                          textoOuro: textoOuro,
                          textoMedio: textoMedio,
                        ),
                        Divider(height: 20, color: cardBordaBege.withOpacity(0.18)),
                        _InfoLinhaCreme(
                          label: 'Dia do Ano',
                          valor: '$diaDoAno',
                          textoOuro: textoOuro,
                          textoMedio: textoMedio,
                        ),
                        Divider(height: 20, color: cardBordaBege.withOpacity(0.18)),
                        _InfoLinhaCreme(
                          label: 'Semana',
                          valor: '$semana',
                          textoOuro: textoOuro,
                          textoMedio: textoMedio,
                        ),
                        if (eHoje) ...[
                          Divider(height: 20, color: cardBordaBege.withOpacity(0.18)),
                          _InfoLinhaCreme(
                            label: 'Sessão Atual',
                            valor: _sessaoNome[sessaoAtual] ?? '',
                            textoOuro: textoOuro,
                            textoMedio: textoMedio,
                            destaque: true,
                          ),
                        ],
                      ],
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

// ─────────────────────────────────────────────────────────────────────────────
// Widgets auxiliares
// ─────────────────────────────────────────────────────────────────────────────

class _InfoLinha extends StatelessWidget {
  final String label;
  final String valor;
  final bool destaque;

  const _InfoLinha({
    required this.label,
    required this.valor,
    this.destaque = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              color: BudaColors.lightBlue.withOpacity(0.65),
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          Text(
            valor,
            style: TextStyle(
              fontSize: 13,
              color: destaque ? BudaColors.gold : Colors.white,
              fontWeight: destaque ? FontWeight.w600 : FontWeight.w400,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoDivisor extends StatelessWidget {
  const _InfoDivisor();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, color: BudaColors.white40);
  }
}

// Widget de linha de info para o card bege (tema claro)
class _InfoLinhaCreme extends StatelessWidget {
  final String label;
  final String valor;
  final Color textoOuro;
  final Color textoMedio;
  final bool destaque;

  const _InfoLinhaCreme({
    required this.label,
    required this.valor,
    required this.textoOuro,
    required this.textoMedio,
    this.destaque = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            color: textoMedio.withOpacity(0.70),
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        Text(
          valor,
          style: TextStyle(
            fontSize: 13,
            color: destaque ? textoOuro : const Color(0xFF2C3252),
            fontWeight: destaque ? FontWeight.w700 : FontWeight.w400,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dots indicador de página
// ─────────────────────────────────────────────────────────────────────────────

class _DotsIndicador extends StatelessWidget {
  final int total;
  final int atual;

  const _DotsIndicador({required this.total, required this.atual});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final ativo = i == atual;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: ativo ? 22 : 6,
          height: 5,
          decoration: BoxDecoration(
            color: ativo ? BudaColors.gold : BudaColors.white40,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}