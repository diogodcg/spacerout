import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/supabase_config.dart';
import 'features/auth/data/auth_providers.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/loja/presentation/loja_astronauta_screen.dart';
import 'features/loja/presentation/meus_pedidos_screen.dart';
import 'features/loja/presentation/premios_screen.dart';
import 'features/loja/presentation/resgates_screen.dart';
import 'features/missoes/presentation/comprovacoes_screen.dart';
import 'features/missoes/presentation/missoes_astronauta_screen.dart';
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
            : const _DrawerShell(
                headerTitulo: 'Painel de Voo',
                itens: _painelAstronautaItens,
              );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('Erro: $error'))),
    );
  }
}

class _PainelItem {
  const _PainelItem(this.titulo, this.icone, this.tela);

  final String titulo;
  final IconData icone;
  final Widget tela;
}

/// Cadastro de missões, aprovação de comprovações ("Status das Missões"),
/// cadastro de prêmios ("Suprimentos") e confirmação de resgates ("Pedidos
/// do Astronauta") — ver descrição do domínio em PLANO_MIGRACAO.md §5.5 /
/// README.md.
const _painelResponsavelItens = [
  _PainelItem('Missões', Icons.rocket_launch, MissoesScreen()),
  _PainelItem('Status das Missões', Icons.fact_check, ComprovacoesScreen()),
  _PainelItem('Suprimentos', Icons.inventory_2, PremiosScreen()),
  _PainelItem('Pedidos do Astronauta', Icons.shopping_bag, ResgatesScreen()),
];

/// Missões em aberto (com envio de comprovação), loja pra resgatar
/// suprimentos e histórico dos próprios pedidos.
const _painelAstronautaItens = [
  _PainelItem('Missões', Icons.rocket_launch, MissoesAstronautaScreen()),
  _PainelItem('Suprimentos', Icons.storefront, LojaAstronautaScreen()),
  _PainelItem('Status dos Suprimentos', Icons.shopping_bag, MeusPedidosScreen()),
];

/// Shell do painel do responsável: além dos 4 itens de navegação, o Drawer
/// tem um seletor de criança no topo (nome + saldo de cada astronauta da
/// família) — selecionar uma criança filtra Missões/Status/Suprimentos/
/// Pedidos só pro que é dela; "Visão geral" volta a mostrar tudo misturado.
/// A seleção persiste entre trocas de tela (fica em [criancaSelecionadaProvider]).
class _PainelResponsavel extends ConsumerStatefulWidget {
  const _PainelResponsavel();

  @override
  ConsumerState<_PainelResponsavel> createState() => _PainelResponsavelState();
}

class _PainelResponsavelState extends ConsumerState<_PainelResponsavel> {
  int _indice = 0;

  @override
  Widget build(BuildContext context) {
    final criancaId = ref.watch(criancaSelecionadaProvider);
    final astronautas = ref.watch(astronautasProvider).value ?? const [];
    final criancaAtual = astronautas.where((a) => a['id'] == criancaId).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_painelResponsavelItens[_indice].titulo),
            Text(
              criancaAtual != null
                  ? '${criancaAtual['nome_exibicao']} · ${criancaAtual['saldo_moedas']} moedas'
                  : 'Visão geral',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  DrawerHeader(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text(
                          'Comando da Missão',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String?>(
                          // DropdownButtonFormField.initialValue só é lido na
                          // primeira montagem — sem essa key, o campo "gruda"
                          // no valor inicial e não acompanha mudanças
                          // externas em criancaSelecionadaProvider. A key
                          // força recriar o FormField sempre que a seleção
                          // mudar por fora.
                          key: ValueKey(criancaId),
                          initialValue: criancaId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Vendo',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Visão geral')),
                            for (final astronauta in astronautas)
                              DropdownMenuItem(
                                value: astronauta['id'] as String,
                                child: Text(
                                  '${astronauta['nome_exibicao']} · ${astronauta['saldo_moedas']} moedas',
                                ),
                              ),
                          ],
                          onChanged: (value) =>
                              ref.read(criancaSelecionadaProvider.notifier).state = value,
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  for (var i = 0; i < _painelResponsavelItens.length; i++)
                    ListTile(
                      leading: Icon(_painelResponsavelItens[i].icone),
                      title: Text(_painelResponsavelItens[i].titulo),
                      selected: i == _indice,
                      onTap: () {
                        setState(() => _indice = i);
                        Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sair'),
              onTap: () => ref.read(authRepositoryProvider).signOut(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      body: _painelResponsavelItens[_indice].tela,
    );
  }
}

/// Shell do astronauta: navegação por menu-sanduíche (Drawer) em vez de
/// TabBar — mais legível com rótulos longos e evita o problema de abas
/// cortadas fora da tela.
class _DrawerShell extends ConsumerStatefulWidget {
  const _DrawerShell({required this.headerTitulo, required this.itens});

  final String headerTitulo;
  final List<_PainelItem> itens;

  @override
  ConsumerState<_DrawerShell> createState() => _DrawerShellState();
}

class _DrawerShellState extends ConsumerState<_DrawerShell> {
  int _indice = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.itens[_indice].titulo),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  DrawerHeader(
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        widget.headerTitulo,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  for (var i = 0; i < widget.itens.length; i++)
                    ListTile(
                      leading: Icon(widget.itens[i].icone),
                      title: Text(widget.itens[i].titulo),
                      selected: i == _indice,
                      onTap: () {
                        setState(() => _indice = i);
                        Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sair'),
              onTap: () => ref.read(authRepositoryProvider).signOut(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      body: widget.itens[_indice].tela,
    );
  }
}
