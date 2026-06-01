import 'package:flutter/material.dart';

import '../../../core/theme/app_ui.dart';
import '../../messages/screens/chat_detail_page.dart';
import '../services/application_service.dart';

class EmployerApplicationDetailsPage extends StatefulWidget {
  const EmployerApplicationDetailsPage({
    super.key,
    required this.applicationId,
  });

  final String applicationId;

  @override
  State<EmployerApplicationDetailsPage> createState() =>
      _EmployerApplicationDetailsPageState();
}

class _EmployerApplicationDetailsPageState
    extends State<EmployerApplicationDetailsPage> {
  final ApplicationService _applicationService = ApplicationService();
  late Future<EmployerApplicationDetails> _detailsFuture;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _detailsFuture = _applicationService.getApplicationDetails(
      widget.applicationId,
    );
  }

  void _reload() {
    setState(() {
      _detailsFuture = _applicationService.getApplicationDetails(
        widget.applicationId,
      );
    });
  }

  Future<void> _approve() async {
    await _runAction(
      () => _applicationService.approveApplication(widget.applicationId),
      'Application approved. Match and chat created.',
    );
  }

  Future<void> _reject() async {
    await _runAction(
      () => _applicationService.rejectApplication(widget.applicationId),
      'Application rejected.',
    );
  }

  Future<void> _runAction(
    Future<void> Function() action,
    String successMessage,
  ) async {
    setState(() => _isBusy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: Colors.green.shade700,
        ),
      );
      _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _openChat(EmployerApplicationItem item) {
    final chatId = item.chatId;
    if (chatId == null || chatId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat will be available after approval.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatDetailPage(chatId: chatId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EmployerApplicationDetails>(
      future: _detailsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.navyBg,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.coralAccent),
            ),
          );
        }

        if (snapshot.hasError) {
          return _MessageScaffold(
            title: 'Could not load application',
            message: snapshot.error.toString(),
            onRetry: _reload,
          );
        }

        final item = snapshot.data?.item;
        if (item == null) {
          return _MessageScaffold(
            title: 'Application not found',
            message: 'This application may have been removed.',
            onRetry: _reload,
          );
        }

        return Scaffold(
          backgroundColor: AppColors.navyBg,
          body: SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 104),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _TopBar(item: item, onMessage: () => _openChat(item)),
                      const SizedBox(height: 12),
                      _CandidateHero(item: item),
                      const SizedBox(height: 20),
                      _SummaryCard(item: item),
                      const SizedBox(height: 16),
                      _TopSkillsCard(skills: item.candidate.skills),
                      const SizedBox(height: 16),
                      _WorkPreferencesCard(candidate: item.candidate),
                      const SizedBox(height: 16),
                      _AboutCandidateCard(candidate: item.candidate),
                      if (item.candidate.pastExperiences.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _PastExperienceCard(
                          experiences: item.candidate.pastExperiences,
                        ),
                      ],
                    ]),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: _BottomActionBar(
            item: item,
            isBusy: _isBusy,
            onApprove: _approve,
            onReject: _reject,
            onMessage: () => _openChat(item),
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.item, required this.onMessage});

  final EmployerApplicationItem item;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundIconButton(
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.pop(context),
        ),
        const Spacer(),
        if (item.isApproved)
          _RoundIconButton(
            icon: Icons.chat_bubble_outline_rounded,
            onTap: onMessage,
          ),
        if (item.isApproved) const SizedBox(width: 8),
        _RoundIconButton(icon: Icons.more_horiz_rounded, onTap: () {}),
      ],
    );
  }
}

class _CandidateHero extends StatelessWidget {
  const _CandidateHero({required this.item});

  final EmployerApplicationItem item;

  @override
  Widget build(BuildContext context) {
    final candidate = item.candidate;
    final status = _StatusStyle.fromStatus(item.status);
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackHeader = constraints.maxWidth < 315;
        final photoSize = stackHeader
            ? 124.0
            : constraints.maxWidth < 370
            ? 132.0
            : 144.0;
        final photo = _CandidatePhoto(
          imageUrl: candidate.imageUrl,
          name: candidate.name,
          size: photoSize,
        );
        final details = LayoutBuilder(
          builder: (context, detailsConstraints) {
            final metaMaxWidth = detailsConstraints.maxWidth;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  candidate.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 29,
                    fontWeight: FontWeight.w900,
                    height: 1.04,
                  ),
                ),
                const SizedBox(height: 8),
                _StatusBadge(style: status),
                const SizedBox(height: 14),
                Text('Applied for', style: AppTextStyles.label),
                const SizedBox(height: 4),
                Text(
                  item.job.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.16,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _MetaText(
                      icon: Icons.location_on_outlined,
                      text:
                          candidate.city ??
                          candidate.locationLabel ??
                          'Location not set',
                      maxWidth: metaMaxWidth,
                    ),
                    _MetaText(
                      icon: Icons.schedule_rounded,
                      text: _relativeTime(item.createdAt),
                      maxWidth: metaMaxWidth,
                    ),
                  ],
                ),
              ],
            );
          },
        );

        if (stackHeader) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [photo, const SizedBox(height: 14), details],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            photo,
            const SizedBox(width: 18),
            Expanded(child: details),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.item});

  final EmployerApplicationItem item;

  @override
  Widget build(BuildContext context) {
    final candidate = item.candidate;
    final facts = [
      _FactItem(
        icon: Icons.person_outline_rounded,
        label: 'Age',
        value: candidate.ageRange ?? 'Not set',
      ),
      _FactItem(
        icon: Icons.location_on_outlined,
        label: 'Location',
        value: candidate.city ?? candidate.locationLabel ?? 'Not set',
      ),
      _FactItem(
        icon: Icons.calendar_month_rounded,
        label: 'Availability',
        value: candidate.availabilityLabel,
      ),
      _FactItem(
        icon: Icons.work_outline_rounded,
        label: 'Experience',
        value: candidate.experienceLabel,
      ),
    ];
    return _Card(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(child: _FactTile(item: facts[0])),
                const VerticalDivider(color: AppColors.border, width: 20),
                Expanded(child: _FactTile(item: facts[1])),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 24),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(child: _FactTile(item: facts[2])),
                const VerticalDivider(color: AppColors.border, width: 20),
                Expanded(child: _FactTile(item: facts[3])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopSkillsCard extends StatelessWidget {
  const _TopSkillsCard({required this.skills});

  final List<String> skills;

  @override
  Widget build(BuildContext context) {
    final visible = skills.take(6).toList();
    return _SectionCard(
      title: 'Top skills',
      trailing: skills.isEmpty ? null : '${skills.length} skills',
      child: skills.isEmpty
          ? const Text('No skills listed yet.', style: AppTextStyles.body)
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: visible.map((skill) => _SkillChip(skill)).toList(),
            ),
    );
  }
}

class _WorkPreferencesCard extends StatelessWidget {
  const _WorkPreferencesCard({required this.candidate});

  final CandidateProfileSummary candidate;

  @override
  Widget build(BuildContext context) {
    final rows = [
      _PreferenceRow(
        icon: Icons.business_center_outlined,
        label: 'Preferred roles',
        value: _joinOrFallback(candidate.preferredRoles, 'Not specified'),
      ),
      _PreferenceRow(
        icon: Icons.local_offer_outlined,
        label: 'Job types',
        value: _joinOrFallback(candidate.preferredJobTypes, 'Not specified'),
      ),
      _PreferenceRow(
        icon: Icons.schedule_rounded,
        label: 'Preferred shifts',
        value: _joinOrFallback(candidate.preferredShiftTypes, 'Not specified'),
      ),
      _PreferenceRow(
        icon: Icons.calendar_today_outlined,
        label: 'Available days',
        value: _joinOrFallback(candidate.availableDays, 'Not specified'),
      ),
      _PreferenceRow(
        icon: Icons.payments_outlined,
        label: 'Salary expectation',
        value: candidate.salaryExpectation ?? 'Not specified',
      ),
      _PreferenceRow(
        icon: Icons.star_border_rounded,
        label: 'Experience level',
        value: candidate.experienceLabel,
      ),
    ];
    return _SectionCard(
      title: 'Work preferences',
      child: Column(
        children: rows
            .map(
              (row) => Column(
                children: [
                  row,
                  if (row != rows.last)
                    const Divider(color: AppColors.border, height: 20),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _AboutCandidateCard extends StatelessWidget {
  const _AboutCandidateCard({required this.candidate});

  final CandidateProfileSummary candidate;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'About ${candidate.name.split(' ').first}',
      child: Text(
        candidate.shortBio ?? 'This candidate has not added a bio yet.',
        style: AppTextStyles.body.copyWith(height: 1.42),
      ),
    );
  }
}

class _PastExperienceCard extends StatelessWidget {
  const _PastExperienceCard({required this.experiences});

  final List<CandidateExperience> experiences;

  @override
  Widget build(BuildContext context) {
    final visible = experiences.take(3).toList();
    return _SectionCard(
      title: 'Past experience',
      child: Column(
        children: visible
            .map(
              (experience) => Padding(
                padding: EdgeInsets.only(
                  bottom: experience == visible.last ? 0 : 14,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.work_outline_rounded,
                      color: AppColors.coralAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            experience.title,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          if (experience.workplace != null)
                            Text(
                              experience.workplace!,
                              style: AppTextStyles.label,
                            ),
                          if (experience.duration != null)
                            Text(
                              experience.duration!,
                              style: AppTextStyles.label.copyWith(fontSize: 12),
                            ),
                          if (experience.description != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              experience.description!,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.body.copyWith(fontSize: 14),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.item,
    required this.isBusy,
    required this.onApprove,
    required this.onReject,
    required this.onMessage,
  });

  final EmployerApplicationItem item;
  final bool isBusy;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (item.isPending) {
      content = Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 54,
              child: OutlinedButton.icon(
                onPressed: isBusy ? null : onReject,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Reject'),
                style: AppButtonStyles.secondaryOutline(
                  borderColor: const Color(0xFFFF8A7A),
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: isBusy ? null : onApprove,
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text('Approve'),
                style: AppButtonStyles.primary(
                  backgroundColor: const Color(0xFF8DDB7F),
                  foregroundColor: AppColors.navyBg,
                ),
              ),
            ),
          ),
        ],
      );
    } else if (item.isApproved) {
      content = SizedBox(
        height: 54,
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: isBusy ? null : onMessage,
          icon: const Icon(Icons.chat_bubble_outline_rounded),
          label: const Text('Message'),
          style: AppButtonStyles.primary(foregroundColor: AppColors.navyBg),
        ),
      );
    } else {
      content = const _DecisionMessage(
        icon: Icons.cancel_outlined,
        text: 'Application rejected',
        color: Color(0xFFFF6B6B),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 16),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: content,
      ),
    );
  }
}

class _DecisionMessage extends StatelessWidget {
  const _DecisionMessage({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (trailing != null) Text(trailing!, style: AppTextStyles.label),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _FactItem {
  const _FactItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _FactTile extends StatelessWidget {
  const _FactTile({required this.item});

  final _FactItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(item.icon, color: AppColors.coralAccent, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.label,
                style: AppTextStyles.label.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 5),
              Text(
                item.value,
                maxLines: item.label == 'Location' ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  height: 1.16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.coralAccent, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.label),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.lightText,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SkillChip extends StatelessWidget {
  const _SkillChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.navyBg.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: AppColors.coralAccent,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: AppColors.lightText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _CandidatePhoto extends StatelessWidget {
  const _CandidatePhoto({
    required this.imageUrl,
    required this.name,
    required this.size,
  });

  final String? imageUrl;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18)),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl == null
          ? _AvatarFallback(name: name)
          : Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _AvatarFallback(name: name),
            ),
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText({required this.icon, required this.text, this.maxWidth});

  final IconData icon;
  final String text;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.coralAccent, size: 16),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF263D67), AppColors.navyBg]),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 42,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.style});

  final _StatusStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: style.color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, color: style.color, size: 15),
          const SizedBox(width: 6),
          Text(
            style.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: style.color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon),
      color: AppColors.lightText,
      style: IconButton.styleFrom(
        fixedSize: const Size(48, 48),
        side: const BorderSide(color: AppColors.border),
        shape: const CircleBorder(),
      ),
    );
  }
}

class _MessageScaffold extends StatelessWidget {
  const _MessageScaffold({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyBg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _Card(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.coralAccent,
                    size: 42,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton(
                    onPressed: onRetry,
                    style: AppButtonStyles.secondaryOutline(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusStyle {
  const _StatusStyle({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  static _StatusStyle fromStatus(String status) {
    return status == 'approved'
        ? const _StatusStyle(
            label: 'Approved',
            color: Color(0xFF6FD37A),
            icon: Icons.check_circle_outline_rounded,
          )
        : status == 'rejected'
        ? const _StatusStyle(
            label: 'Rejected',
            color: Color(0xFFFF6B6B),
            icon: Icons.cancel_outlined,
          )
        : const _StatusStyle(
            label: 'Pending',
            color: Color(0xFFFFC857),
            icon: Icons.schedule_rounded,
          );
  }
}

String _joinOrFallback(List<String> values, String fallback) {
  if (values.isEmpty) return fallback;
  return values.join(', ');
}

String _relativeTime(DateTime? date) {
  if (date == null) return 'Recently';
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'Now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${date.month}/${date.day}/${date.year}';
}
