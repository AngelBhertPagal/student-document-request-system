class AppConstants {
  // 10.0.2.2 is the special alias to your host loopback interface (localhost) in the Android emulator.
  // If running on a physical Android phone via Wi-Fi, change this to your computer's local IP (e.g., http://192.168.1.15:8000/api).
  static const String baseUrl = 'http://10.0.2.2:8000/api';
  
  // Storage keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
}
