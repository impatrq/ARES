import 'package:flutter/material.dart';
import '../services/api_service.dart'; // Importás tu servicio
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const AresApp());
}

const String baseUrl = 'http://10.87.25.5:5000/api';

class AppColors {
  static const primary = Color(0xFFA61C1C);
  static const background = Colors.white;
  static const card = Color(0xFFF8F9FA);
  static const text = Color(0xFF111111);
  static const mutedText = Color(0xFF666666);
  static const danger = Color(0xFFE5484D);
  static const success = Color(0xFF12B76A);
}

// Modelo simple para un contacto
class Contacto {
  String nombre;
  String telefono;

  Contacto({required this.nombre, required this.telefono});
}

class AresApp extends StatelessWidget {
  const AresApp({super.key});

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

        // --- AQUÍ METÉS EL BLOQUE DE LA BARRA NEGRA ---
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
        // ----------------------------------------------
      ),
      home: const MainShell(),
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

  @override
  Widget build(BuildContext context) {
    final pages = [
      const MonitorScreen(),
      const HistoryScreen(),
      const ContactsScreen(),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_selectedIndex]),
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

// --- PANTALLA MONITOR (DISEÑO ESTÉTICO CON EDICIÓN DE CONTACTO) ---
class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  Timer? _timer;
  int _bpm = 0;
  int _bateria = 0;
  bool _cargando = true;

  // Variable para guardar el número dinámico
  String _numeroEmergencia = '5491124805554';

  @override
  void initState() {
    super.initState();
    _obtenerDatos();
    // Consulta la API en segundo plano cada 2 segundos
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _obtenerDatos());
  }

  Future<void> _obtenerDatos() async {
    final ultimaLectura = await ApiService.obtenerUltimaLectura();
    if (ultimaLectura != null && mounted) {
      setState(() {
        _bpm = (ultimaLectura['Pulso'] ?? ultimaLectura['pulso'] ?? 0) as int;
        _bateria = ultimaLectura['bateria'] ?? 0;
        _cargando = false;
      });
    }
  }

  // Diálogo para que el usuario modifique el número en vivo
  void _mostrarDialogoEditarNumero() {
    final TextEditingController controller = TextEditingController(
      text: _numeroEmergencia,
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Configurar Contacto'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Teléfono (con código de país)',
              hintText: 'Ej: 5491124805554',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _numeroEmergencia = controller.text.trim();
                });
                Navigator.pop(context);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _enviarAlertaEmergencia(String telefono, int bpm) async {
  final String texto =
      '¡ALERTA DE EMERGENCIA ARES ECG! 🚨\n'
      'Se ha activado una señal de auxilio.\n'
      'Última frecuencia cardíaca registrada: $bpm BPM.';

  // Cambiamos la URL de WhatsApp por el esquema nativo de SMS
  final Uri smsUrl = Uri.parse(
    'sms:$telefono?body=${Uri.encodeComponent(texto)}',
  );

  try {
    // Esto abrirá la aplicación de mensajes de texto del teléfono con el número y texto listos
    await launchUrl(smsUrl, mode: LaunchMode.externalApplication);
  } catch (e) {
    debugPrint('Error al abrir la aplicación de SMS: $e');
  }
}

  @override
  void dispose() {
    _timer?.cancel(); // Apaga el temporizador al salir de la pantalla
    super.dispose();
  }

  // Métodos auxiliares para diagnosticar estado y colores según los BPM
  String _obtenerDiagnostico(int bpm) {
    if (bpm == 0) return 'Sin lectura';
    if (bpm < 60) return 'Bradicardia';
    if (bpm > 100) return 'Taquicardia';
    return 'Ritmo Sinusal Normal';
  }

  Color _obtenerColorDiagnostico(int bpm) {
    if (bpm == 0) return AppColors.mutedText;
    if (bpm < 60) return Colors.orange;
    if (bpm > 100) return AppColors.danger;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ENCABEZADO
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.monitor_heart_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                        children: [
                          TextSpan(
                            text: 'ARES ',
                            style: TextStyle(color: AppColors.primary),
                          ),
                          TextSpan(
                            text: 'ECG',
                            style: TextStyle(color: AppColors.text),
                          ),
                        ],
                      ),
                    ),
                    const Text(
                      'Monitoreo cardíaco activo',
                      style: TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // ESTADO BATERÍA Y CONEXIÓN
            Row(
              children: [
                // Batería Dinámica
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.battery_5_bar_rounded,
                        size: 16,
                        color: Colors.black87,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$_bateria%', // Muestra el nivel dinámico
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                // Badge En Vivo
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.wifi, size: 16, color: AppColors.success),
                      SizedBox(width: 6),
                      Text(
                        'En vivo',
                        style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),

        // TARJETA PRINCIPAL: BPM DINÁMICO
        Card(
          elevation: 0,
          color: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Frecuencia Cardíaca',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mutedText,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite,
                        color: AppColors.danger,
                        size: 24,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Valor del Pulso
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _cargando ? '--' : '$_bpm',
                      style: const TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'BPM',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Diagnóstico Dinámico con cambio de color
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _obtenerColorDiagnostico(
                      _bpm,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _obtenerDiagnostico(_bpm),
                    style: TextStyle(
                      color: _obtenerColorDiagnostico(_bpm),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // TARJETA ONDA ECG
        Card(
          elevation: 0,
          color: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Container(
            height: 160,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.show_chart, color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Electrocardiograma (ECG)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Center(
                  child: Text(
                    'Espacio reservado para la onda en vivo',
                    style: TextStyle(
                      color: AppColors.mutedText.withValues(alpha: 0.7),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // VISTA Y EDICIÓN DE CONTACTO
        Card(
          elevation: 0,
          color: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Contacto: $_numeroEmergencia',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: AppColors.primary),
                  onPressed: _mostrarDialogoEditarNumero,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // BOTÓN ALERTA DINOÁMICO
        ElevatedButton.icon(
          onPressed: () {
            _enviarAlertaEmergencia(_numeroEmergencia, _bpm);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          icon: const Icon(Icons.warning_amber_rounded),
          label: const Text('ENVIAR ALERTA DE EMERGENCIA'),
        ),
      ],
    );
  }
}

// --- PANTALLA HISTORIAL (DISEÑO LIMPIO Y COMPLETO) ---
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  // Función para asignar el color según el estado que viene de la API
  Color _getColorPorEstado(String? estado) {
    switch (estado?.toLowerCase()) {
      case 'elevado':
      case 'alerta':
        return AppColors.primary;
      case 'reposo':
        return Colors.blue;
      case 'normal':
      default:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: ApiService.obtenerHistorialEcg(), // Consulta a C# / SQL
      builder: (context, snapshot) {
        // 1. Estado de Carga
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // 2. Estado de Error o Sin Datos
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text(
              'No hay lecturas registradas o falló la conexión con la API.',
            ),
          );
        }

        // 3. Datos Reales de SQL
        final registros = snapshot.data!;

        // 🧮 CALCULAR PROMEDIO, MÍNIMO Y MÁXIMO DINÁMICAMENTE
        int suma = 0;
        int minBpm =
            (registros.first['pulso'] ?? registros.first['Pulso'] ?? 0) as int;
        int maxBpm =
            (registros.first['pulso'] ?? registros.first['Pulso'] ?? 0) as int;

        for (var reg in registros) {
          final bpm = (reg['pulso'] ?? reg['Pulso'] ?? 0) as int;
          suma += bpm;
          if (bpm < minBpm) minBpm = bpm;
          if (bpm > maxBpm) maxBpm = bpm;
        }
        final promedioBpm = registros.isNotEmpty
            ? (suma / registros.length).round()
            : 0;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Encabezado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.history_rounded,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                            children: [
                              TextSpan(
                                text: 'ARES ',
                                style: TextStyle(color: AppColors.primary),
                              ),
                              TextSpan(
                                text: 'Historial',
                                style: TextStyle(color: AppColors.text),
                              ),
                            ],
                          ),
                        ),
                        const Text(
                          'Registro continuo de lecturas',
                          style: TextStyle(
                            color: AppColors.mutedText,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // TARJETAS DE RESUMEN RÁPIDO (3 columnas) con datos reales
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Promedio',
                    '$promedioBpm',
                    'BPM',
                    AppColors.text,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    'Mínimo',
                    '$minBpm',
                    'BPM',
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    'Máximo',
                    '$maxBpm',
                    'BPM',
                    AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Título de la sección
            const Text(
              'Lecturas Recientes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 12),

            // Lista de lecturas registradas desde la API
            ...registros.map((reg) {
              final bpm = reg['Pulso'] ?? reg['pulso'] ?? 0;
              final ecgRaw = reg['ValorECG'] ?? reg['valorEcg'] ?? 0;
              final double valorEcg = double.tryParse(ecgRaw.toString()) ?? 0.0;

              // Buscar 'Fecha' con mayúscula y formatearla
              final String fechaRaw =
                  reg['Fecha']?.toString() ?? reg['fecha']?.toString() ?? '';
              String fechaTexto = 'Sin fecha';

              if (fechaRaw.isNotEmpty) {
                try {
                  final DateTime dt = DateTime.parse(fechaRaw);
                  fechaTexto =
                      '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')} hs';
                } catch (_) {
                  fechaTexto = fechaRaw;
                }
              }

              final estado =
                  reg['EstadoRitmo'] ??
                  reg['estadoRitmo'] ??
                  reg['estado'] ??
                  'NORMAL';
              final colorEstado = _getColorPorEstado(estado.toString());

              return Card(
                elevation: 0,
                color: AppColors.card,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorEstado.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.favorite_rounded,
                      color: colorEstado,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    '$bpm BPM',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppColors.text,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ECG: ${valorEcg.toStringAsFixed(2)} mV',
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        fechaTexto,
                        style: const TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colorEstado.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorEstado.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      estado.toString(),
                      style: TextStyle(
                        color: colorEstado,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  // Widget auxiliar para las tarjetas de métricas superiores
  Widget _buildMetricCard(
    String titulo,
    String valor,
    String unidad,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.mutedText,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                valor,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unidad,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.mutedText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- PANTALLA CONTACTOS (DISEÑO NUEVO Y FUNCIONAL) ---
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  // Lista dinámica de contactos
  final List<Map<String, dynamic>> _contactos = [
    {
      'nombre': 'Dra. María González',
      'relacion': 'Cardióloga',
      'telefono': '+54 9 11 1234-5678',
      'esPrincipal': true,
    },
    {
      'nombre': 'Carlos Pérez',
      'relacion': 'Familiar (Hijo)',
      'telefono': '+54 9 11 8765-4321',
      'esPrincipal': false,
    },
  ];

  // Ventana emergente para agregar contacto con el nuevo estilo
  void _mostrarDialogoAgregarContacto() {
    final nombreController = TextEditingController();
    final telefonoController = TextEditingController();
    final relacionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          title: const Text(
            'Nuevo Contacto',
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre y Apellido',
                  prefixIcon: Icon(Icons.person, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: relacionController,
                decoration: const InputDecoration(
                  labelText: 'Relación (ej. Doctor, Hijo)',
                  prefixIcon: Icon(Icons.group, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: telefonoController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  prefixIcon: Icon(Icons.phone, color: AppColors.primary),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: AppColors.mutedText),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (nombreController.text.isNotEmpty &&
                    telefonoController.text.isNotEmpty) {
                  setState(() {
                    _contactos.add({
                      'nombre': nombreController.text,
                      'relacion': relacionController.text.isEmpty
                          ? 'Contacto'
                          : relacionController.text,
                      'telefono': telefonoController.text,
                      'esPrincipal': false,
                    });
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Encabezado
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.contact_phone_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                        children: [
                          TextSpan(
                            text: 'ARES ',
                            style: TextStyle(color: AppColors.primary),
                          ),
                          TextSpan(
                            text: 'Contactos',
                            style: TextStyle(color: AppColors.text),
                          ),
                        ],
                      ),
                    ),
                    const Text(
                      'Red de emergencia registrada',
                      style: TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Tarjeta Informativa
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppColors.primary),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Estos contactos recibirán una alerta automática si el ritmo cardíaco supera los límites normales.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.mutedText,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Título de la lista
        const Text(
          'Contactos de Alerta',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 12),

        // Lista dinámica de contactos
        ..._contactos.asMap().entries.map((entry) {
          final index = entry.key;
          final c = entry.value;
          final esPrincipal = c['esPrincipal'] as bool;

          return Card(
            elevation: 0,
            color: AppColors.card,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: CircleAvatar(
                backgroundColor: esPrincipal
                    ? AppColors.primary
                    : Colors.grey.shade300,
                child: Icon(
                  esPrincipal ? Icons.star_rounded : Icons.person_rounded,
                  color: esPrincipal ? Colors.white : Colors.grey.shade700,
                ),
              ),
              title: Row(
                children: [
                  Text(
                    c['nombre'] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.text,
                    ),
                  ),
                  if (esPrincipal) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Principal',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${c['relacion']} • ${c['telefono']}',
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 13,
                  ),
                ),
              ),
              trailing: IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.primary,
                ),
                onPressed: () {
                  setState(() {
                    _contactos.removeAt(index);
                  });
                },
              ),
            ),
          );
        }),
        const SizedBox(height: 16),

        // Botón para Agregar Nuevo Contacto
        OutlinedButton.icon(
          onPressed: _mostrarDialogoAgregarContacto,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary, width: 1.5),
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'AGREGAR CONTACTO',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
