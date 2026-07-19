class AppSettings {
  const AppSettings({
    this.concurrency = 4,
    this.timeoutSeconds = 12,
    this.geoEndpoints = const <String>[
      'https://api.ip.sb/geoip',
      'https://ipwho.is/',
    ],
  });

  final int concurrency;
  final int timeoutSeconds;
  final List<String> geoEndpoints;

  factory AppSettings.fromJson(Map<String, Object?> json) {
    final Object? rawEndpoints = json['geoEndpoints'];
    return AppSettings(
      concurrency:
          ((json['concurrency'] as num?)?.round() ?? 4).clamp(1, 32),
      timeoutSeconds: ((json['timeoutSeconds'] as num?)?.round() ?? 12)
          .clamp(3, 120),
      geoEndpoints: rawEndpoints is List<Object?>
          ? rawEndpoints.whereType<String>().toList(growable: false)
          : const <String>[
              'https://api.ip.sb/geoip',
              'https://ipwho.is/',
            ],
    );
  }

  AppSettings copyWith({int? concurrency, int? timeoutSeconds}) {
    return AppSettings(
      concurrency: concurrency ?? this.concurrency,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      geoEndpoints: geoEndpoints,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'concurrency': concurrency,
      'timeoutSeconds': timeoutSeconds,
      'geoEndpoints': geoEndpoints,
    };
  }
}
