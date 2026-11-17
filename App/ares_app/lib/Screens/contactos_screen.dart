import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/db_helper.dart'; 
import '../Models/contacto.dart'; 

class AppColors {
  static const primary = Color(0xFFA61C1C);
  static const background = Colors.white;
  static const card = Color(0xFFF8F9FA);
  static const text = Color(0xFF111111);
  static const mutedText = Color(0xFF666666);
  static const danger = Color(0xFFE5484D);
  static const success = Color(0xFF12B76A);
}

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<Contacto> _contactos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarContactos();
  }

  Future<void> _cargarContactos() async {
    setState(() => _cargando = true);
    try {
      final lista = await DatabaseHelper.instance.obtenerContactos();
      if (mounted) setState(() { _contactos = lista; _cargando = false; });
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _hacerLlamada(String numero) async {
    final Uri url = Uri.parse('tel:$numero');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  // --- NUEVA FUNCIÓN: Confirmar y Eliminar ---
  Future<void> _confirmarEliminacion(int id, String nombre) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Contacto', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
        content: Text('¿Estás seguro de que querés eliminar a $nombre de tus contactos de emergencia?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.mutedText)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Cierra el diálogo
              await DatabaseHelper.instance.eliminarContacto(id); // Lo borra de SQLite
              _cargarContactos(); // Recarga la lista
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$nombre eliminado con éxito.')));
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoAgregarContacto() {
    final nombreController = TextEditingController();
    final telefonoController = TextEditingController();
    final relacionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          title: const Text('Nuevo Contacto', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nombreController, decoration: const InputDecoration(labelText: 'Nombre y Apellido', prefixIcon: Icon(Icons.person, color: AppColors.primary))),
              const SizedBox(height: 12),
              TextField(controller: relacionController, decoration: const InputDecoration(labelText: 'Relación (ej. Doctor, Padre)', prefixIcon: Icon(Icons.group, color: AppColors.primary))),
              const SizedBox(height: 12),
              TextField(controller: telefonoController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Teléfono', prefixIcon: Icon(Icons.phone, color: AppColors.primary))),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: AppColors.mutedText))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              onPressed: () async {
                if (nombreController.text.isNotEmpty && telefonoController.text.isNotEmpty) {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context);
                  final nuevoContacto = Contacto(
                    nombre: nombreController.text.trim(),
                    telefono: telefonoController.text.trim(),
                    vinculo: relacionController.text.trim().isEmpty ? 'Contacto' : relacionController.text.trim(),
                  );
                  final idGuardado = await DatabaseHelper.instance.insertarContacto(nuevoContacto);
                  if (idGuardado > 0) {
                    _cargarContactos();
                    messenger.showSnackBar(const SnackBar(content: Text('Contacto guardado localmente')));
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  IconData _getIconoRelacion(String relacion) {
    final r = relacion.toLowerCase();
    if (r.contains('doc') || r.contains('med') || r.contains('méd')) return Icons.medical_services_rounded;
    if (r.contains('padre') || r.contains('madre') || r.contains('hij') || r.contains('fam')) return Icons.family_restroom_rounded;
    return Icons.person_rounded;
  }

  Color _getColorRelacion(String relacion) {
    final r = relacion.toLowerCase();
    if (r.contains('doc') || r.contains('med') || r.contains('méd')) return Colors.blue.shade700;
    if (r.contains('padre') || r.contains('madre') || r.contains('hij') || r.contains('fam')) return Colors.green.shade700;
    return AppColors.text;
  }

  Color _getColorBordeRelacion(String relacion) {
    final r = relacion.toLowerCase();
    if (r.contains('doc') || r.contains('med') || r.contains('méd')) return Colors.blue.shade200;
    if (r.contains('padre') || r.contains('madre') || r.contains('hij') || r.contains('fam')) return Colors.green.shade200;
    return Colors.grey.shade300;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.contact_phone_rounded, color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(text: const TextSpan(style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: -0.5), children: [TextSpan(text: 'ARES ', style: TextStyle(color: AppColors.primary)), TextSpan(text: 'Contactos', style: TextStyle(color: AppColors.text))])),
                    const Text('Red de emergencia', style: TextStyle(color: AppColors.mutedText, fontSize: 13)),
                  ],
                ),
              ],
            ),
            IconButton(icon: const Icon(Icons.refresh, color: AppColors.primary), onPressed: _cargarContactos),
          ],
        ),
        const SizedBox(height: 20),
        const Text('Contactos de Alerta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text)),
        const SizedBox(height: 12),

        // TARJETA FIJA (SAME)
        _buildContactoCard(
          titulo: 'Servicio de Emergencias', nombre: 'Ambulancia (SAME)', especialidad: 'Atención médica', numero: '107',
          icono: Icons.emergency_share_rounded, colorBorde: AppColors.danger.withValues(alpha: 0.4), colorIcono: AppColors.danger, esUrgencia: true, id: null,
        ),
        const SizedBox(height: 16),

        // CONTACTOS SQLITE
        if (_cargando) const Center(child: CircularProgressIndicator(color: AppColors.primary))
        else if (_contactos.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(24.0), child: Text('No hay contactos registrados.', style: TextStyle(color: AppColors.mutedText))))
        else ..._contactos.map((c) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildContactoCard(
              titulo: c.vinculo, nombre: c.nombre, especialidad: 'Contacto guardado localmente', numero: c.telefono,
              icono: _getIconoRelacion(c.vinculo), colorBorde: _getColorBordeRelacion(c.vinculo), colorIcono: _getColorRelacion(c.vinculo), id: c.id,
            ),
          );
        }),

        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _mostrarDialogoAgregarContacto,
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary, width: 1.5), minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          icon: const Icon(Icons.add_rounded),
          label: const Text('AGREGAR CONTACTO NUEVO', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // --- ACÁ AGREGAMOS EL BOTÓN DE ELIMINAR ---
  Widget _buildContactoCard({
    required String titulo, required String nombre, required String especialidad, required String numero,
    required IconData icono, required Color colorBorde, required Color colorIcono, bool esUrgencia = false, required int? id,
  }) {
    return Card(
      elevation: 0, color: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: esUrgencia ? AppColors.danger.withValues(alpha: 0.3) : colorBorde, width: esUrgencia ? 2 : 1)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icono, color: colorIcono, size: 20),
                    const SizedBox(width: 8),
                    Text(titulo.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colorIcono, letterSpacing: 0.5)),
                  ],
                ),
                // Botón Tacho de Basura (solo si no es Urgencia y tiene un ID válido)
                if (!esUrgencia && id != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 22, color: AppColors.mutedText),
                    onPressed: () => _confirmarEliminacion(id, nombre),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(nombre, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text)),
            const SizedBox(height: 2),
            Text(especialidad, style: const TextStyle(fontSize: 13, color: AppColors.mutedText)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _hacerLlamada(numero),
                style: ElevatedButton.styleFrom(backgroundColor: esUrgencia ? AppColors.danger : Colors.white, foregroundColor: esUrgencia ? Colors.white : AppColors.text, elevation: 0, side: esUrgencia ? BorderSide.none : BorderSide(color: Colors.grey.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)),
                icon: const Icon(Icons.call),
                label: Text(esUrgencia ? 'LLAMAR AHORA' : 'Llamar al $numero', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}