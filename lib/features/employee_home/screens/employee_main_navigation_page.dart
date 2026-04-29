import 'package:flutter/material.dart';

import '../../../core/theme/app_ui.dart';
import '../../applications/screens/employee_applications_page.dart';
import '../../employee_profile/screens/employee_profile_page.dart';
import '../../jobs/screens/employee_jobs_page.dart';
import '../../messages/screens/messages_page.dart';
import 'employee_home_page.dart';

class EmployeeMainNavigationPage extends StatefulWidget {
  const EmployeeMainNavigationPage({super.key});

  @override
  State<EmployeeMainNavigationPage> createState() =>
      _EmployeeMainNavigationPageState();
}

class _EmployeeMainNavigationPageState
    extends State<EmployeeMainNavigationPage> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = <Widget>[
    EmployeeHomePage(),
    EmployeeJobsPage(),
    EmployeeApplicationsPage(),
    MessagesPage(role: 'employee'),
    EmployeeProfilePage(),
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
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.work_outline_rounded),
            label: 'Jobs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            label: 'Applications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
