import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

import '../../../core/theme/app_ui.dart';
import '../../messages/screens/chat_detail_page.dart';
import '../../messages/services/chat_service.dart';

class JobDetailsPage extends StatefulWidget {
  const JobDetailsPage({
    super.key,
    required this.jobId,
    this.openedFromChat = false,
  });

  final String jobId;
  final bool openedFromChat;

  @override
  State<JobDetailsPage> createState() => _JobDetailsPageState();
}

class _JobDetailsPageState extends State<JobDetailsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ChatService _chatService = ChatService();

  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _jobStream;
  bool _isApplying = false;
  bool _isOpeningChat = false;
  int _supportDataVersion = 0;

  @override
  void initState() {
    super.initState();
    _jobStream = _firestore.collection('jobs').doc(widget.jobId).snapshots();
  }

  Future<_SupportData> _loadSupportData(_JobDetails job) async {
    final employerFuture = job.employerId.isEmpty
        ? Future<_EmployerDetails?>.value()
        : _firestore
              .collection('employerProfiles')
              .doc(job.employerId)
              .get()
              .then((snapshot) {
                if (!snapshot.exists) {
                  return null;
                }
                return _EmployerDetails.fromMap(snapshot.data() ?? {});
              });

    final applicationFuture = _loadCurrentApplication();

    return _SupportData(
      employer: await employerFuture,
      application: await applicationFuture,
    );
  }

  Future<_ApplicationDetails?> _loadCurrentApplication() async {
    final user = _auth.currentUser;
    if (user == null) {
      return null;
    }

    final snapshot = await _firestore
        .collection('applications')
        .where('jobId', isEqualTo: widget.jobId)
        .where('employeeId', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return _ApplicationDetails.fromMap(snapshot.docs.first.data());
  }

  Future<void> _applyToJob(_JobDetails job) async {
    final user = _auth.currentUser;
    if (user == null) {
      _showSnackBar('Log in to apply');
      return;
    }

    setState(() => _isApplying = true);

    try {
      final existingApplication = await _loadCurrentApplication();
      if (existingApplication != null) {
        if (!mounted) {
          return;
        }
        setState(() => _supportDataVersion++);
        _showSnackBar('Application already sent');
        return;
      }

      final now = FieldValue.serverTimestamp();
      await _firestore.collection('applications').add({
        'jobId': widget.jobId,
        'employeeId': user.uid,
        'employerId': job.employerId,
        'status': 'pending',
        'createdAt': now,
        'updatedAt': now,
      });

      if (!mounted) {
        return;
      }
      setState(() => _supportDataVersion++);
      await _showApplicationSuccessOverlay();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(_friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => _isApplying = false);
      }
    }
  }

  Future<void> _openChat(_JobDetails job) async {
    final user = _auth.currentUser;
    if (user == null) {
      _showSnackBar('Please log in to open chat');
      return;
    }

    if (_isOpeningChat) {
      return;
    }

    setState(() => _isOpeningChat = true);

    try {
      final chatId = await _chatService.getOrCreateChatForApprovedApplication(
        jobId: widget.jobId,
        employeeId: user.uid,
        employerId: job.employerId,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => ChatDetailPage(chatId: chatId)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar('Unable to open chat right now');
    } finally {
      if (mounted) {
        setState(() => _isOpeningChat = false);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showApplicationSuccessOverlay() async {
    HapticFeedback.lightImpact();

    if (!mounted) {
      return;
    }

    var dialogClosed = false;
    final dialogFuture =
        showGeneralDialog<void>(
          context: context,
          barrierDismissible: false,
          barrierLabel: 'Application sent',
          barrierColor: Colors.black.withValues(alpha: 0.62),
          transitionDuration: const Duration(milliseconds: 360),
          pageBuilder: (context, animation, secondaryAnimation) {
            return const _ApplicationSuccessOverlay();
          },
          transitionBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
              reverseCurve: Curves.easeOutCubic,
            );

            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(
                  begin: 0.88,
                  end: 1,
                ).animate(curvedAnimation),
                child: child,
              ),
            );
          },
        ).whenComplete(() {
          dialogClosed = true;
        });

    await Future<void>.delayed(const Duration(milliseconds: 2000));

    if (mounted && !dialogClosed) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    await dialogFuture;
  }

  String _friendlyError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    if (message.isEmpty) {
      return 'Something went wrong. Please try again.';
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _jobStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.navyBg,
            body: _LoadingState(),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: AppColors.navyBg,
            body: _MessageState(
              icon: Icons.error_outline_rounded,
              title: 'Could not load job',
              message: _friendlyError(snapshot.error!),
            ),
          );
        }

        final document = snapshot.data;
        if (document == null || !document.exists) {
          return const Scaffold(
            backgroundColor: AppColors.navyBg,
            body: _MessageState(
              icon: Icons.search_off_rounded,
              title: 'Job not found',
              message: 'This job may have been removed.',
            ),
          );
        }

        final job = _JobDetails.fromSnapshot(document);

        return FutureBuilder<_SupportData>(
          key: ValueKey('${widget.jobId}-$_supportDataVersion'),
          future: _loadSupportData(job),
          builder: (context, supportSnapshot) {
            final support = supportSnapshot.data ?? const _SupportData();
            final isCheckingApplication =
                supportSnapshot.connectionState == ConnectionState.waiting;

            return Scaffold(
              backgroundColor: AppColors.navyBg,
              body: SafeArea(
                top: false,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _JobHero(job: job, employer: support.employer),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.horizontal,
                        22,
                        AppSpacing.horizontal,
                        28,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _InfoChipGrid(job: job, employer: support.employer),
                          const SizedBox(height: AppSpacing.section),
                          _SectionCard(
                            title: 'About this job',
                            child: Text(
                              job.description ??
                                  'No detailed description was added yet.',
                              style: AppTextStyles.body.copyWith(height: 1.42),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.section),
                          _BusinessPreviewCard(employer: support.employer),
                          const SizedBox(height: 88),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: _ApplyBottomBar(
                job: job,
                application: support.application,
                isApplying: _isApplying,
                isOpeningChat: _isOpeningChat,
                isCheckingApplication: isCheckingApplication,
                isAuthenticated: _auth.currentUser != null,
                onApply: () => _applyToJob(job),
                onOpenChat: () => _openChat(job),
              ),
            );
          },
        );
      },
    );
  }
}

class _JobHero extends StatelessWidget {
  const _JobHero({required this.job, required this.employer});

  final _JobDetails job;
  final _EmployerDetails? employer;

  @override
  Widget build(BuildContext context) {
    final imageUrl = employer?.businessLogoUrl;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      child: SizedBox(
        height: 375,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl == null)
              const _HeroFallback()
            else
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const _HeroFallback(),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xAA000000),
                    Color(0x33000000),
                    Color(0xF20B1426),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 14,
              top: MediaQuery.paddingOf(context).top + 8,
              child: _CircleIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            if (job.urgent)
              Positioned(
                right: AppSpacing.horizontal,
                top: MediaQuery.paddingOf(context).top + 18,
                child: const _UrgentHeroBadge(),
              ),
            Positioned(
              left: AppSpacing.horizontal,
              right: AppSpacing.horizontal,
              bottom: 30,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _heroSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    job.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      height: 1.03,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _heroSubtitle {
    final businessName = employer?.businessName ?? 'Wurkit employer';
    final place = employer?.city ?? job.location;
    return place == null ? businessName : '$businessName - $place';
  }
}

class _HeroFallback extends StatelessWidget {
  const _HeroFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surface, Color(0xFF22375F), AppColors.navyBg],
        ),
      ),
      child: Center(
        child: Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            color: AppColors.coralAccent.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border),
          ),
          child: const Icon(
            Icons.storefront_outlined,
            color: AppColors.coralAccent,
            size: 44,
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.navyBg.withValues(alpha: 0.72),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, color: AppColors.white),
        ),
      ),
    );
  }
}

class _UrgentHeroBadge extends StatelessWidget {
  const _UrgentHeroBadge();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.045,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.coralAccent.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          boxShadow: [
            BoxShadow(
              color: AppColors.coralAccent.withValues(alpha: 0.35),
              blurRadius: 22,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt_rounded, color: AppColors.navyBg, size: 24),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'URGENT',
                  style: TextStyle(
                    color: AppColors.navyBg,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Need staff today',
                  style: TextStyle(
                    color: AppColors.navyBg,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChipGrid extends StatelessWidget {
  const _InfoChipGrid({required this.job, required this.employer});

  final _JobDetails job;
  final _EmployerDetails? employer;

  @override
  Widget build(BuildContext context) {
    final location = employer?.city ?? job.location;
    final shift = job.shiftText;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _InfoSummaryRow(
            left: _InfoTile(
              icon: Icons.payments_outlined,
              label: 'Pay',
              value: job.salaryText ?? 'Not listed',
            ),
            right: _InfoTile(
              icon: Icons.calendar_today_outlined,
              label: 'Date',
              value: job.date ?? 'Flexible',
            ),
          ),
          const _InfoHorizontalDivider(),
          _InfoSummaryRow(
            left: _InfoTile(
              icon: Icons.schedule_rounded,
              label: 'Shift',
              value: shift ?? 'Time TBD',
            ),
            right: _InfoTile(
              icon: Icons.auto_awesome_rounded,
              label: 'Skill',
              value: job.requiredSkill ?? 'General help',
            ),
          ),
          const _InfoHorizontalDivider(),
          _InfoTile(
            icon: Icons.place_outlined,
            label: 'Location',
            value: location ?? 'Shared soon',
          ),
        ],
      ),
    );
  }
}

class _InfoSummaryRow extends StatelessWidget {
  const _InfoSummaryRow({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        children: [
          Expanded(child: left),
          const _InfoVerticalDivider(),
          Expanded(child: right),
        ],
      ),
    );
  }
}

class _InfoVerticalDivider extends StatelessWidget {
  const _InfoVerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: AppColors.border,
    );
  }
}

class _InfoHorizontalDivider extends StatelessWidget {
  const _InfoHorizontalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 14),
      color: AppColors.border,
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
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
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.coralAccent.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: AppColors.coralAccent, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _BusinessPreviewCard extends StatelessWidget {
  const _BusinessPreviewCard({required this.employer});

  final _EmployerDetails? employer;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showBusinessDetails(context),
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'About the business',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BusinessAvatar(imageUrl: employer?.businessLogoUrl),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          employer?.businessName ?? 'Wurkit employer',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _businessSubtitle(employer),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.label,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          employer?.businessDescription ??
                              'Business details will appear here soon.',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body.copyWith(height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    'View more',
                    style: AppTextStyles.buttonLabel(
                      color: AppColors.coralAccent,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: AppColors.coralAccent,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBusinessDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (context) => _BusinessDetailsSheet(employer: employer),
    );
  }

  String _businessSubtitle(_EmployerDetails? employer) {
    final parts = [
      employer?.businessType,
      employer?.city,
    ].whereType<String>().where((value) => value.isNotEmpty).toList();

    return parts.isEmpty ? 'Local business' : parts.join(' - ');
  }
}

class _BusinessDetailsSheet extends StatelessWidget {
  const _BusinessDetailsSheet({required this.employer});

  final _EmployerDetails? employer;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.navyBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _BusinessAvatar(imageUrl: employer?.businessLogoUrl),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                employer?.businessName ?? 'Wurkit employer',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  height: 1.08,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                _businessSubtitle(employer),
                                style: AppTextStyles.body,
                              ),
                            ],
                          ),
                        ),
                        _CircleIconButton(
                          icon: Icons.close_rounded,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SheetInfoBlock(
                      icon: Icons.storefront_outlined,
                      title: 'Business story',
                      body:
                          employer?.businessDescription ??
                          'Business details will appear here soon.',
                    ),
                    if (employer?.businessAddress != null) ...[
                      const SizedBox(height: 14),
                      _SheetInfoBlock(
                        icon: Icons.location_on_outlined,
                        title: 'Address',
                        body: employer!.businessAddress!,
                      ),
                    ],
                    if (employer?.city != null) ...[
                      const SizedBox(height: 14),
                      _SheetInfoBlock(
                        icon: Icons.location_city_outlined,
                        title: 'City',
                        body: employer!.city!,
                      ),
                    ],
                    const SizedBox(height: 26),
                    SizedBox(
                      height: AppSpacing.buttonHeight,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: AppButtonStyles.primary(
                          foregroundColor: AppColors.navyBg,
                        ),
                        child: Text(
                          'Got it',
                          style: AppTextStyles.buttonLabel(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _businessSubtitle(_EmployerDetails? employer) {
    final parts = [
      employer?.businessType,
      employer?.city,
    ].whereType<String>().where((value) => value.isNotEmpty).toList();

    return parts.isEmpty ? 'Local business' : parts.join(' - ');
  }
}

class _SheetInfoBlock extends StatelessWidget {
  const _SheetInfoBlock({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.coralAccent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(body, style: AppTextStyles.body.copyWith(height: 1.42)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LegacyBusinessPreviewCard extends StatelessWidget {
  const LegacyBusinessPreviewCard({super.key, required this.employer});

  final dynamic employer;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'About the business',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BusinessAvatar(imageUrl: employer?.businessLogoUrl),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employer?.businessName ?? 'Wurkit employer',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _businessSubtitle(employer),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label,
                ),
                const SizedBox(height: 10),
                Text(
                  employer?.businessDescription ??
                      'Business details will appear here soon.',
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _businessSubtitle(_EmployerDetails? employer) {
    final parts = [
      employer?.businessType,
      employer?.city,
    ].whereType<String>().where((value) => value.isNotEmpty).toList();

    return parts.isEmpty ? 'Local business' : parts.join(' · ');
  }
}

class _BusinessAvatar extends StatelessWidget {
  const _BusinessAvatar({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: AppColors.coralAccent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl == null
          ? const Icon(Icons.storefront_outlined, color: AppColors.coralAccent)
          : Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.storefront_outlined,
                color: AppColors.coralAccent,
              ),
            ),
    );
  }
}

class _ApplyBottomBar extends StatelessWidget {
  const _ApplyBottomBar({
    required this.job,
    required this.application,
    required this.isApplying,
    required this.isOpeningChat,
    required this.isCheckingApplication,
    required this.isAuthenticated,
    required this.onApply,
    required this.onOpenChat,
  });

  final _JobDetails job;
  final _ApplicationDetails? application;
  final bool isApplying;
  final bool isOpeningChat;
  final bool isCheckingApplication;
  final bool isAuthenticated;
  final VoidCallback onApply;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    final button = _buttonState();

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: AppSpacing.buttonHeight,
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: button.onPressed,
                style: AppButtonStyles.primary(
                  foregroundColor: AppColors.navyBg,
                  disabledBackgroundColor: Colors.white24,
                  disabledForegroundColor: Colors.white60,
                ),
                icon:
                    isApplying ||
                        isCheckingApplication ||
                        isOpeningChat ||
                        !button.showIcon
                    ? const SizedBox.shrink()
                    : Icon(button.icon, size: 19),
                label: isApplying || isCheckingApplication || isOpeningChat
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppColors.navyBg,
                        ),
                      )
                    : Text(button.label, style: AppTextStyles.buttonLabel()),
              ),
            ),
            if (button.helperText != null) ...[
              const SizedBox(height: 8),
              Text(
                button.helperText!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  _CtaState _buttonState() {
    if (!isAuthenticated) {
      return const _CtaState(label: 'Log in to apply');
    }

    if (job.status != 'open') {
      return const _CtaState(label: 'Job is no longer open');
    }

    if (isCheckingApplication) {
      return const _CtaState(label: 'Checking application');
    }

    if (application?.status == 'approved') {
      return _CtaState(
        label: 'Open chat',
        icon: Icons.chat_bubble_rounded,
        onPressed: onOpenChat,
      );
    }

    if (application != null) {
      return const _CtaState(label: 'Application sent');
    }

    return _CtaState(
      label: 'Apply now',
      icon: Icons.send_rounded,
      helperText: 'Your application will be reviewed by the employer',
      onPressed: onApply,
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.coralAccent),
    );
  }
}

class _ApplicationSuccessOverlay extends StatelessWidget {
  const _ApplicationSuccessOverlay();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: const _ApplicationSuccessCard(),
          ),
        ),
      ),
    );
  }
}

class _ApplicationSuccessCard extends StatelessWidget {
  const _ApplicationSuccessCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SuccessIconPulse(),
          SizedBox(height: 22),
          Text(
            'Application sent',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1.08,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'The employer will review your request soon',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.lightText,
              fontSize: 15,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessIconPulse extends StatefulWidget {
  const _SuccessIconPulse();

  @override
  State<_SuccessIconPulse> createState() => _SuccessIconPulseState();
}

class _SuccessIconPulseState extends State<_SuccessIconPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final glow = 0.18 + (_pulse.value * 0.16);
        final spread = 2 + (_pulse.value * 4);

        return Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.coralAccent.withValues(alpha: 0.12),
            boxShadow: [
              BoxShadow(
                color: AppColors.coralAccent.withValues(alpha: glow),
                blurRadius: 28,
                spreadRadius: spread,
              ),
            ],
          ),
          child: child,
        );
      },
      child: const Icon(
        Icons.check_circle_rounded,
        color: AppColors.coralAccent,
        size: 64,
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.horizontal),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppColors.coralAccent, size: 38),
                const SizedBox(height: 12),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _JobDetails {
  const _JobDetails({
    required this.id,
    required this.employerId,
    required this.title,
    required this.status,
    required this.urgent,
    this.description,
    this.location,
    this.date,
    this.salary,
    this.salaryType,
    this.requiredSkill,
    this.shiftStart,
    this.shiftEnd,
  });

  final String id;
  final String employerId;
  final String title;
  final String status;
  final bool urgent;
  final String? description;
  final String? location;
  final String? date;
  final double? salary;
  final String? salaryType;
  final String? requiredSkill;
  final String? shiftStart;
  final String? shiftEnd;

  String? get salaryText {
    if (salary == null) {
      return null;
    }

    final amount = salary!;
    final formatted = amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    final type = salaryType == null ? '' : ' $salaryType';
    return '\$$formatted$type';
  }

  String? get shiftText {
    if (shiftStart == null && shiftEnd == null) {
      return null;
    }
    if (shiftStart == null) {
      return shiftEnd;
    }
    if (shiftEnd == null) {
      return shiftStart;
    }
    return '$shiftStart - $shiftEnd';
  }

  factory _JobDetails.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};
    return _JobDetails(
      id: snapshot.id,
      employerId: _readString(data['employerId']) ?? '',
      title: _readString(data['title']) ?? 'Open shift',
      status: _readString(data['status']) ?? 'open',
      urgent: _readBool(data['urgent']) ?? false,
      description: _readString(data['description']),
      location: _readString(data['location']),
      date: _readDate(data['date']),
      salary: _readDouble(data['salary']),
      salaryType: _readString(data['salaryType']),
      requiredSkill: _readString(data['requiredSkill']),
      shiftStart: _readString(data['shiftStart']),
      shiftEnd: _readString(data['shiftEnd']),
    );
  }
}

class _EmployerDetails {
  const _EmployerDetails({
    this.businessName,
    this.businessType,
    this.businessDescription,
    this.businessLogoUrl,
    this.businessAddress,
    this.city,
  });

  final String? businessName;
  final String? businessType;
  final String? businessDescription;
  final String? businessLogoUrl;
  final String? businessAddress;
  final String? city;

  factory _EmployerDetails.fromMap(Map<String, dynamic> data) {
    return _EmployerDetails(
      businessName: _readString(data['businessName']),
      businessType: _readString(data['businessType']),
      businessDescription: _readString(data['businessDescription']),
      businessLogoUrl: _readString(data['businessLogoUrl']),
      businessAddress: _readString(data['businessAddress']),
      city: _readString(data['city']),
    );
  }
}

class _ApplicationDetails {
  const _ApplicationDetails({required this.status});

  final String status;

  factory _ApplicationDetails.fromMap(Map<String, dynamic> data) {
    return _ApplicationDetails(
      status: _readString(data['status']) ?? 'pending',
    );
  }
}

class _SupportData {
  const _SupportData({this.employer, this.application});

  final _EmployerDetails? employer;
  final _ApplicationDetails? application;
}

class _CtaState {
  const _CtaState({
    required this.label,
    this.icon,
    this.helperText,
    this.onPressed,
  });

  final String label;
  final IconData? icon;
  final String? helperText;
  final VoidCallback? onPressed;

  bool get showIcon => icon != null;
}

String? _readString(Object? value) {
  if (value is! String) {
    return null;
  }

  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _readDate(Object? value) {
  if (value is Timestamp) {
    final date = value.toDate();
    return '${date.month}/${date.day}/${date.year}';
  }
  return _readString(value);
}

bool? _readBool(Object? value) {
  if (value is bool) {
    return value;
  }
  return null;
}

double? _readDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return null;
}
