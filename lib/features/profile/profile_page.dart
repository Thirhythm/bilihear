import 'package:bilihear/features/settings/settings_page.dart';
import 'package:bilihear/widgets/account_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Account overview and the entry point into the settings.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const AccountCard(),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('设置'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
    );
  }
}
