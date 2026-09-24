import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'avatar_cache.dart';
import 'initials_avatar.dart';

/// Profile photo of the account that owns [email] (any module), with the
/// initials circle as placeholder and fallback. Photos come from
/// [avatarCacheProvider], so repeated rows cost one request per address.
class UserAvatar extends ConsumerStatefulWidget {
  const UserAvatar({
    super.key,
    required this.email,
    this.label,
    this.radius = 20,
    this.excludeFromSemantics = false,
    this.domainLogo = false,
  });

  final String email;

  /// Name for the initials; the address when null.
  final String? label;
  final double radius;

  /// True inside rows that already speak the name: the avatar adds nothing
  /// for screen readers. Otherwise the photo and the initials fallback are
  /// both announced as the same image with the name.
  final bool excludeFromSemantics;

  /// Without a photo, the mark of the sender's domain before the initials
  /// (desktop mail, as the web's message list).
  final bool domainLogo;

  @override
  ConsumerState<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends ConsumerState<UserAvatar> {
  Uint8List? _bytes;
  Uint8List? _logo;
  bool _imageFailed = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (AvatarCache.normalize(oldWidget.email) !=
        AvatarCache.normalize(widget.email)) {
      _bytes = null;
      _logo = null;
      _imageFailed = false;
      _resolve();
    }
  }

  void _resolve() {
    final cache = ref.read(avatarCacheProvider);
    final email = widget.email;
    final peeked = cache.peek(email);
    if (peeked != null && peeked.hasPhoto) _bytes = peeked.bytes;
    cache.photo(email).then((bytes) {
      if (!mounted || widget.email != email) return;
      if (!identical(bytes, _bytes)) setState(() => _bytes = bytes);
      if (bytes == null && widget.domainLogo) _resolveLogo(email);
    });
  }

  void _resolveLogo(String email) {
    ref.read(domainLogoCacheProvider).logo(email).then((logo) {
      if (!mounted || widget.email != email || logo == null) return;
      setState(() => _logo = logo);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    final name = widget.label?.trim().isNotEmpty == true
        ? widget.label!
        : widget.email;
    final initials = InitialsAvatar(
      label: name,
      colorKey: AvatarCache.normalize(widget.email),
      radius: widget.radius,
      semanticLabel: widget.excludeFromSemantics ? null : name,
    );
    final logo = _logo;
    if ((bytes == null || _imageFailed) && logo != null) {
      final mark = CircleAvatar(
        radius: widget.radius,
        backgroundColor: Colors.white,
        child: Image.memory(
          logo,
          width: widget.radius * 1.1,
          height: widget.radius * 1.1,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) => initials,
        ),
      );
      if (widget.excludeFromSemantics) return ExcludeSemantics(child: mark);
      return Semantics(label: name, image: true, child: mark);
    }
    if (bytes == null || _imageFailed) return initials;
    final photo = CircleAvatar(
      radius: widget.radius,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      backgroundImage: MemoryImage(bytes),
      onBackgroundImageError: (_, _) {
        if (mounted) setState(() => _imageFailed = true);
      },
    );
    if (widget.excludeFromSemantics) return ExcludeSemantics(child: photo);
    return Semantics(label: name, image: true, child: photo);
  }
}
