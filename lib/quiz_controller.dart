import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'attempt_repository.dart';
import 'dev_faults.dart';
import 'opentdb.dart';

/// signedOut -> loading -> playing -> readyToSubmit -> submitting -> verifying
/// -> cloudVerified, plus the failure states. `collision` is an extra guard for
/// a reused round ID whose stored fields differ.
enum Phase {
  signedOut,
  loading,
  playing,
  readyToSubmit,
  submitting,
  verifying,
  cloudVerified,
  authError,
  requestError,
  saveUnknown,
  permissionDenied,
  verificationUnavailable,
  collision,
}

class QuizController extends ChangeNotifier {
  QuizController({
    required this.auth,
    required this.repo,
    required this.trivia,
    required this.faults,
  }) {
    _sub = auth.authStateChanges().listen(_onAuth);
  }

  static const int questionCount = 5;
  static const Duration uiTimeout = Duration(seconds: 10);

  final FirebaseAuth auth;
  final AttemptRepository repo;
  final OpenTdbClient trivia;
  final DevFaults faults;
  late final StreamSubscription<User?> _sub;

  Phase phase = Phase.signedOut;
  String message = '';
  bool lastErrorInjected = false;
  bool signingIn = false;

  String? uid;
  String? email;

  List<ScienceQuestion> questions = const [];
  final List<String?> answers = List<String?>.filled(questionCount, null);
  int index = 0;
  int score = 0;
  String? selected;

  String? roundId;
  Map<String, Object>? _frozen;
  bool commitAcknowledged = false;
  VerifiedAttempt? verified;

  VerifiedAttempt? retrieved;
  String retrieveMessage = '';
  bool retrieving = false;

  bool get isUnresolved =>
      phase == Phase.submitting ||
      phase == Phase.verifying ||
      phase == Phase.saveUnknown ||
      phase == Phase.verificationUnavailable ||
      (phase == Phase.permissionDenied && commitAcknowledged);

  bool get canReplay => uid != null && !isUnresolved && phase != Phase.loading;

  /// Callbacks are bound to the initiating UID and round ID.
  bool _live(String u, String r) => uid == u && roundId == r;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------- auth --------

  void _onAuth(User? user) {
    final newUid = user?.uid;
    if (newUid == uid) return;
    uid = newUid;
    email = user?.email;
    _resetRound();
    roundId = null;
    retrieved = null;
    retrieveMessage = '';
    if (user == null) {
      phase = Phase.signedOut;
      message = '';
      notifyListeners();
    } else {
      phase = Phase.signedOut;
      notifyListeners();
      startRound();
    }
  }

  Future<void> signIn(String emailText, String password) async {
    if (signingIn) return;
    if (emailText.trim().isEmpty || password.isEmpty) {
      phase = Phase.authError;
      message = 'Enter both an email and a password.';
      notifyListeners();
      return;
    }
    signingIn = true;
    message = '';
    notifyListeners();
    try {
      await auth.signInWithEmailAndPassword(email: emailText.trim(), password: password);
      if (phase == Phase.authError) phase = Phase.signedOut;
    } on FirebaseAuthException catch (e) {
      phase = Phase.authError;
      message = 'Sign-in failed (${e.code}): ${e.message ?? 'no details'}';
    } catch (e) {
      phase = Phase.authError;
      message = 'Sign-in failed: $e';
    } finally {
      signingIn = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    if (isUnresolved) return; // disabled while a result is unresolved
    await auth.signOut();
  }

  // ------------------------------------------------------------- round -------

  void _resetRound() {
    questions = const [];
    for (var i = 0; i < questionCount; i++) {
      answers[i] = null;
    }
    index = 0;
    score = 0;
    selected = null;
    _frozen = null;
    commitAcknowledged = false;
    verified = null;
    lastErrorInjected = false;
  }

  /// Starts a fresh round (new ID). Replay uses this too.
  Future<void> startRound() => _loadRound(keepId: false);

  /// Retry after a request error. Reuses the round ID generated at round start.
  Future<void> retryLoad() => _loadRound(keepId: true);

  Future<void> _loadRound({required bool keepId}) async {
    final u = uid;
    if (u == null || isUnresolved || phase == Phase.loading) return;
    _resetRound();
    if (!keepId || roundId == null) roundId = repo.newRoundId(u);
    final rid = roundId!;
    phase = Phase.loading;
    message = 'Fetching five science questions...';
    notifyListeners();

    // One user-triggered wait, never an automatic retry loop.
    final wait = trivia.cooldownRemaining;
    if (wait > Duration.zero) {
      message = 'Waiting ${wait.inSeconds + 1}s so the trivia service is not rate limited...';
      notifyListeners();
      await Future<void>.delayed(wait);
      if (!_live(u, rid)) return;
      message = 'Fetching five science questions...';
      notifyListeners();
    }

    try {
      final qs = await trivia.fetchRound();
      if (!_live(u, rid)) return;
      questions = qs;
      phase = Phase.playing;
      message = '';
    } on TriviaException catch (e) {
      if (!_live(u, rid)) return;
      phase = Phase.requestError;
      message = e.message;
    } catch (e) {
      if (!_live(u, rid)) return;
      phase = Phase.requestError;
      message = 'Could not load questions: $e';
    }
    notifyListeners();
  }

  void answer(String choice) {
    if (phase != Phase.playing) return;
    if (answers[index] != null) return; // one answer per question
    answers[index] = choice;
    selected = choice;
    if (choice == questions[index].correctAnswer) score++;
    notifyListeners();
  }

  void next() {
    if (phase != Phase.playing || answers[index] == null) return;
    if (index < questionCount - 1) {
      index++;
      selected = null;
    } else {
      // Score is captured only now that all five answers are final.
      _frozen = repo.freeze(score);
      phase = Phase.readyToSubmit;
      message = '';
    }
    notifyListeners();
  }

  // ------------------------------------------------------------- cloud -------

  Future<void> submit() async {
    final u = uid, r = roundId, p = _frozen;
    if (u == null || r == null || p == null) return;
    final allowed = phase == Phase.readyToSubmit ||
        (phase == Phase.permissionDenied && !commitAcknowledged);
    if (!allowed) return; // blocks double taps while pending
    phase = Phase.submitting;
    message = 'Writing the attempt to the cloud...';
    lastErrorInjected = false;
    notifyListeners();

    try {
      await repo.commit(u, r, p).timeout(uiTimeout);
      if (!_live(u, r)) return;
      commitAcknowledged = true;
    } on TimeoutException {
      if (!_live(u, r)) return;
      phase = Phase.saveUnknown;
      message = 'No commit acknowledgement within 10 seconds. The write may or may not '
          'have happened (the timeout does not cancel the Firestore operation). '
          'Reconcile this exact round ID with the server before retrying.';
      notifyListeners();
      return;
    } on AttemptCollision catch (e) {
      if (!_live(u, r)) return;
      phase = Phase.collision;
      message = e.message;
      notifyListeners();
      return;
    } on FirebaseException catch (e) {
      if (!_live(u, r)) return;
      _markInjected(e);
      if (e.code == 'permission-denied') {
        phase = Phase.permissionDenied;
        message = 'The write was denied by the security rules (permission-denied). '
            'Nothing was saved. ${e.message ?? ''}';
      } else {
        phase = Phase.saveUnknown;
        message = 'The write did not return an acknowledgement (${e.code}): ${_codeHelp(e.code)} '
            'Reconcile this round ID with the server before retrying. ${e.message ?? ''}';
      }
      notifyListeners();
      return;
    } catch (e) {
      if (!_live(u, r)) return;
      phase = Phase.saveUnknown;
      message = 'Unexpected error before an acknowledgement: $e. Reconcile before retrying.';
      notifyListeners();
      return;
    }
    await _verify(u, r);
  }

  Future<void> retryVerification() async {
    final u = uid, r = roundId;
    if (u == null || r == null) return;
    final ok = phase == Phase.verificationUnavailable ||
        (phase == Phase.permissionDenied && commitAcknowledged);
    if (!ok) return;
    await _verify(u, r); // read only, never writes
  }

  Future<void> _verify(String u, String r) async {
    phase = Phase.verifying;
    message = 'Reading the same document back from the server...';
    lastErrorInjected = false;
    notifyListeners();
    try {
      final v = await repo.verify(u, r, expected: _frozen).timeout(uiTimeout + const Duration(seconds: 6));
      if (!_live(u, r)) return;
      verified = v;
      commitAcknowledged = true;
      phase = Phase.cloudVerified;
      message = '';
    } on FirebaseException catch (e) {
      if (!_live(u, r)) return;
      _markInjected(e);
      if (e.code == 'permission-denied') {
        phase = Phase.permissionDenied;
      } else {
        phase = Phase.verificationUnavailable;
      }
      message = 'Write acknowledged; verification unavailable. '
          'Server read failed with ${e.code}: ${_codeHelp(e.code)} ${e.message ?? ''}';
    } on TimeoutException {
      if (!_live(u, r)) return;
      phase = Phase.verificationUnavailable;
      message = 'Write acknowledged; verification unavailable. The server read timed out.';
    } on AttemptMissing catch (e) {
      if (!_live(u, r)) return;
      phase = Phase.verificationUnavailable;
      message = 'Write acknowledged; verification unavailable. ${e.message}';
    } on VerificationMismatch catch (e) {
      if (!_live(u, r)) return;
      phase = Phase.verificationUnavailable;
      message = 'Write acknowledged; verification unavailable. ${e.message}';
    } catch (e) {
      if (!_live(u, r)) return;
      phase = Phase.verificationUnavailable;
      message = 'Write acknowledged; verification unavailable. $e';
    }
    notifyListeners();
  }

  /// After saveUnknown: read the original ID from the server before any retry.
  Future<void> reconcile() async {
    final u = uid, r = roundId;
    if (u == null || r == null || phase != Phase.saveUnknown) return;
    phase = Phase.verifying;
    message = 'Reconciling the original round ID with the server...';
    lastErrorInjected = false;
    notifyListeners();
    try {
      final v = await repo.verify(u, r, expected: _frozen);
      if (!_live(u, r)) return;
      verified = v;
      commitAcknowledged = true;
      phase = Phase.cloudVerified;
      message = '';
    } on AttemptMissing {
      if (!_live(u, r)) return;
      phase = Phase.readyToSubmit;
      message = 'The server has no record of this round ID, so the earlier write did not '
          'commit. It is safe to submit again with the same ID.';
    } on FirebaseException catch (e) {
      if (!_live(u, r)) return;
      _markInjected(e);
      phase = Phase.saveUnknown;
      message = 'Still cannot reach the server (${e.code}): ${_codeHelp(e.code)} '
          'The save outcome is still unknown. ${e.message ?? ''}';
    } on VerificationMismatch catch (e) {
      if (!_live(u, r)) return;
      phase = Phase.collision;
      message = e.message;
    } catch (e) {
      if (!_live(u, r)) return;
      phase = Phase.saveUnknown;
      message = 'Reconcile failed: $e. The save outcome is still unknown.';
    }
    notifyListeners();
  }

  Future<void> replay() async {
    if (!canReplay) return;
    await startRound();
  }

  // ------------------------------------------------------------- retrieve ----

  Future<void> retrieve(String id) async {
    final u = uid;
    if (u == null || retrieving) return;
    final trimmed = id.trim();
    if (trimmed.isEmpty) {
      retrieveMessage = 'Enter a round ID first.';
      notifyListeners();
      return;
    }
    await _retrieveWith(u, () => repo.retrieve(u, trimmed));
  }

  Future<void> retrieveLatest() async {
    final u = uid;
    if (u == null || retrieving) return;
    await _retrieveWith(u, () => repo.latest(u));
  }

  Future<void> _retrieveWith(String u, Future<VerifiedAttempt> Function() run) async {
    retrieving = true;
    retrieved = null;
    retrieveMessage = 'Reading from the server...';
    notifyListeners();
    try {
      final v = await run();
      if (uid != u) return;
      retrieved = v;
      retrieveMessage = 'Server record found.';
    } on AttemptMissing catch (e) {
      retrieveMessage = e.message;
    } on VerificationMismatch catch (e) {
      retrieveMessage = e.message;
    } on FirebaseException catch (e) {
      retrieveMessage = '${e.code}: ${_codeHelp(e.code)}';
    } on TimeoutException {
      retrieveMessage = 'The server read timed out.';
    } catch (e) {
      retrieveMessage = '$e';
    } finally {
      retrieving = false;
      if (uid == u) notifyListeners();
    }
  }

  // ------------------------------------------------------------- helpers -----

  void _markInjected(FirebaseException e) {
    lastErrorInjected = (e.message ?? '').contains('INJECTED');
  }

  String _codeHelp(String code) {
    switch (code) {
      case 'unavailable':
        return 'the service is unreachable (offline or backend down).';
      case 'resource-exhausted':
        return 'quota exhausted for the project.';
      case 'unauthenticated':
        return 'the request carried no valid sign-in.';
      case 'permission-denied':
        return 'the security rules rejected the request.';
      case 'deadline-exceeded':
        return 'the server did not answer in time.';
      default:
        return 'Firestore reported "$code".';
    }
  }

  /// Exposed for the dev panel: Firestore server timestamp pretty print.
  static String formatTime(DateTime t) => t.toLocal().toIso8601String();
}
