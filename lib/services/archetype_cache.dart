/// Lightweight in-memory cache for the current user's archetype.
/// Populated when dashboard loads. Used by task page for instant
/// AI suggestions without a network call.
class ArchetypeCache {
  static String _archetype = '';
  static int _daysActive = 0;

  static void set(String archetype, int daysActive) {
    _archetype = archetype;
    _daysActive = daysActive;
  }

  static String get archetype => _archetype;
  static int get daysActive => _daysActive;
  static bool get hasData => _archetype.isNotEmpty;

  // ── Suggested base points per archetype per interval ──────────
  // These are research-grounded recommendations based on
  // archetype centroid completion ratios and interval difficulty.
  // User can always override — this is a suggestion only.
  static int suggestPoints(String interval) {
    if (!hasData) return _defaultPoints(interval);

    switch (_archetype) {
      case 'Consistent Achiever':
        // High completion rate — standard points, well distributed
        switch (interval) {
          case 'Daily':   return 15;
          case 'Weekly':  return 60;
          case 'Monthly': return 200;
        }
      case 'Night Owl Performer':
        // Stronger on weekly — suggest more weight there
        switch (interval) {
          case 'Daily':   return 12;
          case 'Weekly':  return 70;
          case 'Monthly': return 180;
        }
      case 'Easily Distracted User':
        // Keep daily small — achievable wins matter most
        switch (interval) {
          case 'Daily':   return 10;
          case 'Weekly':  return 40;
          case 'Monthly': return 100;
        }
      case 'Last-Minute Performer':
        // Front-load weekly and monthly — matches deadline style
        switch (interval) {
          case 'Daily':   return 10;
          case 'Weekly':  return 80;
          case 'Monthly': return 220;
        }
      case 'Burnout-Prone User':
        // Keep everything small — protect against overcommitment
        switch (interval) {
          case 'Daily':   return 8;
          case 'Weekly':  return 40;
          case 'Monthly': return 100;
        }
    }
    return _defaultPoints(interval);
  }

  static int _defaultPoints(String interval) {
    switch (interval) {
      case 'Daily':   return 10;
      case 'Weekly':  return 50;
      case 'Monthly': return 150;
      default:        return 10;
    }
  }

  // ── Archetype emoji ────────────────────────────────────────────
  static String get emoji {
    switch (_archetype) {
      case 'Consistent Achiever':    return '🏆';
      case 'Night Owl Performer':    return '🌙';
      case 'Easily Distracted User': return '⚡';
      case 'Last-Minute Performer':  return '💪';
      case 'Burnout-Prone User':     return '🌱';
      default:                       return '🤖';
    }
  }

  // ── Point caps per interval ────────────────────────────────────
  // Daily total cap: 100, Weekly: 700, Monthly: 3000
  // Individual task cap is a fraction of total cap
  static int maxPointsForTask(String interval) {
    switch (interval) {
      case 'Daily':   return 100;   // single task cannot exceed daily cap
      case 'Weekly':  return 200;   // reasonable weekly task max
      case 'Monthly': return 500;   // reasonable monthly task max
      default:        return 100;
    }
  }
}