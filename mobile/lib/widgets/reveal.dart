import 'package:flutter/material.dart';

/// Brings a screen's contents in, one after another.
///
/// Cards appearing all at once is the difference between a screen that opens
/// and a screen that is simply already there. The stagger is small — a card
/// every 45ms — because the point is that the eye is led down the screen
/// once, not that anybody waits for a performance.
///
/// Honours the platform's reduce-motion switch by rendering everything in
/// place, immediately. That has to be the first thing checked rather than a
/// shorter duration: for somebody with vestibular sensitivity, a fast slide
/// is still a slide.
class Reveal extends StatefulWidget {
  const Reveal({
    super.key,
    required this.child,
    this.index = 0,
    this.step = const Duration(milliseconds: 45),
    this.duration = const Duration(milliseconds: 320),
    this.rise = 14,
  });

  final Widget child;

  /// Position in the run. Later children start later.
  final int index;
  final Duration step;
  final Duration duration;

  /// How far it travels upward, in logical pixels.
  final double rise;

  /// Wraps each of [children] in a [Reveal] with an increasing index.
  static List<Widget> list(
    List<Widget> children, {
    Duration step = const Duration(milliseconds: 45),
  }) {
    var index = 0;
    return <Widget>[
      for (final child in children)
        // Spacers and dividers should not consume a beat of the stagger, or
        // the rhythm reads as uneven for no visible reason.
        if (child is SizedBox && child.child == null)
          child
        else
          Reveal(index: index++, step: step, child: child),
    ];
  }

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  bool _started = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _controller.value = 1;
      return;
    }
    Future<void>.delayed(widget.step * widget.index, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, widget.rise * (1 - t)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
