import 'package:flutter/material.dart';

import '../attempt_repository.dart';
import '../dev_faults.dart';
import '../quiz_controller.dart';
import 'dev_panel.dart';
import 'retrieve_sheet.dart';

class QuizScreen extends StatelessWidget {
  const QuizScreen({super.key, required this.controller, required this.faults});
  final QuizController controller;
  final DevFaults faults;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Science Signal B'),
        actions: [
          IconButton(
            tooltip: 'Retrieve a stored attempt',
            icon: const Icon(Icons.manage_search),
            onPressed: () => showRetrieveSheet(context, c),
          ),
          if (kDevTools)
            IconButton(
              key: const Key('devToolsButton'),
              tooltip: 'Development tools',
              icon: const Icon(Icons.bug_report_outlined),
              onPressed: () => showDevPanel(context, c, faults),
            ),
          IconButton(
            key: const Key('signOutButton'),
            tooltip: c.isUnresolved ? 'Sign-out disabled while unresolved' : 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: c.isUnresolved ? null : c.signOut,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _IdentityBar(c: c),
              const SizedBox(height: 8),
              Expanded(child: _body(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final c = controller;
    switch (c.phase) {
      case Phase.loading:
        return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(c.message, textAlign: TextAlign.center),
          ]),
        );
      case Phase.requestError:
        return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off, size: 56, color: Colors.red),
            const SizedBox(height: 12),
            Text(c.message, key: const Key('requestError'), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('retryLoad'),
              onPressed: c.retryLoad,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ]),
        );
      case Phase.playing:
        return _Question(c: c);
      case Phase.signedOut:
      case Phase.authError:
        return const SizedBox.shrink();
      default:
        return _Results(c: c);
    }
  }
}

class _IdentityBar extends StatelessWidget {
  const _IdentityBar({required this.c});
  final QuizController c;

  @override
  Widget build(BuildContext context) {
    final rid = c.roundId;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Signed in: ${c.email ?? 'unknown'}',
                key: const Key('identityEmail'), style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('UID: ${c.uid}', key: const Key('identityUid'), style: const TextStyle(fontSize: 12)),
            if (rid != null)
              SelectableText('Round ID: $rid',
                  key: const Key('roundId'), style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({required this.c});
  final QuizController c;

  @override
  Widget build(BuildContext context) {
    final i = c.index;
    final q = c.questions[i];
    final answered = c.answers[i] != null;
    final correct = answered && c.selected == q.correctAnswer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Question ${i + 1} of ${QuizController.questionCount}',
            key: const Key('progressText'), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: (i + (answered ? 1 : 0)) / QuizController.questionCount),
        const SizedBox(height: 8),
        Text('Score: ${c.score}', key: const Key('scoreText')),
        const SizedBox(height: 20),
        Text(q.text, key: const Key('questionText'), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 24),
        for (final choice in const ['True', 'False']) ...[
          _ChoiceButton(c: c, choice: choice, answered: answered),
          const SizedBox(height: 12),
        ],
        if (answered)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: correct ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: correct ? Colors.green : Colors.red),
            ),
            child: Row(children: [
              Icon(correct ? Icons.check_circle : Icons.cancel,
                  color: correct ? Colors.green.shade800 : Colors.red.shade800),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  correct
                      ? 'Correct. The answer is ${q.correctAnswer}.'
                      : 'Incorrect. You chose ${c.selected}; the answer is ${q.correctAnswer}.',
                  key: const Key('feedbackText'),
                  style: TextStyle(
                      color: correct ? Colors.green.shade900 : Colors.red.shade900,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ),
        const Spacer(),
        FilledButton(
          key: const Key('continueButton'),
          onPressed: answered ? c.next : null,
          child: Text(i == QuizController.questionCount - 1 ? 'See results' : 'Continue'),
        ),
      ],
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({required this.c, required this.choice, required this.answered});
  final QuizController c;
  final String choice;
  final bool answered;

  @override
  Widget build(BuildContext context) {
    final q = c.questions[c.index];
    Color? bg;
    IconData? icon;
    if (answered) {
      if (choice == q.correctAnswer) {
        bg = Colors.green.shade700;
        icon = Icons.check;
      } else if (choice == c.selected) {
        bg = Colors.red.shade700;
        icon = Icons.close;
      }
    }
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        key: Key('choice$choice'),
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: bg != null ? Colors.white : null,
          disabledBackgroundColor: bg,
          disabledForegroundColor: bg != null ? Colors.white : null,
        ),
        onPressed: answered ? null : () => c.answer(choice),
        icon: icon != null ? Icon(icon) : const SizedBox.shrink(),
        label: Text(choice, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.c});
  final QuizController c;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text('You scored ${c.score} / ${QuizController.questionCount}',
            key: const Key('finalScore'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        for (var i = 0; i < QuizController.questionCount; i++) _reviewTile(i),
        const SizedBox(height: 8),
        _StatusCard(c: c),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('replayButton'),
          onPressed: c.canReplay ? c.replay : null,
          icon: const Icon(Icons.replay),
          label: Text(c.canReplay ? 'Replay with new questions' : 'Replay disabled until resolved'),
        ),
      ],
    );
  }

  Widget _reviewTile(int i) {
    final q = c.questions[i];
    final choice = c.answers[i];
    final ok = choice == q.correctAnswer;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        dense: true,
        leading: Icon(ok ? Icons.check_circle : Icons.cancel, color: ok ? Colors.green : Colors.red),
        title: Text('${i + 1}. ${q.text}'),
        subtitle: Text('Your answer: $choice | Correct: ${q.correctAnswer} | ${ok ? 'Correct' : 'Incorrect'}'),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.c});
  final QuizController c;

  @override
  Widget build(BuildContext context) {
    final spec = _spec();
    return Card(
      color: spec.color,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              spec.busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : Icon(spec.icon, color: spec.fg),
              const SizedBox(width: 10),
              Expanded(
                child: Text(spec.title,
                    key: const Key('statusTitle'),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: spec.fg)),
              ),
            ]),
            if (c.message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(c.message, key: const Key('statusMessage'), style: TextStyle(color: spec.fg)),
            ],
            if (c.lastErrorInjected) ...[
              const SizedBox(height: 6),
              Text('INJECTED FAULT (development tool). Deployed rules are untouched.',
                  key: const Key('injectedLabel'),
                  style: TextStyle(color: spec.fg, fontStyle: FontStyle.italic)),
            ],
            if (c.phase == Phase.cloudVerified && c.verified != null) _verifiedBlock(c.verified!),
            const SizedBox(height: 10),
            ..._actions(),
          ],
        ),
      ),
    );
  }

  Widget _verifiedBlock(VerifiedAttempt v) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SelectableText(
        'Path: users/${c.uid}/attempts/${v.id}\n'
        'schemaVersion: ${v.schemaVersion}\n'
        'variant: ${v.variant}\n'
        'categoryId: ${v.categoryId}\n'
        'questionCount: ${v.questionCount}\n'
        'correctCount: ${v.correctCount}\n'
        'submittedAt (server): ${QuizController.formatTime(v.submittedAt)}',
        key: const Key('verifiedBlock'),
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    );
  }

  List<Widget> _actions() {
    switch (c.phase) {
      case Phase.readyToSubmit:
        return [
          FilledButton.icon(
            key: const Key('submitButton'),
            onPressed: c.submit,
            icon: const Icon(Icons.cloud_upload_outlined),
            label: const Text('Submit score to the cloud'),
          ),
        ];
      case Phase.submitting:
      case Phase.verifying:
        return [
          FilledButton(
              key: const Key('submitButton'), onPressed: null, child: const Text('Working...')),
        ];
      case Phase.saveUnknown:
        return [
          FilledButton.icon(
            key: const Key('reconcileButton'),
            onPressed: c.reconcile,
            icon: const Icon(Icons.sync),
            label: const Text('Reconcile with server (same ID)'),
          ),
        ];
      case Phase.permissionDenied:
        if (c.commitAcknowledged) {
          return [
            FilledButton.icon(
              key: const Key('retryVerifyButton'),
              onPressed: c.retryVerification,
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Retry verification (read only)'),
            ),
          ];
        }
        return [
          FilledButton.icon(
            key: const Key('submitButton'),
            onPressed: c.submit,
            icon: const Icon(Icons.cloud_upload_outlined),
            label: const Text('Submit again (same ID)'),
          ),
        ];
      case Phase.verificationUnavailable:
        return [
          FilledButton.icon(
            key: const Key('retryVerifyButton'),
            onPressed: c.retryVerification,
            icon: const Icon(Icons.verified_outlined),
            label: const Text('Retry verification (read only)'),
          ),
        ];
      default:
        return const [];
    }
  }

  _Spec _spec() {
    switch (c.phase) {
      case Phase.readyToSubmit:
        return _Spec('Ready to submit', Icons.cloud_queue, Colors.blue.shade50, Colors.blue.shade900);
      case Phase.submitting:
        return _Spec('Submitting (waiting for commit)', Icons.cloud_upload, Colors.blue.shade50,
            Colors.blue.shade900, busy: true);
      case Phase.verifying:
        return _Spec('Verifying with the server', Icons.cloud_sync, Colors.blue.shade50,
            Colors.blue.shade900, busy: true);
      case Phase.cloudVerified:
        return _Spec('Cloud verified', Icons.verified, Colors.green.shade50, Colors.green.shade900);
      case Phase.saveUnknown:
        return _Spec('Save outcome unknown', Icons.help_outline, Colors.amber.shade50,
            Colors.brown.shade900);
      case Phase.permissionDenied:
        return _Spec(
            c.commitAcknowledged ? 'Write acknowledged; verification unavailable' : 'Write denied',
            c.commitAcknowledged ? Icons.lock_outline : Icons.block,
            Colors.red.shade50,
            Colors.red.shade900);
      case Phase.verificationUnavailable:
        return _Spec('Write acknowledged; verification unavailable', Icons.cloud_off,
            Colors.orange.shade50, Colors.deepOrange.shade900);
      case Phase.collision:
        return _Spec('Round ID collision (not overwritten)', Icons.warning_amber, Colors.red.shade50,
            Colors.red.shade900);
      default:
        return _Spec('', Icons.info, Colors.grey.shade100, Colors.black87);
    }
  }
}

class _Spec {
  _Spec(this.title, this.icon, this.color, this.fg, {this.busy = false});
  final String title;
  final IconData icon;
  final Color color;
  final Color fg;
  final bool busy;
}
