class GroupMemberModel {
  final String id;
  final String userId;
  final String role;
  final String? email;
  final String? displayName;
  final DateTime? joinedAt;

  const GroupMemberModel({
    required this.id,
    required this.userId,
    required this.role,
    this.email,
    this.displayName,
    this.joinedAt,
  });

  bool get isOwner => role == 'owner';

  factory GroupMemberModel.fromJson(Map<String, dynamic> json) {
    return GroupMemberModel(
      id: json['id'] as String,
      userId:
          json['userId'] as String? ?? json['user_id'] as String? ?? '',
      role: json['role'] as String? ?? 'member',
      email: json['email'] as String?,
      displayName: json['displayName'] as String? ??
          json['display_name'] as String?,
      joinedAt: json['joinedAt'] != null
          ? DateTime.tryParse(json['joinedAt'].toString())
          : json['joined_at'] != null
              ? DateTime.tryParse(json['joined_at'].toString())
              : null,
    );
  }
}

class BudgetGroupModel {
  final String id;
  final String name;
  final String? description;
  final String currency;
  final String createdBy;
  final String? myRole;
  final List<GroupMemberModel>? members;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const BudgetGroupModel({
    required this.id,
    required this.name,
    this.description,
    this.currency = 'PHP',
    required this.createdBy,
    this.myRole,
    this.members,
    this.createdAt,
    this.updatedAt,
  });

  bool get isOwner => myRole == 'owner';

  factory BudgetGroupModel.fromJson(Map<String, dynamic> json) {
    List<GroupMemberModel>? members;
    if (json['members'] is List) {
      members = (json['members'] as List)
          .map((e) => GroupMemberModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return BudgetGroupModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      currency: json['currency'] as String? ?? 'PHP',
      createdBy: json['createdBy'] as String? ??
          json['created_by'] as String? ??
          '',
      myRole: json['myRole'] as String? ?? json['my_role'] as String?,
      members: members,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString())
              : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : json['updated_at'] != null
              ? DateTime.tryParse(json['updated_at'].toString())
              : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (description != null) 'description': description,
        'currency': currency,
      };
}

class GroupInvitationModel {
  final String id;
  final String groupId;
  final String? groupName;
  final String invitedEmail;
  final String invitedBy;
  final String status;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  const GroupInvitationModel({
    required this.id,
    required this.groupId,
    this.groupName,
    required this.invitedEmail,
    required this.invitedBy,
    required this.status,
    this.createdAt,
    this.expiresAt,
  });

  bool get isPending => status == 'pending';
  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  factory GroupInvitationModel.fromJson(Map<String, dynamic> json) {
    return GroupInvitationModel(
      id: json['id'] as String,
      groupId: json['groupId'] as String? ??
          json['group_id'] as String? ??
          '',
      groupName: json['groupName'] as String? ??
          json['group_name'] as String?,
      invitedEmail: json['invitedEmail'] as String? ??
          json['invited_email'] as String? ??
          '',
      invitedBy: json['invitedBy'] as String? ??
          json['invited_by'] as String? ??
          '',
      status: json['status'] as String? ?? 'pending',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString())
              : null,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'].toString())
          : json['expires_at'] != null
              ? DateTime.tryParse(json['expires_at'].toString())
              : null,
    );
  }
}
