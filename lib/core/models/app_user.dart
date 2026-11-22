// Developed by @Ramana Code Softwares

class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.active,
  });

  final String uid;
  final String name;
  final String email;
  final String role;
  final bool active;

  bool get isAdmin => role == 'admin';

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    return AppUser(
      uid: uid,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      role: map['role'] as String? ?? 'student',
      active: map['active'] as bool? ?? false,
    );
  }
}
