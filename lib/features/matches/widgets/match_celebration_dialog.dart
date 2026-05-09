import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/theme/app_ui.dart';

class MatchCelebrationDialog extends StatefulWidget {
  const MatchCelebrationDialog({
    super.key,
    required this.businessName,
    this.businessLogoUrl,
    required this.jobTitle,
    this.date,
    this.shiftStart,
    this.shiftEnd,
    this.location,
    required this.onOpenChat,
    required this.onMaybeLater,
  });

  final String businessName;
  final String? businessLogoUrl;
  final String jobTitle;
  final String? date;
  final String? shiftStart;
  final String? shiftEnd;
  final String? location;
  final VoidCallback onOpenChat;
  final VoidCallback onMaybeLater;

  @override
  State<MatchCelebrationDialog> createState() => _MatchCelebrationDialogState();
}

class _MatchCelebrationDialogState extends State<MatchCelebrationDialog>
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _pulseController;
  late final AnimationController _particleController;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..forward();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    )..repeat(reverse: true);
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();

    final curve = CurvedAnimation(
      parent: _introController,
      curve: Curves.easeOutBack,
    );
    _scale = Tween<double>(begin: 0.86, end: 1).animate(curve);
    _fade = CurvedAnimation(parent: _introController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _introController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 390),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _particleController,
                          builder: (context, child) {
                            return CustomPaint(
                              painter: _CelebrationParticlesPainter(
                                progress: _particleController.value,
                              ),
                            );
                          },
                        ),
                      ),
                      SingleChildScrollView(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                          decoration: BoxDecoration(
                            color: AppColors.coralAccent,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.coralAccent.withValues(
                                  alpha: 0.34,
                                ),
                                blurRadius: 36,
                                spreadRadius: 4,
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.24),
                                blurRadius: 28,
                                offset: const Offset(0, 18),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/images/match_header.png',
                                height: 92,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(height: 14),
                              _BusinessLogoPulse(
                                imageUrl: widget.businessLogoUrl,
                                controller: _pulseController,
                              ),
                              const SizedBox(height: 18),
                              Text(
                                '${widget.businessName} approved your application',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.navyBg,
                                  fontSize: 23,
                                  fontWeight: FontWeight.w900,
                                  height: 1.12,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                "You're one step away from starting this shift.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.navyBg,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 18),
                              _JobSummary(
                                jobTitle: widget.jobTitle,
                                details: _detailsLine,
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: AppSpacing.buttonHeight,
                                child: ElevatedButton.icon(
                                  onPressed: widget.onOpenChat,
                                  style: AppButtonStyles.primary(
                                    backgroundColor: AppColors.navyBg,
                                    foregroundColor: AppColors.white,
                                  ),
                                  icon: const Icon(
                                    Icons.chat_bubble_rounded,
                                    size: 19,
                                  ),
                                  label: Text(
                                    'Open chat',
                                    style: AppTextStyles.buttonLabel(
                                      color: AppColors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextButton(
                                onPressed: widget.onMaybeLater,
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.navyBg,
                                ),
                                child: const Text(
                                  'Maybe later',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
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
      ),
    );
  }

  String get _detailsLine {
    final time = _shiftText;
    return [
      widget.date,
      time,
      widget.location,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');
  }

  String? get _shiftText {
    if (widget.shiftStart == null && widget.shiftEnd == null) {
      return null;
    }
    if (widget.shiftStart == null) {
      return widget.shiftEnd;
    }
    if (widget.shiftEnd == null) {
      return widget.shiftStart;
    }
    return '${widget.shiftStart}-${widget.shiftEnd}';
  }
}

class _BusinessLogoPulse extends StatelessWidget {
  const _BusinessLogoPulse({required this.imageUrl, required this.controller});

  final String? imageUrl;
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.white,
            boxShadow: [
              BoxShadow(
                color: AppColors.white.withValues(
                  alpha: 0.26 + controller.value * 0.2,
                ),
                blurRadius: 26 + controller.value * 12,
                spreadRadius: 2 + controller.value * 4,
              ),
            ],
          ),
          padding: const EdgeInsets.all(5),
          child: child,
        );
      },
      child: ClipOval(
        child: imageUrl == null || imageUrl!.isEmpty
            ? Container(
                color: AppColors.navyBg,
                child: const Icon(
                  Icons.storefront_rounded,
                  color: AppColors.coralAccent,
                  size: 48,
                ),
              )
            : Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: AppColors.navyBg,
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: AppColors.coralAccent,
                    size: 48,
                  ),
                ),
              ),
      ),
    );
  }
}

class _JobSummary extends StatelessWidget {
  const _JobSummary({required this.jobTitle, required this.details});

  final String jobTitle;
  final String details;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.navyBg.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
      ),
      child: Column(
        children: [
          Text(
            jobTitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.navyBg,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              details,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.navyBg.withValues(alpha: 0.82),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CelebrationParticlesPainter extends CustomPainter {
  const _CelebrationParticlesPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    const count = 18;

    for (var i = 0; i < count; i++) {
      final seed = i * 0.73;
      final phase = (progress + seed) % 1;
      final x = (math.sin(seed * 8.4) * 0.5 + 0.5) * size.width;
      final y = size.height * (1.08 - phase * 1.18);
      final radius = 2.2 + (i % 3) * 1.2;
      final alpha = (1 - (phase - 0.5).abs() * 1.6).clamp(0.0, 1.0);

      paint.color = (i.isEven ? AppColors.white : AppColors.navyBg).withValues(
        alpha: alpha * 0.38,
      );

      final rect = Rect.fromCenter(
        center: Offset(x, y),
        width: radius * 2.4,
        height: radius * 1.3,
      );
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(seed + phase * math.pi);
      canvas.translate(-x, -y);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CelebrationParticlesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
