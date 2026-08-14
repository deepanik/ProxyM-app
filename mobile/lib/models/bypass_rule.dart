enum BypassType { local, wildcard, ip, cidr, hostname }

class BypassRule {
  final String id;
  final String pattern;
  final BypassType type;
  final int addedAt;

  const BypassRule({
    required this.id,
    required this.pattern,
    required this.type,
    required this.addedAt,
  });

  factory BypassRule.fromJson(Map<String, dynamic> j) => BypassRule(
        id: j['id'] as String,
        pattern: j['pattern'] as String,
        type: BypassType.values.firstWhere(
          (e) => e.name == j['type'],
          orElse: () => BypassType.hostname,
        ),
        addedAt: j['addedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'pattern': pattern,
        'type': type.name,
        'addedAt': addedAt,
      };
}
