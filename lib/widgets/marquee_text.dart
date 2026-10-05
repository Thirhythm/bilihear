import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';

/// Single line text that scrolls like a marquee **only when it does not fit**.
///
/// Short labels stay perfectly still, so nothing moves for content that already
/// fits the available width.
class MarqueeText extends StatelessWidget {
  const MarqueeText({
    super.key,
    required this.text,
    this.style,
    this.velocity = 40,
    this.blankSpace = 48,
    this.pauseAfterRound = const Duration(seconds: 1),
    this.alignment = Alignment.centerLeft,
  });

  final String text;
  final TextStyle? style;

  /// Scrolling speed in logical pixels per second.
  final double velocity;

  /// Gap inserted between repetitions of the text.
  final double blankSpace;

  /// Pause once a full round has been shown.
  final Duration pauseAfterRound;

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        // Without a bounded width the text cannot be measured meaningfully.
        if (!maxWidth.isFinite || maxWidth <= 0) {
          return Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: effectiveStyle,
          );
        }

        final painter = TextPainter(
          text: TextSpan(text: text, style: effectiveStyle),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();

        if (painter.width <= maxWidth) {
          return Container(
            alignment: alignment,
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: effectiveStyle,
            ),
          );
        }

        // `Marquee` lays the text out in a horizontal viewport, which requires
        // a bounded height; the measured line height supplies it.
        return SizedBox(
          height: painter.height,
          child: Marquee(
            text: text,
            style: effectiveStyle,
            velocity: velocity,
            blankSpace: blankSpace,
            pauseAfterRound: pauseAfterRound,
            fadingEdgeStartFraction: 0.05,
            fadingEdgeEndFraction: 0.05,
          ),
        );
      },
    );
  }
}
