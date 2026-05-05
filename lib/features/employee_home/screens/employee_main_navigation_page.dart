import 'package:flutter/material.dart';

import '../../../core/theme/app_ui.dart';
import '../../applications/screens/employee_applications_page.dart';
import '../../employee_profile/screens/employee_profile_page.dart';
import '../../jobs/screens/employee_jobs_page.dart';
import '../../messages/screens/messages_page.dart';
import '../../messages/services/chat_service.dart';
import 'employee_home_page.dart';

class EmployeeMainNavigationPage extends StatefulWidget {
  const EmployeeMainNavigationPage({super.key});

  @override
  State<EmployeeMainNavigationPage> createState() =>
      _EmployeeMainNavigationPageState();
}

class _EmployeeMainNavigationPageState
    extends State<EmployeeMainNavigationPage> {
  final ChatService _chatService = ChatService();
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
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.work_outline_rounded),
            label: 'Jobs',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            label: 'Applications',
          ),
          BottomNavigationBarItem(
            icon: StreamBuilder<int>(
              stream: _chatService.watchTotalUnreadCount(),
              builder: (context, snapshot) {
                return _MessageNavIcon(
                  unreadCount: snapshot.data ?? 0,
                  isSelected: _selectedIndex == 3,
                );
              },
            ),
            label: 'Messages',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _MessageNavIcon extends StatelessWidget {
  const _MessageNavIcon({required this.unreadCount, required this.isSelected});

  final int unreadCount;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;

    return SizedBox(
      height: 28,
      width: 34,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: hasUnread ? 28 : 24,
            width: hasUnread ? 34 : 24,
            decoration: BoxDecoration(
              color: hasUnread
                  ? AppColors.coralAccent.withValues(alpha: 0.16)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(
              hasUnread
                  ? Icons.chat_bubble_rounded
                  : Icons.chat_bubble_outline_rounded,
              color: isSelected ? AppColors.coralAccent : Colors.white54,
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            bottom: hasUnread ? -1 : 2,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              height: hasUnread ? 4 : 0,
              width: hasUnread ? 4 : 0,
              decoration: const BoxDecoration(
                color: AppColors.coralAccent,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
