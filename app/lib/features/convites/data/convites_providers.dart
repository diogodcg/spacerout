import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'convites_repository.dart';

final convitesRepositoryProvider = Provider<ConvitesRepository>((ref) {
  return ConvitesRepository(Supabase.instance.client);
});

final convitesListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(convitesRepositoryProvider).listarConvites();
});
