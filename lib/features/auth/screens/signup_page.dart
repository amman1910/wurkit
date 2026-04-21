import 'package:flutter/material.dart';
import '../../../core/theme/app_ui.dart';

import '../services/auth_service.dart';
import 'email_signup_page.dart';
import 'choose_profile_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  late final AuthService _authService;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final credential = await _authService.signInWithGoogle();

      if (credential == null) {
        // User cancelled the flow
        return;
      }

      if (credential.additionalUserInfo?.isNewUser == true) {
        // New user - proceed to onboarding
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account created successfully with Google'),
              duration: Duration(seconds: 1),
            ),
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ChooseProfilePage(),
            ),
          );
        }
      } else {
        // Existing user - show error and sign out
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This Google account is already registered. Please sign in instead.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
          await _authService.signOut();
        }
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
                      'Create account',
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
                      'Choose how you want to sign up',
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
                              builder: (context) => const EmailSignupPage(),
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