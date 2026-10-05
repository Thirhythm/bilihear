import 'package:bilihear/features/shell/app_shell.dart';
import 'package:bilihear/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Root widget of 哔哩听见.
class BiliHearApp extends StatelessWidget {
  const BiliHearApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '哔哩听见',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: ThemeMode.system,
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: const AppShell(),
  );
}
