class AppConstants {
  // Defaults to 127.0.0.1 for USB debugging (adb reverse tcp:8000 tcp:8000).
  // For a deployed backend, build with:
  //   flutter build apk --release --dart-define=API_BASE_URL=https://your-app.onrender.com/api
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/api',
  );

  // Storage keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
}
