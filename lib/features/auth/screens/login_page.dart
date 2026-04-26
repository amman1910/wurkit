import 'package:flutter/material.dart';
import '../../../core/theme/app_ui.dart';

import '../services/auth_service.dart';
import 'login_email_page.dart';
import 'choose_profile_page.dart';
import '../../employee_profile/screens/employee_basic_info_page.dart';
import '../../employee_profile/screens/employee_work_preferences_page.dart';
import '../../employee_profile/screens/employee_availability_location_page.dart';
import '../../employee_profile/screens/employee_experience_summary_page.dart';
import '../../employer_profile/screens/employer_business_info_page.dart';
import '../../employer_profile/screens/employer_business_location_page.dart';
import '../../employer_profile/screens/employer_hiring_preferences_page.dart';
import '../../employer_profile/screens/employer_profile_summary_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final AuthService _authService;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
  }

  Future<void> _navigateAfterLogin(PostLoginNavigationState routeState) async {
    if (!mounted) return;

    if (routeState == PostLoginNavigationState.chooseRole) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ChooseProfilePage(),
        ),
      );
    } else if (routeState == PostLoginNavigationState.employeeBasicInfo) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const EmployeeBasicInfoPage(),
        ),
      );
    } else if (routeState == PostLoginNavigationState.employeeWorkPreferences) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const EmployeeWorkPreferencesPage(),
        ),
      );
    } else if (routeState == PostLoginNavigationState.employeeAvailabilityLocation) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const EmployeeAvailabilityLocationPage(),
        ),
      );
    } else if (routeState == PostLoginNavigationState.employeeExperienceSummary) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const EmployeeExperienceSummaryPage(),
        ),
      );
    } else if (routeState == PostLoginNavigationState.employerBusinessInfo) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const EmployerBusinessInfoPage(),
        ),
      );
    } else if (routeState == PostLoginNavigationState.employerBusinessLocation) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const EmployerBusinessLocationPage(),
        ),
      );
    } else if (routeState == PostLoginNavigationState.employerHiringPreferences) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const EmployerHiringPreferencesPage(),
        ),
      );
    } else if (routeState == PostLoginNavigationState.employerProfileSummary) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const EmployerProfileSummaryPage(),
        ),
      );
    } else if (routeState == PostLoginNavigationState.completed) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const TemporaryHomeComingSoonPage(),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signed in successfully with Google'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final credential = await _authService.signInWithGoogle();

      if (credential != null && mounted) {
        final routeState = await _authService.getPostLoginNavigationState();
        await _navigateAfterLogin(routeState);
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $errorMessage'),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.horizontal,
            vertical: AppSpacing.vertical,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  style: AppButtonStyles.text(),
                  child: const Text('Back', style: AppTextStyles.textButton),
                ),
              ),
              const Spacer(flex: 1),

              Center(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Welcome back',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: AppTextStyles.heading(
                        color: AppColors.coralAccent,
                        fontSize: 36,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Sign in to continue',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.lightText,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: AppSpacing.buttonHeight,
                child: ElevatedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginEmailPage(),
                            ),
                          );
                        },
                  style: AppButtonStyles.primary(
                    disabledBackgroundColor: Colors.grey.shade600,
                  ),
                  icon: Padding(
                    padding: const EdgeInsets.only(right: 10.0),
                    child: Image.asset(
                      'assets/images/email-icon.png',
                      width: 30,
                      height: 30,
                      fit: BoxFit.contain,
                    ),
                  ),
                  label: Text(
                    'Continue with Email',
                    style: AppTextStyles.buttonLabel(color: AppColors.navyBg),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: AppSpacing.buttonHeight,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleGoogleSignIn,
                  style: AppButtonStyles.whiteFilled(
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  icon: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.coralAccent,
                            ),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.only(right: 10.0),
                          child: Image.asset(
                            'assets/images/google-logo-icon.png',
                            width: 22,
                            height: 22,
                            fit: BoxFit.contain,
                          ),
                        ),
                  label: Text(
                    'Continue with Google',
                    style: AppTextStyles.buttonLabel(color: AppColors.darkText),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Center(
                child: Image.asset(
                  'assets/images/wurkit_logo.png',
                  height: 60,
                  fit: BoxFit.contain,
                  opacity: const AlwaysStoppedAnimation(0.8),
                ),
              ),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}

class TemporaryHomeComingSoonPage extends StatelessWidget {
  const TemporaryHomeComingSoonPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.horizontal,
            vertical: AppSpacing.vertical,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/wurkit_logo.png',
                  height: 92,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 28),
                Text(
                  'Welcome back',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.heading(
                    color: AppColors.coralAccent,
                    fontSize: 34,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your home screen is still under development and will be ready soon.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.lightText,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Profile completed successfully.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
