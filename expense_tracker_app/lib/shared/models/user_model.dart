class UserModel {
  final String id;
  final String email;
  final String? displayName;
  final String defaultCurrency;
  final String? authProvider;
  final DateTime? createdAt;

  const UserModel({
    required this.id,
    required this.email,
    this.displayName,
    this.defaultCurrency = 'USD',
    this.authProvider,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'].toString(),
      email: json['email'] as String,
      displayName: json['displayName'] as String? ??
          json['display_name'] as String?,
      defaultCurrency: json['defaultCurrency'] as String? ??
          json['default_currency'] as String? ??
          'USD',
      authProvider: json['authProvider'] as String? ??
          json['auth_provider'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString())
              : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'defaultCurrency': defaultCurrency,
      };

  UserModel copyWith({
    String? displayName,
    String? defaultCurrency,
  }) {
    return UserModel(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      authProvider: authProvider,
      createdAt: createdAt,
    );
  }
}
