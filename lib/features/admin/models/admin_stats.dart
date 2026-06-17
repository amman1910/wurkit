class AdminStats {
  const AdminStats({
    required this.totalEmployees,
    required this.totalEmployers,
    required this.totalUsers,
    required this.openJobs,
    required this.closedOrFilledJobs,
    required this.totalApplications,
    required this.totalReviews,
    required this.totalReports,
    required this.pendingReports,
    required this.blockedUsers,
  });

  final int totalEmployees;
  final int totalEmployers;
  final int totalUsers;
  final int openJobs;
  final int closedOrFilledJobs;
  final int totalApplications;
  final int totalReviews;
  final int totalReports;
  final int pendingReports;
  final int blockedUsers;
}
