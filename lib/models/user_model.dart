class User {
  final String id;
  final String? username;
  final String name;
  final String email;
  final String role;
  final String? className;
  final String? section;
  final String? specialization;
  final String? college;
  final String? token;

  User({
    required this.id,
    this.username,
    required this.name,
    required this.email,
    required this.role,
    this.className,
    this.section,
    this.specialization,
    this.college,
    this.token,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['_id'] ?? '',
      username: json['username'],
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'student',
      className: json['className'],
      section: json['section'],
      specialization: json['specialization'],
      college: json['college'],
      token: json['token'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'name': name,
      'email': email,
      'role': role,
      'className': className,
      'section': section,
      'specialization': specialization,
      'college': college,
      'token': token,
    };
  }
}