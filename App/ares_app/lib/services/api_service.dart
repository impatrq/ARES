import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

class ApiService {
  // CONFIGURACIÓN DE RED: IP local de tu PC en la red Wi-Fi
  static const String baseUrl = 'http://192.168.126.139:5000/api';

  // FUNCIÓN AUXILIAR: Obtiene el token activo de Firebase renovado
  static Future<Map<String, String>> _getAuthHeaders() async {
    final Map<String, String> headers = {'Content-Type': 'application/json'};
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        // user.getIdToken(true) fuerza el refresco del token JWT si venció
        final token = await user.getIdToken(true);
        headers['Authorization'] = 'Bearer $token';
        debugPrint('[API] Token de Firebase adjuntado correctamente para: ${user.email}');
      } catch (e) {
        debugPrint('[API] Error al obtener token de Firebase: $e');
      }
    } else {
      debugPrint('[API] ALERTA: No hay ningún usuario autenticado en Firebase. Se enviará la petición sin token.');
    }
    return headers;
  }

  // 1. Obtener la lista de lecturas de ECG desde C# / PostgreSQL
  static Future<List<dynamic>> obtenerHistorialEcg() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/canal'), headers: headers)
          .timeout(const Duration(seconds: 10)); // Timeout extendido para Wi-Fi

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is List) return decoded;
        if (decoded is Map<String, dynamic> && decoded.containsKey('result')) {
          return decoded['result'] as List<dynamic>;
        }
        return [];
      } else {
        debugPrint('[API] Error al obtener historial. Código HTTP: ${response.statusCode}');
        throw Exception('Error en el servidor: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Tiempo agotado. La API C# no responde.');
    } on SocketException {
      throw Exception('Sin conexión. Verificá que la PC y el celular estén en el mismo Wi-Fi.');
    } catch (e) {
      throw Exception('Error inesperado: $e');
    }
  }

  // 2. Obtener la última lectura para la pantalla principal
  static Future<Map<String, dynamic>?> obtenerUltimaLectura() async {
    try {
      final lecturas = await obtenerHistorialEcg();
      if (lecturas.isNotEmpty) {
        return lecturas.first as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[API] Error al obtener última lectura: $e');
    }
    return null;
  }

  // 3. Guardar el diagnóstico de la IA en el servidor C#
  static Future<bool> guardarLecturaEcg({
    required double valorEcg,
    required int pulso,
    required int intervaloRr,
    required String estadoRitmo,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/canal'),
            headers: headers,
            body: jsonEncode({
              'ValorECG': valorEcg,
              'Pulso': pulso,
              'IntervaloRR': intervaloRr,
              'EstadoRitmo': estadoRitmo,
            }),
          )
          .timeout(const Duration(seconds: 8));

      debugPrint('[API] Respuesta guardar ECG: Status ${response.statusCode}');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('[API] Error guardando lectura ECG: $e');
      return false;
    }
  }

  // 4. Obtener contactos de emergencia
  static Future<List<dynamic>> obtenerContactos() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/contacto'), headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is List) return decoded;
        if (decoded is Map<String, dynamic> && decoded.containsKey('result')) {
          return decoded['result'] as List<dynamic>? ?? [];
        }
      }
      return [];
    } catch (e) {
      debugPrint('[API] Error obteniendo contactos: $e');
      return [];
    }
  }

  // 5. Guardar nuevo contacto
  static Future<bool> guardarContacto(
    String nombre,
    String telefono,
    String relacion,
  ) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/contacto'),
            headers: headers,
            body: jsonEncode({
              'Nombre': nombre,
              'Telefono': telefono,
              'Relacion': relacion,
            }),
          )
          .timeout(const Duration(seconds: 8));

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('[API] Error guardando contacto: $e');
      return false;
    }
  }

  // 6. Login directo a la API en C#
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Credenciales incorrectas o error en el servidor');
    }
  }
}