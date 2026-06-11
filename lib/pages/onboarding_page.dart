import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/ml_service.dart';
import 'maindashboard.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _answerC = 2; // Default middle value
  int _answerN = 2;
  int _answerO = 2;
  bool _isSubmitting = false;

  // Questions mapped to Big Five proxies
  final List<Map<String, String>> _questions = [
    {
      'trait': 'C',
      'question': 'I always finish tasks before their deadlines.',
      'low': 'Rarely',
      'high': 'Always',
    },
    {
      'trait': 'N',
      'question': 'I often feel overwhelmed by my workload.',
      'low': 'Never',
      'high': 'Always',
    },
    {
      'trait': 'O',
      'question': 'I prefer varied tasks over fixed daily routines.',
      'low': 'Disagree',
      'high': 'Agree',
    },
  ];

Future<void> _submit() async {
  setState(() => _isSubmitting = true);

  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) {
    setState(() => _isSubmitting = false);
    return;
  }

  // Fire and forget — don't block navigation on ML response
  MLService.submitOnboarding(
    uid: uid,
    answerC: _answerC,
    answerN: _answerN,
    answerO: _answerO,
  ); // no await — proceed immediately

  if (mounted) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainDashboard()),
      (route) => false,
    );
  }
}

  Widget _buildQuestion({
    required int index,
    required String question,
    required String low,
    required String high,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    question,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: colorScheme.primary,
                thumbColor: colorScheme.primary,
                inactiveTrackColor:
                    colorScheme.primary.withOpacity(0.2),
                overlayColor: colorScheme.primary.withOpacity(0.1),
              ),
              child: Slider(
                value: value.toDouble(),
                min: 0,
                max: 4,
                divisions: 4,
                onChanged: (v) => onChanged(v.toInt()),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  low,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 12,
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                Text(
                  high,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 12,
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        automaticallyImplyLeading: false, // No back button
        title: Text(
          'Focentra — Quick Setup',
          style: TextStyle(
            fontFamily: 'OpenSans',
            fontWeight: FontWeight.bold,
            color: colorScheme.onPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'Help us personalise your experience',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onBackground,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Answer 3 quick questions. Takes 30 seconds.',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    color: colorScheme.onBackground.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),

              // Question 1 — Conscientiousness
              _buildQuestion(
                index: 0,
                question: _questions[0]['question']!,
                low: _questions[0]['low']!,
                high: _questions[0]['high']!,
                value: _answerC,
                onChanged: (v) => setState(() => _answerC = v),
              ),

              // Question 2 — Neuroticism
              _buildQuestion(
                index: 1,
                question: _questions[1]['question']!,
                low: _questions[1]['low']!,
                high: _questions[1]['high']!,
                value: _answerN,
                onChanged: (v) => setState(() => _answerN = v),
              ),

              // Question 3 — Openness
              _buildQuestion(
                index: 2,
                question: _questions[2]['question']!,
                low: _questions[2]['low']!,
                high: _questions[2]['high']!,
                value: _answerO,
                onChanged: (v) => setState(() => _answerO = v),
              ),

              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 3,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Start My Journey',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              Center(
                child: TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          // Skip onboarding — go straight to dashboard
                          // ML will use population defaults
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const MainDashboard()),
                            (route) => false,
                          );
                        },
                  child: Text(
                    'Skip for now',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      color: colorScheme.onBackground.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}