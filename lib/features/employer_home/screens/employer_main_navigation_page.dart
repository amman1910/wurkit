import 'package:flutter/material.dart';

import '../../../core/theme/app_ui.dart';
import '../../applications/screens/employer_applications_page.dart';
import '../../employer_profile/screens/employer_profile_page.dart';
import '../../jobs/screens/employer_jobs_page.dart';
import '../../messages/screens/messages_page.dart';
import 'employer_dashboard_page.dart';

class EmployerMainNavigationPage extends StatefulWidget {
  const EmployerMainNavigationPage({super.key});

  @override
  State<EmployerMainNavigationPage> createState() =>
      _EmployerMainNavigationPageState();
}

class _EmployerMainNavigationPageState
    extends State<EmployerMainNavigationPage> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = <Widget>[
    EmployerDashboardPage(),
    EmployerJobsPage(),
    EmployerApplicationsPage(),
    MessagesPage(role: 'employer'),
    EmployerProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyBg,
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.coralAccent,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.work_outline_rounded),
            label: 'Jobs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.groups_rounded),
            label: 'Applications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
