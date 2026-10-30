import 'package:flutter/material.dart';
import 'services/data_service.dart';
import 'services/auth_service.dart';
import 'services/weekend_backup_service.dart';
import 'theme/app_theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/daily_attendance_screen.dart';
import 'screens/student_roster_screen.dart';
import 'screens/absence_alerts_screen.dart';
import 'screens/monthly_reports_screen.dart';
import 'screens/audit_trail_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/section_management_screen.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final data = DataService();
  await data.loadSavedSettings();
  final auth = AuthService();
  await auth.init();
  runApp(const APSchoolAttendanceApp());
}

class APSchoolAttendanceApp extends StatefulWidget {
  const APSchoolAttendanceApp({super.key});

  @override
  State<APSchoolAttendanceApp> createState() => _APSchoolAttendanceAppState();
}

class _APSchoolAttendanceAppState extends State<APSchoolAttendanceApp> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    final auth = AuthService();
    await auth.init();
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  void _onAuthenticated() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final data = DataService();
    final auth = AuthService();

    return ListenableBuilder(
      listenable: Listenable.merge([data, auth]),
      builder: (context, _) {
        return MaterialApp(
          title: 'AP School Attendance Management System',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: data.themeMode,
          home: _loading
              ? const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                )
              : (!auth.isAuthenticated
                  ? LoginScreen(onAuthenticated: _onAuthenticated)
                  : const MainNavigationShell()),
        );
      },
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final List<int> _navigationHistory = [0];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _runWeekendBackup();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _runWeekendBackup();
  }

  void _runWeekendBackup() {
    runWeekendAttendanceBackup(DataService());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onDestinationSelected(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _navigationHistory.add(index);
      _selectedIndex = index;
    });
  }

  void _handleBackNavigation() {
    if (_navigationHistory.length > 1) {
      setState(() {
        _navigationHistory.removeLast();
        _selectedIndex = _navigationHistory.last;
      });
    } else if (_selectedIndex != 0) {
      setState(() {
        _selectedIndex = 0;
        _navigationHistory.clear();
        _navigationHistory.add(0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = DataService();
    final auth = AuthService();

    // Index 0: Dashboard
    // Index 1: Daily Attendance
    // Index 2: Student Roster
    // Index 3: Settings (More tab)
    // Index 4: Absence Alerts
    // Index 5: Monthly Reports
    // Index 6: Audit Trail
    final List<Widget> screens = [
      DashboardScreen(onNavigate: _onDestinationSelected),
      DailyAttendanceScreen(onBack: _handleBackNavigation),
      StudentRosterScreen(onBack: _handleBackNavigation),
      SettingsScreen(onBack: _handleBackNavigation),
      AbsenceAlertsScreen(onBack: _handleBackNavigation),
      MonthlyReportsScreen(onBack: _handleBackNavigation),
      AuditTrailScreen(onBack: _handleBackNavigation),
    ];

    final flaggedCount = data.detectFlaggedStudents().length;

    return PopScope(
      canPop: _selectedIndex == 0 && _navigationHistory.length <= 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleBackNavigation();
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWideScreen = constraints.maxWidth >= 800;

          if (isWideScreen) {
            // Desktop / Tablet layout with NavigationRail
            return Scaffold(
              body: Row(
                children: [
                  NavigationRail(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: _onDestinationSelected,
                    extended: constraints.maxWidth >= 1000,
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipOval(
                            child: Image.asset(
                              'assets/images/ap_logo.png',
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const CircleAvatar(
                                backgroundColor: AppTheme.primaryLight,
                                child: Icon(Icons.school, color: AppTheme.primary),
                              ),
                            ),
                          ),
                          if (constraints.maxWidth >= 1000) ...[
                            const SizedBox(width: 10),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'AP School',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text(
                                  'Attendance System',
                                  style: TextStyle(fontSize: 10, color: AppTheme.primary),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    trailing: Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.logout, color: AppTheme.absent),
                                tooltip: 'Log Out',
                                onPressed: () => auth.logout(),
                              ),
                              IconButton(
                                icon: Icon(data.themeMode == ThemeMode.dark
                                    ? Icons.light_mode
                                    : Icons.dark_mode),
                                onPressed: () => data.toggleTheme(),
                                tooltip: 'Toggle Theme',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    destinations: [
                      const NavigationRailDestination(
                        icon: Icon(Icons.dashboard_outlined),
                        selectedIcon: Icon(Icons.dashboard),
                        label: Text('Dashboard'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.calendar_today_outlined),
                        selectedIcon: Icon(Icons.calendar_today),
                        label: Text('Daily Attendance'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.people_outline),
                        selectedIcon: Icon(Icons.people),
                        label: Text('Student Roster'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.settings_outlined),
                        selectedIcon: Icon(Icons.settings),
                        label: Text('Settings'),
                      ),
                      NavigationRailDestination(
                        icon: Badge(
                          isLabelVisible: flaggedCount > 0,
                          label: Text('$flaggedCount'),
                          child: const Icon(Icons.notification_important_outlined),
                        ),
                        selectedIcon: Badge(
                          isLabelVisible: flaggedCount > 0,
                          label: Text('$flaggedCount'),
                          child: const Icon(Icons.notification_important),
                        ),
                        label: const Text('Absence Alerts'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.analytics_outlined),
                        selectedIcon: Icon(Icons.analytics),
                        label: Text('Monthly Reports'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.history_outlined),
                        selectedIcon: Icon(Icons.history),
                        label: Text('Audit Trail'),
                      ),
                    ],
                  ),
                  const VerticalDivider(thickness: 1, width: 1),
                  Expanded(
                    child: screens[_selectedIndex],
                  ),
                ],
              ),
            );
          }

          // Mobile layout with 4 BottomNav tabs: Dashboard, Attendance, Roster, More (Settings)
          final navBarIndex = _selectedIndex >= 3 ? 3 : _selectedIndex;

          return Scaffold(
            body: screens[_selectedIndex],
            bottomNavigationBar: NavigationBar(
              selectedIndex: navBarIndex,
              onDestinationSelected: (idx) {
                _onDestinationSelected(idx);
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.calendar_today_outlined),
                  selectedIcon: Icon(Icons.calendar_today),
                  label: 'Attendance',
                ),
                NavigationDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: 'Roster',
                ),
                NavigationDestination(
                  icon: Icon(Icons.more_horiz),
                  selectedIcon: Icon(Icons.more_horiz),
                  label: 'More',
                ),
              ],
            ),
            drawer: Drawer(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  DrawerHeader(
                    decoration: const BoxDecoration(color: AppTheme.primary),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/ap_logo.png',
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const CircleAvatar(
                                backgroundColor: Colors.white24,
                                child: Icon(Icons.school, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          data.schoolName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${data.currentTerm} • ${auth.currentUser?.displayName ?? data.currentUserName}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.dashboard),
                    title: const Text('Dashboard'),
                    selected: _selectedIndex == 0,
                    onTap: () {
                      Navigator.pop(context);
                      _onDestinationSelected(0);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Daily Attendance'),
                    selected: _selectedIndex == 1,
                    onTap: () {
                      Navigator.pop(context);
                      _onDestinationSelected(1);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.people),
                    title: const Text('Student Roster'),
                    selected: _selectedIndex == 2,
                    onTap: () {
                      Navigator.pop(context);
                      _onDestinationSelected(2);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.class_outlined),
                    title: const Text('Section Management'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SectionManagementScreen()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text('Settings & Profile'),
                    selected: _selectedIndex == 3,
                    onTap: () {
                      Navigator.pop(context);
                      _onDestinationSelected(3);
                    },
                  ),
                  ListTile(
                    leading: Badge(
                      isLabelVisible: flaggedCount > 0,
                      label: Text('$flaggedCount'),
                      child: const Icon(Icons.notification_important),
                    ),
                    title: const Text('Absence Alerts & Intervention'),
                    selected: _selectedIndex == 4,
                    onTap: () {
                      Navigator.pop(context);
                      _onDestinationSelected(4);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.analytics),
                    title: const Text('Monthly Reports & Summaries'),
                    selected: _selectedIndex == 5,
                    onTap: () {
                      Navigator.pop(context);
                      _onDestinationSelected(5);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.history),
                    title: const Text('Security & Audit Trail'),
                    selected: _selectedIndex == 6,
                    onTap: () {
                      Navigator.pop(context);
                      _onDestinationSelected(6);
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout, color: AppTheme.absent),
                    title: const Text('Log Out', style: TextStyle(color: AppTheme.absent, fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.pop(context);
                      auth.logout();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
