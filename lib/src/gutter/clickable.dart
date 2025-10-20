import 'package:flutter/widgets.dart';

/// MouseRegion + GestureDetector.
class ClickableWidget extends StatelessWidget {
  const ClickableWidget({
    super.key,
    required this.child,
    required this.onTap,
  });
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: child,
      ),
    );
  }
}
