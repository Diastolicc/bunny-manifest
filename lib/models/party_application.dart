class PartyApplication {
  final String id;
  final String partyId;
  final String userId;
  final String status; // pending, approved, rejected

  const PartyApplication({
    required this.id,
    required this.partyId,
    required this.userId,
    required this.status,
  });

  PartyApplication copyWith({String? status}) => PartyApplication(
        id: id,
        partyId: partyId,
        userId: userId,
        status: status ?? this.status,
      );

  factory PartyApplication.fromJson(Map<String, dynamic> json, String id) {
    return PartyApplication(
      id: id,
      partyId: json['partyId'] as String,
      userId: json['userId'] as String,
      status: (json['status'] as String?) ?? 'pending',
    );
  }

  Map<String, dynamic> toJson() => {
        'partyId': partyId,
        'userId': userId,
        'status': status,
      };
}
