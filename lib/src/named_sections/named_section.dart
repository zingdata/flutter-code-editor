import 'package:equatable/equatable.dart';

import 'package:flutter_code_editor/src/util/inclusive_range.dart';

class NamedSection extends InclusiveRange with EquatableMixin {
  const NamedSection({
    required this.firstLine,
    required this.lastLine,
    required this.name,
  });

  /// Zero-based index of the line with the starting tag.
  final int firstLine;

  /// Zero-based index of the line with the ending tag.
  /// `null` if the section spans till the end of the document.
  final int? lastLine;

  final String name;

  @override
  int get first => firstLine;

  @override
  int? get last => lastLine;

  @override
  List<Object?> get props => [
        firstLine,
        lastLine,
        name,
      ];

  @override
  String toString() => '$firstLine-$lastLine: "$name"';
}
