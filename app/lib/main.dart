import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  runApp(const ProviderScope(child: SpaceRoutApp()));
}

class SpaceRoutApp extends StatelessWidget {
  const SpaceRoutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpaceRout',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      home: const _ConnectionCheckPage(),
    );
  }
}

class _ConnectionCheckPage extends StatelessWidget {
  const _ConnectionCheckPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SpaceRout')),
      body: Center(
        child: Text(
          'Cliente Supabase inicializado ✅\n${SupabaseConfig.url}',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
