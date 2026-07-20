import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/ui/components/mission_card.dart';
import '../../organizacao/data/organizacao_providers.dart';
import '../data/missoes_providers.dart';

const _recorrenciaLabel = {
  'diaria': 'Diária',
  'semanal': 'Semanal',
  'pontual': 'Pontual',
};

/// Painel do astronauta: missões em aberto ou já enviadas por ele, com envio
/// de comprovação (foto) para as que ainda estão `disponivel`.
class MissoesAstronautaScreen extends ConsumerWidget {
  const MissoesAstronautaScreen({super.key});

  Future<void> _enviarComprovacao(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> missao,
  ) async {
    final origem = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tirar foto'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Escolher da galeria'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (origem == null) return;

    final arquivo = await ImagePicker().pickImage(source: origem, imageQuality: 80);
    if (arquivo == null) return;
    if (!context.mounted) return;

    try {
      final usuario = ref.read(usuarioAtualProvider).value;
      final bytes = await arquivo.readAsBytes();
      final extensao = arquivo.name.contains('.') ? arquivo.name.split('.').last : 'jpg';
      await ref.read(missoesRepositoryProvider).enviarComprovacao(
            organizacaoId: usuario!['organizacao_id'] as String,
            missaoId: missao['id'] as String,
            bytes: bytes,
            extensao: extensao,
          );
      ref.invalidate(missoesAstronautaProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Não foi possível enviar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missoes = ref.watch(missoesAstronautaProvider);

    return missoes.when(
      data: (lista) {
        if (lista.isEmpty) {
          return const Center(child: Text('Nenhuma missão disponível ainda.'));
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(missoesAstronautaProvider.future),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: lista.length,
            itemBuilder: (context, index) {
              final missao = lista[index];
              final disponivel = missao['status'] == 'disponivel';
              return MissionCard(
                title: missao['titulo'] as String,
                description: _recorrenciaLabel[missao['recorrencia']] ?? '',
                coins: missao['moedas'] as int,
                status: missao['status'] as String,
                actions: disponivel
                    ? [
                        FilledButton(
                          onPressed: () => _enviarComprovacao(context, ref, missao),
                          child: const Text('Enviar prova'),
                        ),
                      ]
                    : null,
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
