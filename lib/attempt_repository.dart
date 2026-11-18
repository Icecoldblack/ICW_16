import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'dev_faults.dart';

class AttemptCollision implements Exception {
  AttemptCollision(this.message);
  final String message;
}

class AttemptMissing implements Exception {
  AttemptMissing(this.message);
  final String message;
}

class VerificationMismatch implements Exception {
  VerificationMismatch(this.message);
  final String message;
}

class VerifiedAttempt {
  const VerifiedAttempt({
    required this.id,
    required this.schemaVersion,
    required this.variant,
    required this.categoryId,
    required this.questionCount,
    required this.correctCount,
    required this.submittedAt,
  });
  final String id;
  final int schemaVersion;
  final String variant;
  final int categoryId;
  final int questionCount;
  final int correctCount;
  final DateTime submittedAt;
}

/// Cloud Firestore access for Class B attempts at
/// users/{authenticatedUid}/attempts/{roundId}.
class AttemptRepository {
  AttemptRepository(this._db, this._faults);

  final FirebaseFirestore _db;
  final DevFaults _faults;

  static const List<String> fixedFields = [
    'schemaVersion',
    'variant',
    'categoryId',
    'questionCount',
    'correctCount',
  ];
  static const Duration ioTimeout = Duration(seconds: 10);

  CollectionReference<Map<String, dynamic>> _attempts(String uid) =>
      _db.collection('users').doc(uid).collection('attempts');

  DocumentReference<Map<String, dynamic>> ref(String uid, String roundId) =>
      _attempts(uid).doc(roundId);

  /// Generates an identifier only. This creates no server record.
  String newRoundId(String uid) => _attempts(uid).doc().id;

  /// The frozen payload for a completed round. Exactly the six schema fields.
  Map<String, Object> freeze(int correctCount) => {
        'schemaVersion': 1,
        'variant': 'B',
        'categoryId': 17,
        'questionCount': 5,
        'correctCount': correctCount,
        'submittedAt': FieldValue.serverTimestamp(),
      };

  /// Create-once transaction. Reads first, creates with transaction.set only if
  /// absent, and treats an identical existing record as the original. The
  /// callback has no side effects because Firestore may retry it.
  Future<void> commit(String uid, String roundId, Map<String, Object> payload) async {
    final injected = _faults.takeCommitFault();
    if (injected != null) throw injected;

    final docRef = ref(uid, roundId);
    await _db.runTransaction<void>((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) {
        tx.set(docRef, payload);
        return;
      }
      final existing = snap.data() ?? const <String, dynamic>{};
      for (final key in fixedFields) {
        if (existing[key] != payload[key]) {
          throw AttemptCollision(
              'Round ID already exists with different "$key". Not overwritten.');
        }
      }
      // Same five fields: reuse the original record, write nothing.
    });
  }

  /// Server-only read of the exact document with all contract checks.
  Future<VerifiedAttempt> verify(String uid, String roundId,
      {Map<String, Object>? expected}) async {
    final injected = _faults.takeVerifyFault();
    if (injected != null) throw injected;

    await _db.waitForPendingWrites().timeout(ioTimeout);
    final snap =
        await ref(uid, roundId).get(const GetOptions(source: Source.server)).timeout(ioTimeout);
    return _check(roundId, snap, expected);
  }

  VerifiedAttempt _check(String roundId, DocumentSnapshot<Map<String, dynamic>> snap,
      Map<String, Object>? expected) {
    if (!snap.exists) throw AttemptMissing('The server has no document for this round ID.');
    if (snap.metadata.isFromCache) {
      throw VerificationMismatch('Result came from cache, which is not proof.');
    }
    if (snap.metadata.hasPendingWrites) {
      throw VerificationMismatch('Document still has pending writes.');
    }
    final d = snap.data()!;
    final wanted = {...fixedFields, 'submittedAt'};
    if (d.keys.toSet().length != wanted.length || !d.keys.toSet().containsAll(wanted)) {
      throw VerificationMismatch('Document fields are not exactly the six schema fields.');
    }
    final ts = d['submittedAt'];
    if (ts is! Timestamp) {
      throw VerificationMismatch('submittedAt is not a resolved server timestamp.');
    }
    if (d['schemaVersion'] != 1 ||
        d['variant'] != 'B' ||
        d['categoryId'] != 17 ||
        d['questionCount'] != 5 ||
        d['correctCount'] is! int ||
        (d['correctCount'] as int) < 0 ||
        (d['correctCount'] as int) > 5) {
      throw VerificationMismatch('A fixed field has an unexpected value.');
    }
    if (expected != null) {
      for (final key in fixedFields) {
        if (d[key] != expected[key]) {
          throw VerificationMismatch('Server value of "$key" differs from this round.');
        }
      }
    }
    return VerifiedAttempt(
      id: roundId,
      schemaVersion: d['schemaVersion'] as int,
      variant: d['variant'] as String,
      categoryId: d['categoryId'] as int,
      questionCount: d['questionCount'] as int,
      correctCount: d['correctCount'] as int,
      submittedAt: ts.toDate(),
    );
  }

  /// Retrieval by ID for the signed-in user (server read, no replay).
  Future<VerifiedAttempt> retrieve(String uid, String roundId) async {
    final snap =
        await ref(uid, roundId).get(const GetOptions(source: Source.server)).timeout(ioTimeout);
    return _check(roundId, snap, null);
  }

  Future<VerifiedAttempt> latest(String uid) async {
    final q = await _attempts(uid)
        .orderBy('submittedAt', descending: true)
        .limit(1)
        .get(const GetOptions(source: Source.server))
        .timeout(ioTimeout);
    if (q.docs.isEmpty) throw AttemptMissing('No attempts stored for this user yet.');
    return _check(q.docs.first.id, q.docs.first, null);
  }

  // ---------------- development-only rule probes (never used by the quiz) -----

  String _verdict(Object e) {
    if (e is FirebaseException) return '${e.code} (rejected by rules)';
    return 'error: $e';
  }

  Future<String> devReadOther(String targetUid) async {
    try {
      await _attempts(targetUid).doc('probe').get(const GetOptions(source: Source.server)).timeout(ioTimeout);
      return 'READ ALLOWED (unexpected)';
    } catch (e) {
      return _verdict(e);
    }
  }

  Future<String> devWriteOther(String targetUid) async {
    try {
      await _attempts(targetUid).doc().set(freeze(1)).timeout(ioTimeout);
      return 'WRITE ALLOWED (unexpected)';
    } catch (e) {
      return _verdict(e);
    }
  }

  Future<String> devScoreSix(String uid) async {
    try {
      final p = freeze(6);
      await _attempts(uid).doc().set(p).timeout(ioTimeout);
      return 'score 6 ALLOWED (unexpected)';
    } catch (e) {
      return _verdict(e);
    }
  }

  Future<String> devExtraField(String uid) async {
    try {
      final p = {...freeze(2), 'displayName': 'extra'};
      await _attempts(uid).doc().set(p).timeout(ioTimeout);
      return 'extra field ALLOWED (unexpected)';
    } catch (e) {
      return _verdict(e);
    }
  }

  Future<String> devUpdate(String uid, String roundId) async {
    try {
      await ref(uid, roundId).update({'correctCount': 0}).timeout(ioTimeout);
      return 'update ALLOWED (unexpected)';
    } catch (e) {
      return _verdict(e);
    }
  }
}
