import 'package:flutter/material.dart';

import '../engine/models.dart';
import '../engine/torrent_controller.dart';
import '../util/format.dart';

class TorrentDetailPage extends StatelessWidget {
  const TorrentDetailPage({
    super.key,
    required this.controller,
    required this.infoHash,
  });

  final TorrentController controller;
  final String infoHash;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final matches = controller.torrents.where((e) => e.infoHash == infoHash);
        final t = matches.isEmpty ? null : matches.first;
        if (t == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Torrent')),
            body: const Center(child: Text('Torrent removed')),
          );
        }
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              bottom: const TabBar(tabs: [
                Tab(text: 'Overview'),
                Tab(text: 'Files'),
                Tab(text: 'Options'),
              ]),
              actions: [
                IconButton(
                  onPressed: t.paused
                      ? () => controller.resume(t.infoHash)
                      : () => controller.pause(t.infoHash),
                  icon: Icon(t.paused ? Icons.play_arrow : Icons.pause),
                ),
              ],
            ),
            body: TabBarView(children: [
              _Overview(t: t),
              _Files(controller: controller, torrent: t),
              _Options(controller: controller, torrent: t),
            ]),
          ),
        );
      },
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.t});
  final TorrentItem t;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        LinearProgressIndicator(value: t.progress.clamp(0.0, 1.0)),
        const SizedBox(height: 12),
        _row('State', stateLabel(t.state)),
        _row('Progress', '${(t.progress * 100).toStringAsFixed(2)}%'),
        _row('Size', '${formatBytes(t.totalWantedDone)} / ${formatBytes(t.totalWanted)}'),
        _row('Download', formatRate(t.downloadRate)),
        _row('Upload', formatRate(t.uploadRate)),
        _row('ETA', formatEta(t.etaSeconds)),
        _row('Peers / Seeds', '${t.numPeers} / ${t.numSeeds}'),
        _row('Save path', t.savePath),
        _row('Info hash', t.infoHash),
        if (t.errorMessage.isNotEmpty)
          _row('Error', t.errorMessage, error: true),
      ],
    );
  }

  Widget _row(String k, String v, {bool error = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(
            child: Text(
              v,
              style: error ? const TextStyle(color: Colors.redAccent) : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _Files extends StatelessWidget {
  const _Files({required this.controller, required this.torrent});
  final TorrentController controller;
  final TorrentItem torrent;

  @override
  Widget build(BuildContext context) {
    if (torrent.files.isEmpty) {
      return const Center(child: Text('Waiting for metadata…'));
    }
    return ListView.builder(
      itemCount: torrent.files.length,
      itemBuilder: (context, i) {
        final f = torrent.files[i];
        return ListTile(
          title: Text(f.path, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text('${formatBytes(f.size)} · ${(f.progress * 100).toStringAsFixed(0)}%'),
          trailing: DropdownButton<FilePriority>(
            value: f.priority,
            items: FilePriority.values
                .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                .toList(),
            onChanged: (p) {
              if (p != null) {
                controller.setFilePriority(torrent.infoHash, i, p);
              }
            },
          ),
        );
      },
    );
  }
}

class _Options extends StatefulWidget {
  const _Options({required this.controller, required this.torrent});
  final TorrentController controller;
  final TorrentItem torrent;

  @override
  State<_Options> createState() => _OptionsState();
}

class _OptionsState extends State<_Options> {
  late final TextEditingController _category;
  late final TextEditingController _tags;

  @override
  void initState() {
    super.initState();
    _category = TextEditingController(text: widget.torrent.category);
    _tags = TextEditingController(text: widget.torrent.tags.join(', '));
  }

  @override
  void dispose() {
    _category.dispose();
    _tags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.torrent;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: const Text('Sequential download'),
          subtitle: const Text('Prefer beginning pieces (better for streaming)'),
          value: t.sequential,
          onChanged: (v) => widget.controller.setSequential(t.infoHash, v),
        ),
        TextField(
          controller: _category,
          decoration: const InputDecoration(labelText: 'Category'),
          onSubmitted: (v) => widget.controller.updateCategory(t.infoHash, v.trim()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _tags,
          decoration: const InputDecoration(
            labelText: 'Tags',
            hintText: 'comma,separated',
          ),
          onSubmitted: (v) => widget.controller.updateTags(
            t.infoHash,
            v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            widget.controller.updateCategory(t.infoHash, _category.text.trim());
            widget.controller.updateTags(
              t.infoHash,
              _tags.text
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList(),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Saved')),
            );
          },
          child: const Text('Save options'),
        ),
      ],
    );
  }
}
