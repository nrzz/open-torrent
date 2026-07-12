import 'package:flutter/material.dart';

import '../engine/models.dart';
import '../engine/torrent_controller.dart';

class RssPage extends StatefulWidget {
  const RssPage({super.key, required this.controller});

  final TorrentController controller;

  @override
  State<RssPage> createState() => _RssPageState();
}

class _RssPageState extends State<RssPage> {
  Future<void> _add() async {
    final name = TextEditingController();
    final url = TextEditingController();
    final filter = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add RSS rule'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: url, decoration: const InputDecoration(labelText: 'Feed URL')),
            TextField(
              controller: filter,
              decoration: const InputDecoration(
                labelText: 'Filter (optional)',
                hintText: 'substring match on magnet',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok != true) return;
    widget.controller.addRssRule(RssRule(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.text.trim().isEmpty ? 'Feed' : name.text.trim(),
      feedUrl: url.text.trim(),
      filter: filter.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final rules = widget.controller.rssRules;
        return Scaffold(
          appBar: AppBar(
            title: const Text('RSS'),
            actions: [
              IconButton(
                tooltip: 'Poll feeds now',
                onPressed: () async {
                  await widget.controller.pollRssFeeds();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('RSS poll complete')),
                    );
                  }
                },
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _add,
            child: const Icon(Icons.add),
          ),
          body: rules.isEmpty
              ? const Center(
                  child: Text('No RSS rules. Add a feed to auto-download matching magnets.'),
                )
              : ListView.builder(
                  itemCount: rules.length,
                  itemBuilder: (context, i) {
                    final r = rules[i];
                    return SwitchListTile(
                      title: Text(r.name),
                      subtitle: Text('${r.feedUrl}\nFilter: ${r.filter.isEmpty ? '(any)' : r.filter}'),
                      isThreeLine: true,
                      value: r.enabled,
                      onChanged: (v) {
                        setState(() => r.enabled = v);
                        widget.controller.applySettings(widget.controller.settings);
                      },
                      secondary: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => widget.controller.removeRssRule(r.id),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
