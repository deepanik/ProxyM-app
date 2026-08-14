import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../../models/bypass_rule.dart';
import '../../utils/bypass_validator.dart';

class BypassRulesScreen extends ConsumerStatefulWidget {
  const BypassRulesScreen({super.key});

  @override
  ConsumerState<BypassRulesScreen> createState() => _BypassRulesScreenState();
}

class _BypassRulesScreenState extends ConsumerState<BypassRulesScreen> {
  final _patternController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _patternController.dispose();
    super.dispose();
  }

  void _addRule() {
    final pattern = _patternController.text.trim();
    final err = validateBypassRule(pattern);
    if (err != null) {
      setState(() => _error = err);
      return;
    }

    final type = detectBypassType(pattern);
    final newRule = BypassRule(
      id: generateBypassId(),
      pattern: pattern,
      type: type,
      addedAt: DateTime.now().millisecondsSinceEpoch,
    );

    final currentRules = ref.read(settingsProvider).bypassRules;
    ref.read(settingsProvider.notifier).update(
      bypassRules: [...currentRules, newRule],
    );

    _patternController.clear();
    setState(() => _error = null);
  }

  void _removeRule(String id) {
    final currentRules = ref.read(settingsProvider).bypassRules;
    ref.read(settingsProvider.notifier).update(
      bypassRules: currentRules.where((r) => r.id != id).toList(),
    );
  }

  void _clearAll() {
    ref.read(settingsProvider.notifier).update(bypassRules: []);
  }

  Color _getTypeColor(BypassType type) {
    switch (type) {
      case BypassType.local:
        return Colors.blue;
      case BypassType.wildcard:
        return Colors.purple;
      case BypassType.ip:
        return Colors.green;
      case BypassType.cidr:
        return Colors.orange;
      case BypassType.hostname:
        return Colors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final rules = settings.bypassRules;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bypass Rules'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear All',
            onPressed: rules.isEmpty ? null : _clearAll,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Input Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add Bypass Rule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _patternController,
                    decoration: InputDecoration(
                      labelText: 'Pattern',
                      hintText: 'example.com or *.example.com or 192.168.1.0/24 or <local>',
                      errorText: _error,
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addRule(),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _addRule,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Rule'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text('Supported Rule Formats', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    children: [
                      ListTile(
                        dense: true,
                        title: Text('<local>', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                        subtitle: Text('Bypass intranet & local addresses'),
                      ),
                      ListTile(
                        dense: true,
                        title: Text('*.google.com', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                        subtitle: Text('Wildcard domain matching'),
                      ),
                      ListTile(
                        dense: true,
                        title: Text('192.168.1.100', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                        subtitle: Text('Exact IP address match'),
                      ),
                      ListTile(
                        dense: true,
                        title: Text('10.0.0.0/8', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                        subtitle: Text('CIDR subnet range'),
                      ),
                      ListTile(
                        dense: true,
                        title: Text('localhost', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                        subtitle: Text('Exact hostname match'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // List Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Active Rules (${rules.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 8),

          if (rules.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text('No bypass rules added yet.', style: TextStyle(color: Colors.grey)),
                ),
              ),
            )
          else
            ...rules.map(
              (rule) => Card(
                child: ListTile(
                  title: Text(
                    rule.pattern,
                    style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Added: ${DateTime.fromMillisecondsSinceEpoch(rule.addedAt).toString().split('.')[0]}', style: const TextStyle(fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Chip(
                        label: Text(
                          rule.type.name.toUpperCase(),
                          style: const TextStyle(fontSize: 10, color: Colors.white),
                        ),
                        backgroundColor: _getTypeColor(rule.type),
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => _removeRule(rule.id),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
