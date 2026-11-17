import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/db_helper.dart';
import '../Models/medicion_model.dart';

// COLORES ARES
class AppColors {
  static const primary = Color(0xFFA61C1C);
  static const background = Colors.white;
  static const card = Color(0xFFF8F9FA);
  static const text = Color(0xFF111111);
  static const mutedText = Color(0xFF666666);
  static const danger = Color(0xFFE5484D);
  static const success = Color(0xFF12B76A);
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<MedicionModel>> _historialFuture;

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  void _cargarHistorial() {
    setState(() {
      _historialFuture = DatabaseHelper.instance.obtenerHistorial().catchError((
        error,
      ) {
        if (mounted) {
          final mensajeError = error.toString().replaceAll('Exception: ', '');
          mostrarAlertaRojo(context, 'Error de carga: $mensajeError');
        }
        return <MedicionModel>[];
      });
    });
  }

  void mostrarAlertaRojo(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                mensaje,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Color _getColorPorEstado(String? estado) {
    switch (estado?.toLowerCase().trim()) {
      case 'anomalia':
      case 'arritmia':
      case 'taquicardia':
      case 'elevado':
      case 'alerta':
        return AppColors.danger;
      case 'bradicardia':
      case 'reposo':
        return Colors.orange;
      case 'sin_contacto':
        return AppColors.mutedText;
      case 'estable':
      case 'normal':
      default:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          _cargarHistorial();
          await _historialFuture;
        },
        child: FutureBuilder<List<MedicionModel>>(
          future: _historialFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            if (snapshot.hasError ||
                !snapshot.hasData ||
                snapshot.data!.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 180),
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 48,
                          color: AppColors.mutedText,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No hay lecturas registradas aún.',
                          style: TextStyle(
                            color: AppColors.mutedText,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            final registros = snapshot.data!;
            int suma = 0;
            int minBpm = registros.first.pulso;
            int maxBpm = registros.first.pulso;

            for (var reg in registros) {
              final bpm = reg.pulso;
              suma += bpm;
              if (bpm < minBpm) minBpm = bpm;
              if (bpm > maxBpm) maxBpm = bpm;
            }
            final promedioBpm = registros.isNotEmpty
                ? (suma / registros.length).round()
                : 0;

            final ultimosRegistros = registros
                .take(7)
                .toList()
                .reversed
                .toList();
            final List<BarChartGroupData> barrasGrafico = List.generate(
              ultimosRegistros.length,
              (index) => _crearBarra(
                index,
                ultimosRegistros[index].pulso.toDouble(),
                esHoy: index == ultimosRegistros.length - 1,
              ),
            );

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
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
                              'Almacenamiento local',
                              style: TextStyle(
                                color: AppColors.mutedText,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: AppColors.primary),
                      onPressed: _cargarHistorial,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // TARJETAS DE ESTADÍSTICAS
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
                        AppColors.danger,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // GRÁFICO DINÁMICO FL_CHART
                if (ultimosRegistros.isNotEmpty) ...[
                  const Text(
                    'Tendencia Reciente',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
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
                      padding: const EdgeInsets.only(
                        top: 24,
                        right: 20,
                        left: 10,
                        bottom: 10,
                      ),
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: 140,
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipColor: (group) => Colors.black87,
                              getTooltipItem:
                                  (group, groupIndex, rod, rodIndex) {
                                    return BarTooltipItem(
                                      '${rod.toY.round()} BPM',
                                      const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    );
                                  },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) => Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    '#${value.toInt() + 1}',
                                    style: const TextStyle(
                                      color: AppColors.mutedText,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 35,
                                getTitlesWidget: (value, meta) {
                                  if (value == 0 || value == 140) {
                                    return const SizedBox.shrink();
                                  }
                                  return Text(
                                    value.toInt().toString(),
                                    style: const TextStyle(
                                      color: AppColors.mutedText,
                                      fontSize: 10,
                                    ),
                                    textAlign: TextAlign.right,
                                  );
                                },
                              ),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (value) => FlLine(
                              color: Colors.grey.shade200,
                              strokeWidth: 1,
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: barrasGrafico,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // LISTA DETALLADA
                const Text(
                  'Detalle de Lecturas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 12),
                ...registros.map((reg) {
                  final bpm = reg.pulso;
                  final double valorEcg = reg.valorEcg;
                  String fechaTexto = 'Sin fecha';
                  if (reg.fechaHora.isNotEmpty) {
                    try {
                      final DateTime dt = DateTime.parse(reg.fechaHora);
                      fechaTexto =
                          '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')} hs';
                    } catch (_) {
                      fechaTexto = reg.fechaHora;
                    }
                  }
                  final estado = reg.estadoRitmo;
                  final colorEstado = _getColorPorEstado(estado);

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
                            'ECG: ${valorEcg.toStringAsFixed(2)} V',
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
                          estado.toUpperCase(),
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
                const SizedBox(height: 80),
              ],
            );
          },
        ),
      ),
    );
  }

  BarChartGroupData _crearBarra(int x, double y, {bool esHoy = false}) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: esHoy
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.5),
          width: 16,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: 140,
            color: Colors.grey.shade100,
          ),
        ),
      ],
    );
  }

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
