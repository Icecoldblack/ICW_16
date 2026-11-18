import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'dev_faults.dart';

class TriviaException implements Exception {
  TriviaException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// One decoded Science & Nature true/false question.
class ScienceQuestion {
  const ScienceQuestion({required this.text, required this.correctAnswer});
  final String text;
  final String correctAnswer;

  /// Validates and decodes one raw result. Endpoint uses encode=url3986, so
  /// every string is percent-encoded and must go through Uri.decodeComponent
  /// (an HTML unescaper would leave %20 and friends in the text).
  factory ScienceQuestion.fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      throw TriviaException('A question entry was not an object.');
    }
    String decode(String key) {
      final v = raw[key];
      if (v is! String) throw TriviaException('Field "$key" is missing.');
      try {
        return Uri.decodeComponent(v).trim();
      } on ArgumentError {
        throw TriviaException('Field "$key" has malformed percent encoding.');
      }
    }

    final category = decode('category');
    final difficulty = decode('difficulty');
    final type = decode('type');
    final text = decode('question');
    final correct = decode('correct_answer');
    final incorrect = raw['incorrect_answers'];

    if (category != 'Science & Nature') {
      throw TriviaException('Unexpected category "$category".');
    }
    if (difficulty != 'medium') {
      throw TriviaException('Unexpected difficulty "$difficulty".');
    }
    if (type != 'boolean') throw TriviaException('Unexpected type "$type".');
    if (text.isEmpty) throw TriviaException('A question was empty.');
    if (incorrect is! List || incorrect.length != 1 || incorrect.first is! String) {
      throw TriviaException('A question did not have exactly one incorrect answer.');
    }
    final String wrong;
    try {
      wrong = Uri.decodeComponent(incorrect.first as String).trim();
    } on ArgumentError {
      throw TriviaException('Incorrect answer has malformed percent encoding.');
    }
    if (!({correct, wrong}.length == 2 &&
        {correct, wrong}.containsAll(const ['True', 'False']))) {
      throw TriviaException('Answer set was not exactly True and False.');
    }
    return ScienceQuestion(text: text, correctAnswer: correct);
  }
}

class OpenTdbClient {
  OpenTdbClient({http.Client? client, DevFaults? faults})
      : _http = client ?? http.Client(),
        _faults = faults;

  static const int questionCount = 5;
  static const Duration minGap = Duration(seconds: 5);
  static const Duration timeout = Duration(seconds: 10);

  final http.Client _http;
  final DevFaults? _faults;
  DateTime? _lastCall;

  Duration get cooldownRemaining {
    final last = _lastCall;
    if (last == null) return Duration.zero;
    final left = minGap - DateTime.now().difference(last);
    return left.isNegative ? Duration.zero : left;
  }

  static final Uri endpoint = Uri.https('opentdb.com', '/api.php', {
    'amount': '$questionCount',
    'category': '17',
    'difficulty': 'medium',
    'type': 'boolean',
    'encode': 'url3986',
  });

  Future<List<ScienceQuestion>> fetchRound() async {
    _lastCall = DateTime.now();
    final http.Response response;
    try {
      response = await _http.get(endpoint).timeout(timeout);
    } on TimeoutException {
      throw TriviaException('The trivia request timed out after 10 seconds.');
    } catch (e) {
      throw TriviaException('Could not reach the trivia service ($e).');
    }
    if (response.statusCode != 200) {
      throw TriviaException('Trivia service returned HTTP ${response.statusCode}.');
    }

    Object? body;
    try {
      body = jsonDecode(response.body);
    } on FormatException {
      throw TriviaException('Trivia response was not valid JSON.');
    }
    if (body is! Map<String, dynamic>) {
      throw TriviaException('Trivia response had an unexpected shape.');
    }
    body = _applyFault(body);

    final code = body['response_code'];
    if (code != 0) throw TriviaException(_codeMessage(code));
    final results = body['results'];
    if (results is! List || results.length != questionCount) {
      throw TriviaException(
          'Expected exactly $questionCount questions but got ${results is List ? results.length : 0}.');
    }
    return results.map(ScienceQuestion.fromJson).toList(growable: false);
  }

  /// Development-only payload injection. Mutates a copy of the real response so
  /// the same validation code path rejects it.
  Map<String, dynamic> _applyFault(Map<String, dynamic> body) {
    final fault = _faults?.takeTrivia() ?? TriviaFault.none;
    if (fault == TriviaFault.none) return body;
    final copy = jsonDecode(jsonEncode(body)) as Map<String, dynamic>;
    final results = (copy['results'] as List?) ?? <dynamic>[];
    switch (fault) {
      case TriviaFault.badEncoding:
        if (results.isNotEmpty) {
          (results.first as Map<String, dynamic>)['question'] = 'Broken%E0%A4%A text';
        }
      case TriviaFault.nonzeroCode:
        copy['response_code'] = 5;
      case TriviaFault.fourResults:
        if (results.isNotEmpty) results.removeLast();
      case TriviaFault.none:
        break;
    }
    return copy;
  }

  String _codeMessage(Object? code) {
    switch (code) {
      case 1:
        return 'Not enough questions available (API code 1).';
      case 2:
        return 'Invalid request parameter (API code 2).';
      case 5:
        return 'Too many requests (API code 5). Wait a few seconds, then retry.';
      default:
        return 'Trivia service returned API code $code.';
    }
  }
}
