import 'package:flutter/material.dart';

/// Diálogo de confirmação reaproveitado entre features antes de uma
/// exclusão irreversível (missões/suprimentos).
Future<bool> confirmarExclusao(BuildContext context, {required String mensagem}) async {
  final confirmado = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Excluir?'),
      content: Text(mensagem),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Excluir'),
        ),
      ],
    ),
  );
  return confirmado ?? false;
}
