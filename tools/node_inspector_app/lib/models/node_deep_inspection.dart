import 'ip_profile.dart';

class NodeInspectionHistoryEntry {
  const NodeInspectionHistoryEntry({
    required this.checkedAt,
    this.ipv4,
    this.ipv6,
  });

  final DateTime checkedAt;
  final String? ipv4;
  final String? ipv6;

  factory NodeInspectionHistoryEntry.fromJson(Map<String, Object?> json) {
    return NodeInspectionHistoryEntry(
      checkedAt:
          DateTime.tryParse(json['checkedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      ipv4: json['ipv4'] as String?,
      ipv6: json['ipv6'] as String?,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'checkedAt': checkedAt.toUtc().toIso8601String(),
      'ipv4': ipv4,
      'ipv6': ipv6,
    };
  }
}

class NodeDeepInspection {
  const NodeDeepInspection({
    required this.checkedAt,
    this.ipv4,
    this.ipv6,
    this.ipv4Error,
    this.ipv6Error,
    this.warnings = const <String>[],
  });

  final DateTime checkedAt;
  final IpProfile? ipv4;
  final IpProfile? ipv6;
  final String? ipv4Error;
  final String? ipv6Error;
  final List<String> warnings;

  bool get hasAnyAddress => ipv4 != null || ipv6 != null;

  String get addressMode {
    if (ipv4 != null && ipv6 != null) return 'IPv4 / IPv6 双栈';
    if (ipv4 != null) return '仅检测到 IPv4';
    if (ipv6 != null) return '仅检测到 IPv6';
    return '未取得出口地址';
  }

  NodeInspectionHistoryEntry get historyEntry => NodeInspectionHistoryEntry(
    checkedAt: checkedAt,
    ipv4: ipv4?.ip,
    ipv6: ipv6?.ip,
  );

  NodeDeepInspection copyWith({
    IpProfile? ipv4,
    IpProfile? ipv6,
    String? ipv4Error,
    String? ipv6Error,
    List<String>? warnings,
  }) {
    return NodeDeepInspection(
      checkedAt: checkedAt,
      ipv4: ipv4 ?? this.ipv4,
      ipv6: ipv6 ?? this.ipv6,
      ipv4Error: ipv4Error ?? this.ipv4Error,
      ipv6Error: ipv6Error ?? this.ipv6Error,
      warnings: warnings ?? this.warnings,
    );
  }

  factory NodeDeepInspection.fromJson(Map<String, Object?> json) {
    final Object? rawIpv4 = json['ipv4'];
    final Object? rawIpv6 = json['ipv6'];
    final Object? rawWarnings = json['warnings'];
    return NodeDeepInspection(
      checkedAt:
          DateTime.tryParse(json['checkedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      ipv4: rawIpv4 is Map<String, Object?>
          ? IpProfile.fromJson(rawIpv4)
          : null,
      ipv6: rawIpv6 is Map<String, Object?>
          ? IpProfile.fromJson(rawIpv6)
          : null,
      ipv4Error: json['ipv4Error'] as String?,
      ipv6Error: json['ipv6Error'] as String?,
      warnings: rawWarnings is List<Object?>
          ? rawWarnings.whereType<String>().toList(growable: false)
          : const <String>[],
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'checkedAt': checkedAt.toUtc().toIso8601String(),
      'ipv4': ipv4?.toJson(),
      'ipv6': ipv6?.toJson(),
      'ipv4Error': ipv4Error,
      'ipv6Error': ipv6Error,
      'warnings': warnings,
    };
  }
}
