class Message {
  final String id;
  final String chatGroupId;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final List<String> readBy; // List of user IDs who have read this message
  final String? type; // 'party_invite', 'system', etc.
  final String? partyId;
  final String? partyTitle;
  final String? inviteCode;

  const Message({
    required this.id,
    required this.chatGroupId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    this.readBy = const [],
    this.type,
    this.partyId,
    this.partyTitle,
    this.inviteCode,
  });

  Message copyWith({
    String? id,
    String? chatGroupId,
    String? senderId,
    String? senderName,
    String? text,
    DateTime? timestamp,
    List<String>? readBy,
    String? type,
    String? partyId,
    String? partyTitle,
    String? inviteCode,
  }) {
    return Message(
      id: id ?? this.id,
      chatGroupId: chatGroupId ?? this.chatGroupId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      readBy: readBy ?? this.readBy,
      type: type ?? this.type,
      partyId: partyId ?? this.partyId,
      partyTitle: partyTitle ?? this.partyTitle,
      inviteCode: inviteCode ?? this.inviteCode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chatGroupId': chatGroupId,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'readBy': readBy,
      'type': type,
      'partyId': partyId,
      'partyTitle': partyTitle,
      'inviteCode': inviteCode,
    };
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      chatGroupId: json['chatGroupId'] as String,
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String,
      text: json['text'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      readBy: List<String>.from(json['readBy'] as List<dynamic>? ?? []),
      type: json['type'] as String?,
      partyId: json['partyId'] as String?,
      partyTitle: json['partyTitle'] as String?,
      inviteCode: json['inviteCode'] as String?,
    );
  }
}
