class User {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? phone;
  final String role;
  final List<String> roles;
  final String? avatarUrl;
  final bool isVerified;
  final String? bio;
  final String? location;
  final String? job;
  final String? dreamDestination;
  final String? school;
  final List<String> languages;
  final int? joinedYear;
  final String status;
  final String? hostApplicationStatus;
  final bool isHostVerified;

  const User({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.role = 'guest',
    this.roles = const [],
    this.avatarUrl,
    this.isVerified = false,
    this.bio,
    this.location,
    this.job,
    this.dreamDestination,
    this.school,
    this.languages = const [],
    this.joinedYear,
    this.status = 'active',
    this.hostApplicationStatus,
    this.isHostVerified = false,
  });

  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isNotEmpty ? name : email;
  }

  String? get phoneNumber => phone;

  static bool _isApprovedHostToken(String raw) {
    final normalized = raw.trim().toLowerCase();
    return normalized == 'host' ||
        normalized == 'host_verified' ||
        normalized == 'host verified';
  }

  static bool _isNewHostToken(String raw) {
    final normalized = raw.trim().toLowerCase();
    return normalized == 'host new' ||
        normalized == 'host_new' ||
        normalized == 'host-new';
  }

  bool get isHost =>
      _isApprovedHostToken(role) || roles.any(_isApprovedHostToken);

  bool get isNewHost =>
      !isHost && (_isNewHostToken(role) || roles.any(_isNewHostToken));

  bool get isAdmin =>
      role.trim().toLowerCase() == 'admin' ||
      roles.any((r) => r.trim().toLowerCase() == 'admin');

  static ({String firstName, String lastName}) splitFullName(String rawName) {
    final parts = rawName
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return (firstName: '', lastName: '');
    }
    if (parts.length == 1) {
      return (firstName: parts.first, lastName: '');
    }
    final lastName = parts.last;
    final firstName = parts.sublist(0, parts.length - 1).join(' ');
    return (firstName: firstName, lastName: lastName);
  }

  static String normalizeRole(String? rawRole, List<String> roles) {
    final allTokens = <String>[
      if (rawRole != null && rawRole.trim().isNotEmpty)
        rawRole.trim().toLowerCase(),
      ...roles.map((r) => r.trim().toLowerCase()).where((r) => r.isNotEmpty),
    ];
    if (allTokens.contains('admin')) return 'admin';

    if (allTokens.any(_isApprovedHostToken)) {
      return 'host';
    }
    if (allTokens.any(_isNewHostToken)) {
      return 'host new';
    }
    return 'guest';
  }

  factory User.fromJson(Map<String, dynamic> json) {
    final idVal = json['id'] ?? json['userId'];
    final profile = json['profile'] is Map<String, dynamic>
        ? json['profile'] as Map<String, dynamic>
        : <String, dynamic>{};

    var firstName = json['firstName']?.toString().trim() ?? '';
    var lastName = json['lastName']?.toString().trim() ?? '';
    if (firstName.isEmpty && lastName.isEmpty) {
      final combinedName =
          (json['fullName'] ?? json['name'] ?? profile['displayName'])
                  ?.toString()
                  .trim() ??
              '';
      if (combinedName.isNotEmpty) {
        final split = splitFullName(combinedName);
        firstName = split.firstName;
        lastName = split.lastName;
      }
    }

    final rolesList = <String>[];
    if (json['roles'] is List) {
      for (final r in json['roles'] as List<dynamic>) {
        if (r != null && r.toString().trim().isNotEmpty) {
          rolesList.add(r.toString().trim());
        }
      }
    }

    final normalizedRole = normalizeRole(json['role']?.toString(), rolesList);

    final rawLanguages = profile['languages'] ?? json['languages'];
    final languagesList = <String>[];
    if (rawLanguages is List) {
      for (final lang in rawLanguages) {
        if (lang != null && lang.toString().trim().isNotEmpty) {
          languagesList.add(lang.toString().trim());
        }
      }
    }

    return User(
      id: idVal?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      firstName: firstName,
      lastName: lastName,
      phone: (json['phone'] ?? json['phoneNumber'])?.toString(),
      role: normalizedRole,
      roles: rolesList,
      avatarUrl: (json['avatarUrl'] ?? profile['avatarUrl'])?.toString(),
      isVerified: (json['isVerified'] as bool?) ??
          (profile['isVerified'] as bool?) ??
          (json['emailVerifiedAt'] != null),
      bio: (profile['bio'] ?? json['bio'])?.toString(),
      location: (profile['location'] ?? json['location'])?.toString(),
      job: (profile['job'] ?? json['job'])?.toString(),
      dreamDestination:
          (profile['dreamDestination'] ?? json['dreamDestination'])?.toString(),
      school: (profile['school'] ?? json['school'])?.toString(),
      languages: languagesList,
      joinedYear: (json['joinedYear'] as num?)?.toInt() ??
          (profile['joinedYear'] as num?)?.toInt(),
      status: json['status']?.toString() ?? 'active',
      hostApplicationStatus:
          (json['hostApplicationStatus'] ?? json['host_application_status'])
              ?.toString(),
      isHostVerified: (json['isHostVerified'] as bool?) ??
          (json['is_host_verified'] == 1) || (json['is_host_verified'] == true),
    );
  }

  User copyWith({
    String? firstName,
    String? lastName,
    String? phone,
    String? role,
    List<String>? roles,
    String? avatarUrl,
    bool? isVerified,
    String? bio,
    String? location,
    String? job,
    String? dreamDestination,
    String? school,
    List<String>? languages,
    int? joinedYear,
    String? status,
    String? hostApplicationStatus,
    bool? isHostVerified,
  }) {
    return User(
      id: id,
      email: email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      roles: roles ?? this.roles,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isVerified: isVerified ?? this.isVerified,
      bio: bio ?? this.bio,
      location: location ?? this.location,
      job: job ?? this.job,
      dreamDestination: dreamDestination ?? this.dreamDestination,
      school: school ?? this.school,
      languages: languages ?? this.languages,
      joinedYear: joinedYear ?? this.joinedYear,
      status: status ?? this.status,
      hostApplicationStatus:
          hostApplicationStatus ?? this.hostApplicationStatus,
      isHostVerified: isHostVerified ?? this.isHostVerified,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'fullName': fullName,
      'phone': phone,
      'role': role,
      'roles': roles,
      'avatarUrl': avatarUrl,
      'isVerified': isVerified,
      'bio': bio,
      'location': location,
      'job': job,
      'dreamDestination': dreamDestination,
      'school': school,
      'languages': languages,
      'joinedYear': joinedYear,
      'status': status,
      'hostApplicationStatus': hostApplicationStatus,
      'isHostVerified': isHostVerified,
    };
  }
}
