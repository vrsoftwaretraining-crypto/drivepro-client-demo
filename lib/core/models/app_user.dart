// Developed by @Ramana Code Softwares

class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.active,
    this.username = '',
    this.mustChangePassword = false,
    this.securityQuestionsSet = false,
  });

  final String uid;
  final String name;
  final String email;
  final String role;
  final bool active;
  final String username;
  final bool mustChangePassword;
  final bool securityQuestionsSet;

  bool get isAdmin => role == 'admin';
  bool get needsSetup => mustChangePassword || !securityQuestionsSet;

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    return AppUser(
      uid: uid,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      role: map['role'] as String? ?? 'student',
      active: map['active'] as bool? ?? false,
      username: map['username'] as String? ?? '',
      mustChangePassword: map['mustChangePassword'] as bool? ?? false,
      securityQuestionsSet: map['securityQuestionsSet'] as bool? ?? false,
    );
  }
}
