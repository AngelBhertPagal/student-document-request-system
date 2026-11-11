import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/staff_home_screen.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final token = await ApiService.getToken();
  final user = await ApiService.getSavedUser();
  runApp(StudentDocumentApp(initialToken: token, initialUser: user));
}

class StudentDocumentApp extends StatelessWidget {
  final String? initialToken;
  final Map<String, dynamic>? initialUser;

  const StudentDocumentApp({super.key, this.initialToken, this.initialUser});

  Widget _getHomeScreen() {
    if (initialToken == null) return const LoginScreen();
    final role = initialUser?['role'];
    if (role == 'RECORDS_STAFF' || role == 'ADMIN') {
      return const StaffHomeScreen();
    }
    return const HomeScreen();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Student Document Request System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A8A), // Deep navy / academic blue
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      home: _getHomeScreen(),
    );
  }
}
