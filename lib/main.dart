import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_shell.dart';
import 'app/theme.dart';

void main() {
  runApp(const ProviderScope(child: ObscuraProApp()));
}

class ObscuraProApp extends StatelessWidget {
  const ObscuraProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Obscura Pro',
      debugShowCheckedModeBanner: false,
      theme: buildObscuraTheme(),
      home: const AppShell(content: _EmptyContent()),
    );
  }
}

class _EmptyContent extends StatelessWidget {
  const _EmptyContent();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Insérez une carte Leica Q3 pour commencer',
        style: ObscuraTypography.bodyMedium.copyWith(color: ObscuraColors.textSecondary),
      ),
    );
  }
}
