import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Models/medicion_model.dart';
import 'api_service.dart';
import 'db_helper.dart';

final Guid kAresServiceUuid = Guid('6b6f0001-8c37-4d5a-9b1a-1e2c9f6d1a10');
final Guid kAresCharacteristicUuid = Guid('6b6f0002-8c37-4d5a-9b1a-1e2c9f6d1a10');
final Guid kAresStreamCharacteristicUuid = Guid('6b6f0003-8c37-4d5a-9b1a-1e2c9f6d1a10');

const double kEcgLsbMv = 0.125;

enum CardiacStatus { estable, anomalia, sinContacto, inconcluso, desconocido }

CardiacStatus parseCardiacStatus(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'estable': return CardiacStatus.estable;
    case 'anomalia': return CardiacStatus.anomalia;
    case 'sin_contacto': return CardiacStatus.sinContacto;
    case 'inconcluso': return CardiacStatus.inconcluso;
    default: return CardiacStatus.desconocido;
  }
}

class CardiacMonitorBleService {
  // =======================================================================
  // PATRÓN SINGLETON: Mantiene el servicio vivo en toda la app
  // =======================================================================
  static final CardiacMonitorBleService _instance = CardiacMonitorBleService._internal();
  factory CardiacMonitorBleService() => _instance;
  CardiacMonitorBleService._internal();
  // =======================================================================

  String emergencyPhone = '+5491112345678';

  static const Duration _saveInterval = Duration(seconds: 10);
  static const Duration _reconnectDelay = Duration(seconds: 3);
  static const int _anomalyConfirmations = 3; 

  BluetoothDevice? _device;
  BluetoothCharacteristic? _statusCharacteristic;
  BluetoothCharacteristic? _streamCharacteristic;

  StreamSubscription<List<int>>? _statusSubscription;
  StreamSubscription<List<int>>? _streamSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;

  final _statusController = StreamController<CardiacStatus>.broadcast();
  final _bpmController = StreamController<int>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _ecgStreamController = StreamController<List<double>>.broadcast();

  bool _alertaYaEnviada = false;
  bool _manualDisconnect = false;
  bool _wasConnected = false;
  bool _disposed = false;
  Timer? _reconnectTimer;

  int _anomalyCount = 0;
  DateTime _lastSave = DateTime.fromMillisecondsSinceEpoch(0);
  double _lastEcgMv = 0;

  Stream<CardiacStatus> get statusStream => _statusController.stream;
  Stream<int> get bpmStream => _bpmController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<List<double>> get ecgStream => _ecgStreamController.stream;
  bool get isConnected => _device?.isConnected ?? false;

  Future<void> _requestPermissions() async {
    if (!Platform.isAndroid) return;
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location, 
    ].request();
  }

  Future<void> connect({Duration timeout = const Duration(seconds: 12)}) async {
    // NUEVO: Si ya estamos conectados (porque venimos de otra pestaña), no hacemos nada
    if (isConnected) return;

    _manualDisconnect = false;
    _reconnectTimer?.cancel();

    await _requestPermissions();

    if (await FlutterBluePlus.isSupported == false) {
      throw Exception('Bluetooth no soportado');
    }

    await FlutterBluePlus.adapterState
        .where((s) => s == BluetoothAdapterState.on)
        .first
        .timeout(timeout, onTimeout: () => throw Exception('Bluetooth apagado'));

    _device = await _scanForDevice(timeout);
    await _connectAndSubscribe(timeout);
  }

  Future<BluetoothDevice> _scanForDevice(Duration timeout) async {
    final completer = Completer<BluetoothDevice>();
    final sub = FlutterBluePlus.onScanResults.listen(
      (results) {
        if (results.isNotEmpty && !completer.isCompleted) {
          completer.complete(results.first.device);
        }
      },
      onError: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
    );

    try {
      await FlutterBluePlus.startScan(withServices: [kAresServiceUuid], timeout: timeout);
      return await completer.future.timeout(
        timeout,
        onTimeout: () => throw Exception('No se encontró el ARES Cardiac Monitor.'),
      );
    } finally {
      await FlutterBluePlus.stopScan();
      await sub.cancel();
    }
  }

  Future<void> _connectAndSubscribe(Duration timeout) async {
    final device = _device!;

    await _connectionSubscription?.cancel();
    _connectionSubscription = device.connectionState.listen(_onConnectionState);

    await device.connect(timeout: timeout, license: License.nonprofit);

    final services = await device.discoverServices();
    final service = services.firstWhere(
      (s) => s.uuid == kAresServiceUuid,
      orElse: () => throw Exception('El dispositivo no expone el servicio ARES.'),
    );

    _statusCharacteristic = service.characteristics.firstWhere(
      (c) => c.uuid == kAresCharacteristicUuid,
      orElse: () => throw Exception('Falta la característica de estado (0002).'),
    );
    _streamCharacteristic = service.characteristics.firstWhere(
      (c) => c.uuid == kAresStreamCharacteristicUuid,
      orElse: () => throw Exception('Falta la característica de ECG (0003).'),
    );

    await _statusSubscription?.cancel();
    await _streamSubscription?.cancel();

    _statusSubscription = _statusCharacteristic!.onValueReceived.listen(_onStatusBytes);
    _streamSubscription = _streamCharacteristic!.onValueReceived.listen(_onEcgBytes);

    await _statusCharacteristic!.setNotifyValue(true);
    await _streamCharacteristic!.setNotifyValue(true);

    _wasConnected = true;
  }

  void _onConnectionState(BluetoothConnectionState state) {
    final connected = state == BluetoothConnectionState.connected;
    if (!_connectionController.isClosed) _connectionController.add(connected);

    if (!connected && _wasConnected && !_manualDisconnect && !_disposed) {
      _wasConnected = false;
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive ?? false) return;
    _reconnectTimer = Timer(_reconnectDelay, () async {
      if (_manualDisconnect || _disposed || _device == null) return;
      try {
        debugPrint('[BLE] Reintentando conexión...');
        await _connectAndSubscribe(const Duration(seconds: 12));
      } catch (e) {
        debugPrint('[BLE] Reconexión fallida: $e');
        _scheduleReconnect();
      }
    });
  }

  void _onStatusBytes(List<int> bytes) {
    final raw = utf8.decode(bytes, allowMalformed: true).trim();
    int bpm = 0;
    bool leadsOff = true;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      bpm = (map['bpm'] as num?)?.toInt() ?? 0;
      leadsOff = map['leadsOff'] as bool? ?? true;
    } catch (e) {
      return;
    }

    final CardiacStatus status;
    if (leadsOff) {
      status = CardiacStatus.sinContacto;
    } else if (bpm == 0) {
      status = CardiacStatus.inconcluso; 
    } else if (bpm > 120 || bpm < 50) {
      status = CardiacStatus.anomalia;
    } else {
      status = CardiacStatus.estable;
    }

    if (!_statusController.isClosed) _statusController.add(status);
    if (!_bpmController.isClosed) _bpmController.add(bpm);

    _handleAlert(status, bpm);
    _persistIfDue(status, bpm);
  }

  void _handleAlert(CardiacStatus status, int bpm) {
    if (status == CardiacStatus.anomalia) {
      _anomalyCount++;
      if (_anomalyCount >= _anomalyConfirmations && !_alertaYaEnviada) {
        _alertaYaEnviada = true;
        _enviarAlertaEmergencia(emergencyPhone, bpm);
      }
    } else {
      _anomalyCount = 0;
      if (status == CardiacStatus.estable) _alertaYaEnviada = false;
    }
  }

  Future<void> _enviarAlertaEmergencia(String telefono, int bpm) async {
    final texto = '¡ALERTA DE EMERGENCIA ARES ECG! 🚨\nSe ha activado una señal de auxilio.\nÚltima frecuencia cardíaca registrada: $bpm BPM.';
    final smsUrl = Uri.parse('sms:$telefono?body=${Uri.encodeComponent(texto)}');
    try {
      await launchUrl(smsUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[SMS] Error al abrir SMS: $e');
    }
  }

  Future<void> _persistIfDue(CardiacStatus status, int bpm) async {
    if (status != CardiacStatus.estable && status != CardiacStatus.anomalia) return;
    if (bpm <= 0) return;

    final now = DateTime.now();
    if (now.difference(_lastSave) < _saveInterval) return;
    _lastSave = now;

    final estado = status.name.toUpperCase();
    final rr = 60000 ~/ bpm;

    try {
      await DatabaseHelper.instance.insertarMedicion(
        MedicionModel(
          fechaHora: now.toIso8601String(),
          valorEcg: _lastEcgMv, pulso: bpm,
          intervaloRr: rr, estadoRitmo: estado, sincronizado: 0,
        ),
      );
    } catch (e) {}

    try {
      await ApiService.guardarLecturaEcg(
        valorEcg: _lastEcgMv, pulso: bpm, intervaloRr: rr, estadoRitmo: estado,
      );
    } catch (_) {}
  }

  void _onEcgBytes(List<int> bytes) {
    if (bytes.length < 2) return;
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    final count = bytes.length ~/ 2; 
    final samples = List<double>.generate(
      count,
      (i) => data.getInt16(i * 2, Endian.little) * kEcgLsbMv,
      growable: false,
    );
    _lastEcgMv = samples.last;
    if (!_ecgStreamController.isClosed) _ecgStreamController.add(samples);
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _wasConnected = false;
    _reconnectTimer?.cancel();
    await _device?.disconnect();
  }

  void dispose() {
    _disposed = true;
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _statusSubscription?.cancel();
    _streamSubscription?.cancel();
    _connectionSubscription?.cancel();
    _statusController.close();
    _bpmController.close();
    _connectionController.close();
    _ecgStreamController.close();
  }
}