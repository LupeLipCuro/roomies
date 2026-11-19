import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/models.dart';

class DataService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  // ---------- Perfil ----------

  Future<Map<String, dynamic>?> userProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data();
  }

  Future<void> updatePaymentInfo(String uid, {String? payInfo, String? phone}) {
    return _db.collection('users').doc(uid).set({
      if (payInfo != null) 'payInfo': payInfo.trim(),
      if (phone != null) 'phone': phone.trim(),
    }, SetOptions(merge: true));
  }

  // ---------- Grupos e invitaciones ----------

  /// El grupo al que pertenece la persona (se usa un solo grupo por persona).
  Stream<Group?> myGroup(String uid) {
    return _db.collection('groups').where('memberIds', arrayContains: uid).limit(1).snapshots().map(
          (s) => s.docs.isEmpty ? null : Group.fromDoc(s.docs.first),
        );
  }

  Future<void> createGroup(String name, User user) async {
    final displayName = user.displayName ?? user.email ?? 'Roomie';
    await _db.collection('groups').add({
      'name': name.trim(),
      'ownerId': user.uid,
      'memberIds': [user.uid],
      'memberNames': {user.uid: displayName},
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// El id del documento es predecible para que las reglas de seguridad puedan
  /// comprobar que existe una invitación para el correo de quien se une.
  Future<void> inviteByEmail({required Group group, required String email, required User by}) {
    final e = email.trim().toLowerCase();
    return _db.collection('invites').doc('${group.id}_$e').set({
      'email': e,
      'groupId': group.id,
      'groupName': group.name,
      'invitedBy': by.uid,
      'invitedByName': by.displayName ?? by.email ?? '',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Invite>> pendingInvites(String email) {
    return _db
        .collection('invites')
        .where('email', isEqualTo: email.toLowerCase())
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.docs.map(Invite.fromDoc).toList());
  }

  Future<void> acceptInvite(Invite invite, User user) async {
    final displayName = user.displayName ?? user.email ?? 'Roomie';
    final batch = _db.batch();
    batch.update(_db.collection('groups').doc(invite.groupId), {
      'memberIds': FieldValue.arrayUnion([user.uid]),
      'memberNames.${user.uid}': displayName,
    });
    batch.update(_db.collection('invites').doc(invite.id), {'status': 'accepted'});
    await batch.commit();
  }

  // ---------- Cuentas ----------

  Stream<List<Bill>> billsOfGroup(String groupId) {
    return _db.collection('bills').where('groupId', isEqualTo: groupId).snapshots().map((s) {
      final list = s.docs.map(Bill.fromDoc).toList();
      list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      return list;
    });
  }

  Stream<Bill?> bill(String id) {
    return _db.collection('bills').doc(id).snapshots().map((d) => d.exists ? Bill.fromDoc(d) : null);
  }

  /// [amounts] y [percents] tienen el mismo orden que [memberIds].
  /// Quien registra la cuenta ya la pagó, así que su parte queda como pagada.
  Future<void> createBill({
    required Group group,
    required User payer,
    required String concept,
    required int totalCents,
    required DateTime dueDate,
    required List<String> memberIds,
    required List<int> amounts,
    required List<double> percents,
    File? invoice,
  }) async {
    final ref = _db.collection('bills').doc();
    String? invoiceUrl;
    if (invoice != null) {
      final sref = _storage.ref('bills/${group.id}/${ref.id}/invoice.jpg');
      await sref.putFile(invoice);
      invoiceUrl = await sref.getDownloadURL();
    }
    final splits = <String, dynamic>{};
    for (var i = 0; i < memberIds.length; i++) {
      final uid = memberIds[i];
      splits[uid] = {
        'amountCents': amounts[i],
        'percent': percents[i],
        'status': uid == payer.uid ? 'paid' : 'pending',
      };
    }
    await ref.set({
      'groupId': group.id,
      'concept': concept.trim(),
      'totalCents': totalCents,
      'dueDate': Timestamp.fromDate(dueDate),
      'month': '${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}',
      'payerId': payer.uid,
      'payerName': payer.displayName ?? payer.email ?? '',
      'invoiceUrl': invoiceUrl,
      'splits': splits,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------- Pagos ----------

  Future<void> uploadProof({required Bill bill, required String uid, required File file}) async {
    final sref = _storage.ref('proofs/${bill.id}/$uid.jpg');
    await sref.putFile(file);
    final url = await sref.getDownloadURL();
    await _db.collection('bills').doc(bill.id).update({
      'splits.$uid.status': 'review',
      'splits.$uid.proofUrl': url,
    });
  }

  Future<void> confirmPayment(String billId, String uid) {
    return _db.collection('bills').doc(billId).update({'splits.$uid.status': 'paid'});
  }

  /// Rechaza el comprobante: la persona vuelve a "pendiente" y debe subir otro.
  Future<void> rejectProof(String billId, String uid) {
    return _db.collection('bills').doc(billId).update({
      'splits.$uid.status': 'pending',
      'splits.$uid.proofUrl': FieldValue.delete(),
    });
  }
}
