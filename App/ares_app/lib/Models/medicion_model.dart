class MedicionModel {
  final int? id; // ID autoincremental de SQLite
  final String fechaHora; // Fecha y hora en formato ISO8601
  final double valorEcg; // Voltaje medido
  final int pulso; // BPM
  final int intervaloRr; // Milisegundos entre latidos
  final String estadoRitmo; // "normal", "arritmia", etc.
  final int sincronizado; // 0 = pendiente, 1 = enviado a SQL Server

  MedicionModel({
    this.id,
    required this.fechaHora,
    required this.valorEcg,
    required this.pulso,
    required this.intervaloRr,
    required this.estadoRitmo,
    this.sincronizado = 0,
  });

  // Convierte el objeto a Map para guardarlo en SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fechaHora': fechaHora,
      'valorEcg': valorEcg,
      'pulso': pulso,
      'intervaloRr': intervaloRr,
      'estadoRitmo': estadoRitmo,
      'sincronizado': sincronizado,
    };
  }

  // Crea un objeto a partir de una fila devuelta por SQLite
  factory MedicionModel.fromMap(Map<String, dynamic> map) {
    return MedicionModel(
      id: map['id'] as int?,
      fechaHora: map['fechaHora'] as String,
      valorEcg: (map['valorEcg'] as num).toDouble(),
      pulso: map['pulso'] as int,
      intervaloRr: map['intervaloRr'] as int,
      estadoRitmo: map['estadoRitmo'] as String,
      sincronizado: map['sincronizado'] as int? ?? 0,
    );
  }
}
