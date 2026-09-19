class StaffAuthUser {
  const StaffAuthUser({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.role,
    required this.isActive,
  });

  final String userId;
  final String username;
  final String displayName;
  final String role;
  final bool isActive;

  bool get isStaff => role == 'STAFF';

  factory StaffAuthUser.fromJson(Map<String, dynamic> json) {
    final userId = (json['userId'] as String?)?.trim() ?? '';
    final username = (json['username'] as String?)?.trim() ?? '';
    final displayName = (json['displayName'] as String?)?.trim() ?? '';
    final role = (json['role'] as String?)?.trim() ?? '';
    final isActive = json['isActive'] as bool? ?? true;

    if (userId.isEmpty ||
        username.isEmpty ||
        displayName.isEmpty ||
        role.isEmpty) {
      throw const FormatException('Authentication user payload is incomplete.');
    }

    return StaffAuthUser(
      userId: userId,
      username: username,
      displayName: displayName,
      role: role,
      isActive: isActive,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'displayName': displayName,
      'role': role,
      'isActive': isActive,
    };
  }
}
