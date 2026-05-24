import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/buda_theme.dart';
import 'admin_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

enum _Modo { entrar, cadastrar }

class _AdminLoginScreenState extends State<AdminLoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _senhaConfirmaController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  _Modo _modo = _Modo.entrar;
  bool _loading = false;
  bool _mostrarSenha = false;
  String? _erro;
  String? _aviso;

  late final AnimationController _animController;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    _senhaConfirmaController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _trocarModo() {
    setState(() {
      _modo = _modo == _Modo.entrar ? _Modo.cadastrar : _Modo.entrar;
      _erro = null;
      _aviso = null;
      _senhaConfirmaController.clear();
    });
  }

  Future<void> _submeter() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _erro = null;
      _aviso = null;
    });

    try {
      if (_modo == _Modo.entrar) {
        await _entrar();
      } else {
        await _cadastrar();
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _erro = _traduzirErro(e.message));
    } catch (e) {
      if (mounted) setState(() => _erro = 'Erro de conexão. Tente novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _entrar() async {
    final response = await Supabase.instance.client.auth.signInWithPassword(
      email: _emailController.text.trim(),
      password: _senhaController.text,
    );

    if (!mounted) return;

    if (response.user != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AdminScreen()),
      );
    } else {
      setState(() => _erro = 'Email ou senha inválidos.');
    }
  }

  Future<void> _cadastrar() async {
    final email = _emailController.text.trim().toLowerCase();

    // Pré-check: email está na allowlist?
    final autorizado = await _emailEstaAutorizado(email);
    if (!autorizado) {
      if (mounted) {
        setState(() => _erro =
        'Este email não está autorizado. Solicite ao administrador que adicione seu email à lista.');
      }
      return;
    }

    final response = await Supabase.instance.client.auth.signUp(
      email: email,
      password: _senhaController.text,
    );

    if (!mounted) return;

    // Com "Confirm email" ativado no Supabase, session=null até o usuário
    // clicar no link de confirmação enviado por email.
    if (response.session != null) {
      // Confirmação está desligada — vai direto pro painel
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AdminScreen()),
      );
    } else if (response.user != null) {
      setState(() {
        _aviso =
        'Email de confirmação enviado para $email.\nClique no link recebido para ativar sua conta — só então a senha será válida.';
        _modo = _Modo.entrar;
        _senhaConfirmaController.clear();
      });
    } else {
      setState(() => _erro = 'Não foi possível criar a conta.');
    }
  }



  Future<bool> _emailEstaAutorizado(String email) async {
    try {
      final data = await Supabase.instance.client
          .from('admins_autorizados')
          .select('email')
          .eq('email', email)
          .maybeSingle();
      return data != null;
    } catch (_) {
      // Se a tabela ainda não existe ou houve erro de rede,
      // confiamos no trigger do Supabase que vai rejeitar.
      return true;
    }
  }

  Future<void> _recuperarSenha() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _erro = 'Informe um email válido antes.');
      return;
    }
    setState(() {
      _loading = true;
      _erro = null;
      _aviso = null;
    });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (mounted) {
        setState(() =>
        _aviso = 'Email de recuperação enviado para $email.');
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _erro = _traduzirErro(e.message));
    } catch (e) {
      if (mounted) setState(() => _erro = 'Erro de conexão.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _traduzirErro(String message) {
    if (message.contains('Email não autorizado')) {
      return 'Este email não está autorizado. Solicite ao administrador que adicione seu email à lista.';
    }
    if (message.contains('Invalid login credentials')) {
      return 'Email ou senha incorretos.';
    }
    if (message.contains('Email not confirmed')) {
      return 'Email ainda não confirmado. Verifique sua caixa de entrada.';
    }
    if (message.contains('User already registered')) {
      return 'Este email já está cadastrado. Tente entrar.';
    }
    if (message.contains('Password should be at least')) {
      return 'Senha muito curta — use pelo menos 6 caracteres.';
    }
    if (message.contains('Too many requests')) {
      return 'Muitas tentativas. Aguarde alguns minutos.';
    }
    if (message.contains('Unable to validate email')) {
      return 'Email inválido.';
    }
    return 'Erro ao autenticar. Tente novamente.';
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: budaTheme(),
      child: Builder(builder: _buildScaffold),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: BudaPalette.mainBlue,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: BudaPalette.gold,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Fechar',
        ),
      ),
      body: FadeTransition(
        opacity: _fadeIn,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [

                      // Logo BUDA com anel pramana
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: BudaPalette.bgMid,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: BudaPalette.pramanaRing, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.20),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Image.asset(
                            'assets/images/BUDA.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.self_improvement,
                              size: 40,
                              color: BudaPalette.gold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Título
                      Text(
                        _modo == _Modo.entrar
                            ? 'PAINEL DA SECRETARIA'
                            : 'CRIAR CONTA',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: BudaPalette.pramanaRing,
                          letterSpacing: 2,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 8),

                      Text(
                        _modo == _Modo.entrar
                            ? 'Entre com seu email e senha.'
                            : 'Cadastre-se com um email válido. Você receberá uma confirmação por email.',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFE8C97A),
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 40),

                      // Campo email
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          hintText: 'secretaria@pramana.org',
                          prefixIcon: const Icon(Icons.mail_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Informe o email.';
                          }
                          if (!val.contains('@')) {
                            return 'Email inválido.';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Campo senha
                      TextFormField(
                        controller: _senhaController,
                        obscureText: !_mostrarSenha,
                        textInputAction: _modo == _Modo.cadastrar
                            ? TextInputAction.next
                            : TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (_modo == _Modo.entrar) _submeter();
                        },
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _mostrarSenha
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () => setState(
                                    () => _mostrarSenha = !_mostrarSenha),
                            tooltip: _mostrarSenha
                                ? 'Ocultar senha'
                                : 'Mostrar senha',
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Informe a senha.';
                          }
                          if (_modo == _Modo.cadastrar && val.length < 6) {
                            return 'Mínimo 6 caracteres.';
                          }
                          return null;
                        },
                      ),



                      // Campo confirmar senha (só no cadastro)
                      if (_modo == _Modo.cadastrar) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _senhaConfirmaController,
                          obscureText: !_mostrarSenha,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submeter(),
                          decoration: InputDecoration(
                            labelText: 'Confirmar senha',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Confirme a senha.';
                            }
                            if (val != _senhaController.text) {
                              return 'Senhas não conferem.';
                            }
                            return null;
                          },
                        ),
                      ],

                      // Link "Esqueci a senha" (só no login)
                      if (_modo == _Modo.entrar) ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _loading ? null : _recuperarSenha,
                            child: const Text('Esqueci a senha',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ] else
                        const SizedBox(height: 8),

                      // Mensagem de aviso (sucesso/info)
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        child: _aviso != null
                            ? Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: colorScheme.primary, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _aviso!,
                                  style: TextStyle(
                                    color:
                                    colorScheme.onPrimaryContainer,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                            : const SizedBox.shrink(),
                      ),

                      // Mensagem de erro
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        child: _erro != null
                            ? Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline,
                                  color: colorScheme.error, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _erro!,
                                  style: TextStyle(
                                    color: colorScheme.onErrorContainer,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                            : const SizedBox.shrink(),
                      ),

                      const SizedBox(height: 24),

                      // Botão submeter
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _loading ? null : _submeter,
                          style: FilledButton.styleFrom(
                            padding:
                            const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _loading
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : Text(
                            _modo == _Modo.entrar
                                ? 'Entrar'
                                : 'Criar conta',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Toggle entre Entrar e Cadastrar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _modo == _Modo.entrar
                                ? 'Recebeu um convite?'
                                : 'Já tem conta?',
                            style: const TextStyle(
                              fontSize: 13,
                              color: BudaPalette.cardBege,
                            ),
                          ),
                          TextButton(
                            onPressed: _loading ? null : _trocarModo,
                            style: TextButton.styleFrom(
                              foregroundColor: BudaPalette.gold,
                            ),
                            child: Text(
                              _modo == _Modo.entrar
                                  ? 'Primeiro Acesso'
                                  : 'Entrar',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}