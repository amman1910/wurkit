import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_ui.dart';
import '../../auth/screens/welcome_page.dart';
import '../../reports/models/report_item.dart';
import '../../reports/services/report_service.dart';
import '../models/admin_category_item.dart';
import '../models/admin_job_item.dart';
import '../models/admin_review_item.dart';
import '../models/admin_stats.dart';
import '../models/admin_user_item.dart';
import '../services/admin_service.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with TickerProviderStateMixin {
  final AdminService _adminService = AdminService();
  final ReportService _reportService = ReportService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DateFormat _dateFormat = DateFormat('MMM d, yyyy - h:mm a');

  late Future<bool> _isAdminFuture;
  String _jobsFilter = 'all';
  String _reportsFilter = 'all';

  @override
  void initState() {
    super.initState();
    final uid = _auth.currentUser?.uid ?? '';
    _isAdminFuture = _adminService.isAdminUser(uid);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isAdminFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.navyBg,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data != true) {
          return _AccessDenied(onBack: _goToWelcome);
        }

        return DefaultTabController(
          length: 6,
          child: Scaffold(
            backgroundColor: AppColors.navyBg,
            appBar: AppBar(
              backgroundColor: AppColors.navyBg,
              foregroundColor: AppColors.white,
              scrolledUnderElevation: 0,
              titleSpacing: 16,
              title: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFA9A88), Color(0xFF7BC5FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 20,
                      color: AppColors.navyBg,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Admin Dashboard',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
              bottom: const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                dividerHeight: 0,
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: [
                  Tab(text: 'Overview'),
                  Tab(text: 'Users'),
                  Tab(text: 'Jobs'),
                  Tab(text: 'Reviews'),
                  Tab(text: 'Reports'),
                  Tab(text: 'Categories'),
                ],
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _HoverIconButton(
                    tooltip: 'Sign out',
                    icon: Icons.logout_rounded,
                    onTap: () async {
                      await _auth.signOut();
                      if (!mounted) return;
                      _goToWelcome();
                    },
                  ),
                ),
              ],
            ),
            body: TabBarView(
              children: [
                _buildOverviewTab(),
                _buildUsersTab(),
                _buildJobsTab(),
                _buildReviewsTab(),
                _buildReportsTab(),
                _buildCategoriesTab(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverviewTab() {
    return StreamBuilder<AdminStats>(
      stream: _adminService.watchStats(),
      builder: (context, statsSnapshot) {
        if (statsSnapshot.hasError) {
          return _CenteredInfo(
            icon: Icons.error_outline,
            title: 'Could not load stats',
            subtitle: '${statsSnapshot.error}',
          );
        }
        if (!statsSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<List<AdminUserItem>>(
          stream: _adminService.watchUsers(),
          builder: (context, usersSnapshot) {
            return StreamBuilder<List<AdminJobItem>>(
              stream: _adminService.watchJobs(),
              builder: (context, jobsSnapshot) {
                return StreamBuilder<List<AdminReviewItem>>(
                  stream: _adminService.watchReviews(),
                  builder: (context, reviewsSnapshot) {
                    return StreamBuilder<List<ReportItem>>(
                      stream: _reportService.watchReportsForAdmin(),
                      builder: (context, reportsSnapshot) {
                        return StreamBuilder<
                          QuerySnapshot<Map<String, dynamic>>
                        >(
                          stream: _firestore
                              .collection('applications')
                              .snapshots(),
                          builder: (context, appsSnapshot) {
                            final stats = statsSnapshot.data!;
                            final users = usersSnapshot.data ?? const [];
                            final jobs = jobsSnapshot.data ?? const [];
                            final reviews = reviewsSnapshot.data ?? const [];
                            final reports = reportsSnapshot.data ?? const [];
                            final applications =
                                appsSnapshot.data?.docs ??
                                const <
                                  QueryDocumentSnapshot<Map<String, dynamic>>
                                >[];

                            final chartData = _DashboardChartData.fromLists(
                              users: users,
                              jobs: jobs,
                              applications: applications,
                            );

                            final todayApplications = _countTodayApplications(
                              applications,
                            );

                            final activityItems = _buildRecentActivities(
                              users: users,
                              jobs: jobs,
                              reports: reports,
                              reviews: reviews,
                            );

                            return LayoutBuilder(
                              builder: (context, constraints) {
                                final horizontal = constraints.maxWidth >= 1200
                                    ? 32.0
                                    : 20.0;
                                final isDesktop = constraints.maxWidth >= 1100;

                                final content = Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildWelcomeHeader(),
                                    const SizedBox(height: 20),
                                    _buildKpiGrid(
                                      totalUsers: stats.totalUsers,
                                      openJobs: stats.openJobs,
                                      applicationsToday: todayApplications,
                                      reports: stats.totalReports,
                                    ),
                                    const SizedBox(height: 20),
                                    _buildAnalyticsSection(
                                      chartData: chartData,
                                      totalEmployees: stats.totalEmployees,
                                      totalEmployers: stats.totalEmployers,
                                    ),
                                    const SizedBox(height: 20),
                                    if (isDesktop)
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            flex: 8,
                                            child: _buildRecentActivityCard(
                                              activityItems,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            flex: 5,
                                            child: Column(
                                              children: [
                                                _buildQuickActionsCard(),
                                                const SizedBox(height: 16),
                                                _buildSystemStatusCard(),
                                              ],
                                            ),
                                          ),
                                        ],
                                      )
                                    else ...[
                                      _buildRecentActivityCard(activityItems),
                                      const SizedBox(height: 16),
                                      _buildQuickActionsCard(),
                                      const SizedBox(height: 16),
                                      _buildSystemStatusCard(),
                                    ],
                                    const SizedBox(height: 28),
                                  ],
                                );

                                return SingleChildScrollView(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: horizontal,
                                    vertical: 18,
                                  ),
                                  child: content,
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildWelcomeHeader() {
    final now = DateTime.now();
    final dateText = DateFormat('EEEE, MMM d').format(now);
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
        ? 'Good afternoon'
        : 'Good evening';

    return _GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      gradient: const LinearGradient(
        colors: [Color(0x1AFA9A88), Color(0x157BC5FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin Dashboard',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  dateText,
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.lightText.withValues(alpha: 0.88),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '$greeting, keep monitoring platform health and team safety.',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.lightText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFA9A88), Color(0xFF7BC5FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFA9A88).withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: AppColors.navyBg,
              size: 26,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid({
    required int totalUsers,
    required int openJobs,
    required int applicationsToday,
    required int reports,
  }) {
    final cards = [
      _KpiCardData(
        title: 'Total Users',
        subtitle: 'Active platform members',
        value: totalUsers,
        icon: Icons.groups_rounded,
        accent: const Color(0xFF63B3FF),
        trend: '+12%',
        trendUp: true,
      ),
      _KpiCardData(
        title: 'Open Jobs',
        subtitle: 'Currently available posts',
        value: openJobs,
        icon: Icons.work_outline_rounded,
        accent: const Color(0xFF6ED6A0),
        trend: '+4%',
        trendUp: true,
      ),
      _KpiCardData(
        title: 'Applications Today',
        subtitle: 'Submitted in last 24h',
        value: applicationsToday,
        icon: Icons.assignment_turned_in_outlined,
        accent: const Color(0xFFFFC36D),
        trend: '+9%',
        trendUp: true,
      ),
      _KpiCardData(
        title: 'Reports',
        subtitle: 'Total platform reports',
        value: reports,
        icon: Icons.flag_outlined,
        accent: const Color(0xFFFF7E8A),
        trend: '-5%',
        trendUp: false,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 920
            ? 4
            : constraints.maxWidth >= 640
            ? 2
            : 1;
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final scaleExtra = ((textScale - 1).clamp(0.0, 1.2)) * 36;
        final baseExtent = columns == 1
            ? 188.0
            : columns == 2
            ? 196.0
            : 188.0;
        final cardExtent = baseExtent + scaleExtra;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            mainAxisExtent: cardExtent,
          ),
          itemBuilder: (context, index) {
            final card = cards[index];
            return _AnimatedReveal(
              delay: Duration(milliseconds: 80 * index),
              child: _HoverCard(
                borderRadius: 22,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 4,
                        decoration: BoxDecoration(
                          color: card.accent,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(22),
                            bottomLeft: Radius.circular(22),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: card.accent.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  card.icon,
                                  color: card.accent,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: _TrendChip(
                                    text: card.trend,
                                    up: card.trendUp,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: _AnimatedCount(
                              value: card.value,
                              textStyle: const TextStyle(
                                color: AppColors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                height: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            card.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            card.subtitle,
                            style: AppTextStyles.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAnalyticsSection({
    required _DashboardChartData chartData,
    required int totalEmployees,
    required int totalEmployers,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;

        final charts = [
          _buildJobsLineChart(chartData.jobsLast7Days),
          _buildApplicationsBarChart(chartData.applicationsLast7Days),
          _buildCategoriesDonutChart(chartData.jobsByCategory),
          _buildUserDistributionCard(totalEmployees, totalEmployers),
        ];

        if (wide) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: charts.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.46,
            ),
            itemBuilder: (context, index) => _AnimatedReveal(
              delay: Duration(milliseconds: 120 * index),
              child: charts[index],
            ),
          );
        }

        return Column(
          children: [
            for (var i = 0; i < charts.length; i++) ...[
              _AnimatedReveal(
                delay: Duration(milliseconds: 120 * i),
                child: charts[i],
              ),
              if (i != charts.length - 1) const SizedBox(height: 14),
            ],
          ],
        );
      },
    );
  }

  Widget _buildJobsLineChart(List<_DayCount> points) {
    final maxY = math.max<double>(
      4,
      points.fold<double>(
        0,
        (maxV, point) => math.max(maxV, point.count * 1.2),
      ),
    );

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Jobs Created (Last 7 Days)',
            subtitle: 'Daily publishing velocity',
            icon: Icons.show_chart_rounded,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 190,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.white.withValues(alpha: 0.08),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: math.max(1, (maxY / 4).roundToDouble()),
                      getTitlesWidget: (value, _) => Text(
                        value.round().toString(),
                        style: AppTextStyles.label.copyWith(fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, _) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= points.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            DateFormat('E').format(points[idx].day),
                            style: AppTextStyles.label.copyWith(fontSize: 11),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    isCurved: true,
                    color: const Color(0xFF7BC5FF),
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, barData, lineData, index) =>
                          FlDotCirclePainter(
                            radius: 3.6,
                            color: const Color(0xFF7BC5FF),
                            strokeWidth: 1.4,
                            strokeColor: AppColors.navyBg,
                          ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF7BC5FF).withValues(alpha: 0.28),
                          const Color(0xFF7BC5FF).withValues(alpha: 0.03),
                        ],
                      ),
                    ),
                    spots: [
                      for (var i = 0; i < points.length; i++)
                        FlSpot(i.toDouble(), points[i].count.toDouble()),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationsBarChart(List<_DayCount> points) {
    final maxY = math.max<double>(
      4,
      points.fold<double>(
        0,
        (maxV, point) => math.max(maxV, point.count * 1.3),
      ),
    );

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Applications Per Day',
            subtitle: 'Last 7 days intake',
            icon: Icons.bar_chart_rounded,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 190,
            child: BarChart(
              BarChartData(
                minY: 0,
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: math.max(1, (maxY / 4).roundToDouble()),
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.white.withValues(alpha: 0.08),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: math.max(1, (maxY / 4).roundToDouble()),
                      getTitlesWidget: (value, _) => Text(
                        value.round().toString(),
                        style: AppTextStyles.label.copyWith(fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, _) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= points.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            DateFormat('E').format(points[idx].day),
                            style: AppTextStyles.label.copyWith(fontSize: 11),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < points.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: points[i].count.toDouble(),
                          width: 16,
                          borderRadius: BorderRadius.circular(8),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6ED6A0), Color(0xFF7BC5FF)],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesDonutChart(Map<String, int> jobsByCategory) {
    final total = jobsByCategory.values.fold<int>(
      0,
      (accumulator, value) => accumulator + value,
    );
    final entries = jobsByCategory.entries.take(5).toList();
    final colors = [
      const Color(0xFF7BC5FF),
      const Color(0xFF6ED6A0),
      const Color(0xFFFFC36D),
      const Color(0xFFFF7E8A),
      const Color(0xFFBFA1FF),
    ];

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Jobs By Category',
            subtitle: 'Top active categories',
            icon: Icons.donut_small_rounded,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 45,
                      sections: entries.isEmpty
                          ? [
                              PieChartSectionData(
                                value: 1,
                                color: Colors.white.withValues(alpha: 0.12),
                                radius: 38,
                                title: '',
                              ),
                            ]
                          : [
                              for (var i = 0; i < entries.length; i++)
                                PieChartSectionData(
                                  value: entries[i].value.toDouble(),
                                  color: colors[i % colors.length],
                                  radius: 42,
                                  title:
                                      '${((entries[i].value / total) * 100).round()}%',
                                  titleStyle: const TextStyle(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  ),
                                ),
                            ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: entries.isEmpty
                        ? [
                            Text(
                              'No category data yet',
                              style: AppTextStyles.label,
                            ),
                          ]
                        : [
                            for (var i = 0; i < entries.length; i++)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: colors[i % colors.length],
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        entries[i].key,
                                        style: AppTextStyles.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${entries[i].value}',
                                      style: const TextStyle(
                                        color: AppColors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserDistributionCard(int totalEmployees, int totalEmployers) {
    final total = math.max(1, totalEmployees + totalEmployers);
    final employeeRatio = totalEmployees / total;
    final employerRatio = totalEmployers / total;

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'User Distribution',
            subtitle: 'Employer vs Employee',
            icon: Icons.stacked_bar_chart_rounded,
          ),
          const SizedBox(height: 18),
          _DistributionRow(
            label: 'Employees',
            value: totalEmployees,
            ratio: employeeRatio,
            color: const Color(0xFF7BC5FF),
          ),
          const SizedBox(height: 14),
          _DistributionRow(
            label: 'Employers',
            value: totalEmployers,
            ratio: employerRatio,
            color: const Color(0xFF6ED6A0),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.groups_outlined,
                  color: AppColors.lightText,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Total tracked users: ${totalEmployees + totalEmployers}',
                  style: AppTextStyles.label,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityCard(List<_ActivityItem> activities) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Recent Activity',
            subtitle: 'Registrations, jobs, reports and reviews',
            icon: Icons.timeline_rounded,
          ),
          const SizedBox(height: 8),
          if (activities.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('No recent activity', style: AppTextStyles.label),
            )
          else
            Column(
              children: [
                for (var i = 0; i < activities.length; i++)
                  _AnimatedReveal(
                    delay: Duration(milliseconds: 80 * i),
                    child: _TimelineTile(
                      item: activities[i],
                      showLine: i != activities.length - 1,
                      dateFormat: _dateFormat,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Quick Actions',
            subtitle: 'Fast admin operations',
            icon: Icons.bolt_rounded,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _QuickActionButton(
                label: 'Verify Users',
                icon: Icons.verified_user_outlined,
                onTap: () => _jumpToTab(1),
              ),
              _QuickActionButton(
                label: 'View Reports',
                icon: Icons.policy_outlined,
                onTap: () => _jumpToTab(4),
              ),
              _QuickActionButton(
                label: 'Manage Jobs',
                icon: Icons.workspaces_outline,
                onTap: () => _jumpToTab(2),
              ),
              _QuickActionButton(
                label: 'Broadcast Notification',
                icon: Icons.campaign_outlined,
                onTap: () =>
                    _showSnack('Broadcast flow is not configured yet.'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSystemStatusCard() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SectionHeader(
            title: 'System Status',
            subtitle: 'Core services health',
            icon: Icons.health_and_safety_outlined,
          ),
          SizedBox(height: 12),
          _SystemStatusRow(name: 'Firebase', online: true),
          _SystemStatusRow(name: 'Firestore', online: true),
          _SystemStatusRow(name: 'Cloud Functions', online: true),
          _SystemStatusRow(name: 'Notifications', online: true),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    return StreamBuilder<List<AdminUserItem>>(
      stream: _adminService.watchUsers(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _CenteredInfo(
            icon: Icons.error_outline,
            title: 'Could not load users',
            subtitle: '${snapshot.error}',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!;
        if (users.isEmpty) {
          return const _CenteredInfo(
            icon: Icons.group_off_outlined,
            title: 'No users found',
            subtitle: 'Users from Firestore will appear here.',
          );
        }

        final currentUid = _auth.currentUser?.uid;
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemBuilder: (context, index) {
            final user = users[index];
            final isSelf = user.userId == currentUid;

            return _AnimatedReveal(
              delay: Duration(milliseconds: 35 * index),
              child: _HoverCard(
                borderRadius: 20,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _UserAvatar(name: user.name, email: user.email),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.name,
                                  style: const TextStyle(
                                    color: AppColors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user.email.isEmpty ? '-' : user.email,
                                  style: AppTextStyles.label,
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _pill(
                                      user.role.isEmpty ? 'unknown' : user.role,
                                      const Color(0xFF7BC5FF),
                                    ),
                                    _pill(
                                      user.isVerified
                                          ? 'Verified'
                                          : 'Unverified',
                                      user.isVerified
                                          ? const Color(0xFF6ED6A0)
                                          : const Color(0xFFFFC36D),
                                    ),
                                    _pill(
                                      user.isBlocked ? 'Blocked' : 'Active',
                                      user.isBlocked
                                          ? const Color(0xFFFF7E8A)
                                          : const Color(0xFF6ED6A0),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (user.createdAt != null)
                        Row(
                          children: [
                            const Icon(
                              Icons.event_outlined,
                              color: AppColors.lightText,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Created ${_dateFormat.format(user.createdAt!)}',
                              style: AppTextStyles.label,
                            ),
                          ],
                        ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _TinyActionButton(
                            tooltip: 'View details',
                            icon: Icons.visibility_outlined,
                            onTap: () => _showUserDetails(user),
                          ),
                          _TinyActionButton(
                            tooltip: user.isBlocked
                                ? 'Unblock user'
                                : 'Block user',
                            icon: user.isBlocked
                                ? Icons.lock_open_rounded
                                : Icons.block_outlined,
                            accent: user.isBlocked
                                ? const Color(0xFF6ED6A0)
                                : const Color(0xFFFF7E8A),
                            onTap: isSelf
                                ? null
                                : () => _runAction(
                                    user.isBlocked
                                        ? () => _adminService.unblockUser(
                                            user.userId,
                                          )
                                        : () => _adminService.blockUser(
                                            user.userId,
                                          ),
                                  ),
                          ),
                          _TinyActionButton(
                            tooltip: user.isVerified
                                ? 'Remove verification'
                                : 'Verify user',
                            icon: user.isVerified
                                ? Icons.verified_outlined
                                : Icons.verified_user_outlined,
                            accent: user.isVerified
                                ? const Color(0xFFFFC36D)
                                : const Color(0xFF6ED6A0),
                            onTap: () => _runAction(
                              user.isVerified
                                  ? () =>
                                        _adminService.unverifyUser(user.userId)
                                  : () => _adminService.verifyUser(user.userId),
                            ),
                          ),
                        ],
                      ),
                      if (isSelf)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            'You cannot block your own admin account.',
                            style: AppTextStyles.label.copyWith(
                              color: const Color(0xFFFFC36D),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemCount: users.length,
        );
      },
    );
  }

  Widget _buildJobsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _jobFilterChip('all', 'All'),
              _jobFilterChip('open', 'Open'),
              _jobFilterChip('closed', 'Closed'),
              _jobFilterChip('filled', 'Filled'),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<AdminJobItem>>(
            stream: _adminService.watchJobs(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _CenteredInfo(
                  icon: Icons.error_outline,
                  title: 'Could not load jobs',
                  subtitle: '${snapshot.error}',
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final jobs = snapshot.data!;
              final filtered = jobs.where((job) {
                if (_jobsFilter == 'all') return true;
                return job.status == _jobsFilter;
              }).toList();

              if (filtered.isEmpty) {
                return const _CenteredInfo(
                  icon: Icons.work_off_outlined,
                  title: 'No jobs found',
                  subtitle: 'Try another filter.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(18),
                itemBuilder: (context, index) {
                  final job = filtered[index];
                  final statusColor = job.status == 'open'
                      ? const Color(0xFF6ED6A0)
                      : const Color(0xFFFFC36D);

                  return _AnimatedReveal(
                    delay: Duration(milliseconds: 35 * index),
                    child: _HoverCard(
                      borderRadius: 20,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF7BC5FF,
                                    ).withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.work_history_outlined,
                                    color: Color(0xFF7BC5FF),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    job.title,
                                    style: const TextStyle(
                                      color: AppColors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                _pill(job.status, statusColor),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 10,
                              children: [
                                _MetaItem(
                                  icon: Icons.category_outlined,
                                  label: job.category,
                                ),
                                _MetaItem(
                                  icon: Icons.location_on_outlined,
                                  label: job.location,
                                ),
                                _MetaItem(
                                  icon: Icons.attach_money_rounded,
                                  label: job.wage,
                                ),
                                _MetaItem(
                                  icon: Icons.storefront_outlined,
                                  label: job.employerName,
                                ),
                              ],
                            ),
                            if (job.createdAt != null) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.schedule_outlined,
                                    color: AppColors.lightText,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Created ${_dateFormat.format(job.createdAt!)}',
                                    style: AppTextStyles.label,
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _showJobDetails(job),
                                  style: AppButtonStyles.secondaryOutline(),
                                  icon: const Icon(
                                    Icons.visibility_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('View job details'),
                                ),
                                if (job.status != 'closed')
                                  OutlinedButton.icon(
                                    onPressed: () => _confirmCloseJob(job),
                                    style: AppButtonStyles.secondaryOutline(),
                                    icon: const Icon(
                                      Icons.cancel_outlined,
                                      size: 18,
                                    ),
                                    label: const Text('Close job'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemCount: filtered.length,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReviewsTab() {
    return StreamBuilder<List<AdminReviewItem>>(
      stream: _adminService.watchReviews(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _CenteredInfo(
            icon: Icons.error_outline,
            title: 'Could not load reviews',
            subtitle: '${snapshot.error}',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final reviews = snapshot.data!;
        if (reviews.isEmpty) {
          return const _CenteredInfo(
            icon: Icons.rate_review_outlined,
            title: 'No reviews found',
            subtitle: 'Reviews will appear here.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(18),
          itemBuilder: (context, index) {
            final review = reviews[index];
            final ratingColor = review.rating >= 4
                ? const Color(0xFF6ED6A0)
                : review.rating >= 3
                ? const Color(0xFFFFC36D)
                : const Color(0xFFFF7E8A);

            return _AnimatedReveal(
              delay: Duration(milliseconds: 35 * index),
              child: _HoverCard(
                borderRadius: 20,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 3,
                              children: List.generate(5, (star) {
                                return Icon(
                                  star < review.rating
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  color: star < review.rating
                                      ? const Color(0xFFFFC36D)
                                      : AppColors.lightText,
                                  size: 24,
                                );
                              }),
                            ),
                          ),
                          _pill('${review.rating}/5', ratingColor),
                          const SizedBox(width: 8),
                          _TinyActionButton(
                            tooltip: 'Delete review',
                            icon: Icons.delete_outline_rounded,
                            accent: const Color(0xFFFF7E8A),
                            circular: true,
                            onTap: () => _confirmDeleteReview(review),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (review.comment.isNotEmpty)
                        Text(
                          review.comment,
                          style: AppTextStyles.body.copyWith(height: 1.4),
                        ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _MetaItem(
                            icon: Icons.person_outline_rounded,
                            label:
                                'Reviewer: ${review.reviewerName} (${review.reviewerRole})',
                          ),
                          _MetaItem(
                            icon: Icons.swap_horiz_rounded,
                            label:
                                'Receiver: ${review.targetUserName} (${review.targetRole})',
                          ),
                        ],
                      ),
                      if (review.createdAt != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(
                              Icons.event_outlined,
                              size: 16,
                              color: AppColors.lightText,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _dateFormat.format(review.createdAt!),
                              style: AppTextStyles.label,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemCount: reviews.length,
        );
      },
    );
  }

  Widget _buildReportsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _reportFilterChip('all', 'All'),
              _reportFilterChip('pending', 'Pending'),
              _reportFilterChip('reviewed', 'Reviewed'),
              _reportFilterChip('resolved', 'Resolved'),
              _reportFilterChip('dismissed', 'Dismissed'),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<ReportItem>>(
            stream: _reportService.watchReportsForAdmin(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _CenteredInfo(
                  icon: Icons.error_outline,
                  title: 'Could not load reports',
                  subtitle: '${snapshot.error}',
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final reports = snapshot.data!;
              final filtered = reports.where((report) {
                if (_reportsFilter == 'all') return true;
                return report.status == _reportsFilter;
              }).toList();

              if (filtered.isEmpty) {
                return const _CenteredInfo(
                  icon: Icons.flag_outlined,
                  title: 'No reports found',
                  subtitle: 'Try another filter.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(18),
                itemBuilder: (context, index) {
                  final report = filtered[index];
                  final statusColor = _reportStatusColor(report.status);

                  return _AnimatedReveal(
                    delay: Duration(milliseconds: 35 * index),
                    child: _HoverCard(
                      borderRadius: 20,
                      borderColor: const Color(
                        0xFFFF7E8A,
                      ).withValues(alpha: 0.35),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFFF7E8A,
                                    ).withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: const Icon(
                                    Icons.warning_amber_rounded,
                                    color: Color(0xFFFF7E8A),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    report.reason,
                                    style: const TextStyle(
                                      color: AppColors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                _pill(report.status, statusColor),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _pill(
                              'Priority: ${_reportPriority(report)}',
                              _reportPriority(report) == 'High'
                                  ? const Color(0xFFFF7E8A)
                                  : _reportPriority(report) == 'Medium'
                                  ? const Color(0xFFFFC36D)
                                  : const Color(0xFF6ED6A0),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              report.description,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.body.copyWith(height: 1.35),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 10,
                              children: [
                                _MetaItem(
                                  icon: Icons.person_outline,
                                  label:
                                      'Reporter: ${report.reportedByName} (${report.reportedByRole})',
                                ),
                                _MetaItem(
                                  icon: Icons.gpp_bad_outlined,
                                  label:
                                      'Reported: ${report.reportedUserName} (${report.reportedUserRole})',
                                ),
                              ],
                            ),
                            if (report.createdAt != null) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.schedule_outlined,
                                    size: 16,
                                    color: AppColors.lightText,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _dateFormat.format(report.createdAt!),
                                    style: AppTextStyles.label,
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _showReportDetails(report),
                                  style: AppButtonStyles.secondaryOutline(),
                                  icon: const Icon(
                                    Icons.visibility_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Review'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _runAction(
                                    () => _reportService.updateReportStatus(
                                      report.reportId,
                                      'dismissed',
                                    ),
                                  ),
                                  style: AppButtonStyles.secondaryOutline(),
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Dismiss'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _runAction(
                                    () => _adminService.blockUser(
                                      report.reportedUserId,
                                    ),
                                  ),
                                  style: AppButtonStyles.secondaryOutline(),
                                  icon: const Icon(
                                    Icons.block_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Ban User'),
                                ),
                                OutlinedButton(
                                  onPressed: () => _runAction(
                                    () => _reportService.updateReportStatus(
                                      report.reportId,
                                      'reviewed',
                                    ),
                                  ),
                                  style: AppButtonStyles.secondaryOutline(),
                                  child: const Text('Mark reviewed'),
                                ),
                                OutlinedButton(
                                  onPressed: () => _runAction(
                                    () => _reportService.updateReportStatus(
                                      report.reportId,
                                      'resolved',
                                    ),
                                  ),
                                  style: AppButtonStyles.secondaryOutline(),
                                  child: const Text('Mark resolved'),
                                ),
                                OutlinedButton(
                                  onPressed: () =>
                                      _showAddAdminNoteDialog(report),
                                  style: AppButtonStyles.secondaryOutline(),
                                  child: const Text('Add admin note'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemCount: filtered.length,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showAddCategoryDialog,
              style: AppButtonStyles.primary(),
              icon: const Icon(Icons.add),
              label: Text(
                'Add category',
                style: AppTextStyles.buttonLabel(color: AppColors.navyBg),
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<AdminCategoryItem>>(
            stream: _adminService.watchCategories(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _CenteredInfo(
                  icon: Icons.error_outline,
                  title: 'Could not load categories',
                  subtitle: '${snapshot.error}',
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final categories = snapshot.data!;
              if (categories.isEmpty) {
                return const _CenteredInfo(
                  icon: Icons.category_outlined,
                  title: 'No categories yet',
                  subtitle: 'Create categories for future job posting flows.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(18),
                itemBuilder: (context, index) {
                  final item = categories[index];
                  return _HoverCard(
                    borderRadius: 18,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    color: AppColors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'ID: ${item.categoryId}',
                                  style: AppTextStyles.label,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          _pill(
                            item.isActive ? 'Active' : 'Disabled',
                            item.isActive
                                ? const Color(0xFF6ED6A0)
                                : const Color(0xFFFFC36D),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () => _runAction(
                              () => _adminService.setCategoryActive(
                                categoryId: item.categoryId,
                                isActive: !item.isActive,
                              ),
                            ),
                            style: AppButtonStyles.secondaryOutline(),
                            child: Text(item.isActive ? 'Disable' : 'Enable'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemCount: categories.length,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _jobFilterChip(String value, String label) {
    final selected = _jobsFilter == value;
    return ChoiceChip(
      selectedColor: AppColors.coralAccent,
      labelStyle: TextStyle(
        color: selected ? AppColors.navyBg : AppColors.white,
        fontWeight: FontWeight.w700,
      ),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _jobsFilter = value),
    );
  }

  Widget _reportFilterChip(String value, String label) {
    final selected = _reportsFilter == value;
    return ChoiceChip(
      selectedColor: AppColors.coralAccent,
      labelStyle: TextStyle(
        color: selected ? AppColors.navyBg : AppColors.white,
        fontWeight: FontWeight.w700,
      ),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _reportsFilter = value),
    );
  }

  Color _reportStatusColor(String status) {
    switch (status) {
      case 'reviewed':
        return const Color(0xFFFFC36D);
      case 'resolved':
        return const Color(0xFF6ED6A0);
      case 'dismissed':
        return const Color(0xFFFF7E8A);
      case 'pending':
      default:
        return const Color(0xFFFFC36D);
    }
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  int _countTodayApplications(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> applications,
  ) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    var count = 0;
    for (final doc in applications) {
      final created = doc.data()['createdAt'];
      if (created is Timestamp && created.toDate().isAfter(startOfDay)) {
        count++;
      }
    }
    return count;
  }

  List<_ActivityItem> _buildRecentActivities({
    required List<AdminUserItem> users,
    required List<AdminJobItem> jobs,
    required List<ReportItem> reports,
    required List<AdminReviewItem> reviews,
  }) {
    final activities = <_ActivityItem>[];

    for (final user in users.take(4)) {
      if (user.createdAt == null) continue;
      activities.add(
        _ActivityItem(
          title: 'New registration',
          subtitle:
              '${user.name} joined as ${user.role.isEmpty ? 'user' : user.role}',
          createdAt: user.createdAt!,
          icon: Icons.person_add_alt_1_rounded,
          color: const Color(0xFF7BC5FF),
        ),
      );
    }

    for (final job in jobs.take(4)) {
      if (job.createdAt == null) continue;
      activities.add(
        _ActivityItem(
          title: 'Job posted',
          subtitle: '${job.title} • ${job.location}',
          createdAt: job.createdAt!,
          icon: Icons.work_outline_rounded,
          color: const Color(0xFF6ED6A0),
        ),
      );
    }

    for (final report in reports.take(4)) {
      if (report.createdAt == null) continue;
      activities.add(
        _ActivityItem(
          title: 'Report created',
          subtitle: report.reason,
          createdAt: report.createdAt!,
          icon: Icons.flag_outlined,
          color: const Color(0xFFFF7E8A),
        ),
      );
    }

    for (final review in reviews.take(4)) {
      if (review.createdAt == null) continue;
      activities.add(
        _ActivityItem(
          title: 'Review submitted',
          subtitle: '${review.reviewerName} rated ${review.targetUserName}',
          createdAt: review.createdAt!,
          icon: Icons.rate_review_outlined,
          color: const Color(0xFFFFC36D),
        ),
      );
    }

    activities.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return activities.take(8).toList();
  }

  String _reportPriority(ReportItem report) {
    final reason = report.reason.toLowerCase();
    final type = report.reportType.toLowerCase();
    final description = report.description.toLowerCase();

    if (reason.contains('harass') ||
        reason.contains('violence') ||
        reason.contains('fraud') ||
        description.contains('urgent') ||
        type == 'chat') {
      return 'High';
    }

    if (reason.contains('spam') || reason.contains('abuse')) {
      return 'Medium';
    }

    return 'Low';
  }

  void _jumpToTab(int index) {
    final controller = DefaultTabController.of(context);
    controller.animateTo(index);
  }

  Future<void> _runAction(Future<void> Function() action) async {
    try {
      await action();
      if (!mounted) return;
      _showSnack('Updated successfully');
    } catch (error) {
      if (!mounted) return;
      _showSnack(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  Future<void> _confirmDeleteReview(AdminReviewItem review) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete review?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _runAction(() => _adminService.deleteReview(review.reviewId));
  }

  Future<void> _confirmCloseJob(AdminJobItem job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close this job?'),
        content: const Text('The job status will be set to closed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Close job'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _runAction(() => _adminService.closeJob(job.jobId));
  }

  void _showUserDetails(AdminUserItem user) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('User details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${user.name}'),
            Text('Email: ${user.email.isEmpty ? '-' : user.email}'),
            Text('Role: ${user.role.isEmpty ? 'unknown' : user.role}'),
            Text('Blocked: ${user.isBlocked ? 'Yes' : 'No'}'),
            Text('Verified: ${user.isVerified ? 'Yes' : 'No'}'),
            Text('User ID: ${user.userId}'),
            if (user.createdAt != null)
              Text('Created: ${_dateFormat.format(user.createdAt!)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showJobDetails(AdminJobItem job) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Job details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Title: ${job.title}'),
            Text('Category: ${job.category}'),
            Text('Employer: ${job.employerName}'),
            Text('Location: ${job.location}'),
            Text('Wage: ${job.wage}'),
            Text('Status: ${job.status}'),
            Text('Job ID: ${job.jobId}'),
            if (job.createdAt != null)
              Text('Created: ${_dateFormat.format(job.createdAt!)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showReportDetails(ReportItem report) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reason: ${report.reason}'),
              Text('Type: ${report.reportType}'),
              Text('Status: ${report.status}'),
              Text('By: ${report.reportedByName} (${report.reportedByRole})'),
              Text(
                'Against: ${report.reportedUserName} (${report.reportedUserRole})',
              ),
              if (report.jobId != null) Text('Job ID: ${report.jobId}'),
              if (report.jobTitle != null) Text('Job: ${report.jobTitle}'),
              const SizedBox(height: 8),
              Text('Description: ${report.description}'),
              if (report.adminNote != null && report.adminNote!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Admin note: ${report.adminNote}'),
              ],
              if (report.createdAt != null) ...[
                const SizedBox(height: 8),
                Text('Created: ${_dateFormat.format(report.createdAt!)}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddAdminNoteDialog(ReportItem report) async {
    final controller = TextEditingController(text: report.adminNote ?? '');
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add admin note'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Write a note'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (save != true) return;
    await _runAction(
      () => _reportService.addAdminNote(report.reportId, controller.text),
    );
  }

  Future<void> _showAddCategoryDialog() async {
    final controller = TextEditingController();
    final added = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Category name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (added != true) return;
    await _runAction(() => _adminService.addCategory(controller.text));
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  void _goToWelcome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomePage()),
      (route) => false,
    );
  }
}

class _DashboardChartData {
  const _DashboardChartData({
    required this.jobsLast7Days,
    required this.applicationsLast7Days,
    required this.jobsByCategory,
  });

  final List<_DayCount> jobsLast7Days;
  final List<_DayCount> applicationsLast7Days;
  final Map<String, int> jobsByCategory;

  factory _DashboardChartData.fromLists({
    required List<AdminUserItem> users,
    required List<AdminJobItem> jobs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> applications,
  }) {
    final now = DateTime.now();
    final days = List.generate(
      7,
      (index) => DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: 6 - index)),
    );

    final jobsPerDay = <DateTime, int>{for (final day in days) day: 0};
    final appsPerDay = <DateTime, int>{for (final day in days) day: 0};

    for (final job in jobs) {
      final created = job.createdAt;
      if (created == null) continue;
      final key = DateTime(created.year, created.month, created.day);
      if (jobsPerDay.containsKey(key)) {
        jobsPerDay[key] = (jobsPerDay[key] ?? 0) + 1;
      }
    }

    for (final doc in applications) {
      final created = doc.data()['createdAt'];
      if (created is! Timestamp) continue;
      final date = created.toDate();
      final key = DateTime(date.year, date.month, date.day);
      if (appsPerDay.containsKey(key)) {
        appsPerDay[key] = (appsPerDay[key] ?? 0) + 1;
      }
    }

    final byCategory = <String, int>{};
    for (final job in jobs) {
      final category = job.category.trim().isEmpty ? 'Other' : job.category;
      byCategory[category] = (byCategory[category] ?? 0) + 1;
    }

    final sortedCategory = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _DashboardChartData(
      jobsLast7Days: [
        for (final day in days)
          _DayCount(day: day, count: jobsPerDay[day] ?? 0),
      ],
      applicationsLast7Days: [
        for (final day in days)
          _DayCount(day: day, count: appsPerDay[day] ?? 0),
      ],
      jobsByCategory: {
        for (final entry in sortedCategory.take(5)) entry.key: entry.value,
      },
    );
  }
}

class _DayCount {
  const _DayCount({required this.day, required this.count});

  final DateTime day;
  final int count;
}

class _KpiCardData {
  const _KpiCardData({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.accent,
    required this.trend,
    required this.trendUp,
  });

  final String title;
  final String subtitle;
  final int value;
  final IconData icon;
  final Color accent;
  final String trend;
  final bool trendUp;
}

class _ActivityItem {
  const _ActivityItem({
    required this.title,
    required this.subtitle,
    required this.createdAt,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final DateTime createdAt;
  final IconData icon;
  final Color color;
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = 20,
    this.gradient,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient:
            gradient ??
            LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.06),
                Colors.white.withValues(alpha: 0.03),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.26),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _HoverCard extends StatefulWidget {
  const _HoverCard({
    required this.child,
    this.borderRadius = 16,
    this.borderColor,
  });

  final Widget child;
  final double borderRadius;
  final Color? borderColor;

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hovered ? -2.0 : 0, 0),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: _hovered ? 0.96 : 0.9),
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color:
                widget.borderColor ??
                Colors.white.withValues(alpha: _hovered ? 0.2 : 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _hovered ? 0.3 : 0.2),
              blurRadius: _hovered ? 20 : 12,
              offset: Offset(0, _hovered ? 8 : 4),
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}

class _AnimatedReveal extends StatefulWidget {
  const _AnimatedReveal({required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  State<_AnimatedReveal> createState() => _AnimatedRevealState();
}

class _AnimatedRevealState extends State<_AnimatedReveal> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (!mounted) return;
      setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.08),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class _AnimatedCount extends StatelessWidget {
  const _AnimatedCount({required this.value, required this.textStyle});

  final int value;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, current, _) {
        return Text(current.round().toString(), style: textStyle);
      },
    );
  }
}

class _TrendChip extends StatelessWidget {
  const _TrendChip({required this.text, required this.up});

  final String text;
  final bool up;

  @override
  Widget build(BuildContext context) {
    final color = up ? const Color(0xFF6ED6A0) : const Color(0xFFFF7E8A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.coralAccent.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.coralAccent, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: AppTextStyles.label),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.item,
    required this.showLine,
    required this.dateFormat,
  });

  final _ActivityItem item;
  final bool showLine;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: item.color.withValues(alpha: 0.2),
                    border: Border.all(
                      color: item.color.withValues(alpha: 0.8),
                    ),
                  ),
                  child: Icon(item.icon, color: item.color, size: 14),
                ),
                if (showLine)
                  Container(
                    width: 1.4,
                    height: 42,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateFormat.format(item.createdAt),
                    style: AppTextStyles.label.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatefulWidget {
  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: widget.onTap,
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: [
                    AppColors.coralAccent.withValues(
                      alpha: _hovered ? 0.25 : 0.16,
                    ),
                    const Color(
                      0xFF7BC5FF,
                    ).withValues(alpha: _hovered ? 0.2 : 0.12),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: _hovered ? 0.24 : 0.1),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, size: 16, color: AppColors.white),
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
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

class _SystemStatusRow extends StatelessWidget {
  const _SystemStatusRow({required this.name, required this.online});

  final String name;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final color = online ? const Color(0xFF6ED6A0) : const Color(0xFFFF7E8A);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            online ? 'Online' : 'Offline',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DistributionRow extends StatelessWidget {
  const _DistributionRow({
    required this.label,
    required this.value,
    required this.ratio,
    required this.color,
  });

  final String label;
  final int value;
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              '$value',
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio.clamp(0, 1),
            minHeight: 10,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.lightText),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.label),
      ],
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.name, required this.email});

  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    final seed = name.trim().isNotEmpty ? name.trim() : email.trim();
    final initial = seed.isEmpty ? '?' : seed[0].toUpperCase();

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFFA9A88), Color(0xFF7BC5FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: AppColors.navyBg,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _TinyActionButton extends StatelessWidget {
  const _TinyActionButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.accent = const Color(0xFF7BC5FF),
    this.circular = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;
  final Color accent;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(circular ? 999 : 10),
          child: Ink(
            width: circular ? 34 : null,
            height: circular ? 34 : null,
            padding: circular
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: onTap == null ? 0.08 : 0.16),
              borderRadius: BorderRadius.circular(circular ? 999 : 10),
              border: Border.all(
                color: accent.withValues(alpha: onTap == null ? 0.1 : 0.36),
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color: onTap == null ? accent.withValues(alpha: 0.5) : accent,
            ),
          ),
        ),
      ),
    );
  }
}

class _HoverIconButton extends StatefulWidget {
  const _HoverIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_HoverIconButton> createState() => _HoverIconButtonState();
}

class _HoverIconButtonState extends State<_HoverIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.tooltip,
        child: InkResponse(
          onTap: widget.onTap,
          radius: 22,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _hovered
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(widget.icon, size: 20),
          ),
        ),
      ),
    );
  }
}

class _CenteredInfo extends StatelessWidget {
  const _CenteredInfo({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: AppColors.coralAccent),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.label,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 52,
                color: AppColors.coralAccent,
              ),
              const SizedBox(height: 14),
              const Text(
                'Access denied',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Only admin users can open this page.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onBack,
                style: AppButtonStyles.secondaryOutline(),
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
