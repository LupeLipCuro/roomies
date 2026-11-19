import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Stream<User?> get authState => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> registerWithEmail({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    await cred.user!.updateDisplayName(name.trim());
    await _saveProfile(cred.user!, name: name.trim(), phone: phone);
  }

  Future<void> signInWithEmail(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  /// Google. Devuelve sin error si la persona cancela la ventana.
  Future<void> signInWithGoogle() async {
    final account = await GoogleSignIn().signIn();
    if (account == null) return;
    final auth = await account.authentication;
    final credential = GoogleAuthProvider.credential(accessToken: auth.accessToken, idToken: auth.idToken);
    final result = await _auth.signInWithCredential(credential);
    await _saveProfile(result.user!);
  }

  /// Facebook. Devuelve sin error si la persona cancela.
  Future<void> signInWithFacebook() async {
    final login = await FacebookAuth.instance.login(permissions: ['email', 'public_profile']);
    if (login.status == LoginStatus.cancelled) return;
    if (login.status != LoginStatus.success || login.accessToken == null) {
      throw Exception(login.message ?? 'No se pudo iniciar sesión con Facebook');
    }
    final credential = FacebookAuthProvider.credential(login.accessToken!.tokenString);
    final result = await _auth.signInWithCredential(credential);
    await _saveProfile(result.user!);
  }

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await FacebookAuth.instance.logOut();
    await _auth.signOut();
  }

  /// Crea o completa users/{uid} sin pisar datos que ya existan (p. ej. Yape).
  Future<void> _saveProfile(User user, {String? name, String? phone}) async {
    final data = <String, dynamic>{
      'name': name ?? user.displayName ?? user.email?.split('@').first ?? 'Roomie',
      'email': user.email?.toLowerCase(),
      'photoUrl': user.photoURL,
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
    };
    await _db.collection('users').doc(user.uid).set(data, SetOptions(merge: true));
  }

  /// Mensaje legible para errores de FirebaseAuth.
  static String friendlyError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'Ese correo ya tiene una cuenta. Inicia sesión.';
        case 'account-exists-with-different-credential':
          return 'Ya existe una cuenta con ese correo usando otro método (Google, Facebook o contraseña). Ingresa con el método original.';
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          return 'Correo o contraseña incorrectos.';
        case 'weak-password':
          return 'La contraseña debe tener al menos 8 caracteres.';
        case 'invalid-email':
          return 'El correo no es válido.';
        case 'network-request-failed':
          return 'Sin conexión. Revisa tu internet.';
      }
      return e.message ?? 'Error de autenticación (${e.code}).';
    }
    return e.toString().replaceFirst('Exception: ', '');
  }
}
