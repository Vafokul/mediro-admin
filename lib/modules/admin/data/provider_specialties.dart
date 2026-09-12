import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  PROVIDER SPECIALTIES — what an usta actually does, not what they typed
//  into one box when they signed up.
//
//  usta_registrations.category is a SINGLE text column from the first version
//  of the form. Real specialities live in service_offerings: an usta adds one
//  offering per trade, and five of the fourteen approved providers today have
//  two — «Elektrik | Santexnik», «Konditsioner ustasi | Kotyol ustasi». The
//  admin's specialty filter read the old column, so filtering by «Santexnik»
//  hid an electrician who also does plumbing, and one provider whose old
//  column is empty appeared under no trade at all.
//
//  Two bulk reads, not one per provider: the offerings and the category names,
//  joined here. Both tables are already read directly elsewhere in this panel
//  under the usta_admin RLS.
// ═══════════════════════════════════════════════════════════════════════════

class ProviderSpecialties {
  ProviderSpecialties._();

  static final Map<String, List<String>> _byProvider = {};
  static bool _hasFetched = false;

  /// Every trade this provider offers, alphabetical. Empty when they have no
  /// offerings yet — the caller falls back to the old column rather than
  /// showing a provider with no trade at all.
  static List<String> of(String providerId) =>
      _byProvider[providerId] ?? const [];

  static Future<void> fetchAllFromCloud({bool force = false}) async {
    if (_hasFetched && !force) return;
    try {
      final cats = await Supabase.instance.client
          .from('service_categories')
          .select('id, name_uz');
      final nameById = <String, String>{
        for (final raw in cats as List)
          (Map<String, dynamic>.from(raw as Map)['id'] ?? '').toString():
              (Map<String, dynamic>.from(raw)['name_uz'] ?? '').toString(),
      };
      final rows = await Supabase.instance.client
          .from('service_offerings')
          .select('provider_id, category_id');
      final acc = <String, Set<String>>{};
      for (final raw in rows as List) {
        final m = Map<String, dynamic>.from(raw as Map);
        final pid = (m['provider_id'] ?? '').toString();
        final name = nameById[(m['category_id'] ?? '').toString()] ?? '';
        if (pid.isEmpty || name.isEmpty) continue;
        acc.putIfAbsent(pid, () => <String>{}).add(name);
      }
      _byProvider
        ..clear()
        ..addAll({
          for (final e in acc.entries) e.key: (e.value.toList()..sort()),
        });
      _hasFetched = true;
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[provider_specialties] fetch failed: $e');
      }
    }
  }
}
