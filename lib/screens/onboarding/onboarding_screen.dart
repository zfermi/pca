import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/app_colors.dart';
import '../home_screen.dart';
import 'steps/welcome_step.dart';
import 'steps/pin_setup_step.dart';
import 'steps/permission_step.dart';
import 'steps/account_setup_step.dart';
import 'steps/add_first_child_step.dart';
import 'steps/setup_complete_step.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late final List<Widget> _steps;
  late int _totalSteps;

  @override
  void initState() {
    super.initState();
    _buildSteps();
  }

  void _buildSteps() {
    _steps = [
      WelcomeStep(onNext: _nextPage),
      PinSetupStep(onPinSet: _onPinSet),
      if (Platform.isAndroid)
        PermissionStep(onPermissionResult: _onPermissionResult),
      AddFirstChildStep(onChildAdded: _onChildAdded, onSkip: _nextPage),
      AccountSetupStep(onComplete: _nextPage, onSkip: _nextPage),
      SetupCompleteStep(onFinish: _finishOnboarding),
    ];
    _totalSteps = _steps.length;
  }

  void _nextPage() {
    if (_currentPage < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onPinSet() => _nextPage();
  void _onPermissionResult(bool granted) => _nextPage();
  void _onChildAdded() => _nextPage();

  void _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(40, 20, 40, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: List.generate(_totalSteps, (index) {
                          return Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: 4,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: index <= _currentPage
                                    ? AppColors.primary
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Step ${_currentPage + 1} of $_totalSteps',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (page) {
                    setState(() => _currentPage = page);
                  },
                  children: _steps,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
