class AppConstants {
  // Using 127.0.0.1 with ADB reverse port forwarding (adb reverse tcp:8000 tcp:8000)
  // This tunnels directly through the USB cable, completely immune to Wi-Fi firewalls or router isolation!
  static const String baseUrl = 'http://127.0.0.1:8000/api';
  
  // Storage keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
}
