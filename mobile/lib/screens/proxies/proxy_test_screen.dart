import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/proxy_provider.dart';
import '../../services/proxy_test_service.dart';
import '../../models/proxy_entry.dart';
import '../../utils/country_flag.dart';

class ProxyTestScreen extends ConsumerStatefulWidget {
  final String proxyId;
  const ProxyTestScreen({super.key, required this.proxyId});

  @override
  ConsumerState<ProxyTestScreen> createState() => _ProxyTestScreenState();
}

class _ProxyTestScreenState extends ConsumerState<ProxyTestScreen> {
  ProxyTestResult? _testResult;
  ProxyEntry? _targetProxy;
  bool _isTesting = true;

  @override
  void initState() {
    super.initState();
    _runTest();
  }

  Future<void> _runTest() async {
    final proxies = ref.read(proxyProvider);
    final proxy = proxies.where((p) => p.id == widget.proxyId).firstOrNull;

    if (proxy == null) {
      if (mounted) {
        setState(() {
          _isTesting = false;
        });
      }
      return;
    }

    _targetProxy = proxy;

    final service = ProxyTestService();
    final result = await service.testProxy(proxy);

    if (mounted) {
      setState(() {
        _testResult = result;
        _isTesting = false;
      });

      // Update proxy result in provider
      ref.read(proxyProvider.notifier).updateEntry(proxy.copyWith(testResult: result));
    }
  }

  Color _getStatusColor(ProxyTestStatus status) {
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
        return Colors.grey;
    }
  }

  Widget _buildMetricCard(IconData icon, String label, String value, [Color? color]) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, color: color ?? Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 14)),
            const Spacer(),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_targetProxy != null ? 'Test: ${_targetProxy!.host}:${_targetProxy!.port}' : 'Proxy Test'),
      ),
      body: _isTesting
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Testing connectivity, speed, DNS & SSL...'),
                ],
              ),
            )
          : _testResult == null
              ? const Center(child: Text('Test failed to execute'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Center(
                      child: Column(
                        children: [
                          Icon(
                            _testResult!.status == ProxyTestStatus.ok ? Icons.check_circle : Icons.warning_amber,
                            size: 64,
                            color: _getStatusColor(_testResult!.status),
                          ),
                          const SizedBox(height: 8),
                          Chip(
                            label: Text(
                              _testResult!.status.name.toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            backgroundColor: _getStatusColor(_testResult!.status),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildMetricCard(
                      Icons.timer,
                      'HTTP Latency',
                      _testResult!.latencyMs != null ? '${_testResult!.latencyMs} ms' : 'N/A',
                      _getStatusColor(_testResult!.status),
                    ),
                    _buildMetricCard(
                      Icons.download,
                      'Download Speed',
                      _testResult!.downloadKbps != null ? '${_testResult!.downloadKbps} KB/s' : 'N/A',
                    ),
                    _buildMetricCard(
                      Icons.dns,
                      'DNS Latency',
                      _testResult!.dnsMs != null ? '${_testResult!.dnsMs} ms' : 'N/A',
                    ),
                    _buildMetricCard(
                      Icons.security,
                      'SSL / HTTPS Valid',
                      _testResult!.sslValid == true ? 'Valid ✓' : 'Invalid ✗',
                      _testResult!.sslValid == true ? Colors.green : Colors.red,
                    ),
                    _buildMetricCard(
                      Icons.public,
                      'Country / Flag',
                      _testResult!.country != null
                          ? '${_testResult!.country} ${countryFlag(_testResult!.country!)}'
                          : 'Unknown',
                    ),
                    _buildMetricCard(
                      Icons.network_check,
                      'Detected IP',
                      _testResult!.ip ?? 'None',
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _isTesting = true);
                        _runTest();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retest Now'),
                    ),
                  ],
                ),
    );
  }
}
