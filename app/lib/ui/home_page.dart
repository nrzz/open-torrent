import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../engine/models.dart';
import '../engine/torrent_controller.dart';
import '../util/format.dart';
import 'settings_page.dart';
import 'torrent_detail_page.dart';
import 'rss_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.controller});

  final TorrentController controller;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _filter = '';

  TorrentController get c => widget.controller;

  Future<void> _addMagnet() async {
    final uri = await _prompt('Add magnet link', 'magnet:?xt=urn:btih:...');
    if (uri == null || uri.trim().isEmpty) return;
    try {
      await c.addMagnet(uri.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Torrent added')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  Future<void> _addFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['torrent'],
    );
    if (result == null || result.files.single.path == null) return;
    try {
      await c.addTorrentFile(result.files.single.path!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _addUrl() async {
    final url = await _prompt('Add torrent URL', 'https://...');
    if (url == null || url.trim().isEmpty) return;
    try {
      await c.addTorrentUrl(url.trim());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<String?> _prompt(String title, String hint) async {
    final field = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: field,
          decoration: InputDecoration(hintText: hint),
          autofocus: true,
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, field.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = c.torrents.where((t) {
      if (_filter.isEmpty) return true;
      final q = _filter.toLowerCase();
      return t.name.toLowerCase().contains(q) ||
          t.category.toLowerCase().contains(q) ||
          t.tags.any((tag) => tag.toLowerCase().contains(q));
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('OpenTorrent'),
        actions: [
          IconButton(
            tooltip: 'RSS',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => RssPage(controller: c)),
            ),
            icon: const Icon(Icons.rss_feed),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => SettingsPage(controller: c)),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final choice = await showModalBottomSheet<String>(
            context: context,
            builder: (ctx) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.link),
                    title: const Text('Magnet link'),
                    onTap: () => Navigator.pop(ctx, 'magnet'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.insert_drive_file_outlined),
                    title: const Text('Torrent file'),
                    onTap: () => Navigator.pop(ctx, 'file'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.http),
                    title: const Text('URL'),
                    onTap: () => Navigator.pop(ctx, 'url'),
                  ),
                ],
              ),
            ),
          );
          if (choice == 'magnet') await _addMagnet();
          if (choice == 'file') await _addFile();
          if (choice == 'url') await _addUrl();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Filter by name, category, tag',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _filter = v),
            ),
          ),
          if (c.usingMock)
            Material(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Theme.of(context).colorScheme.onErrorContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Mock engine — not transferring real torrents. '
                        'Windows: scripts/build_libtorrent_windows.ps1. '
                        'Android: scripts/build_libtorrent_android.ps1. '
                        'Then rebuild without OPENTORRENT_MOCK.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onErrorContainer,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (c.lastError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(c.lastError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          Expanded(
            child: items.isEmpty
                ? const _EmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final t = items[index];
                      return _TorrentTile(
                        torrent: t,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TorrentDetailPage(
                              controller: c,
                              infoHash: t.infoHash,
                            ),
                          ),
                        ),
                        onPause: () => c.pause(t.infoHash),
                        onResume: () => c.resume(t.infoHash),
                        onRemove: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Remove torrent?'),
                              content: const Text('Remove from session. Optionally delete files.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    c.remove(t.infoHash);
                                    Navigator.pop(ctx, true);
                                  },
                                  child: const Text('Remove'),
                                ),
                                FilledButton(
                                  onPressed: () {
                                    c.remove(t.infoHash, deleteFiles: true);
                                    Navigator.pop(ctx, true);
                                  },
                                  child: const Text('Remove + delete files'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true && context.mounted) {}
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_download_outlined,
                size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'No torrents yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Add a magnet link or .torrent file to start downloading.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TorrentTile extends StatelessWidget {
  const _TorrentTile({
    required this.torrent,
    required this.onTap,
    required this.onPause,
    required this.onResume,
    required this.onRemove,
  });

  final TorrentItem torrent;
  final VoidCallback onTap;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = torrent;
    return ListTile(
      onTap: onTap,
      title: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          LinearProgressIndicator(value: t.progress.clamp(0.0, 1.0)),
          const SizedBox(height: 6),
          Text(
            '${(t.progress * 100).toStringAsFixed(1)}% · ${stateLabel(t.state)} · '
            '↓ ${formatRate(t.downloadRate)} ↑ ${formatRate(t.uploadRate)} · '
            'ETA ${formatEta(t.etaSeconds)} · ${t.numSeeds}/${t.numPeers}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            '${formatBytes(t.totalWantedDone)} / ${formatBytes(t.totalWanted)}'
            '${t.category.isNotEmpty ? ' · ${t.category}' : ''}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      isThreeLine: true,
      trailing: Wrap(
        spacing: 0,
        children: [
          IconButton(
            tooltip: t.paused ? 'Resume' : 'Pause',
            onPressed: t.paused ? onResume : onPause,
            icon: Icon(t.paused ? Icons.play_arrow : Icons.pause),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}
