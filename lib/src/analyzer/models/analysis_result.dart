import 'package:flutter_code_editor/src/analyzer/models/issue.dart';

class AnalysisResult {

  const AnalysisResult({
    required this.issues,
  });
  final List<Issue> issues;
}
