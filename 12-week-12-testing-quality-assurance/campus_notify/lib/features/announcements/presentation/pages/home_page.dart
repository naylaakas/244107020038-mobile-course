import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../routes.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  void _onLogout(WidgetRef ref) {
    ref.read(authStateProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            onPressed: () => _onLogout(ref),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: const RepaintBoundary(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selamat datang',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              _AnnouncementMenuCard(),
              SizedBox(height: 8),
              _NotesMenuCard(),
              SizedBox(height: 8),
              _AiAssistantMenuCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnnouncementMenuCard extends StatelessWidget {
  const _AnnouncementMenuCard();

  void _navigateToDetail(BuildContext context) {
    context.go(AppRoutes.announcementDetails('1'));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: const Text('Pengumuman'),
        subtitle: const Text('Lihat pengumuman terbaru'),
        onTap: () => _navigateToDetail(context),
      ),
    );
  }
}

class _NotesMenuCard extends StatelessWidget {
  const _NotesMenuCard();

  void _navigateToNotes(BuildContext context) {
    context.go(AppRoutes.notes);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.note_alt_outlined),
        title: const Text('Catatan Kampus'),
        subtitle: const Text('Kelola dan cari catatan kegiatan'),
        onTap: () => _navigateToNotes(context),
      ),
    );
  }
}

class _AiAssistantMenuCard extends StatelessWidget {
  const _AiAssistantMenuCard();

  void _navigateToAiChat(BuildContext context) {
    context.go(AppRoutes.aiChat);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
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
        onTap: () => _navigateToAiChat(context),
      ),
    );
  }
}
