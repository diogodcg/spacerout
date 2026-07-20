import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/supabase_config.dart';
import 'features/auth/data/auth_providers.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/loja/presentation/premios_screen.dart';
import 'features/loja/presentation/resgates_screen.dart';
import 'features/missoes/presentation/comprovacoes_screen.dart';
import 'features/missoes/presentation/missoes_screen.dart';
import 'features/organizacao/data/organizacao_providers.dart';
import 'features/organizacao/presentation/onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  runApp(const ProviderScope(child: SpaceRoutApp()));
}

class SpaceRoutApp extends StatelessWidget {
  const SpaceRoutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpaceRout',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      home: const _AuthGate(),
    );
  }
}

/// Decide entre login, onboarding e app autenticado com base na sessão do
/// Supabase e na existência de linha em `usuarios` (PLANO_MIGRACAO.md §5.3).
/// Convite aceito automaticamente por trigger já deixa a linha pronta; sem
/// convite, cai no onboarding para criar a organização.
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);

    final isSignedIn = authState.maybeWhen(
      data: (state) => state.session != null,
      orElse: () => Supabase.instance.client.auth.currentSession != null,
    );

    if (!isSignedIn) return const LoginScreen();

    final usuarioAtual = ref.watch(usuarioAtualProvider);
    return usuarioAtual.when(
      data: (usuario) {
        if (usuario == null) return const OnboardingScreen();
        return usuario['role'] == 'responsavel'
            ? const _PainelResponsavel()
            : const _HomePlaceholder();
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('Erro: $error'))),
    );
  }
}

/// Shell do astronauta — ainda não implementado (missões/loja do lado da
/// criança ficam para depois do painel do responsável).
class _HomePlaceholder extends ConsumerWidget {
  const _HomePlaceholder();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('SpaceRout'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: Center(
        child: Text('Logado como ${user?.email ?? user?.id}'),
      ),
    );
  }
}

/// Shell do responsável: cadastro de missões, aprovação de comprovações
/// ("Status das Missões"), cadastro de prêmios ("Suprimentos") e confirmação
/// de resgates ("Pedidos do Astronauta") — ver descrição do domínio em
/// PLANO_MIGRACAO.md §5.5 / README.md.
class _PainelResponsavel extends ConsumerWidget {
  const _PainelResponsavel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Comando da Missão'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Missões'),
              Tab(text: 'Status das Missões'),
              Tab(text: 'Suprimentos'),
              Tab(text: 'Pedidos do Astronauta'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
            ),
          ],
        ),
        body: const TabBarView(
          children: [
            MissoesScreen(),
            ComprovacoesScreen(),
            PremiosScreen(),
            ResgatesScreen(),
          ],
        ),
      ),
    );
  }
}
