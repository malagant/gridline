import 'package:flutter/material.dart';

import 'home_page.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GridlineApp());
}

class GridlineApp extends StatelessWidget {
  const GridlineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gridline',
      debugShowCheckedModeBanner: false,
      theme: GridTheme.material(),
      home: const HomePage(),
    );
  }
}
