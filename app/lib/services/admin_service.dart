import 'package:cloud_firestore/cloud_firestore.dart';

/// Admin-only Firestore access (rules require the `admin` custom claim).
class AdminService {
  final FirebaseFirestore db;
  AdminService(this.db);

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> pendingReviews() async =>
      (await db.collection('review').where('status', isEqualTo: 'pending').limit(100).get()).docs;

  Future<void> decide(String key, String decision, {Map<String, dynamic>? editedRow, String? by}) =>
      db.collection('review').doc(key).set({
        'decision': decision,
        'editedRow': ?editedRow,
        'decidedBy': by,
        'decidedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> partners() async =>
      (await db.collection('partners').limit(200).get()).docs;

  Future<void> updatePartner(String uid, Map<String, dynamic> data) =>
      db.collection('partners').doc(uid).set(data, SetOptions(merge: true));

  Future<Map<String, dynamic>> config(String doc) async => (await db.collection('config').doc(doc).get()).data() ?? {};

  Future<void> setConfig(String doc, Map<String, dynamic> data) => db.collection('config').doc(doc).set(data);

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> runs() async =>
      (await db.collection('runs').orderBy('startedAt', descending: true).limit(20).get()).docs;

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> reports() async =>
      (await db.collection('reports').orderBy('createdAt', descending: true).limit(50).get()).docs;

  Future<void> deleteReport(String id) => db.collection('reports').doc(id).delete();
}
