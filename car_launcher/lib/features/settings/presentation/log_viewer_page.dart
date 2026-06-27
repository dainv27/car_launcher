import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:car_launcher/core/logging/logging.dart';
import 'package:car_launcher/core/theme/carplay_theme.dart';
import 'package:path_provider/path_provider.dart';

/// In-app log viewer for debugging and maintenance.
///
/// Accessible from Settings → System → View Logs.
/// Shows the current log file contents with auto-refresh and filter support.
class LogViewerPage extends StatefulWidget {
  const LogViewerPage({super.key});

  @override
  State<LogViewerPage> createState() => _LogViewerPageState();
}

class _LogViewerPageState extends State<LogViewerPage> {
  String _logContent = 'Loading...';
  String _filterLevel = 'ALL';

  static const _levels = ['ALL', 'DEBUG', 'INFO', 'WARN', 'ERROR'];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final content = await AppLogger.instance.readAll();
    if (mounted) {
      setState(() {
        _logContent = content.isEmpty ? '(no log entries)' : content;
      });
    }
  }

  String _applyFilter(String raw) {
    if (_filterLevel == 'ALL') return raw;
    final lines = raw.split('\n');
    final filtered = lines.where((line) {
      // Match lines that contain the level label
      // Format: 2026-01-01T00:00:00.000 INFO [tag] message
      final parts = line.split(' ');
      if (parts.length < 3) return true; // keep malformed lines
      return parts[2] == _filterLevel;
    });
    return filtered.join('\n');
  }

  Future<void> _copyToClipboard() async {
    final filtered = _applyFilter(_logContent);
    await Clipboard.setData(ClipboardData(text: filtered));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Log copied to clipboard')),
      );
    }
  }

  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CarPlayTheme.surfaceContainer,
        title: const Text(
          'Clear Logs',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Delete all log entries?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final docs = await getApplicationDocumentsDirectory();
        final logFile = File('${docs.path}/logs/app.log');
        if (await logFile.exists()) {
          await logFile.delete();
        }
        // Re-create the log file via AppLogger
        AppLogger.instance.i('Logs cleared by user', tag: 'LOGGER');
        await _loadLogs();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Logs cleared')),
          );
        }
      } catch (e) {
        AppLogger.instance.e('Failed to clear logs', tag: 'LOGGER', error: e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _applyFilter(_logContent);
    final lineCount = filtered == '(no log entries)' ? 0 : filtered.split('\n').length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'System Logs',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          // Level filter dropdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filterLevel,
                dropdownColor: CarPlayTheme.surfaceContainer,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                items: _levels.map((l) => DropdownMenuItem(
                  value: l,
                  child: Text(l, style: TextStyle(
                    color: _levelColor(l),
                    fontSize: 13,
                  )),
                )).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _filterLevel = v);
                },
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
            onPressed: _loadLogs,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.copy, color: Colors.white70, size: 20),
            onPressed: _copyToClipboard,
            tooltip: 'Copy all',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white70, size: 20),
            onPressed: _clearLogs,
            tooltip: 'Clear logs',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  '$lineCount entries',
                  style: TextStyle(
                    fontSize: 12,
                    color: CarPlayTheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (AppLogger.instance.logFilePath != null)
                  Expanded(
                    child: Text(
                      AppLogger.instance.logFilePath!,
                      style: TextStyle(
                        fontSize: 10,
                        color: CarPlayTheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          // Log content
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      '(no entries matching filter)',
                      style: TextStyle(color: CarPlayTheme.onSurfaceVariant),
                    ),
                  )
                : SingleChildScrollView(
                    reverse: true,
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(
                      filtered,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        height: 1.5,
                        color: Colors.white70,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Color _levelColor(String level) {
    switch (level) {
      case 'ERROR':
        return Colors.redAccent;
      case 'WARN':
        return Colors.orangeAccent;
      case 'INFO':
        return Colors.lightBlueAccent;
      case 'DEBUG':
        return Colors.grey;
      default:
        return Colors.white;
    }
  }
}
