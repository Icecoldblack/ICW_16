# ICA 16 Class B: Science Signal (Flutter + Firebase)

Uyiosa Nehikhuere, CSC 4360 Mobile App Development

Five medium Science & Nature true/false questions from Open Trivia Database (category 17, `encode=url3986`), a signed-in round, and a create-once Cloud Firestore attempt at `users/{authenticatedUid}/attempts/{roundId}` that is only called **Cloud verified** after a server-only read of the same document.

## Setup (no credentials are stored in this repository)

1. Create a separate Firebase project (not the Class A one), enable Email/Password sign-in, create two test users, and create a Cloud Firestore database (Standard edition, Native mode, production mode).
2. Run `setup_icw16.bat` (or the equivalent): `flutter create --org com.uyiosa --project-name icw16b --platforms android .`, `flutter pub add http firebase_core firebase_auth cloud_firestore`, `flutterfire configure --project=<your project id> --platforms=android --android-package-name=com.uyiosa.icw16b`, then `firebase deploy --only firestore:rules`.
3. `android.permission.INTERNET` is declared in `android/app/src/main/AndroidManifest.xml`.
4. Run `flutter run -d emulator` (debug builds include the development-only tools panel) or `flutter build apk --release` (dev tools off).

Test passwords are never committed. The instructor can request test access through the course's private channel.

## Layout

| File | Purpose |
| --- | --- |
| `lib/opentdb.dart` | HTTP GET with 10 s timeout, status/`response_code`/count/category/difficulty/type/answer checks, `Uri.decodeComponent` decoding |
| `lib/attempt_repository.dart` | Frozen payload, create-once transaction, `Source.server` verification, retrieval, dev-only rule probes |
| `lib/quiz_controller.dart` | State machine (below), UID and round ID bound callbacks |
| `lib/dev_faults.dart` | Development-only fault injection (off in release) |
| `firestore.rules` | Deployed owner-only schema and immutability rules |

## State machine

`signedOut -> loading -> playing -> readyToSubmit -> submitting -> verifying -> cloudVerified`, with `authError`, `requestError`, `saveUnknown`, `permissionDenied`, `verificationUnavailable` and an extra `collision` guard (same round ID, different stored fields: never overwritten).

Key guards: one answer per question; Continue needs an answer; the payload is frozen once all five answers are final; Submit is disabled while pending; sign-out and replay are disabled while a result is unresolved; async callbacks are dropped if the UID or round ID changed; a verification failure after a real commit never creates a second document (retry verification is read only; a timeout enters `saveUnknown` and is reconciled by reading the original ID).

## Honest limits

Owner-only rules enforce schema and immutability, but the client still supplies the score, so a dishonest owner can submit any valid score. A server-authoritative design would need a trusted backend to compute the score.

AI assistance was used while building this project and is disclosed in the evidence document.
