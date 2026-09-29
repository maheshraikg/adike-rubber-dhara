import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../firebase_config.dart';

class UserClaims {
  final bool admin, partner;
  final String? sourceId;
  const UserClaims({this.admin = false, this.partner = false, this.sourceId});
  static const none = UserClaims();
}

class AlertDoc {
  final String id, crop, variety, marketId, condition;
  final double value;
  final bool active;
  const AlertDoc(this.id, this.crop, this.variety, this.marketId, this.condition, this.value, this.active);
}

class SubmissionDoc {
  final String id, status;
  final String? text, error;
  final DateTime? createdAt;
  final int rows;
  const SubmissionDoc(this.id, this.status, this.text, this.error, this.createdAt, this.rows);
}

/// All Firebase usage (Spark plan): anonymous + Google auth, Firestore for
/// alerts/reports/submissions/admin, FCM topics. Prices never come from here.
class FirebaseService {
  bool available = false;
  FirebaseFirestore get db => FirebaseFirestore.instance;
  FirebaseAuth get auth => FirebaseAuth.instance;

  Future<void> init() async {
    if (!FirebaseConfig.isConfigured) return;
    try {
      await Firebase.initializeApp(options: FirebaseConfig.options);
      available = true;
    } catch (e) {
      debugPrint('Firebase init failed: $e');
    }
  }

  User? get user => available ? auth.currentUser : null;

  Stream<User?> authChanges() => available ? auth.authStateChanges() : const Stream.empty();

  /// Farmers: silent anonymous sign-in (no login screen), only when needed.
  Future<User> ensureAnonymous() async {
    final u = auth.currentUser;
    if (u != null) return u;
    return (await auth.signInAnonymously()).user!;
  }

  /// Partners/admin: Google sign-in via Firebase Auth (free, no SMS).
  Future<User?> signInWithGoogle() async {
    final provider = GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'});
    final cred = kIsWeb ? await auth.signInWithPopup(provider) : await auth.signInWithProvider(provider);
    return cred.user;
  }

  Future<void> signOut() => auth.signOut();

  Future<UserClaims> claims({bool refresh = true}) async {
    final u = user;
    if (u == null || u.isAnonymous) return UserClaims.none;
    final t = await u.getIdTokenResult(refresh);
    final c = t.claims ?? {};
    return UserClaims(admin: c['admin'] == true, partner: c['partner'] == true, sourceId: c['sourceId'] as String?);
  }

  // ---------------- messaging ----------------
  Future<String?> fcmToken() async {
    if (!available || kIsWeb) return null;
    final m = FirebaseMessaging.instance;
    final s = await m.requestPermission();
    if (s.authorizationStatus == AuthorizationStatus.denied) return null;
    return m.getToken();
  }

  Future<void> setTopic(String topic, bool on) async {
    if (!available || kIsWeb) return;
    final m = FirebaseMessaging.instance;
    if (on) {
      await m.requestPermission();
      await m.subscribeToTopic(topic);
    } else {
      await m.unsubscribeFromTopic(topic);
    }
  }

  Stream<RemoteMessage> foregroundMessages() =>
      available && !kIsWeb ? FirebaseMessaging.onMessage : const Stream.empty();

  // ---------------- alerts ----------------
  Future<void> createAlert({
    required String crop,
    required String variety,
    required String marketId,
    required String condition,
    required double value,
  }) async {
    final u = await ensureAnonymous();
    final token = await fcmToken();
    if (token == null) throw StateError('notifications permission denied');
    await db.collection('alerts').add({
      'uid': u.uid,
      'fcmToken': token,
      'crop': crop,
      'variety': variety,
      'marketId': marketId,
      'condition': condition,
      'value': value,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<AlertDoc>> myAlerts() async {
    final u = user;
    if (u == null) return [];
    final q = await db.collection('alerts').where('uid', isEqualTo: u.uid).get();
    return q.docs.map((d) {
      final m = d.data();
      return AlertDoc(d.id, m['crop'] as String, m['variety'] as String, m['marketId'] as String,
          m['condition'] as String, (m['value'] as num).toDouble(), m['active'] == true);
    }).toList();
  }

  Future<void> deleteAlert(String id) => db.collection('alerts').doc(id).delete();

  // ---------------- reports ----------------
  Future<void> reportWrongRate(String priceKey, String reason, String note) async {
    final u = await ensureAnonymous();
    await db.collection('reports').add({
      'uid': u.uid,
      'priceKey': priceKey,
      'reason': reason,
      if (note.isNotEmpty) 'note': note,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------- partner ----------------
  Future<void> submitRates({required String sourceId, String? text, String? imageB64}) async {
    final u = user!;
    await db.collection('submissions').add({
      'partnerUid': u.uid,
      'sourceId': sourceId,
      if (text != null && text.trim().isNotEmpty) 'text': text.trim(),
      'imageB64': ?imageB64,
      'status': 'new',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<SubmissionDoc>> mySubmissions() async {
    final u = user!;
    final q = await db
        .collection('submissions')
        .where('partnerUid', isEqualTo: u.uid)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();
    return q.docs.map((d) {
      final m = d.data();
      return SubmissionDoc(d.id, (m['status'] ?? 'new') as String, (m['text'] ?? m['extractedText']) as String?,
          m['error'] as String?, (m['createdAt'] as Timestamp?)?.toDate(), (m['rows'] ?? 0) as int);
    }).toList();
  }

  Future<Map<String, dynamic>?> myPartnerDoc() async {
    final u = user!;
    final d = await db.collection('partners').doc(u.uid).get();
    return d.data();
  }

  Future<void> applyAsPartner({required String name, required String phone, required String address, String? marketId}) {
    final u = user!;
    return db.collection('partners').doc(u.uid).set({
      'name': name,
      'phone': phone,
      'address': address,
      'marketId': ?marketId,
      'approved': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
