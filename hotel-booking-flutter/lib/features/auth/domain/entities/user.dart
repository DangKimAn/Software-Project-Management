class User {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? phone;
  final String role;
  final String? avatarUrl;
  final bool isVerified;

  const User({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.role = 'guest',
    this.avatarUrl,
    this.isVerified = false,
  });

  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isNotEmpty ? name : email;
  }

  bool get isHost => role == 'host';
  bool get isAdmin => role == 'admin';

  factory User.fromJson(Map<String, dynamic> json) {
    final idVal = json['id'] ?? json['userId'];
    return User(
      id: idVal?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      firstName: json['firstName']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? '',
      phone: json['phone']?.toString() ?? json['phoneNumber']?.toString(),
      role: json['role']?.toString() ?? 'guest',
      avatarUrl: json['avatarUrl']?.toString(),
      isVerified: json['isVerified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'role': role,
      'avatarUrl': avatarUrl,
      'isVerified': isVerified,
    };
  }
}
