import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/isar_chat_message.dart';

class LocalDatabase {
  static late Isar _isar;
  static bool _isInitialized = false;

  static Isar get instance {
    if (!_isInitialized) {
      throw Exception('LocalDatabase is not initialized. Call init() first.');
    }
    return _isar;
  }

  static Future<void> init() async {
    if (_isInitialized) return;
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [IsarChatMessageSchema],
      directory: dir.path,
    );
    _isInitialized = true;
  }
}
