class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.phone,
    required this.role,
  });

  final String uid;
  final String displayName;
  final String email;
  final String phone;
  final String role;

  bool get isAdmin => role == 'admin';

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'displayName': displayName,
        'email': email,
        'phone': phone,
        'role': role,
      };
}
