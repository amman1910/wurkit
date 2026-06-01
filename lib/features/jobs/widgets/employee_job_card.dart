import 'package:flutter/material.dart';

import '../../../core/theme/app_ui.dart';
import '../models/employee_job_discovery_item.dart';

class EmployeeJobCard extends StatelessWidget {
  const EmployeeJobCard({
    super.key,
    required this.job,
    required this.position,
    required this.total,
    required this.onViewDetails,
  });

  final EmployeeJobDiscoveryItem job;
  final int position;
  final int total;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageHeight = constraints.maxHeight.isFinite
            ? (constraints.maxHeight * 0.30).clamp(126.0, 198.0)
            : 188.0;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(26),
            onTap: onViewDetails,
            child: Ink(
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.26),
                    blurRadius: 28,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: imageHeight,
                      child: _JobImageHeader(
                        job: job,
                        counter: '$position/$total',
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 11, 16, 12),
                        child: LayoutBuilder(
                          builder: (context, bodyConstraints) {
                            final compactBody = bodyConstraints.maxHeight < 285;
                            final veryCompact = bodyConstraints.maxHeight < 250;
                            return SizedBox.expand(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.topCenter,
                                child: SizedBox(
                                  width: bodyConstraints.maxWidth,
                                  child: _CardBody(
                                    job: job,
                                    compact: compactBody,
                                    veryCompact: veryCompact,
                                    onViewDetails: onViewDetails,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({
    required this.job,
    required this.compact,
    required this.veryCompact,
    required this.onViewDetails,
  });

  final EmployeeJobDiscoveryItem job;
  final bool compact;
  final bool veryCompact;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (job.jobCategory != null) ...[
          _CategoryPill(label: job.jobCategory!, compact: compact),
          SizedBox(height: veryCompact ? 4 : 6),
        ],
        Text(
          job.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.white,
            fontSize: veryCompact ? 19 : 21,
            fontWeight: FontWeight.w900,
            height: 1.06,
          ),
        ),
        SizedBox(height: veryCompact ? 4 : 6),
        Row(
          children: [
            Expanded(
              child: Text(
                job.businessName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.copyWith(
                  fontSize: veryCompact ? 12 : 13,
                ),
              ),
            ),
            const SizedBox(width: 5),
            const Icon(
              Icons.verified_rounded,
              color: AppColors.coralAccent,
              size: 15,
            ),
          ],
        ),
        SizedBox(height: veryCompact ? 6 : 8),
        _InfoGrid(job: job, compact: true),
        SizedBox(height: veryCompact ? 6 : 8),
        _SkillWrap(skills: job.requiredSkills, compact: true),
        SizedBox(height: veryCompact ? 7 : 9),
        SizedBox(
          width: double.infinity,
          height: veryCompact ? 38 : 40,
          child: OutlinedButton.icon(
            onPressed: onViewDetails,
            icon: const Icon(Icons.visibility_outlined, size: 17),
            label: const Text('View details'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.coralAccent,
              side: const BorderSide(color: AppColors.coralAccent),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 38),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.label, required this.compact});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 190),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.coralAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.coralAccent.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.work_outline_rounded,
            color: AppColors.coralAccent,
            size: compact ? 12 : 14,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.coralAccent,
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JobImageHeader extends StatelessWidget {
  const _JobImageHeader({required this.job, required this.counter});

  final EmployeeJobDiscoveryItem job;
  final String counter;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (job.displayImageUrl == null)
          const _ImageFallback()
        else
          Image.network(
            job.displayImageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const _ImageFallback(),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black26, Colors.transparent, Color(0xD90B1426)],
            ),
          ),
        ),
        if (job.urgent)
          Positioned(
            left: 16,
            top: 16,
            child: _OverlayBadge(
              icon: Icons.bolt_rounded,
              label: 'Urgent',
              color: AppColors.coralAccent,
            ),
          ),
        Positioned(
          right: 16,
          top: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              counter,
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          bottom: 12,
          child: _BusinessAvatar(
            imageUrl: job.employer.businessLogoUrl,
            name: job.businessName,
          ),
        ),
      ],
    );
  }
}

class _OverlayBadge extends StatelessWidget {
  const _OverlayBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _BusinessAvatar extends StatelessWidget {
  const _BusinessAvatar({required this.imageUrl, required this.name});

  final String? imageUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 66,
      height: 66,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.navyBg,
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl == null
          ? Center(
              child: Text(
                _initials(name),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            )
          : Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Center(
                child: Text(
                  _initials(name),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
    );
  }

  String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return 'W';
    }
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.job, required this.compact});

  final EmployeeJobDiscoveryItem job;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _InfoLine(
                icon: Icons.account_balance_wallet_outlined,
                text: job.salaryText,
                compact: compact,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InfoLine(
                icon: Icons.schedule_rounded,
                text: job.dateText,
                compact: compact,
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 7 : 9),
        Row(
          children: [
            Expanded(
              child: _InfoLine(
                icon: Icons.calendar_month_rounded,
                text: job.shiftText,
                compact: compact,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InfoLine(
                icon: Icons.location_on_outlined,
                text: job.locationText,
                compact: compact,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.text,
    this.compact = false,
  });

  final IconData icon;
  final String text;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.coralAccent, size: compact ? 16 : 17),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.label.copyWith(fontSize: compact ? 12 : 13),
          ),
        ),
      ],
    );
  }
}

class _SkillWrap extends StatelessWidget {
  const _SkillWrap({required this.skills, required this.compact});

  final List<String> skills;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final visible = skills.take(3).toList();
    final remaining = skills.length - visible.length;
    if (visible.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        ...visible.map((skill) => _SkillPill(skill, compact: compact)),
        if (remaining > 0) _SkillPill('+$remaining', compact: compact),
      ],
    );
  }
}

class _SkillPill extends StatelessWidget {
  const _SkillPill(this.label, {required this.compact});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: compact ? 108 : 120),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 10,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.navyBg.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.label.copyWith(fontSize: compact ? 11 : 12),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF263D67), AppColors.surface, AppColors.navyBg],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.work_outline_rounded,
          color: AppColors.coralAccent,
          size: 54,
        ),
      ),
    );
  }
}
