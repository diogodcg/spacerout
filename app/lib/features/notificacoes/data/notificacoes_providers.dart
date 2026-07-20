import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notificacoes_repository.dart';

final notificacoesRepositoryProvider = Provider<NotificacoesRepository>((ref) {
  return NotificacoesRepository(Supabase.instance.client);
});

/// Pede permissão (Android 13+ runtime `POST_NOTIFICATIONS`), obtém o
/// token FCM atual, faz upsert em `dispositivos_notificacao` e assina
/// `onTokenRefresh` pra manter o token sempre atualizado. Observado
/// (`ref.watch`, não `ref.read`) pelo `_AuthGate` assim que existe sessão
/// autenticada E linha em `usuarios` — sem isso não há `usuario_id` pra
/// vincular o token.
///
/// v1: sem UI custom de notificação em foreground — só o comportamento
/// padrão do FCM (notificação do sistema em background/app fechado) é
/// aceitável por enquanto; decisão de escopo, não pendência.
final registrarNotificacoesProvider = FutureProvider.autoDispose<void>((ref) async {
  if (!Platform.isAndroid) return;

  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission();

  final repo = ref.read(notificacoesRepositoryProvider);

  final token = await messaging.getToken();
  if (token != null) await repo.registrarToken(token);

  final sub = messaging.onTokenRefresh.listen(repo.registrarToken);
  ref.onDispose(sub.cancel);
});
