import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../attempt_repository.dart';
import '../dev_faults.dart';
import '../quiz_controller.dart';

/// Development-only panel. Not reachable in release builds (kDevTools false).
void showDevPanel(BuildContext context, QuizController c, DevFaults faults) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _DevPanel(c: c, faults: faults),
    ),
  );
}

class _DevPanel extends StatefulWidget {
  const _DevPanel({required this.c, required this.faults});
  final QuizController c;
  final DevFaults faults;

  @override
  State<_DevPanel> createState() => _DevPanelState();
}

class _DevPanelState extends State<_DevPanel> {
  final _target = TextEditingController();
  final List<String> _log = [];

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  AttemptRepository get _repo => widget.c.repo;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  void _add(String line) => setState(() => _log.insert(0, line));

  Future<void> _probe(String label, Future<String> Function() run) async {
    _add('$label ...');
    final r = await run();
    _add('$label -> $r');
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.faults;
    return ListenableBuilder(
      listenable: f,
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Development tools', style: Theme.of(context).textTheme.titleLarge),
            const Text('Injections are labelled in the UI. Deployed rules are never changed.',
                style: TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            Text('Armed: ${f.armedSummary}', key: const Key('armedSummary')),
            const Divider(),
            const Text('Trivia payload (next load)', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(spacing: 8, children: [
              ActionChip(
                  key: const Key('armBadEncoding'),
                  label: const Text('Bad encoding'),
                  onPressed: () => f.armTrivia(TriviaFault.badEncoding)),
              ActionChip(
                  key: const Key('armNonzeroCode'),
                  label: const Text('Nonzero code'),
                  onPressed: () => f.armTrivia(TriviaFault.nonzeroCode)),
              ActionChip(
                  key: const Key('armFourResults'),
                  label: const Text('Four results'),
                  onPressed: () => f.armTrivia(TriviaFault.fourResults)),
            ]),
            const SizedBox(height: 8),
            const Text('Verification fault (first read after a commit)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(spacing: 8, children: [
              ActionChip(
                  key: const Key('armVerifyDenied'),
                  label: const Text('permission-denied'),
                  onPressed: () => f.armVerify('permission-denied')),
              ActionChip(
                  key: const Key('armVerifyUnavailable'),
                  label: const Text('unavailable'),
                  onPressed: () => f.armVerify('unavailable')),
              ActionChip(
                  key: const Key('armVerifyExhausted'),
                  label: const Text('resource-exhausted'),
                  onPressed: () => f.armVerify('resource-exhausted')),
            ]),
            const SizedBox(height: 8),
            const Text('Commit fault (next submit)', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(spacing: 8, children: [
              ActionChip(
                  key: const Key('armCommitUnavailable'),
                  label: const Text('unavailable'),
                  onPressed: () => f.armCommit('unavailable')),
              ActionChip(
                  key: const Key('armCommitExhausted'),
                  label: const Text('resource-exhausted'),
                  onPressed: () => f.armCommit('resource-exhausted')),
              ActionChip(
                  key: const Key('armCommitUnauth'),
                  label: const Text('unauthenticated'),
                  onPressed: () => f.armCommit('unauthenticated')),
            ]),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('disarmAll'),
              onPressed: () {
                f.armTrivia(TriviaFault.none);
                f.armCommit(null);
                f.armVerify(null);
              },
              child: const Text('Disarm everything'),
            ),
            const Divider(),
            const Text('Deployed-rules probes (real server requests)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              key: const Key('targetUid'),
              controller: _target,
              autocorrect: false,
              decoration: const InputDecoration(
                  labelText: "Other user's UID (for T10)", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              ActionChip(
                  key: const Key('probeReadOther'),
                  label: const Text('Read other user'),
                  onPressed: () => _probe("Read other user's path", () => _repo.devReadOther(_target.text.trim()))),
              ActionChip(
                  key: const Key('probeWriteOther'),
                  label: const Text('Write other user'),
                  onPressed: () => _probe("Write other user's path", () => _repo.devWriteOther(_target.text.trim()))),
              ActionChip(
                  key: const Key('probeScoreSix'),
                  label: const Text('Score 6'),
                  onPressed: () {
                    final u = _uid;
                    if (u != null) _probe('Create with correctCount 6', () => _repo.devScoreSix(u));
                  }),
              ActionChip(
                  key: const Key('probeExtraField'),
                  label: const Text('Extra field'),
                  onPressed: () {
                    final u = _uid;
                    if (u != null) _probe('Create with extra field', () => _repo.devExtraField(u));
                  }),
              ActionChip(
                  key: const Key('probeUpdate'),
                  label: const Text('Update existing'),
                  onPressed: () {
                    final u = _uid, r = widget.c.roundId;
                    if (u != null && r != null) _probe('Update round $r', () => _repo.devUpdate(u, r));
                  }),
            ]),
            const SizedBox(height: 8),
            const Text('Probe log', style: TextStyle(fontWeight: FontWeight.bold)),
            for (final line in _log) Text(line, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
