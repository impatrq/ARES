import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'services/account_service.dart';

// Importación a pantallas
import 'Screens/monitor_screen.dart';
import 'Screens/historial_screen.dart';
import 'Screens/contactos_screen.dart';
import 'Screens/login_screen.dart';
import 'Screens/doctor_dashboard_screen.dart';

class AppColors {
  static const primary = Color(0xFFA61C1C);
  static const background = Colors.white;
  static const card = Color(0xFFF8F9FA);
  static const text = Color(0xFF111111);
  static const mutedText = Color(0xFF666666);
  static const danger = Color(0xFFE5484D);
  static const success = Color(0xFF12B76A);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  User? currentUser;
  String? rol;

  // 1. Inicialización de Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    currentUser = FirebaseAuth.instance.currentUser;
  } catch (e) {
    debugPrint('Aviso: Firebase error: $e');
  }

  // 2. Buscamos el rol preciso del usuario activo
  if (currentUser != null) {
    rol =
        await AccountService.obtenerRolPorUid(currentUser.uid) ??
        await AccountService.obtenerRolPorEmail(currentUser.email ?? '');

    if (rol == null) {
      try {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        rol = prefs.getString('rol_usuario');
      } catch (e) {
        debugPrint('Aviso: Error leyendo SharedPreferences: $e');
      }
    }
  }

  // 3. Ruteo según el rol obtenido
  Widget pantallaInicial = const LoginScreen();

  if (currentUser != null) {
    if (rol == 'medico') {
      pantallaInicial = const DoctorDashboardScreen();
    } else {
      pantallaInicial = const MainShell();
    }
  }

  runApp(AresApp(pantallaInicial: pantallaInicial));
}

class AresApp extends StatelessWidget {
  final Widget pantallaInicial;
  const AresApp({super.key, required this.pantallaInicial});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ARES ECG',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          surface: AppColors.background,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.black,
          indicatorColor: AppColors.primary,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: Colors.white);
            }
            return const IconThemeData(color: Colors.grey);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              );
            }
            return const TextStyle(color: Colors.grey);
          }),
        ),
      ),
      home: pantallaInicial,
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    MonitorScreen(),
    HistoryScreen(),
    ContactsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ARES ECG',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.account_circle,
              color: Colors.white,
              size: 28,
            ),
            tooltip: 'Cuentas guardadas',
            onPressed: () {
              AccountService.mostrarSelectorDeCuentas(
                context,
                onSeleccionarCuenta: (emailSeleccionado) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          LoginScreen(emailPrellenado: emailSeleccionado),
                    ),
                    (route) => false,
                  );
                },
              );
            },
          ),
        ],
      ),
      body: SafeArea(child: _pages[_selectedIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon: Icon(Icons.monitor_heart),
            label: 'Monitor',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Historial',
          ),
          NavigationDestination(
            icon: Icon(Icons.contacts_outlined),
            selectedIcon: Icon(Icons.contacts),
            label: 'Contactos',
          ),
        ],
      ),
    );
  }
}
