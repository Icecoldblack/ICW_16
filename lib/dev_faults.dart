import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Development-only tools. Off in release builds unless built with
/// --dart-define=DEV_TOOLS=true. Every injected failure is labelled in the UI.
const bool kDevTools = bool.fromEnvironment('DEV_TOOLS', defaultValue: kDebugMode);

enum TriviaFault { none, badEncoding, nonzeroCode, fourResults }

class DevFaults extends ChangeNotifier {
  TriviaFault trivia = TriviaFault.none;
  String? commitFault; // Firestore error code to throw on the next commit
  String? verifyFault; // Firestore error code to throw on the next verification

  void armTrivia(TriviaFault f) {
    trivia = f;
    notifyListeners();
  }

  void armCommit(String? code) {
    commitFault = code;
    notifyListeners();
  }

  void armVerify(String? code) {
    verifyFault = code;
    notifyListeners();
  }

  TriviaFault takeTrivia() {
    if (!kDevTools) return TriviaFault.none;
    final f = trivia;
    trivia = TriviaFault.none;
    notifyListeners();
    return f;
  }

  FirebaseException? takeCommitFault() {
    if (!kDevTools || commitFault == null) return null;
    final code = commitFault!;
    commitFault = null;
    notifyListeners();
    return FirebaseException(
        plugin: 'cloud_firestore',
        code: code,
        message: 'INJECTED by development-only hook ($code) on commit');
  }

  FirebaseException? takeVerifyFault() {
    if (!kDevTools || verifyFault == null) return null;
    final code = verifyFault!;
    verifyFault = null;
    notifyListeners();
    return FirebaseException(
        plugin: 'cloud_firestore',
        code: code,
        message: 'INJECTED by development-only hook ($code) on verification');
  }

  String get armedSummary {
    final parts = <String>[
      if (trivia != TriviaFault.none) 'trivia:${trivia.name}',
      if (commitFault != null) 'commit:$commitFault',
      if (verifyFault != null) 'verify:$verifyFault',
    ];
    return parts.isEmpty ? 'nothing armed' : parts.join(', ');
  }
}
