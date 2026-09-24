import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:car_launcher/core/logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:car_launcher/core/theme/launcher_palette.dart';

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
        backgroundColor: context.palette.surface,
        title: Text(
          'Clear Logs',
          style: TextStyle(color: context.palette.textPrimary),
        ),
        content: Text(
          'Delete all log entries?',
          style: TextStyle(color: context.palette.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Clear', style: TextStyle(color: context.palette.danger)),
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
          icon: Icon(Icons.arrow_back, color: context.palette.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'System Logs',
          style: TextStyle(color: context.palette.textPrimary),
        ),
        actions: [
          // Level filter dropdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filterLevel,
                dropdownColor: context.palette.surface,
                style: TextStyle(color: context.palette.textPrimary, fontSize: 13),
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
            icon: Icon(Icons.refresh, color: context.palette.textSecondary, size: 20),
            onPressed: _loadLogs,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: Icon(Icons.copy, color: context.palette.textSecondary, size: 20),
            onPressed: _copyToClipboard,
            tooltip: 'Copy all',
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: context.palette.textSecondary, size: 20),
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
                    color: context.palette.textSecondary,
                  ),
                ),
                const Spacer(),
                if (AppLogger.instance.logFilePath != null)
                  Expanded(
                    child: Text(
                      AppLogger.instance.logFilePath!,
                      style: TextStyle(
                        fontSize: 10,
                        color: context.palette.textSecondary,
                      ),
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: context.palette.foreground.withValues(alpha: 0.12)),
          // Log content
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      '(no entries matching filter)',
                      style: TextStyle(color: context.palette.textSecondary),
                    ),
                  )
                : SingleChildScrollView(
                    reverse: true,
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(
                      filtered,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        height: 1.5,
                        color: context.palette.textSecondary,
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
        return context.palette.danger;
      case 'WARN':
        return context.palette.warning;
      case 'INFO':
        return context.palette.accent;
      case 'DEBUG':
        return context.palette.textTertiary;
      default:
        return context.palette.textPrimary;
    }
  }
}
