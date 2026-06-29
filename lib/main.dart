import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:upgrader/upgrader.dart';
import 'config/keys.dart';
import 'services/database_service.dart';
import 'services/sync_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // sqflite requires FFI on Windows, macOS and Linux
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Inicializa Supabase
  await Supabase.initialize(
    url: SupabaseKeys.supabaseUrl,
    anonKey: SupabaseKeys.supabaseAnonKey,
  );

  // Limpa qualquer sessão persistida — login só vale durante a sessão
  // atual do app; ao fechar e reabrir, precisa autenticar de novo.
  try {
    await Supabase.instance.client.auth.signOut();
  } catch (_) {/* já estava deslogado */}

  // Inicializa banco local
  final dbService = DatabaseService();
  await dbService.init();

  runApp(
    MultiProvider(
      providers: [
        Provider<DatabaseService>.value(value: dbService),
        ChangeNotifierProvider(
          create: (_) => SyncService(dbService),
        ),
      ],
      child: const LiturgiaBudaApp(),
    ),
  );
}

class LiturgiaBudaApp extends StatelessWidget {
  const LiturgiaBudaApp({super.key});

  static final _upgrader = Upgrader(
    storeController: UpgraderStoreController(
      onWindows: () => UpgraderAppcastStore(
        appcastURL:
            'https://raw.githubusercontent.com/TashiRabten/LiturgiaBUDA/main/appcast.xml',
      ),
    ),
    daysUntilAlertAgain: 1,
  );

  @override
  Widget build(BuildContext context) {
    return UpgradeAlert(
      upgrader: _upgrader,
      child: MaterialApp(
        title: 'LiturgiaBUDA',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF8B4513),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          fontFamily: 'Serif',
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF8B4513),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
      ),
    );
  }
}