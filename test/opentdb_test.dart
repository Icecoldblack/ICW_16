import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:icw16b/opentdb.dart';

String _q(String text, {String correct = 'True', String wrong = 'False'}) => jsonEncode({
      'type': 'boolean',
      'difficulty': 'medium',
      'category': Uri.encodeComponent('Science & Nature'),
      'question': Uri.encodeComponent(text),
      'correct_answer': correct,
      'incorrect_answers': [wrong],
    });

String _body(List<String> items, {int code = 0}) =>
    '{"response_code":$code,"results":[${items.join(',')}]}';

OpenTdbClient _client(String body, {int status = 200}) =>
    OpenTdbClient(client: MockClient((_) async => http.Response(body, status)));

void main() {
  final five = List.generate(5, (i) => _q('Question $i about the Sun & Moon?'));

  test('percent encoded text is decoded with Uri.decodeComponent', () async {
    final qs = await _client(_body(five)).fetchRound();
    expect(qs, hasLength(5));
    expect(qs.first.text, 'Question 0 about the Sun & Moon?');
    expect(qs.first.text.contains('%20'), isFalse);
  });

  test('four results are rejected', () async {
    expect(_client(_body(five.take(4).toList())).fetchRound(),
        throwsA(isA<TriviaException>()));
  });

  test('nonzero response code is rejected', () async {
    expect(_client(_body(five, code: 5)).fetchRound(), throwsA(isA<TriviaException>()));
  });

  test('malformed percent encoding is rejected as invalid data', () async {
    final bad = [...five];
    bad[0] = bad[0].replaceFirst('Question%200', 'Broken%E0%A4%A');
    expect(_client(_body(bad)).fetchRound(), throwsA(isA<TriviaException>()));
  });

  test('answer set must be exactly True and False', () async {
    final bad = [...five];
    bad[2] = _q('x?', correct: 'True', wrong: 'True');
    expect(_client(_body(bad)).fetchRound(), throwsA(isA<TriviaException>()));
  });

  test('non 200 status is rejected', () async {
    expect(_client('{}', status: 500).fetchRound(), throwsA(isA<TriviaException>()));
  });
}
