class Contacto {
  int? id;
  String nombre;
  String vinculo;
  String telefono;

  Contacto({
    this.id, 
    required this.nombre, 
    required this.vinculo, 
    required this.telefono
  });

  // Convertir a Map para insertar en SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'vinculo': vinculo,
      'telefono': telefono,
    };
  }

  // Convertir de Map a Objeto Dart al leer de SQLite
  factory Contacto.fromMap(Map<String, dynamic> map) {
    return Contacto(
      id: map['id'],
      nombre: map['nombre'],
      vinculo: map['vinculo'],
      telefono: map['telefono'],
    );
  }
}