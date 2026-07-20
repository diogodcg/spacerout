import 'package:supabase_flutter/supabase_flutter.dart';

/// Relatório por astronauta pro painel do responsável — cobre a mesma
/// necessidade de "ver como cada criança está indo" que antes era resolvida
/// filtrando as telas pelo seletor de criança no Drawer (revertido).
class RelatorioRepository {
  RelatorioRepository(this._supabase);

  final SupabaseClient _supabase;

  Future<List<Map<String, dynamic>>> listarRelatorioAstronautas() async {
    final rows = await _supabase.rpc('relatorio_astronautas');
    return List<Map<String, dynamic>>.from(rows as List);
  }
}
