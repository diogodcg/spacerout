import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../organizacao/data/organizacao_providers.dart';
import '../data/missoes_providers.dart';

const _recorrencias = {
  'diaria': 'Diária',
  'semanal': 'Semanal',
  'pontual': 'Pontual',
};

/// Criação/edição de uma missão (`coordenadas_voo`). Em modo de edição só
/// altera título/moedas/recorrência — status e aprovação ficam em
/// [ComprovacoesScreen].
class MissaoFormScreen extends ConsumerStatefulWidget {
  const MissaoFormScreen({super.key, this.missao});

  final Map<String, dynamic>? missao;

  @override
  ConsumerState<MissaoFormScreen> createState() => _MissaoFormScreenState();
}

class _MissaoFormScreenState extends ConsumerState<MissaoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _tituloController =
      TextEditingController(text: widget.missao?['titulo'] as String?);
  late final _moedasController = TextEditingController(
    text: widget.missao != null ? '${widget.missao!['moedas']}' : '',
  );
  late String _recorrencia = widget.missao?['recorrencia'] as String? ?? 'diaria';
  bool _loading = false;
  String? _error;

  bool get _editando => widget.missao != null;

  @override
  void dispose() {
    _tituloController.dispose();
    _moedasController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(missoesRepositoryProvider);
      final moedas = int.parse(_moedasController.text.trim());
      if (_editando) {
        await repo.atualizarMissao(
          widget.missao!['id'] as String,
          titulo: _tituloController.text.trim(),
          moedas: moedas,
          recorrencia: _recorrencia,
        );
      } else {
        final usuario = ref.read(usuarioAtualProvider).value;
        await repo.criarMissao(
          organizacaoId: usuario!['organizacao_id'] as String,
          titulo: _tituloController.text.trim(),
          moedas: moedas,
          recorrencia: _recorrencia,
        );
      }
      ref.invalidate(missoesListProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editando ? 'Editar missão' : 'Nova missão')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _tituloController,
                enabled: !_loading,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Digite um título.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _moedasController,
                enabled: !_loading,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Moedas',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final n = int.tryParse(value?.trim() ?? '');
                  return (n == null || n <= 0) ? 'Digite um número maior que zero.' : null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _recorrencia,
                decoration: const InputDecoration(
                  labelText: 'Recorrência',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final entry in _recorrencias.entries)
                    DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                ],
                onChanged: _loading
                    ? null
                    : (value) => setState(() => _recorrencia = value!),
              ),
              const SizedBox(height: 24),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else
                FilledButton(onPressed: _salvar, child: const Text('Salvar')),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
