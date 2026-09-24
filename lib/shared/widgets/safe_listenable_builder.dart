import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// [ListenableBuilder] that survives a notification arriving while a frame
/// is already building.
///
/// The router announces its first route while the widget tree that listens
/// to it is still being built (the desktop shell around every page, the
/// lock gate above it). A plain ListenableBuilder then trips «setState()
/// called during build». Here such a notification is applied right after
/// the frame instead; every other notification rebuilds at once, exactly
/// as ListenableBuilder does.
class SafeListenableBuilder extends StatefulWidget {
  const SafeListenableBuilder({super.key, required this.listenable, required this.builder, this.child});

  final Listenable listenable;
  final TransitionBuilder builder;
  final Widget? child;

  @override
  State<SafeListenableBuilder> createState() => _SafeListenableBuilderState();
}

class _SafeListenableBuilderState extends State<SafeListenableBuilder> {
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    widget.listenable.addListener(_changed);
  }

  @override
  void didUpdateWidget(SafeListenableBuilder old) {
    super.didUpdateWidget(old);
    if (old.listenable != widget.listenable) {
      old.listenable.removeListener(_changed);
      widget.listenable.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks || phase == SchedulerPhase.midFrameMicrotasks) {
      if (_scheduled) return;
      _scheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _scheduled = false;
        if (mounted) setState(() {});
      });
      return;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, widget.child);
}
