import 'package:flutter/material.dart';

import '../../../core/theme/app_ui.dart';

class InAppNotificationBanner extends StatelessWidget {
  const InAppNotificationBanner({
    super.key,
    required this.title,
    required this.body,
    this.icon = Icons.notifications_active_outlined,
    this.onTap,
    this.onDismiss,
    this.avatarImageUrl,
    this.fallbackInitial,
    this.fallbackIcon,
    this.showAccentDot = true,
    this.showWatermark = true,
  });

  final String title;
  final String body;
  final IconData? icon;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;
  final String? avatarImageUrl;
  final String? fallbackInitial;
  final IconData? fallbackIcon;
  final bool showAccentDot;
  final bool showWatermark;

  @override
  Widget build(BuildContext context) {
    final resolvedTitle = title.trim().isEmpty ? 'Great news!' : title.trim();
    final resolvedBody = body.trim();
    final resolvedIcon = icon ?? Icons.trending_up_rounded;
    final hasAvatarImage = avatarImageUrl?.trim().isNotEmpty == true;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(32),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.surface,
                    AppColors.navyBg,
                    AppColors.coralAccent.withValues(alpha: 0.12),
                  ],
                  stops: const [0, 0.72, 1],
                ),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: AppColors.coralAccent.withValues(alpha: 0.55),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.coralAccent.withValues(alpha: 0.20),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.30),
                    blurRadius: 26,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(31),
                child: Stack(
                  children: [
                    Positioned(
                      left: -28,
                      top: -22,
                      child: _GlowSpot(size: 92, opacity: 0.08),
                    ),
                    Positioned(
                      right: -34,
                      bottom: -42,
                      child: _GlowSpot(size: 110, opacity: 0.06),
                    ),
                    if (showWatermark)
                      Positioned(
                        right: 34,
                        top: 5,
                        child: Text(
                          'W',
                          style: TextStyle(
                            color: AppColors.white.withValues(alpha: 0.035),
                            fontSize: 96,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          _BannerAvatar(
                            imageUrl: hasAvatarImage
                                ? avatarImageUrl!.trim()
                                : null,
                            icon: hasAvatarImage
                                ? fallbackIcon
                                : fallbackIcon ?? resolvedIcon,
                            initial: fallbackInitial,
                            showAccentDot: showAccentDot,
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  resolvedTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    height: 1.12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  resolvedBody,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.body.copyWith(
                                    color: AppColors.lightText,
                                    fontSize: 14,
                                    height: 1.22,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (onTap != null) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.coralAccent,
                              size: 25,
                            ),
                          ],
                          if (onDismiss != null) ...[
                            const SizedBox(width: 3),
                            IconButton(
                              onPressed: onDismiss,
                              icon: const Icon(Icons.close_rounded),
                              color: AppColors.lightText,
                              iconSize: 20,
                              constraints: const BoxConstraints.tightFor(
                                width: 34,
                                height: 34,
                              ),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(31),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppColors.white.withValues(alpha: 0.07),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
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

class _GlowSpot extends StatelessWidget {
  const _GlowSpot({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.coralAccent.withValues(alpha: opacity),
      ),
    );
  }
}

class _BannerAvatar extends StatelessWidget {
  const _BannerAvatar({
    required this.imageUrl,
    required this.icon,
    required this.initial,
    required this.showAccentDot,
  });

  final String? imageUrl;
  final IconData? icon;
  final String? initial;
  final bool showAccentDot;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 62,
      height: 62,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.coralAccent.withValues(alpha: 0.18),
                border: Border.all(
                  color: AppColors.coralAccent.withValues(alpha: 0.45),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: ClipOval(
                  child: imageUrl == null
                      ? _AvatarFallback(initial: initial, icon: icon)
                      : Image.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _AvatarFallback(initial: initial, icon: icon),
                        ),
                ),
              ),
            ),
          ),
          if (showAccentDot)
            Positioned(
              top: 3,
              right: 3,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.coralAccent,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.initial, required this.icon});

  final String? initial;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final displayInitial = initial?.trim();
    return Container(
      color: AppColors.navyBg.withValues(alpha: 0.86),
      alignment: Alignment.center,
      child: displayInitial != null && displayInitial.isNotEmpty
          ? Text(
              displayInitial.characters.first.toUpperCase(),
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            )
          : Icon(
              icon ?? Icons.person_rounded,
              color: AppColors.coralAccent,
              size: 28,
            ),
    );
  }
}
