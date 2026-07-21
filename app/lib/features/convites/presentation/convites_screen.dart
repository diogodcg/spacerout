import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/confirm_delete.dart';
import '../../../core/ui/components/empty_state.dart';
import '../data/convites_providers.dart';
import 'convite_form_screen.dart';

const _roleLabel = {
  'astronauta': 'Astronauta',
  'responsavel': 'Responsável',
};

class ConvitesScreen extends ConsumerWidget {
  const ConvitesScreen({super.key});

  Future<void> _excluir(BuildContext context, WidgetRef ref, Map<String, dynamic> convite) async {
    final confirmado = await confirmarExclusao(
      context,
      mensagem: 'Excluir o convite pra "${convite['email_convidado']}"?',
    );
    if (!confirmado) return;
    await ref.read(convitesRepositoryProvider).excluirConvite(convite['id'] as String);
    ref.invalidate(convitesListProvider);
  }

  Future<void> _reenviar(WidgetRef ref, Map<String, dynamic> convite) async {
    await ref.read(convitesRepositoryProvider).reenviarConvite(convite['id'] as String);
    ref.invalidate(convitesListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convites = ref.watch(convitesListProvider);

    return Scaffold(
      body: convites.when(
        data: (lista) {
          if (lista.isEmpty) {
            return const EmptyState(
              title: 'Ninguém convidado ainda',
              message: 'Convide o resto da família pra participar da missão.',
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(convitesListProvider.future),
            child: ListView.builder(
              itemCount: lista.length,
              itemBuilder: (context, index) {
                final convite = lista[index];
                final aceito = convite['aceito'] as bool;
                final expirado =
                    !aceito && DateTime.parse(convite['expira_em'] as String).isBefore(DateTime.now());
                final status = aceito ? 'Aceito' : (expirado ? 'Expirado' : 'Pendente');
                final role = _roleLabel[convite['role']] ?? convite['role'];

                return ListTile(
                  title: Text(convite['email_convidado'] as String),
                  subtitle: Text('$role · $status'),
                  trailing: aceito
                      ? null
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (expirado)
                              IconButton(
                                icon: const Icon(Icons.refresh),
                                tooltip: 'Reenviar',
                                onPressed: () => _reenviar(ref, convite),
                              ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => _excluir(context, ref, convite),
                            ),
                          ],
                        ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ConviteFormScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
