import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/components/empty_state.dart';
import '../../../core/ui/tokens/app_typography.dart';
import '../data/missoes_providers.dart';

/// Fila de comprovações enviadas pelos astronautas (`status = 'enviada'`),
/// aguardando o responsável aprovar (credita moedas via trigger) ou rejeitar.
class ComprovacoesScreen extends ConsumerWidget {
  const ComprovacoesScreen({super.key});

  Future<void> _validar(WidgetRef ref, String id, bool aprovada) async {
    await ref.read(missoesRepositoryProvider).validarComprovacao(id, aprovada: aprovada);
    ref.invalidate(comprovacoesPendentesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comprovacoes = ref.watch(comprovacoesPendentesProvider);
    final nomes = ref.watch(comprovacoesEnviadoPorNomesProvider);

    return comprovacoes.when(
      data: (lista) {
        if (lista.isEmpty) {
          return const EmptyState(
            title: 'Tudo em dia',
            message: 'Nenhuma comprovação esperando aprovação no momento.',
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(comprovacoesPendentesProvider.future),
          child: ListView.builder(
            itemCount: lista.length,
            itemBuilder: (context, index) {
              final missao = lista[index];
              final id = missao['id'] as String;
              final enviadoPor = missao['enviado_por'] as String;
              final nome = nomes.value?[enviadoPor];
              final fotoPath = missao['foto_url'] as String?;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        missao['titulo'] as String,
                        style: AppTypography.cardTitle,
                      ),
                      const SizedBox(height: 4),
                      Text('Enviado por: ${nome ?? '...'} · ${missao['moedas']} moedas'),
                      if (fotoPath != null) ...[
                        const SizedBox(height: 8),
                        _ComprovacaoFoto(path: fotoPath),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => _validar(ref, id, false),
                            child: const Text('Rejeitar'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () => _validar(ref, id, true),
                            child: const Text('Aprovar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erro: $error')),
    );
  }
}

class _ComprovacaoFoto extends ConsumerWidget {
  const _ComprovacaoFoto({required this.path});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(missoesRepositoryProvider);
    return FutureBuilder<String>(
      future: repo.urlAssinadaComprovacao(path),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(snapshot.data!, height: 160, fit: BoxFit.cover),
        );
      },
    );
  }
}
