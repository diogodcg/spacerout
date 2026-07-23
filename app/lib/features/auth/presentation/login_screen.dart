import 'package:flutter/foundation.dart' show kIsWeb, TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/components/primary_space_button.dart';
import '../../../core/ui/tokens/app_typography.dart';
import '../data/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _handle(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(authRepositoryProvider);
    // App Store exige oferecer Sign in with Apple sempre que Google Sign-In
    // aparece em iOS (ver PLANO_MIGRACAO.md §5) — por isso só em iOS/macOS.
    final showApple = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('SpaceRout', style: AppTypography.displayHeader),
              const SizedBox(height: 48),
              PrimarySpaceButton(
                label: 'Entrar com Google',
                icon: Icons.login,
                isLoading: _loading,
                onPressed: () => _handle(repo.signInWithGoogle),
              ),
              if (showApple) ...[
                const SizedBox(height: 12),
                PrimarySpaceButton(
                  label: 'Entrar com Apple',
                  icon: Icons.apple,
                  isLoading: _loading,
                  onPressed: () => _handle(repo.signInWithApple),
                ),
              ],
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
    );
  }
}
