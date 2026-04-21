import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../../../core/theme/app_ui.dart';

import '../services/auth_service.dart';
import 'choose_profile_page.dart';

class EmailSignupPage extends StatefulWidget {
  const EmailSignupPage({super.key});

  @override
  State<EmailSignupPage> createState() => _EmailSignupPageState();
}

class _EmailSignupPageState extends State<EmailSignupPage> {
  late final AuthService _authService;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  late final RegExp emailRegex;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _verificationEmailSent = false;
  String? _userEmail;
  Timer? _verificationTimer;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _verificationTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (_isLoading) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showError('Please complete all fields');
      return;
    }

    if (!emailRegex.hasMatch(email)) {
      _showError('Please enter a valid email address');
      return;
    }

    if (password.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    if (password != confirmPassword) {
      _showError('Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.signUpWithEmail(
        email: email,
        password: password,
      );

      if (mounted) {
        // Send verification email
        try {
          await _authService.sendCurrentUserEmailVerification();
        } catch (e) {
          if (mounted) {
            _showError('Failed to send verification email');
          }
          return;
        }

        // Switch to verification state
        setState(() {
          _userEmail = email;
          _verificationEmailSent = true;
        });

        // Start polling for verification
        _startVerificationPolling();
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

  Future<void> _resendVerificationEmail() async {
    try {
      await _authService.sendCurrentUserEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent again'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to resend verification email');
      }
    }
  }

  void _startVerificationPolling() {
    _verificationTimer?.cancel(); // Ensure no duplicate timers
    _verificationTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final isVerified = await _authService.reloadAndCheckEmailVerified();
        if (isVerified) {
          timer.cancel();
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ChooseProfilePage(),
              ),
            );
          }
        }
      } catch (e) {
        // Silently handle polling errors to avoid crashing
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_verificationEmailSent) {
      return _buildVerificationScreen();
    } else {
      return _buildSignupForm();
    }
  }

  Widget _buildSignupForm() {
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
                'Create your account',
                style: AppTextStyles.heading(
                  color: AppColors.coralAccent,
                  fontSize: 40,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Enter your details to continue',
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

              const SizedBox(height: AppSpacing.field),

              TextFormField(
                controller: _confirmPasswordController,
                enabled: !_isLoading,
                obscureText: _obscureConfirmPassword,
                decoration: AppInputDecorations.authField(
                  label: 'Confirm password',
                  hint: '••••••••',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white54,
                    ),
                    onPressed: !_isLoading
                        ? () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword)
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
                  onPressed: _isLoading ? null : _handleSignUp,
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
                          'Create account',
                          style: AppTextStyles.buttonLabel(color: AppColors.navyBg),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationScreen() {
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
                  onPressed: () => Navigator.pop(context),
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
                      'Verify your email',
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
                      'Check your inbox and verify your email to continue. We\'ll automatically continue once your email is verified.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.lightText,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    if (_userEmail != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Email: $_userEmail',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.lightText,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: AppSpacing.buttonHeight,
                child: ElevatedButton(
                  onPressed: _resendVerificationEmail,
                  style: AppButtonStyles.primary(
                    disabledBackgroundColor: Colors.grey.shade600,
                  ),
                  child: Text(
                    'Resend email',
                    style: AppTextStyles.buttonLabel(color: AppColors.navyBg),
                  ),
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
