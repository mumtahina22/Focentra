import 'archetype_cache.dart';

/// A suggested point value plus a short, human-readable reason.
class PointSuggestion {
  final int points;
  final String reason;

  const PointSuggestion(this.points, this.reason);
}

class _EffortRule {
  final double factor;
  final String label;
  final List<String> words;

  const _EffortRule(this.factor, this.label, this.words);
}

/// Rule-based, archetype-aware point suggestion.
///
/// No language model and no network call, so it is instant and works
/// offline. Steps:
/// 1. Start from the user's archetype baseline for the interval
///    (ArchetypeCache.suggestPoints).
/// 2. Scale it by how much effort the task text suggests:
///    a stated duration ("2 hours") if there is one; otherwise
///    effort keywords ("exam", "drink water") and quantities
///    ("3 chapters", "50 pages").
/// 3. Burnout-Prone users get a lower ceiling to avoid overcommitment.
/// 4. Round to the nearest 5 and keep within the per-task cap.
class PointSuggester {
  static const double _minFactor = 0.5;
  static const double _maxFactor = 2.5;
  static const double _burnoutMaxFactor = 1.8;

  /// Minutes of work for a "standard" task in each interval.
  static const Map<String, double> _standardMinutes = {
    'Daily': 45,
    'Weekly': 180,
    'Monthly': 600,
  };

  /// Effort keywords. If several match, the heaviest one wins.
  static const List<_EffortRule> _rules = [
    _EffortRule(2.2, 'Major task', [
      'thesis', 'dissertation', 'defense', 'defence', 'final exam',
      'finals', 'capstone',
    ]),
    _EffortRule(1.7, 'Big task', [
      'exam', 'midterm', 'project', 'research', 'report', 'presentation',
      'essay', 'paper', 'assignment', 'interview', 'application',
      'deadline', 'implement', 'develop', 'build', 'debug', 'revise',
      'revision', 'mock test',
    ]),
    _EffortRule(1.3, 'Medium task', [
      'study', 'homework', 'practice', 'lab', 'lecture', 'class', 'course',
      'read', 'review', 'notes', 'learn', 'write', 'workout', 'gym', 'run',
      'exercise', 'clean', 'cook', 'laundry', 'meeting', 'tutorial', 'quiz',
      'code', 'coding',
    ]),
    _EffortRule(0.6, 'Quick task', [
      'drink water', 'water', 'walk', 'stretch', 'meditate', 'meditation',
      'journal', 'make bed', 'email', 'reply', 'call', 'vitamins', 'brush',
      'floss', 'skincare', 'sleep early', 'wake up', 'tidy', 'plan day',
      'to-do', 'todo',
    ]),
  ];

  /// Units that are each a sizeable piece of work ("3 chapters").
  static const Set<String> _bigUnits = {
    'chapter', 'lesson', 'lecture', 'module', 'assignment',
  };

  /// Units counted in larger numbers, with a "standard" amount.
  static const Map<String, double> _smallUnitStandard = {
    'page': 20,
    'problem': 10,
    'question': 10,
    'exercise': 10,
    'km': 3,
  };

  static final RegExp _durationPattern = RegExp(
    r'(\d+(?:\.\d+)?)\s*(hours?|hrs?|h|minutes?|mins?|m)\b',
  );

  static final RegExp _quantityPattern = RegExp(
    r'(\d+)\s*(chapters?|lessons?|lectures?|modules?|assignments?|pages?|problems?|questions?|exercises?|km|kilometers?|kilometres?)\b',
  );

  static PointSuggestion suggest({
    required String title,
    required String description,
    required String interval,
  }) {
    final text = '$title $description'.toLowerCase();
    final base = ArchetypeCache.suggestPoints(interval);

    double factor;
    String reason;

    final minutes = _statedMinutes(text);
    if (minutes != null) {
      // A stated duration is the most direct effort signal.
      final standard = _standardMinutes[interval] ?? 45;
      factor = minutes / standard;
      reason = 'About ${_formatMinutes(minutes)} of work';
    } else {
      final parts = <String>[];

      // Effort keywords: the heaviest match wins.
      double keywordFactor = 1.0;
      for (final rule in _rules) {
        for (final word in rule.words) {
          if (_containsWord(text, word) &&
              (parts.isEmpty || rule.factor > keywordFactor)) {
            keywordFactor = rule.factor;
            parts
              ..clear()
              ..add('${rule.label} ("$word")');
          }
        }
      }

      // Quantities: "3 chapters", "50 pages".
      double quantityFactor = 1.0;
      final q = _quantityPattern.firstMatch(text);
      if (q != null) {
        final n = int.parse(q.group(1)!);
        final unit = _normalizeUnit(q.group(2)!);
        if (_bigUnits.contains(unit)) {
          quantityFactor = (1 + 0.3 * (n - 1)).clamp(0.6, 2.0).toDouble();
        } else {
          final standard = _smallUnitStandard[unit] ?? 10;
          quantityFactor = (n / standard).clamp(0.6, 2.0).toDouble();
        }
        parts.add('$n ${unit == 'km' ? 'km' : (n == 1 ? unit : '${unit}s')}');
      }

      factor = keywordFactor * quantityFactor;
      reason = parts.isEmpty ? 'Standard task' : parts.join(' · ');
    }

    // Keep the scaling within sensible bounds.
    final isBurnoutProne = ArchetypeCache.archetype == 'Burnout-Prone User';
    final ceiling = isBurnoutProne ? _burnoutMaxFactor : _maxFactor;
    if (factor > ceiling) {
      factor = ceiling;
      if (isBurnoutProne) reason = '$reason · kept small to avoid overload';
    }
    if (factor < _minFactor) factor = _minFactor;

    // Round to the nearest 5 and keep within the per-task cap.
    int points = ((base * factor) / 5).round() * 5;
    if (points < 5) points = 5;
    points = points.clamp(1, ArchetypeCache.maxPointsForTask(interval));

    return PointSuggestion(points, reason);
  }

  // ── Helpers ──────────────────────────────────────────────────────

  static double? _statedMinutes(String text) {
    double total = 0;
    for (final m in _durationPattern.allMatches(text)) {
      final value = double.parse(m.group(1)!);
      final unit = m.group(2)!;
      total += unit.startsWith('h') ? value * 60 : value;
    }
    return total > 0 ? total : null;
  }

  static bool _containsWord(String text, String word) {
    return RegExp('\\b${RegExp.escape(word)}\\b').hasMatch(text);
  }

  static String _normalizeUnit(String unit) {
    if (unit.startsWith('kilomet')) return 'km';
    if (unit != 'km' && unit.endsWith('s')) {
      return unit.substring(0, unit.length - 1);
    }
    return unit;
  }

  static String _formatMinutes(double minutes) {
    if (minutes < 60) return '${minutes.round()} min';
    final hours = minutes / 60;
    final text = hours == hours.roundToDouble()
        ? hours.toInt().toString()
        : hours.toStringAsFixed(1);
    return '$text h';
  }
}
