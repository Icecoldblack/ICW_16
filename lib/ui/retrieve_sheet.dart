import 'package:flutter/material.dart';

import '../quiz_controller.dart';

void showRetrieveSheet(BuildContext context, QuizController c) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _RetrieveSheet(c: c),
    ),
  );
}

class _RetrieveSheet extends StatefulWidget {
  const _RetrieveSheet({required this.c});
  final QuizController c;

  @override
  State<_RetrieveSheet> createState() => _RetrieveSheetState();
}

class _RetrieveSheetState extends State<_RetrieveSheet> {
  final _id = TextEditingController();

  @override
  void dispose() {
    _id.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final v = c.retrieved;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Retrieve a stored attempt', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('Reads users/${c.uid}/attempts/<round ID> from the server only.',
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              TextField(
                key: const Key('retrieveId'),
                controller: _id,
                autocorrect: false,
                decoration: const InputDecoration(
                    labelText: 'Round ID', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: FilledButton(
                    key: const Key('retrieveButton'),
                    onPressed: c.retrieving ? null : () => c.retrieve(_id.text),
                    child: const Text('Retrieve by ID'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    key: const Key('retrieveLatestButton'),
                    onPressed: c.retrieving ? null : c.retrieveLatest,
                    child: const Text('Latest attempt'),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              if (c.retrieveMessage.isNotEmpty)
                Text(c.retrieveMessage, key: const Key('retrieveMessage')),
              if (v != null)
                SelectableText(
                  'Round ID: ${v.id}\n'
                  'schemaVersion: ${v.schemaVersion}\n'
                  'variant: ${v.variant}\n'
                  'categoryId: ${v.categoryId}\n'
                  'questionCount: ${v.questionCount}\n'
                  'correctCount: ${v.correctCount}\n'
                  'submittedAt (server): ${QuizController.formatTime(v.submittedAt)}',
                  key: const Key('retrievedBlock'),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
            ],
          ),
        );
      },
    );
  }
}
