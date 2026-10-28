import 'package:flutter/material.dart';
import 'core/config/gemini_config.dart';
import 'core/theme/app_theme.dart';
import 'features/groups/viewmodels/group_viewmodel.dart';
import 'features/groups/views/groups_list_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GeminiConfig.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  final GroupViewModel? viewModel;

  const MyApp({super.key, this.viewModel});

  @override
  Widget build(BuildContext context) {
    final groupViewModel = viewModel ?? GroupViewModel();

    return MaterialApp(
      title: 'StudyMate - Mobile',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: AppMainShell(groupViewModel: groupViewModel),
    );
  }
}

/// Shell component providing unified navigation across screens.
class AppMainShell extends StatefulWidget {
  final GroupViewModel groupViewModel;

  const AppMainShell({
    super.key,
    required this.groupViewModel,
  });

  @override
  State<AppMainShell> createState() => _AppMainShellState();
}

class _AppMainShellState extends State<AppMainShell> {
  int _currentIndex = 1; // Default to Groupes tab for instant testing

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _HomeScreenPlaceholder(),
      GroupsListPage(viewModel: widget.groupViewModel),
      const _ProfileScreenPlaceholder(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppColors.primary),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups, color: AppColors.primary),
            label: 'Groupes',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppColors.primary),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

class _HomeScreenPlaceholder extends StatelessWidget {
  const _HomeScreenPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accueil')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school, size: 64, color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Bienvenue sur StudyMate',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Basculez sur l\'onglet "Groupes" pour gérer vos groupes d\'étude.',
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileScreenPlaceholder extends StatelessWidget {
  const _ProfileScreenPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.primarySoft,
              child: Icon(Icons.person, size: 48, color: AppColors.primary),
            ),
            SizedBox(height: 16),
            Text(
              'Étudiant StudyMate',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              'etudiant@studymate.tn',
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
