import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../../core/theme/app_ui.dart';
import '../services/auth_service.dart';
import 'login_page.dart';
import 'welcome_page.dart';
import '../../employee_profile/screens/employee_basic_info_page.dart';
import '../../employer_profile/screens/employer_business_info_page.dart';

class ChooseProfilePage extends StatefulWidget {
  const ChooseProfilePage({super.key});

  @override
  State<ChooseProfilePage> createState() => _ChooseProfilePageState();
}

class _ChooseProfilePageState extends State<ChooseProfilePage> {
  late final AuthService _authService;
  String? _selectedRole;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
  }

  Future<void> _handleContinue() async {
    if (_selectedRole == null) return;

    setState(() {
      _isLoading = true;
    });

    final role = _selectedRole == 'employee' ? 'employee' : 'employer';

    try {
      await _authService.updateUserRole(role);

      if (!mounted) return;

      if (role == 'employee') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const EmployeeBasicInfoPage(),
          ),
        );
      } else if (role == 'employer') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const EmployerBusinessInfoPage(),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } finally {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

void _goToLogin() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const LoginPage(),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final bool canContinue = _selectedRole != null && !_isLoading;

    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(color: AppColors.coralAccent),
              ),
              Expanded(
                child: Container(color: AppColors.navyBg),
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WelcomePage(),
                        ),
                      ),
                      style: AppButtonStyles.text(),
                      child: const Text('Back', style: AppTextStyles.textButton),
                    ),
                  ),
                  const SizedBox(height: 28),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Wu',
                        style: AppTextStyles.heading(
                          color: AppColors.navyBg,
                          fontSize: 48,
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(-2, 0),
                        child: Text(
                          'rkit',
                          style: AppTextStyles.heading(
                            color: AppColors.coralAccent,
                            fontSize: 48,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: _ProfileCard(
                            title: 'WORKER',
                            description:
                                'Find short-term jobs fast and apply in minutes.',
                            illustrationPath: 'assets/images/worker.png',
                            titleColor: AppColors.navyBg,
                            bodyColor: AppColors.navyBg,
                            iconColor: AppColors.navyBg,
                            borderColor: AppColors.navyBg,
                            backgroundColor: AppColors.coralAccent,
                            isSelected: _selectedRole == 'employee',
                            onTap: () => setState(() {
                                  _selectedRole = 'employee';
                                }),
                            features: const [
                              _ProfileFeature(
                                icon: Icons.payments_outlined,
                                label: 'Get paid quickly',
                              ),
                              _ProfileFeature(
                                icon: Icons.calendar_today_outlined,
                                label: 'Flexible shifts',
                              ),
                              _ProfileFeature(
                                icon: Icons.star_border_rounded,
                                label: 'Rate employers',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _ProfileCard(
                            title: 'EMPLOYER',
                            description:
                                'Post jobs fast and connect with available workers.',
                            illustrationPath: 'assets/images/employer.png',
                            titleColor: AppColors.coralAccent,
                            bodyColor: const Color(0xFFF4F1EC),
                            iconColor: AppColors.coralAccent,
                            borderColor: AppColors.coralAccent,
                            backgroundColor: AppColors.navyBg,
                            isSelected: _selectedRole == 'employer',
                            onTap: () => setState(() {
                                  _selectedRole = 'employer';
                                }),
                            features: const [
                              _ProfileFeature(
                                icon: Icons.campaign_outlined,
                                label: 'Post jobs',
                              ),
                              _ProfileFeature(
                                icon: Icons.assignment_turned_in_outlined,
                                label: 'Review profiles',
                              ),
                              _ProfileFeature(
                                icon: Icons.chat_bubble_outline_rounded,
                                label: 'Direct chat',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 26),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: canContinue ? _handleContinue : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.navyBg,
                          disabledBackgroundColor:
                              AppColors.navyBg.withOpacity(0.45),
                          elevation: canContinue ? 10 : 0,
                          shadowColor: canContinue
                              ? AppColors.coralAccent.withOpacity(0.45)
                              : Colors.transparent,
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                                'Continue',
                                style: AppTextStyles.buttonLabel(
                                  color: canContinue
                                      ? AppColors.coralAccent
                                      : AppColors.coralAccent.withOpacity(0.55),
                                  fontSize: 18,
                                ),
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.78),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                      children: [
                        const TextSpan(
                          text: 'Already have an account? ',
                        ),
                        TextSpan(
                          text: 'Log in',
                          style: const TextStyle(
                            color: AppColors.coralAccent,
                            fontWeight: FontWeight.w700,
                          ),
                          recognizer: TapGestureRecognizer()..onTap = _goToLogin,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.title,
    required this.description,
    required this.illustrationPath,
    required this.features,
    required this.titleColor,
    required this.bodyColor,
    required this.iconColor,
    required this.borderColor,
    required this.backgroundColor,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String description;
  final String illustrationPath;
  final List<_ProfileFeature> features;
  final Color titleColor;
  final Color bodyColor;
  final Color iconColor;
  final Color borderColor;
  final Color backgroundColor;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isSelected ? 1.02 : 1.0,
      duration: const Duration(milliseconds: 180),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: borderColor,
              width: isSelected ? 2.8 : 1.6,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: borderColor.withOpacity(0.28),
                  blurRadius: 16,
                  spreadRadius: 1,
                  offset: const Offset(0, 8),
                )
              else
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SizedBox(
                height: 130,
                child: Image.asset(
                  illustrationPath,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 26,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: bodyColor.withOpacity(0.92),
                  fontSize: 12.8,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              Column(
                children: features
                    .map(
                      (feature) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              feature.icon,
                              size: 18,
                              color: iconColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                feature.label,
                                style: TextStyle(
                                  color: bodyColor.withOpacity(0.95),
                                  fontSize: 12.8,
                                  fontWeight: FontWeight.w600,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileFeature {
  const _ProfileFeature({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}