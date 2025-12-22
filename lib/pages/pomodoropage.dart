import 'dart:async';
import 'package:flutter/material.dart';

import '../db/tasks_db.dart';
import '../notification.dart';
import '../widgets/left_panel.dart';


class Pomodoro extends StatefulWidget {
  const Pomodoro({super.key});

  @override
  State<Pomodoro> createState() => _PomodoroState();
}

class _PomodoroState extends State<Pomodoro> {
  final taskdatabase = tasksdb();

  static const int WORK_MIN = 3;        // set your work duration
  static const int SHORT_BREAK_MIN = 5; // short break
  static const int LONG_BREAK_MIN = 20; // long break

  int reps = 0;
  late int totalSeconds;
  late int secondsRemaining;
  bool isRunning = false;
  String currentLabel = "Timer";
  String completedMarks = "";
  Timer? timer;
  int workSessionsDone = 0; // sessions completed today

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _loadWorkSessions();      // load today's sessions once
    totalSeconds = WORK_MIN * 60;
    secondsRemaining = totalSeconds;
  }

  Future<void> _loadWorkSessions() async {
    final sessions = await taskdatabase.getWorkSessionsToday();
    setState(() {
      workSessionsDone = sessions;
    });
  }

  Future<void> _initializeNotifications() async {
    await LocalNotifications.init();
    await LocalNotifications.requestExactAlarmPermissionSafe();
  }

  void startTimer() {
    reps++;

    if (reps % 8 == 0) {
      totalSeconds = LONG_BREAK_MIN * 60;
      currentLabel = "Break";

      // Notify long break start
      LocalNotifications.showScheduleNotification(
        duration: 0,
        title: "Break Time!",
        body: "Take a long break. Relax and recharge.",
        payload: "break_start",
      );
    } else if (reps % 2 == 0) {
      totalSeconds = SHORT_BREAK_MIN * 60;
      currentLabel = "Break";

      // Notify short break start
      LocalNotifications.showScheduleNotification(
        duration: 0,
        title: "Short Break",
        body: "Hang in there! Your short break starts now.",
        payload: "short_break_start",
      );
    } else {
      totalSeconds = WORK_MIN * 60;
      currentLabel = "Work";

      // Notify work session start
      LocalNotifications.showScheduleNotification(
        duration: 0,
        title: "Work Session Started",
        body: "Focus now! Let's get some work done.",
        payload: "work_start",
      );


      // Pre-break alert 1 minute before work session ends
      if (totalSeconds > 60) {
        int duration = totalSeconds - 60;
        print(duration);
        LocalNotifications.showScheduleNotification(
          duration: duration,
          title: "Almost Done!",
          body: "Your work session is almost over. Get ready to rest.",
          payload: "work_almost_over",
        );
      }
    }

    secondsRemaining = totalSeconds;
    timer?.cancel();

    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        if (secondsRemaining > 0) {
          secondsRemaining--;
        } else {
          timer?.cancel();

          if (currentLabel == "Work") {
            completedMarks = "✓" * ((reps / 2).floor());
            taskdatabase.addWorkSession(); // save session to DB
            _loadWorkSessions();           // update today's count
          }

          startTimer(); // start next session automatically
        }
      });
    });

    setState(() => isRunning = true);
  }

  void resetTimer() {
    timer?.cancel();
    reps = 0;
    LocalNotifications.cancelAll();  // cancel all pending notifications
    totalSeconds = WORK_MIN * 60;
    secondsRemaining = totalSeconds;
    currentLabel = "Timer";
    completedMarks = "";
    isRunning = false;
    setState(() {});
  }

  String formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  double get progress => 1 - secondsRemaining / totalSeconds;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const double size = 180;
    const double strokeWidth = 12;
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      drawer: Drawer(
        child: SizedBox(
          width: screenSize.width * 0.5,
          child: LeftPanel(),
        ),
      ),
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        title: Text(
          'Focentra - Pomodoro',
          style: TextStyle(
            fontFamily: 'OpenSans',
            fontWeight: FontWeight.bold,
            color: colorScheme.onPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Row(
          children: [
            // LEFT PANEL
            //const LeftPanel(currentPage: 'Pomodoro'),
            
            // RIGHT PANEL (Pomodoro content)
            Expanded(
              child: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primaryContainer.withOpacity(0.3),
                      colorScheme.secondaryContainer.withOpacity(0.2),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Page Title
                        Center(
                          child: Text(
                            'Pomodoro Timer',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onBackground,
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        
                        // Centered timer content
                        Center(
                          child: Column(
                            children: [
                              // Session label
                              Text(
                                currentLabel,
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Montserrat',
                                  color: colorScheme.onBackground,
                                ),
                              ),
                              const SizedBox(height: 30),

                              // Timer + progress ring
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: size,
                                    height: size,
                                    child: CircularProgressIndicator(
                                      value: progress,
                                      strokeWidth: strokeWidth,
                                      valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                                      backgroundColor: colorScheme.surface.withOpacity(0.3),
                                    ),
                                  ),
                                  ClipOval(
                                    child: SizedBox(
                                      width: size - strokeWidth,
                                      height: size - strokeWidth,
                                      child: Image.asset(
                                        'assets/c3.png',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    formatTime(secondsRemaining),
                                    style: const TextStyle(
                                      fontSize: 36,
                                      fontFamily: 'OpenSans',
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 40),

                              // Buttons
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton(
                                    onPressed: isRunning ? null : startTimer,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: colorScheme.primary,
                                      foregroundColor: colorScheme.onPrimary,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 32, vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                      elevation: 3,
                                    ),
                                    child: Text(
                                      "Start",
                                      style: TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  ElevatedButton(
                                    onPressed: resetTimer,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: colorScheme.secondary,
                                      foregroundColor: colorScheme.onSecondary,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 32, vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                      elevation: 3,
                                    ),
                                    child: Text(
                                      "Reset",
                                      style: TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 30),

                              // Completed marks
                              Text(
                                completedMarks,
                                style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary),
                              ),

                              const SizedBox(height: 30),

                              // Work sessions today display
                              Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                elevation: 4,
                                color: colorScheme.surfaceVariant,
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    children: [
                                      Text(
                                        "Work Sessions Today",
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          fontFamily: 'Montserrat',
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: List.generate(
                                          8, // Max sessions
                                          (index) => Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 4),
                                            child: CircleAvatar(
                                              radius: 12,
                                              backgroundColor: index < workSessionsDone
                                                  ? colorScheme.primary
                                                  : colorScheme.onSurface.withOpacity(0.2),
                                              child: index < workSessionsDone
                                                  ? Icon(
                                                      Icons.check,
                                                      color: colorScheme.onPrimary,
                                                      size: 16,
                                                    )
                                                  : null,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        "$workSessionsDone / 10 sessions completed",
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Montserrat',
                                          color: colorScheme.onSurface.withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 30),
                              
                              // Pomodoro technique info card
                              Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                elevation: 4,
                                color: colorScheme.primaryContainer.withOpacity(0.3),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Pomodoro Technique",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          fontFamily: 'Montserrat',
                                          color: colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        "• 25 minutes of focused work\n• 5 minutes short break\n• 20 minutes long break (every 4 sessions)\n• Stay focused and productive!",
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontFamily: 'Montserrat',
                                          color: colorScheme.onPrimaryContainer.withOpacity(0.8),
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }
}

