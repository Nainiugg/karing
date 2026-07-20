import 'dart:math' as math;

class IpProfile {
  const IpProfile({
    required this.ip,
    required this.version,
    required this.checkedAt,
    this.latencyMs,
    this.countryCode,
    this.country,
    this.region,
    this.city,
    this.timezone,
    this.latitude,
    this.longitude,
    this.asn,
    this.organization,
    this.isp,
    this.cidr,
    this.hostname,
    this.networkType,
    this.isVpn,
    this.isProxy,
    this.isTor,
    this.isRelay,
    this.isHosting,
    this.isAnycast,
    this.isMobile,
    this.isResidentialProxy,
    this.abuseConfidenceScore,
    this.totalReports,
    this.lastReportedAt,
    this.sources = const <String>[],
    this.warnings = const <String>[],
  });

  final String ip;
  final int version;
  final DateTime checkedAt;
  final int? latencyMs;
  final String? countryCode;
  final String? country;
  final String? region;
  final String? city;
  final String? timezone;
  final double? latitude;
  final double? longitude;
  final String? asn;
  final String? organization;
  final String? isp;
  final String? cidr;
  final String? hostname;
  final String? networkType;
  final bool? isVpn;
  final bool? isProxy;
  final bool? isTor;
  final bool? isRelay;
  final bool? isHosting;
  final bool? isAnycast;
  final bool? isMobile;
  final bool? isResidentialProxy;
  final int? abuseConfidenceScore;
  final int? totalReports;
  final DateTime? lastReportedAt;
  final List<String> sources;
  final List<String> warnings;

  bool get hasRiskEvidence =>
      isVpn != null ||
      isProxy != null ||
      isTor != null ||
      isRelay != null ||
      isHosting != null ||
      isResidentialProxy != null ||
      abuseConfidenceScore != null ||
      totalReports != null;

  int? get riskScore {
    if (!hasRiskEvidence) return null;
    int value = abuseConfidenceScore?.clamp(0, 100).toInt() ?? 0;
    if (isTor == true) value = math.max(value, 95);
    if (isProxy == true || isVpn == true || isResidentialProxy == true) {
      value = math.max(value, 70);
    }
    if (isRelay == true) value = math.max(value, 60);
    if (isHosting == true) value = math.max(value, 35);
    if ((totalReports ?? 0) >= 10) value = math.max(value, 45);
    return value.clamp(0, 100).toInt();
  }

  int? get purityScore {
    final int? risk = riskScore;
    return risk == null ? null : 100 - risk;
  }

  String get riskLabel {
    final int? score = riskScore;
    if (score == null) return '数据不足';
    if (score >= 80) return '高风险';
    if (score >= 45) return '中风险';
    return '低风险';
  }

  String get locationLabel {
    final String value = <String?>[country, region, city]
        .whereType<String>()
        .where((String item) => item.trim().isNotEmpty)
        .join(' · ');
    return value.isEmpty ? '未知' : value;
  }

  IpProfile merge(IpProfile other) {
    if (other.ip != ip || other.version != version) return this;
    return IpProfile(
      ip: ip,
      version: version,
      checkedAt: checkedAt.isAfter(other.checkedAt)
          ? checkedAt
          : other.checkedAt,
      latencyMs: latencyMs ?? other.latencyMs,
      countryCode: other.countryCode ?? countryCode,
      country: other.country ?? country,
      region: other.region ?? region,
      city: other.city ?? city,
      timezone: other.timezone ?? timezone,
      latitude: other.latitude ?? latitude,
      longitude: other.longitude ?? longitude,
      asn: other.asn ?? asn,
      organization: other.organization ?? organization,
      isp: other.isp ?? isp,
      cidr: other.cidr ?? cidr,
      hostname: other.hostname ?? hostname,
      networkType: other.networkType ?? networkType,
      isVpn: other.isVpn ?? isVpn,
      isProxy: other.isProxy ?? isProxy,
      isTor: other.isTor ?? isTor,
      isRelay: other.isRelay ?? isRelay,
      isHosting: other.isHosting ?? isHosting,
      isAnycast: other.isAnycast ?? isAnycast,
      isMobile: other.isMobile ?? isMobile,
      isResidentialProxy: other.isResidentialProxy ?? isResidentialProxy,
      abuseConfidenceScore: other.abuseConfidenceScore ?? abuseConfidenceScore,
      totalReports: other.totalReports ?? totalReports,
      lastReportedAt: other.lastReportedAt ?? lastReportedAt,
      sources: <String>{...sources, ...other.sources}.toList(growable: false),
      warnings: <String>{
        ...warnings,
        ...other.warnings,
      }.toList(growable: false),
    );
  }

  factory IpProfile.fromJson(Map<String, Object?> json) {
    final Object? rawSources = json['sources'];
    final Object? rawWarnings = json['warnings'];
    return IpProfile(
      ip: json['ip'] as String? ?? '',
      version: (json['version'] as num?)?.round() ?? 0,
      checkedAt:
          DateTime.tryParse(json['checkedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      latencyMs: (json['latencyMs'] as num?)?.round(),
      countryCode: json['countryCode'] as String?,
      country: json['country'] as String?,
      region: json['region'] as String?,
      city: json['city'] as String?,
      timezone: json['timezone'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      asn: json['asn'] as String?,
      organization: json['organization'] as String?,
      isp: json['isp'] as String?,
      cidr: json['cidr'] as String?,
      hostname: json['hostname'] as String?,
      networkType: json['networkType'] as String?,
      isVpn: json['isVpn'] as bool?,
      isProxy: json['isProxy'] as bool?,
      isTor: json['isTor'] as bool?,
      isRelay: json['isRelay'] as bool?,
      isHosting: json['isHosting'] as bool?,
      isAnycast: json['isAnycast'] as bool?,
      isMobile: json['isMobile'] as bool?,
      isResidentialProxy: json['isResidentialProxy'] as bool?,
      abuseConfidenceScore: (json['abuseConfidenceScore'] as num?)?.round(),
      totalReports: (json['totalReports'] as num?)?.round(),
      lastReportedAt: DateTime.tryParse(
        json['lastReportedAt'] as String? ?? '',
      ),
      sources: rawSources is List<Object?>
          ? rawSources.whereType<String>().toList(growable: false)
          : const <String>[],
      warnings: rawWarnings is List<Object?>
          ? rawWarnings.whereType<String>().toList(growable: false)
          : const <String>[],
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'ip': ip,
      'version': version,
      'checkedAt': checkedAt.toUtc().toIso8601String(),
      'latencyMs': latencyMs,
      'countryCode': countryCode,
      'country': country,
      'region': region,
      'city': city,
      'timezone': timezone,
      'latitude': latitude,
      'longitude': longitude,
      'asn': asn,
      'organization': organization,
      'isp': isp,
      'cidr': cidr,
      'hostname': hostname,
      'networkType': networkType,
      'isVpn': isVpn,
      'isProxy': isProxy,
      'isTor': isTor,
      'isRelay': isRelay,
      'isHosting': isHosting,
      'isAnycast': isAnycast,
      'isMobile': isMobile,
      'isResidentialProxy': isResidentialProxy,
      'abuseConfidenceScore': abuseConfidenceScore,
      'totalReports': totalReports,
      'lastReportedAt': lastReportedAt?.toUtc().toIso8601String(),
      'sources': sources,
      'warnings': warnings,
    };
  }
}
