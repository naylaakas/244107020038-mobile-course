import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/ai_service.dart';

/// Model pesan untuk antarmuka percakapan AI
class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isFallback;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isFallback = false,
  });
}

/// Provider instance AiService tunggal
final aiServiceProvider = Provider<AiService>((ref) {
  return AiService();
});

/// Notifier status loading AI (Riverpod 3 kompatibel)
class AiLoadingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setLoading(bool loading) {
    state = loading;
  }
}

final aiLoadingProvider = NotifierProvider<AiLoadingNotifier, bool>(
  AiLoadingNotifier.new,
);

/// State Notifier untuk daftar riwayat percakapan chat (Riverpod 3 kompatibel)
class ChatMessagesNotifier extends Notifier<List<ChatMessage>> {
  @override
  List<ChatMessage> build() => [
    ChatMessage(
      id: 'initial-welcome',
      text: 'Halo! Saya Asisten AI Kampus. Tanyakan informasi jadwal, beasiswa, fasilitas, atau perpustakaan kampus.',
      isUser: false,
      timestamp: DateTime.now(),
    ),
  ];

  void addMessage(ChatMessage message) {
    state = [...state, message];
  }

  void clearChat() {
    state = [
      ChatMessage(
        id: 'welcome-${DateTime.now().millisecondsSinceEpoch}',
        text: 'Percakapan telah dibersihkan. Ada yang ingin Anda tanyakan seputar kampus?',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    ];
  }
}

final chatMessagesProvider =
    NotifierProvider<ChatMessagesNotifier, List<ChatMessage>>(
      ChatMessagesNotifier.new,
    );

/// Halaman Chat Screen utama dengan AI (Jobsheet Bagian 3: Praktikum Chat Interface)
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isOnline = true;
  bool _hasApiKey = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final aiService = ref.read(aiServiceProvider);
    final online = await aiService.isNetworkConnected();
    final key = await aiService.getApiKey();
    if (mounted) {
      setState(() {
        _isOnline = online;
        _hasApiKey = key != null && key.trim().isNotEmpty;
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String query) async {
    final text = query.trim();
    if (text.isEmpty) return;

    _textController.clear();

    final aiService = ref.read(aiServiceProvider);
    final isOnline = await aiService.isNetworkConnected();

    // 1. Tambahkan pesan user ke daftar
    final userMsg = ChatMessage(
      id: 'usr-${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );
    ref.read(chatMessagesProvider.notifier).addMessage(userMsg);
    _scrollToBottom();

    // JIKA OFFLINE: Beri tahu bahwa saat offline tidak bisa percakapan cloud
    if (!isOnline) {
      _showOfflineDialog(text);
      return;
    }

    // 2. Tampilkan indikator loading (Saat Online)
    ref.read(aiLoadingProvider.notifier).setLoading(true);

    try {
      // Ambil riwayat percakapan sebelumnya untuk multi-turn chat
      final currentMessages = ref.read(chatMessagesProvider);
      final history = currentMessages
          .where((m) => m.id != 'initial-welcome' && !m.isFallback)
          .take(6)
          .map((m) => {'role': m.isUser ? 'user' : 'model', 'text': m.text})
          .toList();

      final responseText = await aiService.ask(
        text,
        history: history,
        allowFallback: true,
      );

      final isFallback = responseText.contains('[Mode Offline]');
      final aiMsg = ChatMessage(
        id: 'ai-${DateTime.now().millisecondsSinceEpoch}',
        text: responseText,
        isUser: false,
        timestamp: DateTime.now(),
        isFallback: isFallback,
      );
      ref.read(chatMessagesProvider.notifier).addMessage(aiMsg);
    } catch (_) {
      if (mounted) {
        _showOfflineDialog(text);
      }
    } finally {
      ref.read(aiLoadingProvider.notifier).setLoading(false);
      _scrollToBottom();
      _checkStatus();
    }
  }

  void _showOfflineDialog(String failedQuery) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.orange),
            SizedBox(width: 8),
            Text('Perangkat Offline'),
          ],
        ),
        content: const Text(
          'Perangkat sedang tidak terhubung ke internet. Percakapan AI online dinonaktifkan saat offline. Anda dapat menggunakan jawaban lokal kampus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Tutup'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              final fallbackText = AiService.getFallbackResponse(failedQuery);
              ref
                  .read(chatMessagesProvider.notifier)
                  .addMessage(
                    ChatMessage(
                      id: 'fallback-${DateTime.now().millisecondsSinceEpoch}',
                      text: fallbackText,
                      isUser: false,
                      timestamp: DateTime.now(),
                      isFallback: true,
                    ),
                  );
              _scrollToBottom();
            },
            child: const Text('Gunakan Jawaban Offline'),
          ),
        ],
      ),
    );
  }

  Future<void> _showApiKeyDialog() async {
    final aiService = ref.read(aiServiceProvider);
    final currentKey = await aiService.getApiKey() ?? '';
    final controller = TextEditingController(text: currentKey);

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.key, color: Colors.blue),
            SizedBox(width: 8),
            Text('Pengaturan API Key'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan Google Gemini API Key Anda. Kunci akan disimpan secara aman di FlutterSecureStorage.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Gemini API Key',
                border: OutlineInputBorder(),
                hintText: 'AIzaSy...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal'),
          ),
          if (currentKey.isNotEmpty)
            TextButton(
              onPressed: () async {
                await aiService.deleteApiKey();
                if (dialogCtx.mounted) {
                  Navigator.pop(dialogCtx);
                }
                await _checkStatus();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('API Key berhasil dihapus')),
                  );
                }
              },
              child: const Text('Hapus', style: TextStyle(color: Colors.red)),
            ),
          FilledButton(
            onPressed: () async {
              await aiService.saveApiKey(controller.text);
              if (dialogCtx.mounted) {
                Navigator.pop(dialogCtx);
              }
              await _checkStatus();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'API Key berhasil disimpan! AI kini berstatus Online.',
                    ),
                  ),
                );
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider);
    final isLoading = ref.watch(aiLoadingProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Asisten AI Kampus', style: TextStyle(fontSize: 18)),
            Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 8,
                  color: _isOnline ? Colors.greenAccent : Colors.redAccent,
                ),
                const SizedBox(width: 4),
                Text(
                  _isOnline
                      ? (_hasApiKey
                            ? 'Online (Gemini Cloud Active)'
                            : 'Online (Smart Assistant Active)')
                      : 'Offline (Internet Terputus)',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Konfigurasi API Key',
            icon: const Icon(Icons.key),
            onPressed: _showApiKeyDialog,
          ),
          IconButton(
            tooltip: 'Bersihkan Riwayat',
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              ref.read(chatMessagesProvider.notifier).clearChat();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const _PrivacyNoticeBanner(),
          Expanded(
            child: RepaintBoundary(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: messages.length + (isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == messages.length) {
                    return const _LoadingMessageBubble();
                  }
                  return _ChatMessageBubble(
                    key: ValueKey(messages[index].id),
                    message: messages[index],
                  );
                },
              ),
            ),
          ),
          _QuickSuggestionsBar(onSelect: _sendMessage),
          _ChatInputArea(
            controller: _textController,
            isLoading: isLoading,
            onSend: () => _sendMessage(_textController.text),
          ),
        ],
      ),
    );
  }
}

/// Banner pemberitahuan privasi data pengguna
class _PrivacyNoticeBanner extends StatelessWidget {
  const _PrivacyNoticeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.amber.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, size: 16, color: Colors.amber.shade900),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Privasi Terjaga: NIK, nomor telepon, dan email disamarkan secara otomatis.',
              style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gelembung tampilan pesan pengguna atau asisten AI
class _ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatMessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final theme = Theme.of(context);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primary
              : (message.isFallback
                    ? Colors.orange.shade50
                    : theme.colorScheme.surfaceContainerHighest),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: message.isFallback
              ? Border.all(color: Colors.orange.shade300)
              : null,
        ),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    message.isFallback
                        ? Icons.cloud_off
                        : Icons.smart_toy_outlined,
                    size: 14,
                    color: message.isFallback
                        ? Colors.orange.shade800
                        : theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    message.isFallback ? 'Offline Fallback' : 'Asisten AI',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: message.isFallback
                          ? Colors.orange.shade800
                          : theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            SelectableText(
              message.text,
              style: TextStyle(
                color: isUser
                    ? Colors.white
                    : (message.isFallback
                          ? Colors.orange.shade900
                          : theme.colorScheme.onSurfaceVariant),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 10,
                color: isUser ? Colors.white70 : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Indikator animasi loading saat AI memproses jawaban
class _LoadingMessageBubble extends StatelessWidget {
  const _LoadingMessageBubble();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(
              'Asisten sedang mengetik...',
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bilah saran pertanyaan cepat seputar kampus
class _QuickSuggestionsBar extends StatelessWidget {
  final Function(String) onSelect;

  const _QuickSuggestionsBar({required this.onSelect});

  static const List<String> _suggestions = [
    'Jadwal kampus hari Senin?',
    'Lokasi perpustakaan pusat?',
    'Info beasiswa kampus?',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _suggestions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, idx) {
          final text = _suggestions[idx];
          return ActionChip(
            label: Text(text, style: const TextStyle(fontSize: 12)),
            onPressed: () => onSelect(text),
          );
        },
      ),
    );
  }
}

/// Area input teks dan tombol kirim
class _ChatInputArea extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSend;

  const _ChatInputArea({
    required this.controller,
    required this.isLoading,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !isLoading,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Tanyakan sesuatu ke asisten kampus...',
                  hintStyle: const TextStyle(fontSize: 13),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send),
              onPressed: isLoading ? null : onSend,
            ),
          ],
        ),
      ),
    );
  }
}
