import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/account_service.dart';
import 'doctor_dashboard_screen.dart';
import '../main.dart';

class LoginScreen extends StatefulWidget {
  final String? emailPrellenado;
  const LoginScreen({super.key, this.emailPrellenado});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _esRegistro = false;
  String _rolSeleccionado = 'paciente';

  @override
  void initState() {
    super.initState();
    if (widget.emailPrellenado != null && widget.emailPrellenado!.isNotEmpty) {
      _emailController.text = widget.emailPrellenado!;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _procesarAutenticacion() async {
    setState(() => _isLoading = true);
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, completá todos los campos.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      UserCredential userCredential;
      String rolFinal = 'paciente';

      if (_esRegistro) {
        // CREAR CUENTA NUEVA
        userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);
        rolFinal = _rolSeleccionado;
      } else {
        // INICIAR SESIÓN EXISTENTE
        userCredential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email, password: password);

        // Buscamos si ya teníamos el rol guardado para esta casilla específica
        String? rolGuardado = await AccountService.obtenerRolPorEmail(email);
        if (rolGuardado != null && rolGuardado.isNotEmpty) {
          rolFinal = rolGuardado;
        } else {
          // Si no estaba guardado en este teléfono, inferimos por el correo
          rolFinal = email.toLowerCase().contains('medico') ? 'medico' : 'paciente';
        }
      }

      final String uid = userCredential.user?.uid ?? '';

      // Guardamos la cuenta y su rol específico
      await AccountService.guardarCuentaLocal(uid, email, rolFinal);

      if (!mounted) return;

      // Redirigir según el rol
      if (rolFinal == 'medico') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DoctorDashboardScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String mensajeError = 'Ocurrió un error.';
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        mensajeError = 'Correo o contraseña incorrectos.';
      } else if (e.code == 'email-already-in-use') {
        mensajeError = 'Este correo ya está registrado.';
      } else if (e.code == 'weak-password') {
        mensajeError = 'La contraseña debe tener al menos 6 caracteres.';
      } else if (e.code == 'invalid-email') {
        mensajeError = 'Formato de correo electrónico no válido.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeError),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de conexión: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ARES - Identificación 🫀',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFFA61C1C),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.monitor_heart,
                  size: 80,
                  color: Color(0xFFA61C1C),
                ),
                const SizedBox(height: 20),
                Text(
                  _esRegistro
                      ? 'Crear Cuenta ARES'
                      : 'Bienvenido a ARES Cardiac Monitor',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña (mínimo 6 caracteres)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),

                if (_esRegistro) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _rolSeleccionado,
                    decoration: InputDecoration(
                      labelText: 'Tipo de Perfil',
                      prefixIcon: Icon(
                        _rolSeleccionado == 'medico'
                            ? Icons.medical_services
                            : Icons.person,
                        color: const Color(0xFFA61C1C),
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'paciente',
                        child: Text('Paciente'),
                      ),
                      DropdownMenuItem(
                        value: 'medico',
                        child: Text('Médico'),
                      ),
                    ],
                    onChanged: (nuevoRol) {
                      if (nuevoRol != null) {
                        setState(() {
                          _rolSeleccionado = nuevoRol;
                        });
                      }
                    },
                  ),
                ],

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA61C1C),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isLoading ? null : _procesarAutenticacion,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            _esRegistro ? 'Registrarse' : 'Ingresar',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _esRegistro = !_esRegistro;
                    });
                  },
                  child: Text(
                    _esRegistro
                        ? '¿Ya tenés cuenta? Iniciá Sesión'
                        : '¿No tenés cuenta? Registrate acá',
                    style: const TextStyle(color: Color(0xFFA61C1C)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}