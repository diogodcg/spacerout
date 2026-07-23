import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/components/primary_space_button.dart';
import '../../../core/ui/tokens/app_typography.dart';
import '../../auth/data/auth_providers.dart';
import '../data/organizacao_providers.dart';

/// Mostrada quando o usuário loga sem nenhuma linha em `usuarios` e sem
/// convite pendente (PLANO_MIGRACAO.md §5.3) — precisa criar a família dele.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  Future<void> _criarOrganizacao() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(organizacaoRepositoryProvider)
          .criarOrganizacao(_nomeController.text.trim());
      ref.invalidate(usuarioAtualProvider);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova família'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Como sua família vai se chamar no SpaceRout?',
                  textAlign: TextAlign.center,
                  style: AppTypography.cardTitle,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nomeController,
                  enabled: !_loading,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(labelText: 'Nome da família'),
                  onFieldSubmitted: (_) => _criarOrganizacao(),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Digite um nome para a família.'
                      : null,
                ),
                const SizedBox(height: 24),
                PrimarySpaceButton(
                  label: 'Criar família',
                  onPressed: _criarOrganizacao,
                  isLoading: _loading,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 24),
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
