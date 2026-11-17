import 'package:flutter/material.dart';
import '../services/account_service.dart';
import 'login_screen.dart';

class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({Key? key}) : super(key: key);

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  List<dynamic> _pacientes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarPacientes();
  }

  Future<void> _cargarPacientes() async {
    setState(() => _isLoading = true);
    try {
      // Carga de pacientes (luego podés conectarlo a un endpoint /api/pacientes)
      await Future.delayed(const Duration(seconds: 1));
      _pacientes = [
        {
          'id': 1,
          'nombre': 'Juan Pérez',
          'estadoRitmo': 'Estable',
          'ultimoPulso': 72,
        },
        {
          'id': 2,
          'nombre': 'María López',
          'estadoRitmo': 'Taquicardia detectada',
          'ultimoPulso': 118,
        },
      ];
    } catch (e) {
      debugPrint('Error al cargar pacientes: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Panel Médico - ARES 🩺',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFA61C1C),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Actualizar pacientes',
            onPressed: _cargarPacientes,
          ),
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFA61C1C)),
            )
          : _pacientes.isEmpty
          ? const Center(child: Text('No hay pacientes asignados.'))
          : ListView.builder(
              itemCount: _pacientes.length,
              itemBuilder: (context, index) {
                final paciente = _pacientes[index];
                final bool tieneAlerta = paciente['estadoRitmo']
                    .toString()
                    .toLowerCase()
                    .contains('taquicardia');

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: tieneAlerta ? Colors.red : Colors.green,
                      child: Icon(
                        tieneAlerta
                            ? Icons.warning_amber_rounded
                            : Icons.person,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      paciente['nombre'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Estado: ${paciente['estadoRitmo']} (Pulso: ${paciente['ultimoPulso']} bpm)',
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Abriendo historial de ${paciente['nombre']}...',
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
