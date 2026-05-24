import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/keys.dart';

/// Operações administrativas em auth.users que requerem service_role.
///
/// ⚠️ Usa o service_role key embutido em keys.dart. Em produção, o ideal é
/// mover essas operações pra uma Supabase Edge Function que valida o caller.
/// Por ora, mantemos client-side aceitando o trade-off de segurança.
class AuthAdminService {
  // Cliente paralelo com service_role — só usado para operações admin
  final SupabaseClient _adminClient = SupabaseClient(
    SupabaseKeys.supabaseUrl,
    SupabaseKeys.supabaseServiceKey,
  );

  // Cliente normal (anon) — usado para resend e magic link
  SupabaseClient get _anon => Supabase.instance.client;

  /// Envia convite. Cria usuário em auth.users com email enviado pra ele
  /// definir senha. O email autorizado deve estar em admins_autorizados.
  Future<void> inviteUser(String email) async {
    final e = email.trim().toLowerCase();
    await _adminClient.auth.admin.inviteUserByEmail(e);
    // Aguarda 2s para o usuário ser criado antes de enviar o reset
    await Future.delayed(const Duration(seconds: 2));
    await _anon.auth.resetPasswordForEmail(e);
  }

  /// Reenvia o email de confirmação de signup pra um usuário existente
  /// que ainda não confirmou o cadastro.
  Future<void> resendSignupConfirmation(String email) async {
    await _anon.auth.resend(
      type: OtpType.signup,
      email: email.trim().toLowerCase(),
    );
  }

  /// Envia magic link (login sem senha) pra um email já cadastrado.
  Future<void> sendMagicLink(String email) async {
    await _anon.auth.signInWithOtp(
      email: email.trim().toLowerCase(),
      shouldCreateUser: false,
    );
  }

  /// Troca o email de um usuário existente. Encontra pelo email antigo.
  /// Supabase envia email de confirmação pro novo email automaticamente.
  Future<void> changeUserEmail({
    required String emailAntigo,
    required String emailNovo,
  }) async {
    final user = await findUserByEmail(emailAntigo);
    if (user == null) {
      throw Exception('Usuário com email $emailAntigo não encontrado.');
    }
    await _adminClient.auth.admin.updateUserById(
      user.id,
      attributes: AdminUserAttributes(email: emailNovo.trim().toLowerCase()),
    );
  }

  /// Busca usuário em auth.users pelo email. Pagina até encontrar.
  Future<User?> findUserByEmail(String email) async {
    final alvo = email.trim().toLowerCase();
    int page = 1;
    const perPage = 200;
    while (true) {
      final users = await _adminClient.auth.admin.listUsers(
        page: page,
        perPage: perPage,
      );
      if (users.isEmpty) return null;
      for (final u in users) {
        if ((u.email ?? '').toLowerCase() == alvo) return u;
      }
      if (users.length < perPage) return null;
      page++;
    }
  }

  /// Retorna true se o email já tem conta em auth.users.
  Future<bool> userExists(String email) async {
    return (await findUserByEmail(email)) != null;
  }
}
