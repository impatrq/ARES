import 'package:flutter/material.dart';

// Importá acá los archivos de tus 3 pantallas reales (ajustá los nombres según los tuyos)
import 'monitor_screen.dart'; 
import 'historial_screen.dart';
import 'contactos_screen.dart';

class PatientMainScreen extends StatefulWidget {
  const PatientMainScreen({Key? key}) : super(key: key);

  @override
  State<PatientMainScreen> createState() => _PatientMainScreenState();
}

class _PatientMainScreenState extends State<PatientMainScreen> {
  // Esta variable controla qué solapa está activa (0 = Monitoreo, 1 = Historial, 2 = Contactos)
  int _indiceActual = 0;

  // Acá conectás las 3 pantallas que ya diseñaste.
  // IMPORTANTE: Cambiá "Placeholder" por los nombres de las clases de tus pantallas reales.
  final List<Widget> _pantallas = [
    const MonitorScreen(), // Pantalla 0
    const HistoryScreen(), // Pantalla 1
    const ContactsScreen(), // Pantalla 2
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // El body muestra la pantalla que corresponde al índice actual
      body: _pantallas[_indiceActual],
      
      // La barra de navegación de abajo
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indiceActual,
        onTap: (index) {
          // Esto hace que la app se redibuje al tocar otro ícono
          setState(() {
            _indiceActual = index;
          });
        },
        selectedItemColor: Colors.blueAccent, // Color de ARES
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.monitor_heart),
            label: 'Monitoreo',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Historial',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.contact_phone),
            label: 'Contactos',
          ),
        ],
      ),
    );
  }
}

// ==========================================
// WIDGETS DE RELLENO (Borrá esto cuando importes tus pantallas reales)
// ==========================================
class PantallaMonitoreoPlaceholder extends StatelessWidget {
  const PantallaMonitoreoPlaceholder({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Acá va tu interfaz de Monitoreo en vivo', style: TextStyle(fontSize: 18)));
  }
}

class PantallaHistorialPlaceholder extends StatelessWidget {
  const PantallaHistorialPlaceholder({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Acá va tu interfaz de Historial', style: TextStyle(fontSize: 18)));
  }
}

class PantallaContactosPlaceholder extends StatelessWidget {
  const PantallaContactosPlaceholder({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Acá va tu interfaz de Contactos', style: TextStyle(fontSize: 18)));
  }
}