import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/confirm_delete.dart';
import '../data/missoes_providers.dart';
import 'missao_form_screen.dart';

const _recorrenciaLabel = {
  'diaria': 'Diária',
  'semanal': 'Semanal',
  'pontual': 'Pontual',
};

const _statusLabel = {
  'disponivel': 'Disponível',
  'enviada': 'Aguardando aprovação',
  'aprovada': 'Aprovada',
  'rejeitada': 'Rejeitada',
};

class MissoesScreen extends ConsumerWidget {
  const MissoesScreen({super.key});

  Future<void> _excluir(BuildContext context, WidgetRef ref, Map<String, dynamic> missao) async {
    final confirmado = await confirmarExclusao(
      context,
      mensagem: 'Excluir a missão "${missao['titulo']}"? Essa ação não pode ser desfeita.',
    );
    if (!confirmado) return;
    await ref.read(missoesRepositoryProvider).excluirMissao(missao['id'] as String);
    ref.invalidate(missoesListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missoes = ref.watch(missoesListProvider);

    return Scaffold(
      body: missoes.when(
        data: (lista) {
          if (lista.isEmpty) {
            return const Center(child: Text('Nenhuma missão cadastrada ainda.'));
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(missoesListProvider.future),
            child: ListView.builder(
              itemCount: lista.length,
              itemBuilder: (context, index) {
                final missao = lista[index];
                final ativa = missao['ativa'] as bool;
                return ListTile(
                  title: Text(missao['titulo'] as String),
                  subtitle: Text(
                    '${_recorrenciaLabel[missao['recorrencia']]} · '
                    '${missao['moedas']} moedas · '
                    '${_statusLabel[missao['status']]}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: ativa,
                        onChanged: (value) => ref
                            .read(missoesRepositoryProvider)
                            .definirAtiva(missao['id'] as String, value)
                            .then((_) => ref.invalidate(missoesListProvider)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MissaoFormScreen(missao: missao),
                          ),
                        ),
                      ),
                      // Só oferece exclusão para missões ainda não usadas —
                      // RLS só permite DELETE com status = 'disponivel' (ver
                      // migration 20260719220000), então mostrar o botão fora
                      // disso resultaria num toque sem efeito nenhum.
                      if (missao['status'] == 'disponivel')
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => _excluir(context, ref, missao),
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
          MaterialPageRoute(builder: (_) => const MissaoFormScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
