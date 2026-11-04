import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../routes.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            onPressed: () async {
              await ref.read(authStateProvider.notifier).logout();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Selamat datang',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              title: const Text('Pengumuman'),
              subtitle: const Text('Lihat pengumuman terbaru'),
              onTap: () {
                context.go(AppRoutes.announcementDetails('1'));
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.note_alt_outlined),
              title: const Text('Catatan Kampus'),
              subtitle: const Text('Kelola dan cari catatan kegiatan'),
              onTap: () {
                context.go(AppRoutes.notes);
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: Colors.blue.shade50,
            child: ListTile(
              leading: const Icon(Icons.smart_toy_outlined, color: Colors.blue),
              title: const Row(
                children: [
                  Text(
                    'Asisten AI Kampus',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 8),
                  Chip(
                    label: Text(
                      'AI',
                      style: TextStyle(fontSize: 10, color: Colors.white),
                    ),
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
              subtitle: const Text(
                'Tanya jadwal, fasilitas, dan informasi kampus',
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                context.go(AppRoutes.aiChat);
              },
            ),
          ),
        ],
      ),
    );
  }
}
