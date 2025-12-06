import 'package:flutter/material.dart';
import 'package:freezme/main.dart';
import 'package:freezme/ui/onboarding/onboarding_step1.dart';
import 'package:freezme/ui/onboarding/onboarding_step2.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  int _currentStep = 0;
  final PageController _pageController = PageController();

  void _next() {
    if (_currentStep < 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      // onboarding finished, navigate to profile completion
      AppFlowScope.of(context).replaceStack([AppStage.profileCompletion]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome to Freezme')),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          OnboardingStep1(),
          OnboardingStep2(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _next,
        label: Text(_currentStep == 0 ? 'Next' : 'Get Started'),
        icon: const Icon(Icons.arrow_forward),
      ),
    );
  }
}
