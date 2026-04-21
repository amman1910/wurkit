import 'package:flutter/material.dart';
import '../../../core/theme/app_ui.dart';

import '../services/auth_service.dart';
import 'choose_profile_page.dart';
import '../../employee_profile/screens/employee_basic_info_page.dart';
import '../../employee_profile/screens/employee_work_preferences_page.dart';
import '../../employee_profile/screens/employee_availability_location_page.dart';
import '../../employee_profile/screens/employee_experience_summary_page.dart';

class LoginEmailPage extends StatefulWidget {
  const LoginEmailPage({super.key});

  @override
  State<LoginEmailPage> createState() => _LoginEmailPageState();
}

class _LoginEmailPageState extends State<LoginEmailPage> {
  late final AuthService _authService;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Please complete all fields');
      return;
    }

    if (!email.contains('@')) {
      _showError('Please enter a valid email address');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.signInWithEmail(
        email: email,
        password: password,
      );

      if (!mounted) return;

      final routeState = await _authService.getPostLoginNavigationState();

      if (routeState == PostLoginNavigationState.chooseRole) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ChooseProfilePage(),
            ),
          );
        }
      } else if (routeState == PostLoginNavigationState.employeeBasicInfo) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EmployeeBasicInfoPage(),
            ),
          );
        }
      } else if (routeState == PostLoginNavigationState.employeeWorkPreferences) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EmployeeWorkPreferencesPage(),
            ),
          );
        }
      } else if (routeState == PostLoginNavigationState.employeeAvailabilityLocation) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EmployeeAvailabilityLocationPage(),
            ),
          );
        }
      } else if (routeState == PostLoginNavigationState.employeeExperienceSummary) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EmployeeExperienceSummaryPage(),
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("You're in!"),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        _showError(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.horizontal,
            vertical: AppSpacing.vertical,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton(
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                style: AppButtonStyles.text(),
                child: const Text(
                  'Back',
                  style: AppTextStyles.textButton,
                ),
              ),

              const SizedBox(height: AppSpacing.field),

              Text(
                'Sign in to your account',
                style: AppTextStyles.heading(
                  color: AppColors.coralAccent,
                  fontSize: 32,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Enter your email and password to continue',
                style: TextStyle(
                  color: AppColors.lightText,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),

              const SizedBox(height: 40),

              TextFormField(
                controller: _emailController,
                enabled: !_isLoading,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                decoration: AppInputDecorations.authField(
                  label: 'Email',
                  hint: 'example@email.com',
                ),
                style: AppTextStyles.input,
              ),

              const SizedBox(height: AppSpacing.field),

              TextFormField(
                controller: _passwordController,
                enabled: !_isLoading,
                obscureText: _obscurePassword,
                decoration: AppInputDecorations.authField(
                  label: 'Password',
                  hint: '••••••••',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white54,
                    ),
                    onPressed: !_isLoading
                        ? () => setState(() => _obscurePassword = !_obscurePassword)
                        : null,
                  ),
                ),
                style: AppTextStyles.input,
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: AppSpacing.buttonHeight,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: AppButtonStyles.primary(
                    disabledBackgroundColor: Colors.grey.shade600,
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.grey.shade800,
                            ),
                          ),
                        )
                      : Text(
                          'Sign In',
                          style: AppTextStyles.buttonLabel(color: AppColors.navyBg),
                        ),
                ),
              ),

              const SizedBox(height: 20),

              Center(
                child: Image.asset(
                  'assets/images/wurkit_logo.png',
                  height: 50,
                  fit: BoxFit.contain,
                  opacity: const AlwaysStoppedAnimation(0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}