// ESTE ARCHIVO ES UN MARCADOR. Se reemplaza al ejecutar:
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure
//
// Eso genera las claves reales de tu proyecto de Firebase (no son secretas,
// se pueden subir al repositorio). Ver README.md, paso 2.
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'Falta configurar Firebase. Ejecuta "flutterfire configure" (ver README.md).',
    );
  }
}
