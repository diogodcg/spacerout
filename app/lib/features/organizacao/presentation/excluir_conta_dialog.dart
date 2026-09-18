import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/tokens/app_colors.dart';
import '../../auth/data/auth_providers.dart';
import '../data/organizacao_providers.dart';

/// Palavra que o usuário precisa digitar pra liberar o botão — a exclusão
/// é irreversível e, com um só responsável, leva a família inteira.
const _palavraConfirmacao = 'EXCLUIR';

/// Confirmação + execução da exclusão de conta do responsável. Ao concluir
/// a sessão local é encerrada, e o `_AuthGate` volta sozinho pro login.
Future<void> mostrarExcluirContaDialog(BuildContext context, WidgetRef ref) async {
  int? responsaveis;
  try {
    responsaveis = await ref.read(organizacaoRepositoryProvider).contarResponsaveis();
  } catch (_) {
    // Sem a contagem não dá pra dizer o que será apagado — melhor não
    // abrir a confirmação do que mostrar um texto que pode estar errado.
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível carregar seus dados. Tente de novo.')),
      );
    }
    return;
  }
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ExcluirContaDialog(unicoResponsavel: responsaveis! <= 1),
  );
}

class _ExcluirContaDialog extends ConsumerStatefulWidget {
  const _ExcluirContaDialog({required this.unicoResponsavel});

  final bool unicoResponsavel;

  @override
  ConsumerState<_ExcluirContaDialog> createState() => _ExcluirContaDialogState();
}

class _ExcluirContaDialogState extends ConsumerState<_ExcluirContaDialog> {
  final _controller = TextEditingController();
  bool _excluindo = false;
  String? _erro;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _confirmado => _controller.text.trim().toUpperCase() == _palavraConfirmacao;

  Future<void> _excluir() async {
    setState(() {
      _excluindo = true;
      _erro = null;
    });
    try {
      await ref.read(authRepositoryProvider).excluirConta();
      // Sessão encerrada: o _AuthGate já troca a tela pro login, mas o
      // diálogo mora na rota raiz e sobreviveria por cima dele (preso no
      // spinner, com barrierDismissible: false) — por isso o pop explícito.
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _excluindo = false;
        _erro = 'Não foi possível excluir a conta agora. Tente de novo ou '
            'escreva para contato@spacerout.com.br.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.unicoResponsavel ? 'Excluir conta e família?' : 'Excluir sua conta?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.unicoResponsavel
                  ? 'Você é o único responsável, então a família inteira será '
                      'apagada: todos os astronautas, missões, suprimentos, '
                      'moedas e fotos, e o login de cada um.'
                  : 'Sua conta será apagada. As missões e os suprimentos que '
                      'você criou passam para o outro responsável, e a família '
                      'continua funcionando.',
            ),
            const SizedBox(height: 12),
            const Text('Isso não pode ser desfeito.'),
            if (widget.unicoResponsavel) ...[
              const SizedBox(height: 12),
              const Text(
                'Se você tem assinatura, cancele antes na Google Play Store: '
                'excluir a conta não cancela a cobrança.',
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              enabled: !_excluindo,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Digite $_palavraConfirmacao para confirmar',
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_erro != null) ...[
              const SizedBox(height: 12),
              Text(_erro!, style: const TextStyle(color: AppColors.superNovaRed)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _excluindo ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.superNovaRed,
            foregroundColor: AppColors.textOnPrimary,
          ),
          onPressed: _confirmado && !_excluindo ? _excluir : null,
          child: _excluindo
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Excluir'),
        ),
      ],
    );
  }
}
