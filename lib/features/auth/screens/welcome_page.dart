import 'package:flutter/material.dart';
import '../../../core/theme/app_ui.dart';
import 'login_page.dart';
import 'signup_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.horizontal,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Logo
              Image.asset(
                'assets/images/wurkit_logo.png',
                height: 120,
                fit: BoxFit.contain,
              ),

              const SizedBox(height: AppSpacing.small),

              // App Name
              SizedBox(
                width: double.infinity,
                height: 125,
                child: Image.asset(
                  'assets/images/wurkit_retro_header.png',
                  fit: BoxFit.contain,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Your shortcut to flexible work',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const Spacer(flex: 2),

              SizedBox(
                width: double.infinity,
                height: AppSpacing.buttonHeight,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SignupPage(),
                      ),
                    );
                  },
                  style: AppButtonStyles.primary(),
                  child: Text(
                    'Get started for free',
                    style: AppTextStyles.buttonLabel(color: AppColors.navyBg),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.section),

              SizedBox(
                width: double.infinity,
                height: AppSpacing.buttonHeight,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                    );
                  },
                  style: AppButtonStyles.secondaryOutline(),
                  child: Text(
                    'Log in',
                    style: AppTextStyles.buttonLabel(color: Colors.white),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Already have an account?',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(width: 4),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginPage(),
                          ),
                        );
                      },
                      child: const Text(
                        'Log in',
                        style: TextStyle(
                          color: AppColors.coralAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 1),

              // Small logo bottom
              Image.asset(
                'assets/images/wurkit_logo.png',
                height: 40,
                opacity: const AlwaysStoppedAnimation(0.8),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
