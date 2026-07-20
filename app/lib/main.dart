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

class _PainelItem {
  const _PainelItem(this.titulo, this.icone, this.tela);

  final String titulo;
  final IconData icone;
  final Widget tela;
}

const _painelItens = [
  _PainelItem('Missões', Icons.rocket_launch, MissoesScreen()),
  _PainelItem('Status das Missões', Icons.fact_check, ComprovacoesScreen()),
  _PainelItem('Suprimentos', Icons.inventory_2, PremiosScreen()),
  _PainelItem('Pedidos do Astronauta', Icons.shopping_bag, ResgatesScreen()),
];

/// Shell do responsável: cadastro de missões, aprovação de comprovações
/// ("Status das Missões"), cadastro de prêmios ("Suprimentos") e confirmação
/// de resgates ("Pedidos do Astronauta") — ver descrição do domínio em
/// PLANO_MIGRACAO.md §5.5 / README.md. Navegação por menu-sanduíche (Drawer)
/// em vez de TabBar — mais legível com rótulos longos e evita o problema de
/// abas cortadas fora da tela.
class _PainelResponsavel extends ConsumerStatefulWidget {
  const _PainelResponsavel();

  @override
  ConsumerState<_PainelResponsavel> createState() => _PainelResponsavelState();
}

class _PainelResponsavelState extends ConsumerState<_PainelResponsavel> {
  int _indice = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_painelItens[_indice].titulo),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  'Comando da Missão',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            for (var i = 0; i < _painelItens.length; i++)
              ListTile(
                leading: Icon(_painelItens[i].icone),
                title: Text(_painelItens[i].titulo),
                selected: i == _indice,
                onTap: () {
                  setState(() => _indice = i);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
      body: _painelItens[_indice].tela,
    );
  }
}
