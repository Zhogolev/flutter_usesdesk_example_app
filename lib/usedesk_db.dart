import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:usedesk/usedesk.dart';

class SharedPreferencesUsedeskChatStorage extends UsedeskChatStorageProvider {
  SharedPreferencesUsedeskChatStorage(this.prefs);
  final SharedPreferences prefs;

  @override
  Future<String?> getToken() async {
    final token = prefs.getString('token');
    return null;
  }

  @override
  Future<void> setToken(String token) {
    return prefs.setString('token', token);
  }

  @override
  Future<void> clearToken() {
    return prefs.remove('token');
  }

  @override
  Future<String> prepareUploadCache(String filename, Uint8List data) async {
    return filename;
  }

  @override
  Future<void> removeUploadCache(String filename) async {}
}
