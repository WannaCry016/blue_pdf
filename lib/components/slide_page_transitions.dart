import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

/// Pages slide in from the right and back out to the right. The Android back
/// gesture drags the page along with the finger, revealing the page beneath,
/// instead of Flutter's default of shrinking the page into a card.
class SlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const SlidePageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _SlideTransition(route: route, animation: animation, secondaryAnimation: secondaryAnimation, child: child);
  }
}

/// Slides [child] with the route's animations, and drives those animations from
/// the system back gesture while one is in progress.
class _SlideTransition extends StatefulWidget {
  const _SlideTransition({
    required this.route,
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  final PageRoute<dynamic> route;
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  State<_SlideTransition> createState() => _SlideTransitionState();
}

class _SlideTransitionState extends State<_SlideTransition> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    final route = widget.route;
    if (backEvent.isButtonEvent || !route.isCurrent || !route.popGestureEnabled) return false;
    route.handleStartBackGesture(progress: 1 - backEvent.progress);
    setState(() {});
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {
    widget.route.handleUpdateBackGestureProgress(progress: 1 - backEvent.progress);
  }

  @override
  void handleCancelBackGesture() => widget.route.handleCancelBackGesture();

  // Flutter's own commit restarts the exit from fully open; this finishes the
  // slide from where the finger let go instead.
  @override
  void handleCommitBackGesture() {
    final route = widget.route;
    final navigator = route.navigator;
    if (navigator == null || !route.isCurrent) return;
    navigator.pop();
    final animation = widget.animation;
    if (!animation.isAnimating) return navigator.didStopUserGesture();
    late final AnimationStatusListener settled;
    settled = (status) {
      if (status.isAnimating) return;
      animation.removeStatusListener(settled);
      navigator.didStopUserGesture();
    };
    animation.addStatusListener(settled);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageTransition(
      primaryRouteAnimation: widget.animation,
      secondaryRouteAnimation: widget.secondaryAnimation,
      // Stays linear until the gesture's settle animation ends; a curve would
      // make the page lag behind the finger and jump on release.
      linearTransition: widget.route.popGestureInProgress,
      child: widget.child,
    );
  }
}
