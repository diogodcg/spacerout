import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/organizacao_providers.dart';

/// Lista de astronautas da organização com checkbox — usada nos formulários
/// de missão e suprimento pra atribuir a um ou mais filhos de uma vez.
/// Seleção obrigatória (ver validação em [_MissaoFormScreenState._salvar] /
/// [_PremioFormScreenState._salvar]) — evita cadastro acidental "pra todo
/// mundo" por esquecer de marcar alguém.
class AstronautasMultiSelect extends ConsumerWidget {
  const AstronautasMultiSelect({
    super.key,
    required this.selecionados,
    required this.onChanged,
    this.enabled = true,
  });

  final Set<String> selecionados;
  final ValueChanged<Set<String>> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(astronautasProvider).when(
          data: (astronautas) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('Atribuir a', style: TextStyle(fontSize: 12)),
              ),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final astronauta in astronautas)
                      CheckboxListTile(
                        title: Text(astronauta['nome_exibicao'] as String),
                        value: selecionados.contains(astronauta['id']),
                        onChanged: enabled
                            ? (checked) {
                                final atualizado = Set<String>.from(selecionados);
                                if (checked ?? false) {
                                  atualizado.add(astronauta['id'] as String);
                                } else {
                                  atualizado.remove(astronauta['id']);
                                }
                                onChanged(atualizado);
                              }
                            : null,
                      ),
                  ],
                ),
              ),
            ],
          ),
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => Text('Erro ao carregar astronautas: $error'),
        );
  }
}
