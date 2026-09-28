import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart'; // <-- Tambahkan import ini untuk StateProvider

import '../data/prefs.dart';

final prefsRepositoryProvider = Provider<PrefsRepository>(
  (ref) => PrefsRepository(),
);

final forceOfflineProvider = StateProvider<bool>(
  (ref) => false,
);

final darkModeProvider =
    AsyncNotifierProvider<DarkModeNotifier, bool>(
  DarkModeNotifier.new,
);

class DarkModeNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() {
    return ref.watch(prefsRepositoryProvider).getDarkMode();
  }

  Future<void> toggle() async {
    final next = !(state.value ?? false);

    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      await ref
          .read(prefsRepositoryProvider)
          .setDarkMode(next);

      return next;
    });
  }
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final darkModeAsync = ref.watch(darkModeProvider);
    final forceOffline = ref.watch(forceOfflineProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
      ),
      body: darkModeAsync.when(
        data: (isDarkMode) {
          return ListView(
            children: [
              SwitchListTile(
                title: const Text('Mode Gelap'),
                subtitle: const Text(
                  'Gunakan tema gelap pada aplikasi',
                ),
                value: isDarkMode,
                onChanged: (_) {
                  ref
                      .read(darkModeProvider.notifier)
                      .toggle();
                },
              ),

              const Divider(),

              SwitchListTile(
                title: const Text('Simulasi Force Offline'),
                subtitle: const Text(
                  'Gunakan cache tanpa mengambil data dari jaringan',
                ),
                value: forceOffline,
                onChanged: (value) {
                  ref
                      .read(forceOfflineProvider.notifier)
                      .state = value;
                },
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (err, stack) => Center(
          child: Text('Error: $err'),
        ),
      ),
    );
  }
}