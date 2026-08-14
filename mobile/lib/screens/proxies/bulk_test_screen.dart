import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/proxy_provider.dart';
import '../../services/proxy_test_service.dart';
import '../../models/proxy_entry.dart';
import '../../utils/country_flag.dart';

class BulkTestScreen extends ConsumerStatefulWidget {
  const BulkTestScreen({super.key});

  @override
  ConsumerState<BulkTestScreen> createState() => _BulkTestScreenState();
}

class _BulkTestScreenState extends ConsumerState<BulkTestScreen> {
  bool _isTesting = false;
  int _completed = 0;
  int _total = 0;
  Map<String, ProxyTestResult> _results = {};

  Future<void> _startBulkTest() async {
    final proxies = ref.read(proxyProvider);
    if (proxies.isEmpty) return;

    setState(() {
      _isTesting = true;
      _completed = 0;
      _total = proxies.length;
      _results = {};
    });

    final service = ProxyTestService();
    final results = await service.testAll(
      proxies,
      maxConcurrency: 5,
      onProgress: (completed, total) {
        if (mounted) {
          setState(() {
            _completed = completed;
            _total = total;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _results = results;
        _isTesting = false;
      });

      // Update provider entries with new test results
      final updatedList = proxies.map((p) {
        final res = results[p.id];
        return res != null ? p.copyWith(testResult: res) : p;
      }).toList();

      ref.read(proxyProvider.notifier).fetchProxies();
      for (final p in updatedList) {
        ref.read(proxyProvider.notifier).updateEntry(p);
      }
    }
  }

  Color _getStatusColor(ProxyTestStatus? status) {
    switch (status) {
      case ProxyTestStatus.ok:
        return Colors.green;
      case ProxyTestStatus.slow:
        return Colors.amber;
      case ProxyTestStatus.dead:
        return Colors.red;
      case ProxyTestStatus.blocked:
      case ProxyTestStatus.expired:
        return Colors.purple;
      case ProxyTestStatus.leaked:
        return Colors.orange;
      case ProxyTestStatus.untested:
      case null:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final proxies = ref.watch(proxyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Testing'),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Start Bulk Test',
            onPressed: (_isTesting || proxies.isEmpty) ? null : _startBulkTest,
          ),
        ],
      ),
      body: proxies.isEmpty
          ? const Center(child: Text('No proxies available to test.'))
          : Column(
              children: [
                if (_isTesting)
                  LinearProgressIndicator(
                    value: _total > 0 ? _completed / _total : null,
                  ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isTesting ? 'Testing $_completed / $_total proxies...' : 'Test Complete (${proxies.length} proxies)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isTesting ? null : _startBulkTest,
                        icon: const Icon(Icons.speed),
                        label: Text(_isTesting ? 'Testing...' : 'Test All'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: proxies.length,
                    itemBuilder: (context, index) {
                      final proxy = proxies[index];
                      final result = _results[proxy.id] ?? proxy.testResult;
                      final status = result?.status;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(status).withValues(alpha: 0.15),
                          child: Icon(
                            status == ProxyTestStatus.ok ? Icons.check : Icons.public,
                            color: _getStatusColor(status),
                          ),
                        ),
                        title: Text('${proxy.host}:${proxy.port}'),
                        subtitle: Text(
                          result != null
                              ? 'Latency: ${result.latencyMs ?? "N/A"}ms • Down: ${result.downloadKbps ?? "N/A"}KB/s • Country: ${result.country ?? "N/A"} ${countryFlag(result.country ?? "")}'
                              : 'Untested',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Chip(
                          label: Text(
                            (status?.name ?? 'untested').toUpperCase(),
                            style: const TextStyle(fontSize: 10, color: Colors.white),
                          ),
                          backgroundColor: _getStatusColor(status),
                          visualDensity: VisualDensity.compact,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
