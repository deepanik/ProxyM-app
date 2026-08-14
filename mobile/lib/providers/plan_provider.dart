import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';

class Plan {
  final int id;
  final String name;
  final String description;
  final double price;
  final int maxProxies;
  final String features;

  Plan({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.maxProxies,
    required this.features,
  });

  factory Plan.fromJson(Map<String, dynamic> json) {
    return Plan(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Unnamed Plan',
      description: json['description'] ?? '',
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      maxProxies: json['max_proxies'] ?? 0,
      features: json['features'] ?? '',
    );
  }
}

final planProvider = AsyncNotifierProvider<PlanNotifier, List<Plan>>(() {
  return PlanNotifier();
});

class PlanNotifier extends AsyncNotifier<List<Plan>> {
  final _apiService = ApiService();

  @override
  Future<List<Plan>> build() async {
    return fetchPlans();
  }

  Future<List<Plan>> fetchPlans() async {
    final response = await _apiService.client.get('/plans');
    final List<dynamic> data = response.data;
    return data.map((item) => Plan.fromJson(item)).toList();
  }

  Future<void> subscribeToPlan(int planId) async {
    try {
      await _apiService.client.post('/subscribe', data: {'plan_id': planId});
    } catch (e) {
      print('Failed to subscribe: $e');
      rethrow;
    }
  }
}
