import 'dart:async';
import 'package:flutter/material.dart';
import 'package:zenstudy/auth/authservice.dart';
import 'package:zenstudy/db/tasks_db.dart';
import 'package:zenstudy/widgets/left_panel.dart'; // Import the LeftPanel

class TaskPage extends StatefulWidget {
  const TaskPage({super.key});

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage>
    with SingleTickerProviderStateMixin {
  final _taskController = TextEditingController();
  final _titleController = TextEditingController();
  final _pointsController = TextEditingController();
  final authservice = Authservice();
  final taskdatabase = tasksdb();

  final List<String> chooseList = ["Daily", "Weekly", "Monthly"];
  String choose = "Daily";
  late TabController _tabController;

  Timer? _resetTimer;

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
    _startResetTimer();
  }

  void _startResetTimer() {
    _resetTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (!mounted) return;
      final now = DateTime.now();

      if (now.hour == 0 && now.minute == 0) {
        await taskdatabase.resetTasks("Daily");
        await taskdatabase.updateResetLog('Daily');
        
        if (now.weekday == DateTime.friday) {
          await taskdatabase.resetTasks("Weekly");
          await taskdatabase.updateResetLog('Weekly');
        }
        
        if (now.day == 30) {
          await taskdatabase.resetTasks("Monthly");
          await taskdatabase.updateResetLog('Monthly');
        }
      }
    });
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    _taskController.dispose();
    _titleController.dispose();
    _pointsController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void addNewTask() {
    _taskController.clear();
    _titleController.clear();
    _pointsController.clear();
    choose = "Daily";

    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
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
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(labelText: "Title"),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: _taskController,
                    maxLines: 2,
                    decoration: InputDecoration(labelText: "Description"),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: _pointsController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: "Points (1-100)"),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: chooseList.map((period) {
                      final isSelected = choose == period;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() => choose = period),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            margin: EdgeInsets.symmetric(horizontal: 2),
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
                child: Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_titleController.text.isNotEmpty &&
                      _taskController.text.isNotEmpty &&
                      _pointsController.text.isNotEmpty) {
                    final points =
                        int.tryParse(_pointsController.text)?.clamp(1, 100) ??
                        10;
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
                child: Text("Add Task"),
              ),
            ],
          ),
        );
      },
    );
  }

  void toggleDone(dynamic id, bool done, int points) async {
    await taskdatabase.toggleDone(id, done);
    if (done) await taskdatabase.addPointsLog(id, points);
  }

  @override
  Widget build(BuildContext context) {
    final uid = authservice.getcurrentUseruid();
    final colorScheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: chooseList.length,
      child: Scaffold(
        backgroundColor: colorScheme.background,
        appBar: AppBar(
          backgroundColor: colorScheme.primary,
          title: Text(
            'ZenStudy - Tasks',
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
              const LeftPanel(currentPage: 'Tasks'),
              
              // RIGHT PANEL (Tasks content)
              Expanded(
                child: Column(
                  children: [
                    // Page Title
                    Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.centerLeft,
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
                    
                    // Tab Bar
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        tabs: chooseList.map((c) => Tab(text: c)).toList(),
                        labelColor: colorScheme.primary,
                        unselectedLabelColor: colorScheme.onSurfaceVariant,
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
                              if (!snapshot.hasData)
                                return Center(child: CircularProgressIndicator());
                              final allTasks = snapshot.data!;
                              final tasks = allTasks
                                  .where((t) => t['choose'] == category)
                                  .toList();
                              if (tasks.isEmpty) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.task_alt,
                                        size: 64,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        "No tasks in $category",
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: colorScheme.onSurfaceVariant,
                                          fontFamily: 'Montserrat',
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return ListView.builder(
                                padding: const EdgeInsets.all(24),
                                itemCount: tasks.length,
                                itemBuilder: (context, index) {
                                  final task = tasks[index];
                                  final id = task['id'];
                                  final title = task['title'] ?? '';
                                  final content = task['content'] ?? '';
                                  final points = task['points'] ?? 10;
                                  final done = task['done'] ?? false;
                                  final cardColor = cardColors[index % cardColors.length];

                                  return Card(
                                    color: cardColor,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 2,
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.all(16),
                                      leading: Checkbox(
                                        value: done,
                                        onChanged: (value) =>
                                            toggleDone(id, value ?? false, points),
                                      ),
                                      title: Text(
                                        title,
                                        style: TextStyle(
                                          fontFamily: 'Montserrat',
                                          fontWeight: FontWeight.w600,
                                          decoration: done 
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                      subtitle: content.isNotEmpty 
                                          ? Text(
                                              content,
                                              style: TextStyle(
                                                fontFamily: 'Montserrat',
                                                decoration: done 
                                                    ? TextDecoration.lineThrough
                                                    : null,
                                              ),
                                            ) 
                                          : null,
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: colorScheme.primaryContainer,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              "$points pts",
                                              style: TextStyle(
                                                fontFamily: 'Montserrat',
                                                fontWeight: FontWeight.w600,
                                                color: colorScheme.onPrimaryContainer,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Edit Button
                                          IconButton(
                                            icon: Icon(Icons.edit, color: Colors.blue),
                                            onPressed: () {
                                              _titleController.text = title;
                                              _taskController.text = content;
                                              _pointsController.text = points.toString();
                                              choose = task['choose'];

                                              showDialog(
                                                context: context,
                                                builder: (context) {
                                                  return StatefulBuilder(
                                                    builder: (context, setDialogState) =>
                                                        AlertDialog(
                                                          title: Text("Edit Task"),
                                                          content: Column(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              TextField(
                                                                controller: _titleController,
                                                                decoration: InputDecoration(
                                                                  labelText: "Title",
                                                                ),
                                                              ),
                                                              TextField(
                                                                controller: _taskController,
                                                                decoration: InputDecoration(
                                                                  labelText: "Description",
                                                                ),
                                                              ),
                                                              TextField(
                                                                controller: _pointsController,
                                                                keyboardType:
                                                                    TextInputType.number,
                                                                decoration: InputDecoration(
                                                                  labelText: "Points",
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(context),
                                                              child: Text("Cancel"),
                                                            ),
                                                            ElevatedButton(
                                                              onPressed: () async {
                                                                final updatedPoints =
                                                                    int.tryParse(
                                                                      _pointsController.text,
                                                                    )?.clamp(1, 100) ??
                                                                    10;
                                                                await taskdatabase.updatetask(
                                                                  id,
                                                                  _taskController.text,
                                                                  _titleController.text,
                                                                  choose,
                                                                  updatedPoints,
                                                                );
                                                                if (mounted)
                                                                  Navigator.pop(context);
                                                              },
                                                              child: Text("Update"),
                                                            ),
                                                          ],
                                                        ),
                                                  );
                                                },
                                              );
                                            },
                                          ),
                                          // Delete Button
                                          IconButton(
                                            icon: Icon(Icons.delete, color: Colors.red),
                                            onPressed: () async {
                                              try {
                                                final taskId = task['id'];
                                                await taskdatabase.deletetask(
                                                  taskId is int
                                                      ? taskId
                                                      : int.parse(taskId.toString()),
                                                );
                                                if (mounted) setState(() {}); // refresh UI
                                              } catch (e) {
                                                print("Error deleting task: $e");
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
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
        // Floating Action Button
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