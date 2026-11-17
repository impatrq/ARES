import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/cardiac_monitor_ble_service.dart';
import 'package:fl_chart/fl_chart.dart';

class AppColors {
  static const primary = Color(0xFFA61C1C);
  static const background = Colors.white;
  static const card = Color(0xFFF8F9FA);
  static const text = Color(0xFF111111);
  static const mutedText = Color(0xFF666666);
  static const danger = Color(0xFFE5484D);
  static const success = Color(0xFF12B76A);
}

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Timer? _timer;
  int _bpm = 0;
  int _bateria = 0;
  bool _cargando = true;

  String _numeroEmergencia = '5491124805554';
  bool _alertaActiva = false;

  late AnimationController _pulsoController;
  late Animation<double> _pulsoAnimacion;

  final CardiacMonitorBleService _ble = CardiacMonitorBleService();
  CardiacStatus _estadoIA = CardiacStatus.desconocido;
  bool _iaConectada = false;
  bool _iaConectando = false;

  StreamSubscription<CardiacStatus>? _iaStatusSub;
  StreamSubscription<bool>? _iaConnSub;
  StreamSubscription<List<double>>? _iaEcgSub;
  StreamSubscription<int>? _iaBpmSub;

  static const int _sampleRate = 250;
  static const int _bufferSize = _sampleRate * 5;
  static const int _decimacion = 2;
  static const int _puntosVisibles = _bufferSize ~/ _decimacion;

  final Float32List _ecgBuffer = Float32List(_bufferSize);
  int _ecgHead = 0;
  bool _ecgDirty = false;
  Timer? _ecgTimer;
  final ValueNotifier<int> _ecgTick = ValueNotifier<int>(0);
  double _yMin = -10, _yMax = 10;

  Timer? _reintentoTimer;

  void _agregarMuestrasBLE(List<double> nuevas) {
    if (nuevas.isEmpty) return;

    for (final m in nuevas) {
      double safeValue = m;
      if (m.isNaN || m.isInfinite) {
        safeValue = 1.65;
      }
      _ecgBuffer[_ecgHead] = safeValue;
      _ecgHead = (_ecgHead + 1) % _bufferSize;
    }
    _ecgDirty = true;
  }

  List<FlSpot> _construirPuntos() {
    final spots = List<FlSpot>.generate(_puntosVisibles, (i) {
      final v = _ecgBuffer[(_ecgHead + i * _decimacion) % _bufferSize]
          .toDouble();
      return FlSpot(i.toDouble(), v);
    }, growable: false);

    var minV = double.infinity, maxV = -double.infinity;
    for (final s in spots) {
      if (s.y < minV) minV = s.y;
      if (s.y > maxV) maxV = s.y;
    }
    if (maxV - minV < 20) {
      final c = (maxV + minV) / 2;
      minV = c - 10;
      maxV = c + 10;
    }
    final margen = (maxV - minV) * 0.15;
    _yMin += ((minV - margen) - _yMin) * 0.15;
    _yMax += ((maxV + margen) - _yMax) * 0.15;
    return spots;
  }

  @override
  void initState() {
    super.initState();

    _pulsoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulsoAnimacion = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulsoController, curve: Curves.easeInOut),
    );
    _pulsoController.repeat(reverse: true);

    for (int i = 0; i < _bufferSize; i++) {
      _ecgBuffer[i] = 1.65;
    }

    _obtenerDatos();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _obtenerDatos());
    _conectarIA();

    _ecgTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (_ecgDirty) {
        _ecgDirty = false;
        _ecgTick.value++;
      }
    });
  }

  void _actualizarVelocidadLatido(int bpmActual) {
    if (bpmActual > 0) {
      int duracionMs = (60000 / bpmActual / 2).round();
      if (duracionMs < 100) duracionMs = 100;

      _pulsoController.duration = Duration(milliseconds: duracionMs);
      if (!_pulsoController.isAnimating) {
        _pulsoController.repeat(reverse: true);
      }
    } else {
      _pulsoController.stop();
    }
  }

  Future<void> _obtenerDatos() async {
    final ultimaLectura = await ApiService.obtenerUltimaLectura();
    if (ultimaLectura != null && mounted) {
      setState(() {
        _bateria = ultimaLectura['bateria'] ?? _bateria;
      });
    }
  }

  void _verificarRitmoCardiaco(int bpmActual) {
    if ((bpmActual > 120 || (bpmActual < 50 && bpmActual > 0)) &&
        !_alertaActiva) {
      _dispararAlertaEmergencia(bpmActual);
    } else if (bpmActual >= 50 && bpmActual <= 120 && _alertaActiva) {
      _alertaActiva = false;
    }
  }

  void _dispararAlertaEmergencia(int bpmCritico) {
    _alertaActiva = true;
    HapticFeedback.heavyImpact();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.danger,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 32),
              SizedBox(width: 10),
              Text(
                '¡ALERTA CRÍTICA!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            'El paciente presenta un ritmo cardíaco anormal: $bpmCritico BPM.',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _enviarAlertaEmergencia(_numeroEmergencia, bpmCritico);
              },
              child: const Text(
                'ENVIAR SMS',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'ATENDER PACIENTE',
                style: TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _onBpmBLE(int bpm) {
    if (!mounted) return;
    setState(() {
      _bpm = bpm;
      _cargando = bpm == 0;
    });

    // --- ENVÍO AUTOMÁTICO A LA API C# Y POSTGRESQL ---
    if (bpm > 0) {
      double ultimoVoltaje =
          _ecgBuffer[_ecgHead == 0 ? _bufferSize - 1 : _ecgHead - 1];

      ApiService.guardarLecturaEcg(
        valorEcg: ultimoVoltaje > 0 ? ultimoVoltaje : 1.65,
        pulso: bpm,
        intervaloRr: (60000 / bpm).round(),
        estadoRitmo: _labelEstadoIA(_estadoIA, _iaConectada),
      ).then((exito) {
        if (exito) {
          debugPrint(
            '[MONITOR] Lectura ($bpm BPM) guardada exitosamente en PostgreSQL.',
          );
        } else {
          debugPrint('[MONITOR] Error al guardar lectura en la API.');
        }
      });
    }

    _verificarRitmoCardiaco(bpm);
    _actualizarVelocidadLatido(bpm);
    if (bpm >= 50 && bpm <= 120) _alertaActiva = false;
  }

  Future<void> _conectarIA() async {
    _reintentoTimer?.cancel();

    _iaStatusSub ??= _ble.statusStream.listen((estado) {
      if (mounted) setState(() => _estadoIA = estado);
    });

    _iaConnSub ??= _ble.connectionStream.listen((conectada) {
      if (mounted) setState(() => _iaConectada = conectada);
    });

    _iaEcgSub ??= _ble.ecgStream.listen(_agregarMuestrasBLE);
    _iaBpmSub ??= _ble.bpmStream.listen(_onBpmBLE);

    if (_ble.isConnected) {
      if (mounted) setState(() => _iaConectada = true);
      return;
    }

    if (mounted) setState(() => _iaConectando = true);
    try {
      await _ble.connect();
    } catch (e) {
      debugPrint('No se pudo conectar: $e');
    } finally {
      if (mounted) {
        setState(() => _iaConectando = false);
        if (!_ble.isConnected) {
          _reintentoTimer = Timer(const Duration(seconds: 5), _conectarIA);
        }
      }
    }
  }

  Color _colorEstadoIA(CardiacStatus estado) {
    switch (estado) {
      case CardiacStatus.estable:
        return AppColors.success;
      case CardiacStatus.anomalia:
        return AppColors.danger;
      case CardiacStatus.sinContacto:
        return AppColors.mutedText;
      case CardiacStatus.inconcluso:
        return Colors.orange;
      case CardiacStatus.desconocido:
        return AppColors.mutedText;
    }
  }

  IconData _iconoEstadoIA(CardiacStatus estado) {
    switch (estado) {
      case CardiacStatus.estable:
        return Icons.check_circle;
      case CardiacStatus.anomalia:
        return Icons.warning_rounded;
      case CardiacStatus.sinContacto:
        return Icons.sensors_off_rounded;
      case CardiacStatus.inconcluso:
        return Icons.help_outline_rounded;
      case CardiacStatus.desconocido:
        return Icons.bluetooth_searching_rounded;
    }
  }

  String _labelEstadoIA(CardiacStatus estado, bool conectada) {
    if (!conectada) return 'Buscando el monitor por Bluetooth...';
    switch (estado) {
      case CardiacStatus.estable:
        return 'Estable';
      case CardiacStatus.anomalia:
        return 'Anomalía detectada';
      case CardiacStatus.sinContacto:
        return 'Sin contacto (electrodos)';
      case CardiacStatus.inconcluso:
        return 'Analizando señal...';
      case CardiacStatus.desconocido:
        return 'Esperando datos...';
    }
  }

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
              labelText: 'Teléfono',
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
                setState(() => _numeroEmergencia = controller.text.trim());
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
        '¡ALERTA DE EMERGENCIA ARES ECG! 🚨\nSe ha activado una señal de auxilio manual.\nÚltima frecuencia cardíaca registrada: $bpm BPM.';
    final Uri smsUrl = Uri.parse(
      'sms:$telefono?body=${Uri.encodeComponent(texto)}',
    );
    try {
      await launchUrl(smsUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error al abrir SMS: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ecgTimer?.cancel();
    _reintentoTimer?.cancel();
    _ecgTick.dispose();
    _iaStatusSub?.cancel();
    _iaConnSub?.cancel();
    _iaEcgSub?.cancel();
    _iaBpmSub?.cancel();
    _pulsoController.dispose();
    super.dispose();
  }

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
    super.build(context);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Monitor Cardíaco ARES 🫀',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.monitor_heart_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 20,
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
                      'Monitoreo activo',
                      style: TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.battery_5_bar_rounded,
                        size: 14,
                        color: Colors.black87,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '$_bateria%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _iaConectada
                        ? AppColors.success.withValues(alpha: 0.1)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _iaConectada
                          ? AppColors.success.withValues(alpha: 0.3)
                          : Colors.grey.shade400,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _iaConectada
                            ? Icons.bluetooth_connected
                            : Icons.bluetooth_disabled,
                        size: 14,
                        color: _iaConectada
                            ? AppColors.success
                            : AppColors.mutedText,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _iaConectada ? 'En vivo' : 'Descon.',
                        style: TextStyle(
                          color: _iaConectada
                              ? AppColors.success
                              : AppColors.mutedText,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
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
                    ScaleTransition(
                      scale: _pulsoAnimacion,
                      child: Container(
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
                    ),
                  ],
                ),
                const SizedBox(height: 16),
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
        Card(
          elevation: 0,
          color: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _colorEstadoIA(_estadoIA).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _iconoEstadoIA(_estadoIA),
                    color: _colorEstadoIA(_estadoIA),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Análisis de arritmias (IA en la placa)',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _labelEstadoIA(_estadoIA, _iaConectada),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _colorEstadoIA(_estadoIA),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_iaConectada)
                  IconButton(
                    icon: _iaConectando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, color: AppColors.primary),
                    onPressed: _iaConectando ? null : _conectarIA,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          color: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Container(
            height: 220,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.show_chart, color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Electrocardiograma (ECG en vivo)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ValueListenableBuilder<int>(
                    valueListenable: _ecgTick,
                    builder: (context, tick, child) {
                      final puntos = _construirPuntos();
                      return LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (value) => FlLine(
                              color: Colors.grey.shade200,
                              strokeWidth: 1,
                            ),
                          ),
                          titlesData: const FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          lineTouchData: const LineTouchData(enabled: false),
                          minX: 0.0,
                          maxX: (puntos.length - 1).toDouble(),
                          minY: _yMin,
                          maxY: _yMax,
                          lineBarsData: [
                            LineChartBarData(
                              spots: puntos,
                              isCurved: true,
                              curveSmoothness: 0.2,
                              color: AppColors.primary,
                              barWidth: 2.0,
                              dotData: const FlDotData(show: false),
                            ),
                          ],
                        ),
                        duration: Duration.zero,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
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
        ElevatedButton.icon(
          onPressed: () => _enviarAlertaEmergencia(_numeroEmergencia, _bpm),
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
        const SizedBox(height: 20),
      ],
    );
  }
}
