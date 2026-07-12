import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../engine/models.dart';
import '../engine/torrent_controller.dart';
import '../util/format.dart';
import '../util/update_checker.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller});

  final TorrentController controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late SessionSettings _s;
  late SchedulerWindow _sched;

  @override
  void initState() {
    super.initState();
    _s = widget.controller.settings.copy();
    _sched = SchedulerWindow.fromJson(widget.controller.scheduler.toJson());
  }

  Future<void> _save() async {
    widget.controller.scheduler = _sched;
    await widget.controller.applySettings(_s);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        children: [
          const _Section('Downloads'),
          ListTile(
            title: const Text('Save path'),
            subtitle: Text(_s.savePath.isEmpty ? '(default)' : _s.savePath),
            trailing: const Icon(Icons.folder_open),
            onTap: () async {
              final dir = await FilePicker.platform.getDirectoryPath();
              if (dir != null) setState(() => _s.savePath = dir);
            },
          ),
          SwitchListTile(
            title: const Text('Wi‑Fi only (Android hint)'),
            value: _s.wifiOnly,
            onChanged: (v) => setState(() => _s.wifiOnly = v),
          ),
          SwitchListTile(
            title: const Text('Sequential by default'),
            value: _s.sequentialDefault,
            onChanged: (v) => setState(() => _s.sequentialDefault = v),
          ),
          const _Section('Bandwidth'),
          _IntTile(
            label: 'Download limit (B/s, 0=unlimited)',
            value: _s.downloadRateLimit,
            onChanged: (v) => setState(() => _s.downloadRateLimit = v),
          ),
          _IntTile(
            label: 'Upload limit (B/s, 0=unlimited)',
            value: _s.uploadRateLimit,
            onChanged: (v) => setState(() => _s.uploadRateLimit = v),
          ),
          _IntTile(
            label: 'Max connections',
            value: _s.maxConnections,
            onChanged: (v) => setState(() => _s.maxConnections = v),
          ),
          _IntTile(
            label: 'Max uploads',
            value: _s.maxUploads,
            onChanged: (v) => setState(() => _s.maxUploads = v),
          ),
          const _Section('Network'),
          _IntTile(
            label: 'Listen port',
            value: _s.listenPort,
            onChanged: (v) => setState(() => _s.listenPort = v),
          ),
          SwitchListTile(
            title: const Text('DHT'),
            value: _s.enableDht,
            onChanged: (v) => setState(() => _s.enableDht = v),
          ),
          SwitchListTile(
            title: const Text('LSD'),
            value: _s.enableLsd,
            onChanged: (v) => setState(() => _s.enableLsd = v),
          ),
          SwitchListTile(
            title: const Text('PEX'),
            value: _s.enablePex,
            onChanged: (v) => setState(() => _s.enablePex = v),
          ),
          ListTile(
            title: const Text('Encryption'),
            subtitle: Text(switch (_s.encryptionMode) {
              0 => 'Disabled',
              2 => 'Forced',
              _ => 'Enabled',
            }),
            onTap: () async {
              final v = await showDialog<int>(
                context: context,
                builder: (ctx) => SimpleDialog(
                  title: const Text('Encryption mode'),
                  children: [
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(ctx, 0),
                      child: const Text('Disabled'),
                    ),
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(ctx, 1),
                      child: const Text('Enabled'),
                    ),
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(ctx, 2),
                      child: const Text('Forced'),
                    ),
                  ],
                ),
              );
              if (v != null) setState(() => _s.encryptionMode = v);
            },
          ),
          const _Section('Proxy (SOCKS5)'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: const InputDecoration(labelText: 'Host'),
              controller: TextEditingController(text: _s.proxyHost)
                ..selection = TextSelection.collapsed(offset: _s.proxyHost.length),
              onChanged: (v) => _s.proxyHost = v,
            ),
          ),
          _IntTile(
            label: 'Port',
            value: _s.proxyPort,
            onChanged: (v) => setState(() => _s.proxyPort = v),
          ),
          const _Section('IP blocklist'),
          ListTile(
            title: const Text('Blocklist file'),
            subtitle: Text(_s.blocklistPath.isEmpty ? 'None' : _s.blocklistPath),
            onTap: () async {
              final result = await FilePicker.platform.pickFiles();
              if (result?.files.single.path != null) {
                setState(() => _s.blocklistPath = result!.files.single.path!);
              }
            },
          ),
          const _Section('Scheduler'),
          SwitchListTile(
            title: const Text('Limit bandwidth by schedule'),
            value: _sched.enabled,
            onChanged: (v) => setState(() => _sched.enabled = v),
          ),
          _IntTile(
            label: 'Start hour (0-23)',
            value: _sched.startHour,
            onChanged: (v) => setState(() => _sched.startHour = v.clamp(0, 23)),
          ),
          _IntTile(
            label: 'End hour (0-23)',
            value: _sched.endHour,
            onChanged: (v) => setState(() => _sched.endHour = v.clamp(0, 23)),
          ),
          ListTile(
            title: const Text('Limited download rate'),
            subtitle: Text(formatRate(_sched.limitedDownloadRate)),
          ),
          const _Section('Appearance'),
          ListTile(
            title: const Text('Theme'),
            subtitle: Text(_s.themeMode),
            onTap: () async {
              final v = await showDialog<String>(
                context: context,
                builder: (ctx) => SimpleDialog(
                  title: const Text('Theme'),
                  children: [
                    for (final m in ['system', 'light', 'dark'])
                      SimpleDialogOption(
                        onPressed: () => Navigator.pop(ctx, m),
                        child: Text(m),
                      ),
                  ],
                ),
              );
              if (v != null) setState(() => _s.themeMode = v);
            },
          ),
          ListTile(
            title: const Text('Locale'),
            subtitle: Text(_s.locale),
            onTap: () async {
              final v = await showDialog<String>(
                context: context,
                builder: (ctx) => SimpleDialog(
                  title: const Text('Locale'),
                  children: [
                    for (final m in ['en', 'es', 'de', 'fr', 'hi', 'zh'])
                      SimpleDialogOption(
                        onPressed: () => Navigator.pop(ctx, m),
                        child: Text(m),
                      ),
                  ],
                ),
              );
              if (v != null) setState(() => _s.locale = v);
            },
          ),
          SwitchListTile(
            title: const Text('Debug logging'),
            value: _s.debugLogging,
            onChanged: (v) => setState(() => _s.debugLogging = v),
          ),
          const _Section('About'),
          ListTile(
            title: const Text('Engine'),
            subtitle: Text(widget.controller.engineVersion),
          ),
          const ListTile(
            title: Text('License'),
            subtitle: Text('GNU GPL v3 — free software, no ads, no telemetry'),
          ),
          ListTile(
            title: const Text('Check for updates'),
            subtitle: const Text('Uses GitHub Releases'),
            onTap: () async {
              final checker = UpdateChecker(
                owner: 'nrzz',
                repo: 'open-torrent',
                currentVersion: '0.2.0',
              );
              final available = await checker.isUpdateAvailable();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      available
                          ? 'Update available on GitHub Releases'
                          : 'You are on the latest published version (or no release yet)',
                    ),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _IntTile extends StatelessWidget {
  const _IntTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      subtitle: Text('$value'),
      onTap: () async {
        final field = TextEditingController(text: '$value');
        final result = await showDialog<int>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(label),
            content: TextField(
              controller: field,
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, int.tryParse(field.text.trim())),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        if (result != null) onChanged(result);
      },
    );
  }
}
