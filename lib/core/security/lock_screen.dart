import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/desktop.dart';
import '../platform/desktop_settings.dart';
import '../theme/skin_backdrop.dart';
import '../../features/calls/presentation/calls_providers.dart';
import '../../shared/widgets/brand_logo.dart';
import '../../shared/widgets/safe_listenable_builder.dart';
import '../auth/auth_providers.dart';
import '../lifecycle/app_visibility.dart';
import '../localization/localization.dart';
import '../preferences/app_preferences.dart';
import '../routing/app_router.dart';
import '../routing/routes.dart';
import '../theme/tokens.dart';
import 'app_lock.dart';

/// Sits above the router (MaterialApp.builder): shows [LockScreen] over the
/// app while locked, and a neutral cover in the app switcher when the user
/// asked to hide content. The app below keeps its state.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  late final AppLifecycleListener _lifecycle;
  bool _inBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
    if (ref.read(appPreferencesProvider).hideInSwitcher) {
      unawaited(WindowSecurity.setSecure(true));
    }
    if (isDesktop) DesktopTray.instance.onClosedToTray = _onClosedToTray;
  }

  @override
  void dispose() {
    if (DesktopTray.instance.onClosedToTray == _onClosedToTray) {
      DesktopTray.instance.onClosedToTray = null;
    }
    _lifecycle.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Desktop «Запрашивать PIN при закрытии окна»: the «X» hides the window
  /// to the tray, and with the setting on the app locks at that moment, so
  /// the window comes back asking for the PIN whatever the lock timeout.
  void _onClosedToTray() {
    if (ref.read(appPreferencesProvider).lockOnClose) {
      ref.read(appLockProvider.notifier).lockNow();
    }
  }

  void _onLifecycle(AppLifecycleState state) {
    final lock = ref.read(appLockProvider.notifier);
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        lock.onBackground();
      case AppLifecycleState.resumed:
        lock.onForeground();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
    // A desktop window is «inactive» whenever another window has focus:
    // only a minimized / hidden window counts as background there.
    final background = isDesktop
        ? state == AppLifecycleState.hidden || state == AppLifecycleState.paused
        : state != AppLifecycleState.resumed;
    if (background != _inBackground && mounted) {
      setState(() => _inBackground = background);
    }
  }

  bool _callOnTop() {
    if (!ref.read(callsEnabledProvider) || !ref.read(callControllerProvider).inCall) return false;
    return ref.read(appRouterProvider).routeInformationProvider.value.uri.path == Routes.call;
  }

  bool get _lockVisible =>
      ref.read(appLockProvider).locked &&
      ref.read(authSessionProvider).isAuthenticated &&
      !_callOnTop();

  /// Android back must not pop routes hidden behind the lock screen.
  @override
  Future<bool> didPopRoute() async => _lockVisible;

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(
      appPreferencesProvider.select((p) => p.hideInSwitcher),
      (_, hide) => unawaited(WindowSecurity.setSecure(hide)),
    );
    final hideInSwitcher = ref.watch(
      appPreferencesProvider.select((p) => p.hideInSwitcher),
    );
    final locked = ref.watch(appLockProvider).locked;
    final session = ref.watch(authSessionProvider);
    final inCall = ref.watch(callsEnabledProvider) &&
        ref.watch(callControllerProvider.select((s) => s.inCall));
    final location = ref.watch(appRouterProvider).routeInformationProvider;
    return SafeListenableBuilder(
      listenable: Listenable.merge([session, location]),
      builder: (context, _) {
        // A ringing or running call stays usable over the lock (answer, mute,
        // hang up); leaving the call screen brings the lock back.
        final callOnTop = inCall && location.value.uri.path == Routes.call;
        final showLock = locked && session.isAuthenticated && !callOnTop;
        final cover = !showLock && hideInSwitcher && _inBackground;
        return Stack(
          children: [
            Positioned.fill(
              child: ExcludeSemantics(
                excluding: showLock,
                child: TickerMode(enabled: !showLock, child: widget.child),
              ),
            ),
            if (showLock) const Positioned.fill(child: LockScreen()),
            if (cover) const Positioned.fill(child: _PrivacyCover()),
          ],
        );
      },
    );
  }
}

class _PrivacyCover extends StatelessWidget {
  const _PrivacyCover();

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('privacy_cover'),
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Icon(LucideIcons.lock, size: 56, color: context.tokens.brand),
      ),
    );
  }
}

/// PIN entry over the app. No Navigator/Overlay above it, so everything
/// (including the "forgot PIN" confirmation) is inline.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _entered = '';
  int _length = 4;
  String? _error;
  DateTime? _retryAt;
  ForegroundPeriodic? _tick;
  bool _busy = false;
  bool _confirmForgot = false;
  int _wrongCount = 0;

  @override
  void initState() {
    super.initState();
    final vault = ref.read(pinVaultProvider);
    unawaited(
      vault.pinLength().then((l) {
        if (mounted && l != null) setState(() => _length = l);
      }),
    );
    unawaited(
      vault.retryAt().then((at) {
        if (mounted && at != null) _throttle(at);
      }),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _biometric());
    // Desktop: digits and Backspace from the keyboard, whatever has focus
    // (the page under the lock may hold it; the lock has no Navigator of
    // its own to take it).
    if (isDesktop) HardwareKeyboard.instance.addHandler(_hardwareKey);
  }

  @override
  void dispose() {
    if (isDesktop) HardwareKeyboard.instance.removeHandler(_hardwareKey);
    _tick?.dispose();
    super.dispose();
  }

  // Not const: LogicalKeyboardKey overrides ==, which a const map forbids.
  static final _numpad = <LogicalKeyboardKey, String>{
    LogicalKeyboardKey.numpad0: '0',
    LogicalKeyboardKey.numpad1: '1',
    LogicalKeyboardKey.numpad2: '2',
    LogicalKeyboardKey.numpad3: '3',
    LogicalKeyboardKey.numpad4: '4',
    LogicalKeyboardKey.numpad5: '5',
    LogicalKeyboardKey.numpad6: '6',
    LogicalKeyboardKey.numpad7: '7',
    LogicalKeyboardKey.numpad8: '8',
    LogicalKeyboardKey.numpad9: '9',
  };

  /// A pressed key as a PIN digit: the digit row, the numeric keypad, or
  /// null for anything else.
  static String? digitOf(KeyEvent e) {
    final ch = e.character;
    if (ch != null && ch.length == 1 && ch.codeUnitAt(0) >= 0x30 && ch.codeUnitAt(0) <= 0x39) return ch;
    return _numpad[e.logicalKey];
  }

  bool _hardwareKey(KeyEvent e) {
    if (e is! KeyDownEvent || !mounted || _confirmForgot) return false;
    if (e.logicalKey == LogicalKeyboardKey.backspace) {
      _delete();
      return true;
    }
    final digit = digitOf(e);
    if (digit == null) return false;
    _digit(digit);
    return true;
  }

  DateTime _now() => ref.read(lockClockProvider)();

  int get _secondsLeft {
    final at = _retryAt;
    if (at == null) return 0;
    final s = (at.difference(_now()).inMilliseconds / 1000).ceil();
    return s < 0 ? 0 : s;
  }

  void _throttle(DateTime at) {
    _tick?.dispose();
    setState(() {
      _retryAt = at;
      _error = null;
    });
    // Countdown of the PIN lockout; no ticks while the app is hidden (the
    // remaining time is computed from the clock on return).
    _tick = ForegroundPeriodic(ref.read(appVisibilityProvider), const Duration(seconds: 1), () {
      if (!mounted) return _tick?.dispose();
      if (_secondsLeft == 0) {
        _tick?.dispose();
        setState(() => _retryAt = null);
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _biometric() async {
    if (!mounted || !ref.read(appPreferencesProvider).biometricEnabled) return;
    await ref
        .read(appLockProvider.notifier)
        .unlockWithBiometrics(context.l10n.lockBiometricReason);
  }

  void _digit(String d) {
    if (_busy || _secondsLeft > 0 || _entered.length >= _length) return;
    HapticFeedback.selectionClick();
    setState(() {
      _entered += d;
      _error = null;
    });
    if (_entered.length == _length) unawaited(_submit());
  }

  void _delete() {
    if (_busy || _entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final l10n = context.l10n;
    final check = await ref.read(appLockProvider.notifier).submit(_entered);
    if (!mounted) return;
    setState(() {
      _entered = '';
      _busy = false;
    });
    switch (check.result) {
      case PinCheckResult.wrong:
        HapticFeedback.heavyImpact();
        setState(() {
          _error = l10n.lockWrong(check.attemptsLeft);
          _wrongCount++;
        });
      case PinCheckResult.throttled:
        if (check.retryAt != null) _throttle(check.retryAt!);
      case PinCheckResult.ok:
      case PinCheckResult.exhausted:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final biometric = ref.watch(
      appPreferencesProvider.select((p) => p.biometricEnabled),
    );
    final name = ref.watch(authSessionProvider).user?.displayName.trim() ?? '';
    final inCall = ref.watch(callsEnabledProvider) &&
        ref.watch(callControllerProvider.select((s) => s.inCall));
    final wait = _secondsLeft;
    final message = wait > 0 ? l10n.lockThrottled(wait) : _error;

    final body = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (inCall) ...[
                    FilledButton.tonalIcon(
                      key: const Key('lock_return_to_call'),
                      style: FilledButton.styleFrom(
                        backgroundColor: tokens.successSoft,
                        foregroundColor: tokens.success,
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () => ref.read(appRouterProvider).push(Routes.call),
                      icon: const Icon(LucideIcons.phone, size: 18),
                      label: Text(l10n.lockReturnToCall),
                    ),
                    const SizedBox(height: Space.lg),
                  ],
                  ExcludeSemantics(
                    child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: tokens.surface,
                      shape: BoxShape.circle,
                      boxShadow: tokens.shadowSm,
                      border: Border.all(color: tokens.border, width: tokens.borderWidth),
                    ),
                    alignment: Alignment.center,
                    child: BrandMark(size: 40, color: tokens.mark),
                  ),
                  ),
                  const SizedBox(height: Space.md),
                  if (name.isNotEmpty) ...[
                    Text(
                      l10n.lockGreeting(name),
                      style: theme.textTheme.titleMedium?.copyWith(color: tokens.textSecondary),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: Space.xs),
                  ],
                  Text(
                    l10n.lockTitle,
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Space.lg),
                  _Shake(
                    trigger: _wrongCount,
                    child: PinDots(length: _length, filled: _entered.length, error: message != null && wait == 0),
                  ),
                  const SizedBox(height: Space.md),
                  // Min height (not fixed): a wrapped error must not clip at
                  // large text.
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 40),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        message ?? '',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: tokens.danger,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  if (_confirmForgot)
                    _ForgotConfirm(
                      onCancel: () => setState(() => _confirmForgot = false),
                      onConfirm: () =>
                          ref.read(appLockProvider.notifier).forgotPin(),
                    )
                  else ...[
                    PinPad(
                      enabled: !_busy && wait == 0,
                      // Desktop: the lock listens to the keyboard itself.
                      keyboard: !isDesktop,
                      onDigit: _digit,
                      onDelete: _delete,
                      leading: biometric
                          ? PinPadKey(
                              key: const Key('lock_biometric'),
                              semanticLabel: l10n.lockBiometric,
                              onPressed: _biometric,
                              child: Icon(LucideIcons.fingerprint, size: 32, color: tokens.primary),
                            )
                          : null,
                    ),
                    const SizedBox(height: Space.sm),
                    TextButton(
                      onPressed: () => setState(() => _confirmForgot = true),
                      child: Text(l10n.lockForgot),
                    ),
                  ],
                ],
              );

    if (isDesktop) {
      // The lock sits above the whole shell, glass backdrop included, and
      // tokens.appBg is translucent on a glass skin: painted alone it let the
      // page show through the PIN pad. So the lock paints the skin's own
      // picture, frosts it, and puts the PIN in a card — a proper lock
      // screen rather than a veil.
      final glass = tokens.glass;
      final custom = ref.watch(desktopSettingsProvider.select((s) => s.backdrop));
      return Material(
        key: const Key('lock_screen'),
        color: tokens.overlaySurface,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (glass != null)
              SkinBackdropView(backdrop: glass.backdrop, custom: custom)
            else
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [tokens.primarySoft, tokens.appBg],
                  ),
                ),
              ),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: ColoredBox(color: tokens.appBg.withValues(alpha: glass != null ? 0.45 : 0.35)),
            ),
            // The card keeps its proportions and shrinks as a whole when
            // the window is small, rather than scrolling its PIN pad out of
            // sight.
            Center(
              child: Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Container(
                    width: 380,
                    padding: const EdgeInsets.fromLTRB(Space.xl, Space.xl, Space.xl, Space.md),
                    decoration: BoxDecoration(
                      color: tokens.overlaySurface,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: tokens.border, width: tokens.borderWidth),
                      boxShadow: tokens.shadowSm,
                    ),
                    child: body,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Phone: the glass of the tab bar — soft colour under frosted glass,
    // the PIN pad's keys are drops of glass on it.
    Widget blob(Color color, double size) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
    return Material(
      key: const Key('lock_screen'),
      color: tokens.appBg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [tokens.primarySoft, tokens.appBg],
                stops: const [0, 0.7],
              ),
            ),
          ),
          Positioned(top: -60, left: -40, child: blob(tokens.primary.withValues(alpha: 0.35), 260)),
          Positioned(bottom: 40, right: -70, child: blob(tokens.info.withValues(alpha: 0.28), 280)),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: const SizedBox.expand(),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Space.lg),
                child: body,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal shake when [trigger] changes (wrong PIN).
class _Shake extends StatelessWidget {
  const _Shake({required this.trigger, required this.child});
  final int trigger;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (trigger == 0 || (MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      return child;
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey(trigger),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      builder: (_, v, child) => Transform.translate(
        offset: Offset(math.sin(v * math.pi * 6) * (1 - v) * 14, 0),
        child: child,
      ),
      child: child,
    );
  }
}

class _ForgotConfirm extends StatelessWidget {
  const _ForgotConfirm({required this.onCancel, required this.onConfirm});

  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.lockForgotConfirm, textAlign: TextAlign.center),
            const SizedBox(height: Space.md),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: Space.sm,
              children: [
                TextButton(onPressed: onCancel, child: Text(l10n.cancel)),
                FilledButton(
                  onPressed: onConfirm,
                  child: Text(l10n.lockForgotSignOut),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.length, required this.filled, this.error = false});

  final int length;
  final int filled;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = error ? t.danger : t.brand;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Semantics(
      label: context.l10n.a11yPinEntered(filled, length),
      liveRegion: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < length; i++)
            AnimatedContainer(
              duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 160),
              curve: Curves.easeOutBack,
              width: i < filled ? 16 : 14,
              height: i < filled ? 16 : 14,
              margin: const EdgeInsets.symmetric(horizontal: Space.sm),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < filled ? color : Colors.transparent,
                border: Border.all(color: color, width: 2),
              ),
            ),
        ],
      ),
    );
  }
}

class PinPadKey extends StatelessWidget {
  const PinPadKey({
    super.key,
    required this.child,
    required this.semanticLabel,
    this.onPressed,
  });

  final Widget child;
  final String semanticLabel;
  final VoidCallback? onPressed;

  static const size = 72.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      // excludeSemantics drops the InkWell's own action, so the tap is
      // exposed here for TalkBack / VoiceOver activation.
      onTap: onPressed,
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        // Desktop: a filled key that lights up under the pointer; phone: a
        // drop of glass (see-through fill and a light rim).
        child: isDesktop
            ? Material(
                color: onPressed == null ? Colors.transparent : context.tokens.surfaceSubtle,
                shape: CircleBorder(side: BorderSide(color: context.tokens.border, width: context.tokens.borderWidth)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  hoverColor: context.tokens.surfaceHover,
                  onTap: onPressed,
                  child: Center(child: child),
                ),
              )
            : Material(
                color: onPressed == null
                    ? Colors.transparent
                    : context.tokens.surface.withValues(
                        alpha: Theme.of(context).brightness == Brightness.dark ? 0.28 : 0.55,
                      ),
                shape: CircleBorder(
                  side: BorderSide(
                    color: Colors.white.withValues(
                      alpha: Theme.of(context).brightness == Brightness.dark ? 0.18 : 0.7,
                    ),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onPressed,
                  child: Center(child: child),
                ),
              ),
      ),
    );
  }
}

/// 3×4 digit pad shared by the lock screen and PIN setup.
class PinPad extends StatelessWidget {
  const PinPad({
    super.key,
    required this.onDigit,
    required this.onDelete,
    this.leading,
    this.enabled = true,
    this.keyboard = true,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final Widget? leading;
  final bool enabled;

  /// Desktop: take digits and Backspace from the keyboard through focus.
  /// Off where a screen listens to the keyboard itself (the lock screen,
  /// which has no focus of its own): Flutter hands a key to both the
  /// hardware-keyboard handlers and the focused widget, and a digit typed
  /// once must not be entered twice.
  final bool keyboard;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.headlineSmall;
    Widget digit(String d) => PinPadKey(
      key: Key('pin_key_$d'),
      semanticLabel: d,
      onPressed: enabled ? () => onDigit(d) : null,
      child: Text(d, style: style, textScaler: TextScaler.noScaling),
    );
    Widget row(List<Widget> keys) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final k in keys)
          Padding(
            padding: const EdgeInsets.all(Space.xs),
            child: k,
          ),
      ],
    );
    // Desktop: the keyboard's digits and Backspace work too.
    return Focus(
      autofocus: isDesktop && keyboard,
      canRequestFocus: isDesktop && keyboard,
      onKeyEvent: (_, e) {
        if (!keyboard || !enabled || e is! KeyDownEvent) return KeyEventResult.ignored;
        if (e.logicalKey == LogicalKeyboardKey.backspace) {
          onDelete();
          return KeyEventResult.handled;
        }
        final ch = e.character;
        if (ch != null && ch.length == 1 && ch.codeUnitAt(0) >= 0x30 && ch.codeUnitAt(0) <= 0x39) {
          onDigit(ch);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row([digit('1'), digit('2'), digit('3')]),
          row([digit('4'), digit('5'), digit('6')]),
          row([digit('7'), digit('8'), digit('9')]),
          row([
            leading ?? const SizedBox(width: PinPadKey.size, height: PinPadKey.size),
            digit('0'),
            PinPadKey(
              key: const Key('pin_key_delete'),
              semanticLabel: context.l10n.lockDelete,
              onPressed: enabled ? onDelete : null,
              child: const Icon(LucideIcons.delete),
            ),
          ]),
        ],
      ),
    );
  }
}

/// New / changed PIN, entered twice. Pops `true` once saved.
class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  static const minLength = 4;
  static const maxLength = 6;

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  String _first = '';
  String _entered = '';
  bool _repeat = false;
  bool _saving = false;
  String? _error;

  void _digit(String d) {
    if (_saving || _entered.length >= PinSetupScreen.maxLength) return;
    setState(() {
      _entered += d;
      _error = null;
    });
    if (_repeat && _entered.length == _first.length) unawaited(_next());
  }

  Future<void> _next() async {
    if (_entered.length < PinSetupScreen.minLength) return;
    if (!_repeat) {
      setState(() {
        _first = _entered;
        _entered = '';
        _repeat = true;
      });
      return;
    }
    if (_entered != _first) {
      setState(() {
        _error = context.l10n.lockSetupMismatch;
        _first = '';
        _entered = '';
        _repeat = false;
      });
      return;
    }
    setState(() => _saving = true);
    await ref.read(appLockProvider.notifier).enable(_first);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final length = _repeat
        ? _first.length
        : (_entered.length < PinSetupScreen.minLength
              ? PinSetupScreen.minLength
              : _entered.length);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.lockSetupTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Space.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _repeat ? l10n.lockSetupRepeat : l10n.lockSetupEnter,
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Space.lg),
                PinDots(length: length, filled: _entered.length),
                const SizedBox(height: Space.md),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error ?? '',
                    style: TextStyle(color: context.tokens.danger),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: Space.md),
                PinPad(
                  enabled: !_saving,
                  onDigit: _digit,
                  onDelete: () {
                    if (_entered.isEmpty) return;
                    setState(
                      () => _entered = _entered.substring(
                        0,
                        _entered.length - 1,
                      ),
                    );
                  },
                ),
                const SizedBox(height: Space.md),
                if (!_repeat)
                  FilledButton(
                    key: const Key('pin_setup_next'),
                    onPressed:
                        _entered.length >= PinSetupScreen.minLength && !_saving
                        ? _next
                        : null,
                    child: Text(l10n.lockSetupNext),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
