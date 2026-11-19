import 'package:cloud_firestore/cloud_firestore.dart';

class Group {
  Group({required this.id, required this.name, required this.ownerId, required this.members});

  final String id;
  final String name;
  final String ownerId;

  /// uid -> nombre para mostrar
  final Map<String, String> members;

  factory Group.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Group(
      id: doc.id,
      name: d['name'] as String? ?? '',
      ownerId: d['ownerId'] as String? ?? '',
      members: Map<String, String>.from(d['memberNames'] as Map? ?? {}),
    );
  }
}

class Invite {
  Invite({required this.id, required this.groupId, required this.groupName, required this.invitedBy});

  final String id;
  final String groupId;
  final String groupName;
  final String invitedBy;

  factory Invite.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Invite(
      id: doc.id,
      groupId: d['groupId'] as String? ?? '',
      groupName: d['groupName'] as String? ?? '',
      invitedBy: d['invitedByName'] as String? ?? '',
    );
  }
}

enum PayStatus { pending, review, paid }

PayStatus _statusFrom(String? s) => PayStatus.values.firstWhere((e) => e.name == s, orElse: () => PayStatus.pending);

class Split {
  Split({required this.uid, required this.amountCents, required this.percent, required this.status, this.proofUrl});

  final String uid;
  final int amountCents;
  final double percent;
  final PayStatus status;
  final String? proofUrl;
}

class Bill {
  Bill({
    required this.id,
    required this.groupId,
    required this.concept,
    required this.totalCents,
    required this.dueDate,
    required this.payerId,
    required this.payerName,
    required this.month,
    required this.splits,
    this.invoiceUrl,
  });

  final String id;
  final String groupId;
  final String concept;
  final int totalCents;
  final DateTime dueDate;
  final String payerId;
  final String payerName;
  final String month; // yyyy-MM
  final List<Split> splits;
  final String? invoiceUrl;

  /// Quien registra la cuenta es quien la pagó al proveedor; los demás le deben.
  Split? splitOf(String uid) {
    for (final s in splits) {
      if (s.uid == uid) return s;
    }
    return null;
  }

  factory Bill.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    final raw = Map<String, dynamic>.from(d['splits'] as Map? ?? {});
    final splits = raw.entries.map((e) {
      final v = Map<String, dynamic>.from(e.value as Map);
      return Split(
        uid: e.key,
        amountCents: (v['amountCents'] as num).toInt(),
        percent: (v['percent'] as num).toDouble(),
        status: _statusFrom(v['status'] as String?),
        proofUrl: v['proofUrl'] as String?,
      );
    }).toList();
    return Bill(
      id: doc.id,
      groupId: d['groupId'] as String,
      concept: d['concept'] as String? ?? '',
      totalCents: (d['totalCents'] as num).toInt(),
      dueDate: (d['dueDate'] as Timestamp).toDate(),
      payerId: d['payerId'] as String,
      payerName: d['payerName'] as String? ?? '',
      month: d['month'] as String? ?? '',
      splits: splits,
      invoiceUrl: d['invoiceUrl'] as String?,
    );
  }
}
