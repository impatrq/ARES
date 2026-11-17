import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccountService {
  static const String _keyCuentas = 'cuentas_guardadas';

  // Guardar o actualizar la cuenta en la lista local del dispositivo
  static Future<void> guardarCuentaLocal(
    String uid,
    String email,
    String rol,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> cuentasJson = prefs.getStringList(_keyCuentas) ?? [];

    final String cleanEmail = email.toLowerCase().trim();

    Map<String, String> nuevaCuenta = {
      'uid': uid,
      'email': cleanEmail,
      'rol': rol,
    };

    // Remover registros viejos de la misma cuenta antes de guardar
    cuentasJson.removeWhere((item) {
      try {
        final map = jsonDecode(item);
        return map['email'].toString().toLowerCase().trim() == cleanEmail ||
            map['uid'] == uid;
      } catch (_) {
        return false;
      }
    });

    cuentasJson.add(jsonEncode(nuevaCuenta));
    await prefs.setStringList(_keyCuentas, cuentasJson);

    // Guardamos la sesión activa actual
    await prefs.setString('rol_usuario', rol);
    await prefs.setString('email_activo', cleanEmail);
  }

  // Buscar el rol guardado para un correo específico
  static Future<String?> obtenerRolPorEmail(String email) async {
    final cuentas = await obtenerCuentasGuardadas();
    final String cleanEmail = email.toLowerCase().trim();
    for (var c in cuentas) {
      if (c['email']?.toString().toLowerCase().trim() == cleanEmail) {
        return c['rol']?.toString();
      }
    }
    return null;
  }

  // Buscar el rol guardado para un UID específico de Firebase
  static Future<String?> obtenerRolPorUid(String uid) async {
    final cuentas = await obtenerCuentasGuardadas();
    for (var c in cuentas) {
      if (c['uid']?.toString() == uid) {
        return c['rol']?.toString();
      }
    }
    return null;
  }

  // Obtener todas las cuentas registradas en este dispositivo
  static Future<List<Map<String, dynamic>>> obtenerCuentasGuardadas() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> cuentasJson = prefs.getStringList(_keyCuentas) ?? [];
    return cuentasJson
        .map((item) {
          try {
            return jsonDecode(item) as Map<String, dynamic>;
          } catch (_) {
            return <String, dynamic>{};
          }
        })
        .where((map) => map.isNotEmpty)
        .toList();
  }

  // Ventana flotante inferior para cambiar de perfil o cerrar sesión
  static void mostrarSelectorDeCuentas(
    BuildContext context, {
    required Function(String emailSeleccionado) onSeleccionarCuenta,
  }) async {
    final cuentas = await obtenerCuentasGuardadas();
    final usuarioActual = FirebaseAuth.instance.currentUser;

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Cuentas en este dispositivo',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (cuentas.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Text(
                    'No hay otras cuentas registradas aún en este teléfono.',
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: cuentas.length,
                    itemBuilder: (context, index) {
                      final cuenta = cuentas[index];
                      final bool esActual =
                          usuarioActual?.email?.toLowerCase().trim() ==
                          cuenta['email']?.toString().toLowerCase().trim();

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: cuenta['rol'] == 'medico'
                              ? Colors.blue
                              : const Color(0xFFA61C1C),
                          child: Icon(
                            cuenta['rol'] == 'medico'
                                ? Icons.medical_services
                                : Icons.person,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(cuenta['email'] ?? ''),
                        subtitle: Text(
                          (cuenta['rol'] ?? 'paciente')
                              .toString()
                              .toUpperCase(),
                        ),
                        trailing: esActual
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              )
                            : null,
                        onTap: () async {
                          Navigator.pop(ctx);
                          if (!esActual) {
                            await FirebaseAuth.instance.signOut();
                            onSeleccionarCuenta(cuenta['email'] ?? '');
                          }
                        },
                      );
                    },
                  ),
                ),
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.person_add_alt_1,
                  color: Color(0xFFA61C1C),
                ),
                title: const Text('Agregar otra cuenta / Registrarse'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await FirebaseAuth.instance.signOut();
                  onSeleccionarCuenta('');
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
