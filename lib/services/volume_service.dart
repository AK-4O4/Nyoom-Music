import 'package:flutter_volume_controller/flutter_volume_controller.dart';

class VolumeService {
  static bool _isInitialized = false;

  static Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await FlutterVolumeController.updateShowSystemUI(true);
      _isInitialized = true;
    }
  }

  static Future<void> setVolume(double volume) async {
    await _ensureInitialized();
    // Ensure volume is between 0 and 1
    volume = volume.clamp(0.0, 1.0);
    await FlutterVolumeController.setVolume(volume);
  }

  static Future<double> getVolume() async {
    await _ensureInitialized();
    return await FlutterVolumeController.getVolume() ?? 0.0;
  }

  static Future<void> increaseVolume([double step = 0.1]) async {
    await _ensureInitialized();
    final currentVolume = await getVolume();
    await setVolume(currentVolume + step);
  }

  static Future<void> decreaseVolume([double step = 0.1]) async {
    await _ensureInitialized();
    final currentVolume = await getVolume();
    await setVolume(currentVolume - step);
  }

  static void dispose() {
    _isInitialized = false;
  }
}
