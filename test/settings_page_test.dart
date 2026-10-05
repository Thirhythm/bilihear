import 'package:bilihear/data/repositories/settings_repository.dart';
import 'package:bilihear/features/profile/profile_page.dart';
import 'package:bilihear/features/settings/about_page.dart';
import 'package:bilihear/features/settings/settings_page.dart';
import 'package:bilihear/state/auth_controller.dart';
import 'package:bilihear/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Signed-out session, so the account card needs no API access.
class _SignedOutAuth extends AuthController {
  @override
  AuthState build() => const AuthState(initialized: true);
}

Future<SharedPreferences> _freshPrefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

Widget _wrap(SharedPreferences prefs, Widget home) => ProviderScope(
  overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    authControllerProvider.overrideWith(_SignedOutAuth.new),
  ],
  child: MaterialApp(home: home),
);

void main() {
  testWidgets('the auto open player switch defaults to off and is persisted', (
    tester,
  ) async {
    final prefs = await _freshPrefs();
    await tester.pumpWidget(_wrap(prefs, const SettingsPage()));
    await tester.pumpAndSettle();

    final switchTile = find.byType(SwitchListTile);
    expect(tester.widget<SwitchListTile>(switchTile).value, isFalse);

    await tester.tap(find.text('点击曲目后自动打开播放器'));
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(switchTile).value, isTrue);
    expect(SettingsRepository(prefs).loadAutoOpenPlayer(), isTrue);

    // A fresh provider container reads the stored value back.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_wrap(prefs, const SettingsPage()));
    await tester.pumpAndSettle();

    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
  });

  testWidgets('我的 leads to the settings page and on to 关于', (tester) async {
    final prefs = await _freshPrefs();
    await tester.pumpWidget(_wrap(prefs, const ProfilePage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.text('点击曲目后自动打开播放器'), findsOneWidget);

    await tester.tap(find.text('关于'));
    await tester.pumpAndSettle();

    expect(find.byType(AboutPage), findsOneWidget);
  });

  testWidgets('关于 lists the version, the developer and the repository', (
    tester,
  ) async {
    final prefs = await _freshPrefs();
    await tester.pumpWidget(_wrap(prefs, const AboutPage()));
    await tester.pumpAndSettle();

    expect(find.text('版本 ${AboutPage.appVersion}'), findsOneWidget);
    expect(find.text('开发者'), findsOneWidget);
    expect(find.text(AboutPage.developerName), findsOneWidget);
    expect(find.text('开源仓库'), findsOneWidget);
    expect(find.text(AboutPage.repositoryUrl), findsOneWidget);
    // Both the developer and the repository open a browser.
    expect(find.byIcon(Icons.open_in_new_rounded), findsNWidgets(2));
  });
}
