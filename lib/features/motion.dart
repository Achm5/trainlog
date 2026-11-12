import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/planning.dart';

/// Переход между экранами: мягкое проявление со сдвигом.
class FadeSlideTransitionsBuilder extends PageTransitionsBuilder {
  const FadeSlideTransitionsBuilder();

  static final _fade = CurveTween(curve: Curves.easeOutCubic);
  static final _slide =
      Tween<Offset>(begin: const Offset(0.07, 0), end: Offset.zero).chain(CurveTween(curve: Curves.easeOutCubic));
  static final _out =
      Tween<Offset>(begin: Offset.zero, end: const Offset(-0.04, 0)).chain(CurveTween(curve: Curves.easeOutCubic));

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: secondaryAnimation.drive(_out),
      child: FadeTransition(
        opacity: animation.drive(_fade),
        child: SlideTransition(position: animation.drive(_slide), child: child),
      ),
    );
  }
}

/// Появление карточки: проявление с подъёмом. [index] задаёт задержку для каскада в списке.
class Appear extends StatefulWidget {
  const Appear({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;

  @override
  State<Appear> createState() => _AppearState();
}

class _AppearState extends State<Appear> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
  late final _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  Timer? _delay;

  @override
  void initState() {
    super.initState();
    final i = widget.index > 8 ? 8 : widget.index;
    _delay = Timer(Duration(milliseconds: 45 * i), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(_curve),
        child: widget.child,
      ),
    );
  }
}

/// Короткое поздравление с новым рекордом расчётного 1ПМ поверх экрана.
void showRecordCelebration(BuildContext context, String exercise, double e1rmKg) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  HapticFeedback.heavyImpact();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _RecordBanner(exercise: exercise, e1rmKg: e1rmKg, onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _RecordBanner extends StatefulWidget {
  const _RecordBanner({required this.exercise, required this.e1rmKg, required this.onDone});
  final String exercise;
  final double e1rmKg;
  final VoidCallback onDone;

  @override
  State<_RecordBanner> createState() => _RecordBannerState();
}

class _RecordBannerState extends State<_RecordBanner> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.6, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 35),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 65),
    ]).animate(_controller);
    final opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_controller);
    return IgnorePointer(
      child: Center(
        child: FadeTransition(
          opacity: opacity,
          child: ScaleTransition(
            scale: scale,
            child: Material(
              elevation: 12,
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emoji_events, size: 56, color: Color(0xFFF2B01E)),
                    const SizedBox(height: 8),
                    Text('Новый рекорд!', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Text(widget.exercise, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                    Text('Расчётный 1ПМ: ${formatKg((widget.e1rmKg * 10).round() / 10)} кг',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.primary)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
