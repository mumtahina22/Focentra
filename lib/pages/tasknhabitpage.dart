import 'dart:async';
import 'package:flutter/material.dart';

import '../auth/authservice.dart';
import '../db/tasks_db.dart';
import '../services/archetype_cache.dart';
import '../services/point_suggester.dart';
import '../widgets/left_panel.dart';

class TaskPage extends StatefulWidget {
  const TaskPage({super.key});

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage>
    with SingleTickerProviderStateMixin {
  final _taskController   = TextEditingController();
  final _titleController  = TextEditingController();
  final _pointsController = TextEditingController();
  final authservice  = Authservice();
  final taskdatabase = tasksdb();

  final List<String> chooseList = ["Daily", "Weekly", "Monthly"];
  String choose = "Daily";
  late TabController _tabController;

  // Per-tab assigned point totals
  int _dailyAssigned   = 0;
  int _weeklyAssigned  = 0;
  int _monthlyAssigned = 0;

  final List<Color> cardColors = [
    Colors.purple.shade100,
    Colors.blue.shade100,
    Colors.green.shade100,
    Colors.orange.shade100,
    Colors.teal.shade100,
    Colors.pink.shade100,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: chooseList.length, vsync: this);
  }

  @override
  void dispose() {
    _taskController.dispose();
    _titleController.dispose();
    _pointsController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ── Dynamic cap calculation ────────────────────────────────────
  int _dynamicCap(int assigned, int baseCap, int step) {
    if (assigned <= baseCap) return baseCap;
    final extra = assigned - baseCap;
    final steps = (extra ~/ step) + 1;
    return baseCap + steps * step;
  }

  int get dynamicDailyCap =>
      _dynamicCap(_dailyAssigned, 100, 50);
  int get dynamicWeeklyCap =>
      _dynamicCap(_weeklyAssigned, 700, 50);
  int get dynamicMonthlyCap =>
      _dynamicCap(_monthlyAssigned, 3000, 50);

  void addNewTask() {
    _taskController.clear();
    _titleController.clear();
    _pointsController.clear();
    choose = "Daily";

    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        int? localSuggested;
        String? localReason;

        return StatefulBuilder(
          builder: (context, setDialogState) {

            void updateInterval(String interval) {
              setDialogState(() {
                choose = interval;
                localSuggested = null; // reset suggestion on interval change
                localReason = null;
              });
            }

            // Rule-based suggestion from the task text + archetype.
            // Instant, no internet needed (see point_suggester.dart).
            void onSuggestTapped() {
              if (_titleController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a task title first.'),
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }
              final suggestion = PointSuggester.suggest(
                title: _titleController.text,
                description: _taskController.text,
                interval: choose,
              );
              setDialogState(() {
                localSuggested = suggestion.points;
                localReason = suggestion.reason;
              });
            }

            return AlertDialog(
              backgroundColor: colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                "Add New Task",
                style: TextStyle(color: colorScheme.onSurface),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    // Title
                    TextField(
                      controller: _titleController,
                      decoration:
                          const InputDecoration(labelText: "Title"),
                    ),
                    const SizedBox(height: 12),

                    // Description
                    TextField(
                      controller: _taskController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                          labelText: "Description (optional)"),
                    ),
                    const SizedBox(height: 12),

                    // Points field
                    TextField(
                      controller: _pointsController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText:
                            "Points (1-${ArchetypeCache.maxPointsForTask(choose)})",
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── AI Suggest button + chip ───────────────
                    Row(
                      children: [
                        // Suggest button
                        GestureDetector(
                          onTap: onSuggestTapped,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '✨',
                                        style: const TextStyle(
                                            fontSize: 14),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Suggest Points',
                                        style: TextStyle(
                                          fontFamily: 'Montserrat',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: colorScheme.onPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),

                        // Suggestion chip with accept
                        if (localSuggested != null) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer
                                    .withOpacity(0.5),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: colorScheme.primary
                                      .withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${ArchetypeCache.emoji} $localSuggested pts',
                                    style: TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () {
                                      setDialogState(() {
                                        _pointsController.text =
                                            localSuggested.toString();
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary,
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        'Use',
                                        style: TextStyle(
                                          fontFamily: 'Montserrat',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: colorScheme.onPrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Why this number was suggested
                    if (localReason != null) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          localReason!,
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Interval selector
                    Row(
                      children: chooseList.map((period) {
                        final isSelected = choose == period;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => updateInterval(period),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12),
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 2),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colorScheme.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                period,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? colorScheme.onPrimary
                                      : colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_titleController.text.isNotEmpty &&
                        _taskController.text.isNotEmpty ||
                        _titleController.text.isNotEmpty) {
                      final maxPts =
                          ArchetypeCache.maxPointsForTask(choose);
                      final points =
                          int.tryParse(_pointsController.text)
                              ?.clamp(1, maxPts) ??
                          localSuggested ??
                          PointSuggester.suggest(
                            title: _titleController.text,
                            description: _taskController.text,
                            interval: choose,
                          ).points;
                      try {
                        await taskdatabase.inserttask(
                          _taskController.text,
                          _titleController.text,
                          choose,
                          points,
                        );
                        if (mounted) Navigator.pop(context);
                      } catch (e) {
                        print("Error adding task: $e");
                      }
                    }
                  },
                  child: const Text("Add Task"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void toggleDone(
    dynamic id,
    bool done,
    int points,
    String taskInterval,
  ) async {
    await taskdatabase.toggleDone(
      id,
      done,
      taskInterval: taskInterval,
      basePoints: done ? points : 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = authservice.getcurrentUseruid();
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    return DefaultTabController(
      length: chooseList.length,
      child: Scaffold(
        drawer: Drawer(
          child: SizedBox(
            width: size.width * 0.5,
            child: LeftPanel(),
          ),
        ),
        backgroundColor: colorScheme.background,
        appBar: AppBar(
          backgroundColor: colorScheme.primary,
          title: Text(
            'Focentra - Tasks',
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
              Expanded(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'Tasks & Habits',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onBackground,
                          ),
                        ),
                      ),
                    ),

                    // Tab Bar
                    Container(
                      margin:
                          const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        tabs: chooseList
                            .map((c) => Tab(text: c))
                            .toList(),
                        labelColor: colorScheme.primary,
                        unselectedLabelColor:
                            colorScheme.onSurfaceVariant,
                        indicatorColor: colorScheme.primary,
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                      ),
                    ),

                    // Tab Bar View
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: chooseList.map((category) {
                          return StreamBuilder(
                            stream: taskdatabase.tasktable
                                .stream(primaryKey: ['id'])
                                .eq('uid', uid!),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Center(
                                    child:
                                        CircularProgressIndicator());
                              }
                              final allTasks = snapshot.data!;
                              final tasks = allTasks
                                  .where(
                                      (t) => t['choose'] == category)
                                  .toList();

                              // ── Compute assigned points total ──
                              final totalAssigned = tasks.fold<int>(
                                0,
                                (sum, t) =>
                                    sum + ((t['points'] as int?) ?? 0),
                              );

                              // Update state for dynamic caps
                              // Only redraw when the total actually
                              // changed, otherwise this loops forever.
                              WidgetsBinding.instance
                                  .addPostFrameCallback((_) {
                                if (!mounted) return;
                                final previous = category == 'Daily'
                                    ? _dailyAssigned
                                    : category == 'Weekly'
                                        ? _weeklyAssigned
                                        : _monthlyAssigned;
                                if (previous == totalAssigned) return;
                                setState(() {
                                  if (category == 'Daily') {
                                    _dailyAssigned = totalAssigned;
                                  } else if (category == 'Weekly') {
                                    _weeklyAssigned = totalAssigned;
                                  } else {
                                    _monthlyAssigned = totalAssigned;
                                  }
                                });
                              });

                              // Cap for this category
                              final baseCap = category == 'Daily'
                                  ? 100
                                  : category == 'Weekly'
                                      ? 700
                                      : 3000;
                              final dynCap = _dynamicCap(
                                  totalAssigned, baseCap, 50);

                              return Column(
                                children: [
                                  // ── Points counter bar ─────
                                  Container(
                                    margin: const EdgeInsets.fromLTRB(
                                        24, 16, 24, 0),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surfaceVariant
                                          .withOpacity(0.5),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment
                                                  .spaceBetween,
                                          children: [
                                            Text(
                                              '$category Tasks',
                                              style: TextStyle(
                                                fontFamily: 'Montserrat',
                                                fontWeight:
                                                    FontWeight.w600,
                                                fontSize: 13,
                                                color: colorScheme
                                                    .onSurface
                                                    .withOpacity(0.7),
                                              ),
                                            ),
                                            Text(
                                              '$totalAssigned / $dynCap pts assigned',
                                              style: TextStyle(
                                                fontFamily: 'Montserrat',
                                                fontWeight:
                                                    FontWeight.w700,
                                                fontSize: 13,
                                                color: totalAssigned >
                                                        baseCap
                                                    ? Colors.orange
                                                    : colorScheme
                                                        .primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: LinearProgressIndicator(
                                            value: dynCap > 0
                                                ? (totalAssigned /
                                                        dynCap)
                                                    .clamp(0.0, 1.0)
                                                : 0,
                                            minHeight: 8,
                                            backgroundColor: colorScheme
                                                .primary
                                                .withOpacity(0.12),
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              totalAssigned > baseCap
                                                  ? Colors.orange
                                                  : colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                        if (totalAssigned > baseCap) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            '⚠️ Exceeds base cap — progress bar auto-adjusted to $dynCap pts',
                                            style: TextStyle(
                                              fontFamily: 'Montserrat',
                                              fontSize: 10,
                                              color: Colors.orange
                                                  .withOpacity(0.8),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  // ── Task list ──────────────
                                  Expanded(
                                    child: tasks.isEmpty
                                        ? Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .center,
                                              children: [
                                                Icon(Icons.task_alt,
                                                    size: 64,
                                                    color: colorScheme
                                                        .onSurfaceVariant),
                                                const SizedBox(
                                                    height: 16),
                                                Text(
                                                  "No tasks in $category",
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    color: colorScheme
                                                        .onSurfaceVariant,
                                                    fontFamily:
                                                        'Montserrat',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : ListView.builder(
                                            padding:
                                                const EdgeInsets.all(24),
                                            itemCount: tasks.length,
                                            itemBuilder:
                                                (context, index) {
                                              final task = tasks[index];
                                              final id = task['id'];
                                              final title =
                                                  task['title'] ?? '';
                                              final content =
                                                  task['content'] ?? '';
                                              final points =
                                                  task['points'] ?? 10;
                                              final done =
                                                  task['done'] ?? false;
                                              final taskInterval =
                                                  task['choose'] ??
                                                      'Daily';
                                              final cardColor = cardColors[
                                                  index %
                                                      cardColors.length];
                                              final archetypeEmoji =
                                                  ArchetypeCache.hasData
                                                      ? ArchetypeCache
                                                          .emoji
                                                      : '';

                                              return Card(
                                                color: cardColor,
                                                margin: const EdgeInsets
                                                    .only(bottom: 12),
                                                shape:
                                                    RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius
                                                          .circular(12),
                                                ),
                                                elevation: 2,
                                                child: ListTile(
                                                  contentPadding:
                                                      const EdgeInsets
                                                          .all(10),
                                                  leading: Checkbox(
                                                    value: done,
                                                    onChanged: (value) {
                                                      toggleDone(
                                                        id,
                                                        value ?? false,
                                                        points,
                                                        taskInterval,
                                                      );
                                                    },
                                                  ),
                                                  title: Text(
                                                    title,
                                                    style: TextStyle(
                                                      fontFamily:
                                                          'Montserrat',
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      decoration: done
                                                          ? TextDecoration
                                                              .lineThrough
                                                          : null,
                                                    ),
                                                  ),
                                                  subtitle:
                                                      content.isNotEmpty
                                                          ? Text(
                                                              content,
                                                              style:
                                                                  TextStyle(
                                                                fontFamily:
                                                                    'Montserrat',
                                                                decoration: done
                                                                    ? TextDecoration
                                                                        .lineThrough
                                                                    : null,
                                                              ),
                                                            )
                                                          : null,
                                                  trailing: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      // Points badge
                                                      Container(
                                                        padding: const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 8,
                                                            vertical: 4),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: colorScheme
                                                              .primaryContainer,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      8),
                                                        ),
                                                        child: Text(
                                                          archetypeEmoji
                                                                  .isNotEmpty
                                                              ? '$archetypeEmoji $points pts'
                                                              : '$points pts',
                                                          style: TextStyle(
                                                            fontFamily:
                                                                'Montserrat',
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600,
                                                            fontSize: 12,
                                                            color: colorScheme
                                                                .onPrimaryContainer,
                                                          ),
                                                        ),
                                                      ),

                                                      // Edit button
                                                      IconButton(
                                                        icon: const Icon(
                                                            Icons.edit,
                                                            color: Colors
                                                                .blue),
                                                        onPressed: () {
                                                          _titleController
                                                              .text = title;
                                                          _taskController
                                                              .text = content;
                                                          _pointsController
                                                                  .text =
                                                              points
                                                                  .toString();
                                                          choose =
                                                              task['choose'];
                                                          showDialog(
                                                            context:
                                                                context,
                                                            builder:
                                                                (context) {
                                                              return StatefulBuilder(
                                                                builder: (context,
                                                                        setDialogState) =>
                                                                    AlertDialog(
                                                                  title: const Text(
                                                                      "Edit Task"),
                                                                  content:
                                                                      Column(
                                                                    mainAxisSize:
                                                                        MainAxisSize.min,
                                                                    children: [
                                                                      TextField(
                                                                        controller:
                                                                            _titleController,
                                                                        decoration: const InputDecoration(
                                                                            labelText:
                                                                                "Title"),
                                                                      ),
                                                                      TextField(
                                                                        controller:
                                                                            _taskController,
                                                                        decoration: const InputDecoration(
                                                                            labelText:
                                                                                "Description"),
                                                                      ),
                                                                      TextField(
                                                                        controller:
                                                                            _pointsController,
                                                                        keyboardType:
                                                                            TextInputType.number,
                                                                        decoration: const InputDecoration(
                                                                            labelText:
                                                                                "Points"),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  actions: [
                                                                    TextButton(
                                                                      onPressed: () =>
                                                                          Navigator.pop(context),
                                                                      child: const Text(
                                                                          "Cancel"),
                                                                    ),
                                                                    ElevatedButton(
                                                                      onPressed:
                                                                          () async {
                                                                        final maxPts = ArchetypeCache.maxPointsForTask(choose);
                                                                        final updatedPoints = int.tryParse(_pointsController.text)?.clamp(1, maxPts) ?? 10;
                                                                        await taskdatabase.updatetask(
                                                                          id,
                                                                          _taskController.text,
                                                                          _titleController.text,
                                                                          choose,
                                                                          updatedPoints,
                                                                        );
                                                                        if (mounted) Navigator.pop(context);
                                                                      },
                                                                      child: const Text(
                                                                          "Update"),
                                                                    ),
                                                                  ],
                                                                ),
                                                              );
                                                            },
                                                          );
                                                        },
                                                      ),

                                                      // Delete button
                                                      IconButton(
                                                        icon: const Icon(
                                                            Icons.delete,
                                                            color:
                                                                Colors.red),
                                                        onPressed:
                                                            () async {
                                                          try {
                                                            final taskId =
                                                                task['id'];
                                                            await taskdatabase
                                                                .deletetask(
                                                              taskId is int
                                                                  ? taskId
                                                                  : int.parse(
                                                                      taskId.toString()),
                                                            );
                                                            if (mounted) {
                                                              setState(
                                                                  () {});
                                                            }
                                                          } catch (e) {
                                                            print(
                                                                "Error deleting task: $e");
                                                          }
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                  ),
                                ],
                              );
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: addNewTask,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}