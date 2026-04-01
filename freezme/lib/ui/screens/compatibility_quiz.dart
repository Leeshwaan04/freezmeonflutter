import 'package:flutter/material.dart';
import '../theme.dart';
import '../../controllers/flow_controller.dart';
import '../widgets/freezme_logo.dart';

class CompatibilityQuizPage extends StatefulWidget {
  const CompatibilityQuizPage({super.key});

  @override
  State<CompatibilityQuizPage> createState() => _CompatibilityQuizPageState();
}

class _CompatibilityQuizPageState extends State<CompatibilityQuizPage> {
  static const _questions = <({String emoji, String text})>[
    (emoji: '💬', text: 'I prefer deep conversations over small talk'),
    (emoji: '🎒', text: 'I enjoy spontaneous adventures'),
    (emoji: '⏰', text: 'Quality time is my love language'),
    (emoji: '🏠', text: 'I\'m more introverted than extroverted'),
    (emoji: '🤗', text: 'Physical touch is important to me'),
    (emoji: '🎯', text: 'I value ambition and drive'),
    (emoji: '🧘', text: 'I need alone time to recharge'),
    (emoji: '📅', text: 'I\'m a planner, not a go-with-the-flow person'),
    (emoji: '💖', text: 'I express my feelings openly'),
    (emoji: '🎨', text: 'Shared hobbies are essential in a relationship'),
  ];

  int _currentQuestion = 0;
  final List<double> _answers =
      List<double>.filled(_questions.length, 50.0, growable: false);

  void _handleNext(AppFlowController flow) {
    if (_currentQuestion < _questions.length - 1) {
      setState(() => _currentQuestion++);
    } else {
      flow.pop();
    }
  }

  void _handleBack() {
    if (_currentQuestion > 0) {
      setState(() => _currentQuestion--);
    }
  }

  String _emojiForValue(double value) {
    if (value < 25) return '😐';
    if (value < 50) return '🙂';
    if (value < 75) return '😊';
    return '😍';
  }

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context, listen: false);
    final progress = (_currentQuestion + 1) / _questions.length;
    final question = _questions[_currentQuestion];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: FreezmeGradients.backgroundSoft,
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FreezmeLogo(size: LogoSize.sm, showText: true),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: FreezmeColors.border,
                        valueColor: const AlwaysStoppedAnimation(
                          FreezmeColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Question ${_currentQuestion + 1} of ${_questions.length}',
                      style: const TextStyle(color: FreezmeColors.muted),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(question.emoji,
                            style: const TextStyle(fontSize: 60)),
                        const SizedBox(height: 16),
                        Text(
                          question.text,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color: FreezmeColors.neutral,
                                fontWeight: FontWeight.w600,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        Text(
                          _emojiForValue(_answers[_currentQuestion]),
                          style: const TextStyle(fontSize: 60),
                        ),
                        const SizedBox(height: 16),
                        Slider(
                          value: _answers[_currentQuestion],
                          onChanged: (value) {
                            setState(() {
                              _answers[_currentQuestion] = value;
                            });
                          },
                          min: 0,
                          max: 100,
                          activeColor: FreezmeColors.primary,
                          inactiveColor: FreezmeColors.border,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Disagree',
                                style: TextStyle(color: FreezmeColors.muted),
                              ),
                              Text(
                                'Agree',
                                style: TextStyle(color: FreezmeColors.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Row(
                  children: [
                    OutlinedButton(
                      onPressed: _currentQuestion == 0 ? null : _handleBack,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: FreezmeColors.primary,
                        side: const BorderSide(color: FreezmeColors.border),
                        shape: const StadiumBorder(),
                        minimumSize: const Size(56, 56),
                      ),
                      child: const Icon(Icons.chevron_left),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: FreezmeColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(56),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () => _handleNext(flow),
                        icon: Icon(
                          _currentQuestion == _questions.length - 1
                              ? Icons.check
                              : Icons.chevron_right,
                        ),
                        label: Text(
                          _currentQuestion == _questions.length - 1
                              ? 'Complete'
                              : 'Next',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
