class User {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? className;
  final String? section;
  final String? token;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.className,
    this.section,
    this.token,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'student',
      className: json['className'],
      section: json['section'],
      token: json['token'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'className': className,
      'section': section,
      'token': token,
    };
  }
}