class AppSettings {
  const AppSettings({
    this.concurrency = 4,
    this.timeoutSeconds = 12,
    this.bindAddress = '',
    this.ipv4Endpoint = 'https://api.ipify.org?format=json',
    this.ipv6Endpoint = 'https://api6.ipify.org?format=json',
    this.publicIntelligenceEnabled = true,
    this.intelligenceCacheHours = 24,
    this.abuseMaxAgeDays = 90,
    this.geoEndpoints = const <String>[
      'https://api.ip.sb/geoip',
      'https://ipwho.is/',
    ],
  });

  final int concurrency;
  final int timeoutSeconds;
  final String bindAddress;
  final String ipv4Endpoint;
  final String ipv6Endpoint;
  final bool publicIntelligenceEnabled;
  final int intelligenceCacheHours;
  final int abuseMaxAgeDays;
  final List<String> geoEndpoints;

  factory AppSettings.fromJson(Map<String, Object?> json) {
    final Object? rawEndpoints = json['geoEndpoints'];
    return AppSettings(
      concurrency: ((json['concurrency'] as num?)?.round() ?? 4).clamp(1, 32),
      timeoutSeconds: ((json['timeoutSeconds'] as num?)?.round() ?? 12).clamp(
        3,
        120,
      ),
      bindAddress: json['bindAddress'] as String? ?? '',
      ipv4Endpoint:
          json['ipv4Endpoint'] as String? ??
          'https://api.ipify.org?format=json',
      ipv6Endpoint:
          json['ipv6Endpoint'] as String? ??
          'https://api6.ipify.org?format=json',
      publicIntelligenceEnabled:
          json['publicIntelligenceEnabled'] as bool? ?? true,
      intelligenceCacheHours:
          ((json['intelligenceCacheHours'] as num?)?.round() ?? 24).clamp(
            0,
            720,
          ),
      abuseMaxAgeDays: ((json['abuseMaxAgeDays'] as num?)?.round() ?? 90).clamp(
        1,
        365,
      ),
      geoEndpoints: rawEndpoints is List<Object?>
          ? rawEndpoints.whereType<String>().toList(growable: false)
          : const <String>['https://api.ip.sb/geoip', 'https://ipwho.is/'],
    );
  }

  AppSettings copyWith({
    int? concurrency,
    int? timeoutSeconds,
    String? bindAddress,
    String? ipv4Endpoint,
    String? ipv6Endpoint,
    bool? publicIntelligenceEnabled,
    int? intelligenceCacheHours,
    int? abuseMaxAgeDays,
  }) {
    return AppSettings(
      concurrency: concurrency ?? this.concurrency,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      bindAddress: bindAddress ?? this.bindAddress,
      ipv4Endpoint: ipv4Endpoint ?? this.ipv4Endpoint,
      ipv6Endpoint: ipv6Endpoint ?? this.ipv6Endpoint,
      publicIntelligenceEnabled:
          publicIntelligenceEnabled ?? this.publicIntelligenceEnabled,
      intelligenceCacheHours:
          intelligenceCacheHours ?? this.intelligenceCacheHours,
      abuseMaxAgeDays: abuseMaxAgeDays ?? this.abuseMaxAgeDays,
      geoEndpoints: geoEndpoints,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'concurrency': concurrency,
      'timeoutSeconds': timeoutSeconds,
      'bindAddress': bindAddress,
      'ipv4Endpoint': ipv4Endpoint,
      'ipv6Endpoint': ipv6Endpoint,
      'publicIntelligenceEnabled': publicIntelligenceEnabled,
      'intelligenceCacheHours': intelligenceCacheHours,
      'abuseMaxAgeDays': abuseMaxAgeDays,
      'geoEndpoints': geoEndpoints,
    };
  }
}
