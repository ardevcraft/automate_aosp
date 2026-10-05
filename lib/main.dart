import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/automation/presentation/automation_page.dart';
import 'shared/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: AutomationApp()));
}

class AutomationApp extends StatelessWidget {
  const AutomationApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Automate',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.create(Brightness.light),
    darkTheme: AppTheme.create(Brightness.dark),
    themeMode: ThemeMode.system,
    home: const AutomationPage(),
  );
}
