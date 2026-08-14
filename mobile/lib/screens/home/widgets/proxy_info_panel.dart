import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/geo_service.dart';
import '../../../models/proxy_entry.dart';

class ProxyInfoPanel extends ConsumerStatefulWidget {
  const ProxyInfoPanel({super.key});

  @override
  ConsumerState<ProxyInfoPanel> createState() => _ProxyInfoPanelState();
}

class _ProxyInfoPanelState extends ConsumerState<ProxyInfoPanel> {
  GeoData? _geoData;
  bool _isLoading = false;
  String? _error;
  String? _fetchedForHost;

  Future<void> _fetchGeo(ProxyEntry activeProxy) async {
    if (_isLoading || _fetchedForHost == activeProxy.host) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final geo = await GeoService.fetchGeoInfo(activeProxy.host);
      if (mounted) {
        setState(() {
          _geoData = geo;
          _fetchedForHost = activeProxy.host;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildInfoTile(IconData icon, String label, String value, [String? extra]) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          ),
          if (extra != null && extra.isNotEmpty) Text(extra, style: const TextStyle(fontSize: 18)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeProxy = ref.watch(activeProxyProvider);
    if (activeProxy == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        onExpansionChanged: (expanded) {
          if (expanded) _fetchGeo(activeProxy);
        },
        leading: const Icon(Icons.travel_explore),
        title: Text(
          'Active Proxy Info (${activeProxy.host})',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _error != null
                    ? Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.amber),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Geo lookup: $_error', style: const TextStyle(color: Colors.grey))),
                          TextButton(
                            onPressed: () {
                              _fetchedForHost = null;
                              _fetchGeo(activeProxy);
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildInfoTile(
                                  Icons.dns,
                                  'Protocol',
                                  activeProxy.protocol.name.toUpperCase(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildInfoTile(
                                  Icons.lock,
                                  'Authentication',
                                  activeProxy.username != null ? 'User/Pass ✓' : 'None',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildInfoTile(
                                  Icons.tag,
                                  'IP Address',
                                  _geoData?.ip ?? activeProxy.host,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildInfoTile(
                                  Icons.location_on,
                                  'Location',
                                  '${_geoData?.city ?? "Unknown"}, ${_geoData?.country ?? "Unknown"}',
                                  _geoData?.flagEmoji,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildInfoTile(
                                  Icons.business,
                                  'ISP / Org',
                                  _geoData?.isp ?? 'Unknown',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildInfoTile(
                                  Icons.access_time,
                                  'Timezone',
                                  _geoData?.timezone ?? 'Unknown',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
