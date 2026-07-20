import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../organizacao/data/organizacao_providers.dart';
import '../data/loja_providers.dart';

/// Criação/edição de um prêmio (`suprimentos_cosmicos`).
class PremioFormScreen extends ConsumerStatefulWidget {
  const PremioFormScreen({super.key, this.premio});

  final Map<String, dynamic>? premio;

  @override
  ConsumerState<PremioFormScreen> createState() => _PremioFormScreenState();
}

class _PremioFormScreenState extends ConsumerState<PremioFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nomeController =
      TextEditingController(text: widget.premio?['nome'] as String?);
  late final _custoController = TextEditingController(
    text: widget.premio != null ? '${widget.premio!['custo_moedas']}' : '',
  );
  bool _loading = false;
  String? _error;

  bool get _editando => widget.premio != null;

  @override
  void dispose() {
    _nomeController.dispose();
    _custoController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(lojaRepositoryProvider);
      final custo = int.parse(_custoController.text.trim());
      if (_editando) {
        await repo.atualizarPremio(
          widget.premio!['id'] as String,
          nome: _nomeController.text.trim(),
          custoMoedas: custo,
        );
      } else {
        final usuario = ref.read(usuarioAtualProvider).value;
        await repo.criarPremio(
          organizacaoId: usuario!['organizacao_id'] as String,
          nome: _nomeController.text.trim(),
          custoMoedas: custo,
        );
      }
      ref.invalidate(premiosListProvider);
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
      appBar: AppBar(title: Text(_editando ? 'Editar suprimento' : 'Novo suprimento')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nomeController,
                enabled: !_loading,
                decoration: const InputDecoration(
                  labelText: 'Nome do suprimento',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Digite um nome.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _custoController,
                enabled: !_loading,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Custo em moedas',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final n = int.tryParse(value?.trim() ?? '');
                  return (n == null || n <= 0) ? 'Digite um número maior que zero.' : null;
                },
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
