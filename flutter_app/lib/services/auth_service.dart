import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }
  
  static Future<User?> signIn(String email, String password) async {
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } catch (e) {
      rethrow;
    }
  }
  
  static Future<User?> signUp(String email, String password) async {
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } catch (e) {
      rethrow;
    }
  }
}