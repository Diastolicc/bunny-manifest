class ChatGroup {
  final String id;
  final String name;
  final String groupPhotoUrl;
  final List<String> memberIds;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final Map<String, int>? unreadByUser;
  final bool isActive;
  final String? hostUserId;
  final String? hostName;
  final String? partyId;

  const ChatGroup({
    required this.id,
    required this.name,
    required this.groupPhotoUrl,
    required this.memberIds,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
    this.unreadByUser,
    required this.isActive,
    this.hostUserId,
    this.hostName,
    this.partyId,
  });

  ChatGroup copyWith({
    String? id,
    String? name,
    String? groupPhotoUrl,
    List<String>? memberIds,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    Map<String, int>? unreadByUser,
    bool? isActive,
    String? hostUserId,
    String? hostName,
    String? partyId,
  }) {
    return ChatGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      groupPhotoUrl: groupPhotoUrl ?? this.groupPhotoUrl,
      memberIds: memberIds ?? this.memberIds,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      unreadByUser: unreadByUser ?? this.unreadByUser,
      isActive: isActive ?? this.isActive,
      hostUserId: hostUserId ?? this.hostUserId,
      hostName: hostName ?? this.hostName,
      partyId: partyId ?? this.partyId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'groupPhotoUrl': groupPhotoUrl,
      'memberIds': memberIds,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime.toIso8601String(),
      'unreadCount': unreadCount,
      'unreadByUser': unreadByUser,
      'isActive': isActive,
      'hostUserId': hostUserId,
      'hostName': hostName,
      'partyId': partyId,
    };
  }

  factory ChatGroup.fromJson(Map<String, dynamic> json) {
    return ChatGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      groupPhotoUrl: json['groupPhotoUrl'] as String,
      memberIds: List<String>.from(json['memberIds']),
      lastMessage: json['lastMessage'] as String,
      lastMessageTime: DateTime.parse(json['lastMessageTime'] as String),
      unreadCount: json['unreadCount'] as int,
        unreadByUser: (json['unreadByUser'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, v as int)),
      isActive: json['isActive'] as bool,
      hostUserId: json['hostUserId'] as String?,
      hostName: json['hostName'] as String?,
      partyId: json['partyId'] as String?,
    );
  }
}
