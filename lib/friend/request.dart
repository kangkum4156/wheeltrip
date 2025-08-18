import 'package:cloud_firestore/cloud_firestore.dart';

class GuardianRequest {
  final String from;
  final String to;
  final String status; // 'pending' | 'accepted' | 'declined'
  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final DateTime? declinedAt;

  GuardianRequest({
    required this.from,
    required this.to,
    required this.status,
    this.createdAt,
    this.acceptedAt,
    this.declinedAt,
  });

  factory GuardianRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    DateTime? _ts(Timestamp? t) => t == null ? null : t.toDate();
    return GuardianRequest(
      from: (d['from'] ?? '').toString(),
      to: (d['to'] ?? '').toString(),
      status: (d['status'] ?? '').toString(),
      createdAt: _ts(d['createdAt']),
      acceptedAt: _ts(d['acceptedAt']),
      declinedAt: _ts(d['declinedAt']),
    );
  }
}
