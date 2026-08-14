import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/proxy_provider.dart';
import '../../utils/proxy_parser.dart';
import '../../models/proxy_entry.dart';

class AddProxyScreen extends ConsumerStatefulWidget {
  const AddProxyScreen({super.key});

  @override
  ConsumerState<AddProxyScreen> createState() => _AddProxyScreenState();
}

class _AddProxyScreenState extends ConsumerState<AddProxyScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _uriController = TextEditingController();

  // Manual fields
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  ProxyProtocol _selectedProtocol = ProxyProtocol.http;

  ProxyEntry? _parsedPreview;
  String? _parseError;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _uriController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  void _onUriChanged(String val) {
    if (val.trim().isEmpty) {
      setState(() {
        _parsedPreview = null;
        _parseError = null;
      });
      return;
    }
    try {
      final parsed = parseProxyUri(val);
      setState(() {
        _parsedPreview = parsed;
        _parseError = null;
      });
    } catch (e) {
      setState(() {
        _parsedPreview = null;
        _parseError = e is FormatException ? e.message : e.toString();
      });
    }
  }

  Future<void> _submitUri() async {
    final raw = _uriController.text.trim();
    if (raw.isEmpty) return;
    await _addProxy(raw);
  }

  Future<void> _submitManual() async {
    final host = _hostController.text.trim();
    final portStr = _portController.text.trim();
    if (host.isEmpty || portStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Host and Port are required')),
      );
      return;
    }

    final user = _userController.text.trim();
    final pass = _passController.text.trim();
    final authStr = user.isNotEmpty ? (pass.isNotEmpty ? '$user:$pass@' : '$user@') : '';
    final raw = '${_selectedProtocol.name}://$authStr$host:$portStr';

    await _addProxy(raw);
  }

  Future<void> _addProxy(String rawProxy) async {
    setState(() => _isLoading = true);
    try {
      await ref.read(proxyProvider.notifier).addProxy(rawProxy);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('limit')) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Upgrade Required'),
              content: Text(e.toString()),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.push('/settings/premium');
                  },
                  child: const Text('Upgrade Now'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Proxy'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.auto_awesome), text: 'Auto Detect / URI'),
            Tab(icon: Icon(Icons.tune), text: 'Manual'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Auto Detect / URI
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                TextField(
                  controller: _uriController,
                  onChanged: _onUriChanged,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Proxy String / URI',
                    hintText: 'http://user:pass@1.2.3.4:8080\n1.2.3.4:8080:user:pass\nuser:pass@1.2.3.4:8080',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                if (_parseError != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _parseError!,
                            style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_parsedPreview != null)
                  Card(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Chip(
                                label: Text(_parsedPreview!.protocol.name.toUpperCase()),
                                visualDensity: VisualDensity.compact,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_parsedPreview!.host}:${_parsedPreview!.port}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                          if (_parsedPreview!.username != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                'Auth: ${_parsedPreview!.username}:${_parsedPreview!.password ?? "****"}',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: (_isLoading || _parsedPreview == null) ? null : _submitUri,
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  child: _isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Add Proxy'),
                ),
              ],
            ),
          ),

          // Tab 2: Manual Form
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                DropdownButtonFormField<ProxyProtocol>(
                  initialValue: _selectedProtocol,
                  decoration: const InputDecoration(labelText: 'Protocol', border: OutlineInputBorder()),
                  items: ProxyProtocol.values
                      .map((p) => DropdownMenuItem(value: p, child: Text(p.name.toUpperCase())))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedProtocol = val);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _hostController,
                        decoration: const InputDecoration(labelText: 'Host / IP', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _portController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Port', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _userController,
                  decoration: const InputDecoration(labelText: 'Username (Optional)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password (Optional)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitManual,
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  child: _isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Add Proxy'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
