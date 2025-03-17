import 'dart:async';

import 'package:flutter_code_editor/src/code/code.dart';
import 'package:flutter_code_editor/src/code_field/code_controller/code_controller.dart';
import 'package:flutter_code_editor/src/code_field/code_field.dart';
import 'package:flutter_code_editor/src/analyzer/models/analysis_result.dart';

/// Service for analyzing the code inside [CodeField].
///
/// Inherit and implement [analyze] method to use in [CodeController].
abstract class AbstractAnalyzer {
  const AbstractAnalyzer();

  /// Analyzes the code and generates new list of issues.
  Future<AnalysisResult> analyze(Code code);

  void dispose() {}
}
