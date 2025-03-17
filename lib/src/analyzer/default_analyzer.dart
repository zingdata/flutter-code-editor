import 'package:flutter_code_editor/src/code/code.dart';

import 'package:flutter_code_editor/src/analyzer/abstract.dart';
import 'package:flutter_code_editor/src/analyzer/models/analysis_result.dart';

class DefaultLocalAnalyzer extends AbstractAnalyzer {
  const DefaultLocalAnalyzer();

  @override
  Future<AnalysisResult> analyze(Code code) async {
    final issues = code.invalidBlocks.map((e) => e.issue).toList(
          growable: false,
        );
    return AnalysisResult(issues: issues);
  }
}
