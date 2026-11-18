import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'attempt_repository.dart';
import 'dev_faults.dart';
import 'firebase_options.dart';
import 'opentdb.dart';
import 'quiz_controller.dart';
import 'ui/quiz_screen.dart';
import 'ui/sign_in_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // No local persistence: a restart starts empty, so anything shown afterwards
  // must come from the server, and offline writes are not silently queued.
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
  runApp(const ScienceSignalApp());
}

class ScienceSignalApp extends StatefulWidget {
  const ScienceSignalApp({super.key});

  @override
  State<ScienceSignalApp> createState() => _ScienceSignalAppState();
}

class _ScienceSignalAppState extends State<ScienceSignalApp> {
  late final DevFaults _faults = DevFaults();
  late final QuizController _controller = QuizController(
    auth: FirebaseAuth.instance,
    repo: AttemptRepository(FirebaseFirestore.instance, _faults),
    trivia: OpenTdbClient(faults: _faults),
    faults: _faults,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Science Signal B',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
      home: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => _controller.uid == null
            ? SignInScreen(controller: _controller)
            : QuizScreen(controller: _controller, faults: _faults),
      ),
    );
  }
}
