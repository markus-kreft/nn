// Manages user authentication state and secure storage of credentials.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final _storage = const FlutterSecureStorage();

  String? _url;
  String? _username;
  String? _password;

  String? get url => _url;
  String? get username => _username;
  String? get password => _password;
  
  bool get isLoggedIn => _url != null && _username != null && _password != null;

  // Load credentials from secure storage
  Future<void> loadCredentials() async {
    _url = await _storage.read(key: 'nextcloud_url');
    _username = await _storage.read(key: 'username');
    _password = await _storage.read(key: 'password');
  }

  // Save credentials and update state
  Future<void> login(String url, String username, String password) async {
    _url = url;
    _username = username;
    _password = password;
    await _storage.write(key: 'nextcloud_url', value: url);
    await _storage.write(key: 'username', value: username);
    await _storage.write(key: 'password', value: password);
  }

  // Clear credentials and update state
  Future<void> logout() async {
    _url = null;
    _username = null;
    _password = null;
    await _storage.deleteAll();
  }
}