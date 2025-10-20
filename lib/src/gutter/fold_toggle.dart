import 'package:flutter/material.dart';

import 'package:flutter_code_editor/src/gutter/clickable.dart';

class FoldToggle extends StatelessWidget {
  const FoldToggle({
    super.key,
    required this.color,
    required this.isFolded,
    required this.onTap,
  });
  final Color? color;
  final bool isFolded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClickableWidget(
      onTap: onTap,
      child: RotatedBox(
        quarterTurns: isFolded ? 0 : 1,
        child: Icon(
          Icons.chevron_right,
          color: color,
          size: 16,
        ),
      ),
    );
  }
}
