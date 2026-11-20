/// Thực thể miền đại diện cho người dùng hệ thống (Khách hàng, Chủ nhà, Chủ nhà mới đăng ký hoặc Quản trị viên).
class User {
  /// Mã định danh duy nhất của người dùng.
  final String id;

  /// Địa chỉ email đăng nhập chính thức.
  final String email;

  /// Họ và tên đệm của người dùng.
  final String firstName;

  /// Tên gọi chính của người dùng.
  final String lastName;

  /// Số điện thoại liên hệ của người dùng.
  final String? phone;

  /// Mã vai trò chính đã được chuẩn hóa (`'guest'`, `'host'`, `'host new'`, `'admin'`).
  final String role;

  /// Danh sách toàn bộ các mã vai trò được gán cho tài khoản trên máy chủ.
  final List<String> roles;

  /// Đường dẫn ảnh đại diện của người dùng.
  final String? avatarUrl;

  /// Cho biết địa chỉ email hoặc danh tính cơ bản của tài khoản đã được xác minh hay chưa.
  final bool isVerified;

  /// Đoạn giới thiệu bản thân trên trang hồ sơ cá nhân.
  final String? bio;

  /// Tỉnh/thành phố hoặc khu vực sinh sống hiện tại.
  final String? location;

  /// Nghề nghiệp hoặc lĩnh vực công việc của người dùng.
  final String? job;

  /// Điểm đến mơ ước chia sẻ trên hồ sơ cộng đồng.
  final String? dreamDestination;

  /// Trường học đã hoặc đang theo học.
  final String? school;

  /// Danh sách các ngôn ngữ giao tiếp mà người dùng sử dụng.
  final List<String> languages;

  /// Năm gia nhập nền tảng The Palm Villa.
  final int? joinedYear;

  /// Trạng thái hoạt động của tài khoản (`'active'`, `'locked'`, ...).
  final String status;

  /// Trạng thái xét duyệt hồ sơ đăng ký trở thành Chủ nhà (nếu có).
  final String? hostApplicationStatus;

  /// Cho biết hồ sơ pháp lý/danh tính Chủ nhà đã được Quản trị viên xác minh hay chưa.
  final bool isHostVerified;

  /// Khởi tạo thực thể `User`.
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

  /// Họ và tên đầy đủ kết hợp từ `firstName` và `lastName`, tự động lùi về `email` nếu tên trống.
  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isNotEmpty ? name : email;
  }

  /// Bí danh truy cập số điện thoại `phone`.
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

  /// Cho biết tài khoản đã được phê duyệt quyền Chủ nhà chính thức hay chưa.
  bool get isHost =>
      _isApprovedHostToken(role) || roles.any(_isApprovedHostToken);

  /// Cho biết tài khoản đang ở trạng thái Chủ nhà mới chờ hoàn tất/duyệt hồ sơ hay không.
  bool get isNewHost =>
      !isHost && (_isNewHostToken(role) || roles.any(_isNewHostToken));

  /// Cho biết tài khoản có quyền Quản trị viên hệ thống (`'admin'`) hay không.
  bool get isAdmin =>
      role.trim().toLowerCase() == 'admin' ||
      roles.any((r) => r.trim().toLowerCase() == 'admin');

  /// Tách chuỗi họ tên đầy đủ `rawName` thành cặp `(firstName, lastName)` chuẩn hóa khoảng trắng.
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

  /// Phân giải vai trò ưu tiên cao nhất từ `rawRole` và mảng `roles` theo thứ tự: `'admin'` -> `'host'` -> `'host new'` -> `'guest'`.
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

  /// Giải mã đối tượng JSON từ `/api/auth/me` hoặc `/api/users/me` thành thực thể `User`.
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

  /// Tạo bản sao `User` bất biến với các trường hồ sơ được cập nhật mới.
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

  /// Tuần tự hóa thực thể `User` thành bản đồ JSON phục vụ lưu trữ hoặc truyền tải nội bộ.
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
