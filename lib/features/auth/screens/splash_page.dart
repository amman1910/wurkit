import 'package:flutter/material.dart';

import '../../../core/theme/app_branding.dart';
import '../../../core/theme/app_ui.dart';
import 'welcome_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1600), () {
      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WelcomePage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppBranding.backgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.horizontal),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  AppBranding.logoPath,
                  width: 150,
                  height: 150,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 20),
                Text(
                  AppBranding.appName,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.heading(
                    color: AppBranding.primaryColor,
                    fontSize: 34,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  AppBranding.slogan,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppBranding.textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
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