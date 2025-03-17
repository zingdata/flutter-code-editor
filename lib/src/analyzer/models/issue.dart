import 'dart:core';

import 'package:flutter_code_editor/src/analyzer/models/issue_type.dart';

class Issue {

  const Issue({
    required this.line,
    required this.message,
    required this.type,
    this.suggestion,
    this.url,
  });
  final int line;
  final String message;
  final IssueType type;
  final String? suggestion;
  final String? url;
}

Comparator<Issue> issueLineComparator = (issue1, issue2) {
  return issue1.line - issue2.line;
};
