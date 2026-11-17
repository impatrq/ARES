import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
// ¡Importante importar el nuevo modelo de contactos!
import '../Models/medicion_model.dart';
import '../Models/contacto.dart'; // O el nombre del archivo de tu clase Contacto

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('ares_cardiac.db'); // Unifica todo en el mismo archivo db
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  // Se agregan ambas tablas en el onCreate
  Future _createDB(Database db, int version) async {
    // 1. Tabla de Mediciones (la que ya tenías)
    await db.execute('''
      CREATE TABLE mediciones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fechaHora TEXT NOT NULL,
        valorEcg REAL NOT NULL,
        pulso INTEGER NOT NULL,
        intervaloRr INTEGER NOT NULL,
        estadoRitmo TEXT NOT NULL,
        sincronizado INTEGER NOT NULL DEFAULT 0
      )
    ''');
    
    // 2. Tabla de Contactos (¡NUEVA!)
    await db.execute('''
      CREATE TABLE contactos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        vinculo TEXT NOT NULL,
        telefono TEXT NOT NULL
      )
    ''');
  }

  // ----------------------------------------------------
  // MÉTODOS PARA MEDICIONES (Ya los tenías)
  // ----------------------------------------------------
  Future<int> insertarMedicion(MedicionModel medicion) async {
    final db = await instance.database;
    return await db.insert('mediciones', medicion.toMap());
  }

  Future<List<MedicionModel>> obtenerHistorial() async {
    final db = await instance.database;
    final result = await db.query('mediciones', orderBy: 'id DESC');
    return result.map((json) => MedicionModel.fromMap(json)).toList();
  }

  Future<int> vaciarHistorial() async {
    final db = await instance.database;
    return await db.delete('mediciones');
  }

  // ----------------------------------------------------
  // MÉTODOS PARA CONTACTOS (¡NUEVOS!)
  // ----------------------------------------------------
  
  // Guardar un contacto nuevo
  Future<int> insertarContacto(Contacto contacto) async {
    final db = await instance.database;
    return await db.insert('contactos', contacto.toMap());
  }

  // Leer todos los contactos guardados
  Future<List<Contacto>> obtenerContactos() async {
    final db = await instance.database;
    final result = await db.query('contactos'); // Leer la tabla completa
    return result.map((json) => Contacto.fromMap(json)).toList();
  }

  // Borrar un contacto específico (para cuando quieras eliminarlos de la lista)
  Future<int> eliminarContacto(int id) async {
    final db = await instance.database;
    return await db.delete('contactos', where: 'id = ?', whereArgs: [id]);
  }
}