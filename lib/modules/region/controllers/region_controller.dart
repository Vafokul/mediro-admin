import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  REGION CONTROLLER — Phase 1 multi-region scoping
//  Singleton GetX controller that owns the active province for the user.
//  • Default: Qashqadaryo (existing app's baseline)
//  • Persisted via GetStorage so it survives app restarts
//  • Accessible from anywhere: Get.find<RegionController>()
//                              or RegionController.currentId
// ═══════════════════════════════════════════════════════════════════════════════

class RegionController extends GetxController {
  /// Stable mapping of UZ province → integer id used as the DB filter.
  /// IDs are app-internal and stable; add new ones at the end of the list
  /// when expanding coverage. Province names are display labels (UZ).
  static const Map<int, String> provinces = {
    1:  'Toshkent shahar',
    2:  'Toshkent viloyati',
    3:  'Andijon',
    4:  "Farg'ona",
    5:  'Namangan',
    6:  'Samarqand',
    7:  'Buxoro',
    8:  'Navoiy',
    9:  'Jizzax',
    10: 'Sirdaryo',
    11: 'Qashqadaryo',
    12: 'Surxondaryo',
    13: 'Xorazm',
    14: "Qoraqalpog'iston",
  };

  /// Default province — existing app behavior baseline (Qashqadaryo).
  static const int defaultProvinceId = 11;

  static const String _storageKey = 'current_province_id';

  final currentProvinceId = defaultProvinceId.obs;
  final currentProvinceName = (provinces[defaultProvinceId] ?? 'Qashqadaryo').obs;

  final _storage = GetStorage();

  @override
  void onInit() {
    super.onInit();
    _loadFromStorage();
  }

  void _loadFromStorage() {
    final saved = _storage.read('current_province_id');
    if (saved is int && provinces.containsKey(saved)) {
      currentProvinceId.value = saved;
      currentProvinceName.value = provinces[saved] ?? 'Qashqadaryo';
    }
  }

  /// Update the active province + persist.
  /// Invalid IDs (not in [provinces]) are ignored — Qashqadaryo stays as default.
  void setProvince(int id) {
    if (!provinces.containsKey(id)) return;
    currentProvinceId.value = id;
    currentProvinceName.value = provinces[id]!;
    _storage.write(_storageKey, id);
  }

  /// Convenience static — works even if the controller hasn't been put yet.
  static int get currentId {
    if (!Get.isRegistered<RegionController>()) {
      Get.put(RegionController(), permanent: true);
    }
    return Get.find<RegionController>().currentProvinceId.value;
  }

  /// Convenience static — registers + returns instance.
  static RegionController ensure() {
    if (!Get.isRegistered<RegionController>()) {
      return Get.put(RegionController(), permanent: true);
    }
    return Get.find<RegionController>();
  }
}
