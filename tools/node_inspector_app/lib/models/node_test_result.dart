class NodeTestResult {
  const NodeTestResult({
    required this.checkedAt,
    this.exitIp,
    this.countryCode,
    this.country,
    this.asn,
    this.organization,
    this.latencyMs,
    this.error,
  });

  final DateTime checkedAt;
  final String? exitIp;
  final String? countryCode;
  final String? country;
  final String? asn;
  final String? organization;
  final int? latencyMs;
  final String? error;

  bool get isUsable => exitIp != null && exitIp!.isNotEmpty && error == null;

  factory NodeTestResult.fromJson(Map<String, Object?> json) {
    return NodeTestResult(
      checkedAt:
          DateTime.tryParse(json['checkedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      exitIp: json['exitIp'] as String?,
      countryCode: json['countryCode'] as String?,
      country: json['country'] as String?,
      asn: json['asn'] as String?,
      organization: json['organization'] as String?,
      latencyMs: (json['latencyMs'] as num?)?.round(),
      error: json['error'] as String?,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'checkedAt': checkedAt.toUtc().toIso8601String(),
      'exitIp': exitIp,
      'countryCode': countryCode,
      'country': country,
      'asn': asn,
      'organization': organization,
      'latencyMs': latencyMs,
      'error': error,
    };
  }
}
