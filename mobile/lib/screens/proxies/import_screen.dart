import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../providers/proxy_provider.dart';
import '../../utils/proxy_parser.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final _textController = TextEditingController();
  bool _isLoading = false;
  BulkParseResult? _parseResult;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _onTextChanged(String val) {
    if (val.trim().isEmpty) {
      setState(() => _parseResult = null);
      return;
    }
    final res = parseBulkProxies(val);
    setState(() => _parseResult = res);
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'csv', 'list', 'conf'],
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final text = await file.readAsString();
        _textController.text = text;
        _onTextChanged(text);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to read file: $e')),
        );
      }
    }
  }

  Future<void> _importProxies() async {
    if (_parseResult == null || _parseResult!.proxies.isEmpty) return;

    setState(() => _isLoading = true);

    final notifier = ref.read(proxyProvider.notifier);
    for (final proxy in _parseResult!.proxies) {
      notifier.addProxy(proxy.raw);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully imported ${_parseResult!.proxies.length} proxies')),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Proxies'),
        actions: [
          IconButton(
            icon: const Icon(Icons.attach_file),
            tooltip: 'Pick File',
            onPressed: _pickFile,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.file_open),
                    label: const Text('Pick .txt / .csv File'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              onChanged: _onTextChanged,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Paste raw proxies (one per line)',
                hintText: '1.2.3.4:8080\nhttp://user:pass@5.6.7.8:3128\n5.6.7.8:3128:user:pass',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            if (_parseResult != null) ...[
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        _parseResult!.proxies.isNotEmpty ? Icons.check_circle : Icons.warning,
                        color: _parseResult!.proxies.isNotEmpty ? Colors.green : Colors.amber,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Valid: ${_parseResult!.proxies.length} proxies • Errors: ${_parseResult!.errors.length} lines',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_parseResult!.errors.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Errors Summary:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 4),
                ..._parseResult!.errors.take(5).map(
                      (err) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(err, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.error)),
                      ),
                    ),
                if (_parseResult!.errors.length > 5)
                  Text('...and ${_parseResult!.errors.length - 5} more errors', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: (_isLoading || _parseResult == null || _parseResult!.proxies.isEmpty) ? null : _importProxies,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              child: _isLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('Import ${_parseResult?.proxies.length ?? 0} Proxies'),
            ),
          ],
        ),
      ),
    );
  }
}
