import 'dart:convert';
import 'dart:io';

import '../models/app_settings.dart';
import '../models/ip_profile.dart';
import '../models/node_deep_inspection.dart';
import '../storage/app_secret_store.dart';

abstract interface class IpIntelligenceService {
  Future<NodeDeepInspection> enrich(
    NodeDeepInspection inspection,
    AppSettings settings,
    AppApiSecrets secrets, {
    NodeDeepInspection? cached,
  });
}

class PublicIpIntelligenceService implements IpIntelligenceService {
  const PublicIpIntelligenceService();

  @override
  Future<NodeDeepInspection> enrich(
    NodeDeepInspection inspection,
    AppSettings settings,
    AppApiSecrets secrets, {
    NodeDeepInspection? cached,
  }) async {
    final List<String> warnings = <String>[...inspection.warnings];
    final Future<IpProfile?> ipv4 = _enrichProfile(
      inspection.ipv4,
      _cachedProfile(cached, inspection.ipv4?.ip),
      settings,
      secrets,
    );
    final Future<IpProfile?> ipv6 = _enrichProfile(
      inspection.ipv6,
      _cachedProfile(cached, inspection.ipv6?.ip),
      settings,
      secrets,
    );
    final List<IpProfile?> profiles = await Future.wait<IpProfile?>(
      <Future<IpProfile?>>[ipv4, ipv6],
    );
    for (final IpProfile? profile in profiles) {
      if (profile != null) warnings.addAll(profile.warnings);
    }
    if (!settings.publicIntelligenceEnabled &&
        !secrets.hasIpInfoToken &&
        !secrets.hasAbuseIpDbKey) {
      warnings.add('IP 情报查询已关闭；本次只检测 IPv4/IPv6 出口。');
    }
    return NodeDeepInspection(
      checkedAt: inspection.checkedAt,
      ipv4: profiles[0],
      ipv6: profiles[1],
      ipv4Error: inspection.ipv4Error,
      ipv6Error: inspection.ipv6Error,
      warnings: warnings.toSet().toList(growable: false),
    );
  }

  static IpProfile? _cachedProfile(NodeDeepInspection? inspection, String? ip) {
    if (inspection == null || ip == null) return null;
    if (inspection.ipv4?.ip == ip) return inspection.ipv4;
    if (inspection.ipv6?.ip == ip) return inspection.ipv6;
    return null;
  }

  static Future<IpProfile?> _enrichProfile(
    IpProfile? base,
    IpProfile? cached,
    AppSettings settings,
    AppApiSecrets secrets,
  ) async {
    if (base == null) return null;
    IpProfile value = base;
    final Duration cacheAge = Duration(hours: settings.intelligenceCacheHours);
    if (cached != null &&
        settings.intelligenceCacheHours > 0 &&
        DateTime.now().toUtc().difference(cached.checkedAt).abs() <= cacheAge) {
      value = value.merge(cached);
      return value.merge(
        IpProfile(
          ip: value.ip,
          version: value.version,
          checkedAt: value.checkedAt,
          sources: const <String>['本机缓存'],
        ),
      );
    }

    final List<String> warnings = <String>[];
    if (settings.publicIntelligenceEnabled) {
      try {
        value = value.merge(await _lookupIpWho(value));
      } on Object catch (error) {
        warnings.add('ipwho.is：${_safeError(error)}');
      }
    }
    if (secrets.hasIpInfoToken) {
      try {
        value = value.merge(await _lookupIpInfo(value, secrets.ipInfoToken));
      } on Object catch (error) {
        warnings.add('IPinfo 基础情报：${_safeError(error)}');
      }
      try {
        value = value.merge(
          await _lookupIpInfoPrivacy(value, secrets.ipInfoToken),
        );
      } on Object catch (error) {
        warnings.add('IPinfo 隐私检测：${_safeError(error)}');
      }
    }
    if (secrets.hasAbuseIpDbKey) {
      try {
        value = value.merge(
          await _lookupAbuseIpDb(
            value,
            secrets.abuseIpDbKey,
            settings.abuseMaxAgeDays,
          ),
        );
      } on Object catch (error) {
        warnings.add('AbuseIPDB：${_safeError(error)}');
      }
    }
    if (warnings.isEmpty) return value;
    return value.merge(
      IpProfile(
        ip: value.ip,
        version: value.version,
        checkedAt: value.checkedAt,
        warnings: warnings,
      ),
    );
  }

  static Future<IpProfile> _lookupIpWho(IpProfile base) async {
    final Map<String, Object?> json = await _getJson(
      Uri.https('ipwho.is', '/${base.ip}'),
      const <String, String>{'Accept': 'application/json'},
    );
    if (json['success'] == false) {
      throw FormatException(_string(json['message']) ?? '查询失败');
    }
    final Map<String, Object?> connection = _map(json['connection']);
    final Map<String, Object?> timezone = _map(json['timezone']);
    return IpProfile(
      ip: base.ip,
      version: base.version,
      checkedAt: DateTime.now().toUtc(),
      countryCode: _string(json['country_code']),
      country: _string(json['country']),
      region: _string(json['region']),
      city: _string(json['city']),
      timezone: _string(timezone['id']),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      asn: _asn(connection['asn']),
      organization: _string(connection['org']),
      isp: _string(connection['isp']),
      networkType: _string(connection['type']),
      sources: const <String>['ipwho.is'],
    );
  }

  static Future<IpProfile> _lookupIpInfo(IpProfile base, String token) async {
    final Uri uri = Uri.https(
      'api.ipinfo.io',
      '/lookup/${base.ip}',
      <String, String>{'token': token.trim()},
    );
    final Map<String, Object?> json = await _getJson(
      uri,
      const <String, String>{'Accept': 'application/json'},
    );
    final Map<String, Object?> geo = _map(json['geo']);
    final Map<String, Object?> asn = _map(json['asn']);
    final Map<String, Object?> anonymous = <String, Object?>{
      ..._map(json['anonymous']),
      ..._map(json['privacy']),
    };
    final Map<String, Object?> company = _map(json['company']);
    return IpProfile(
      ip: base.ip,
      version: base.version,
      checkedAt: DateTime.now().toUtc(),
      countryCode: _string(geo['country_code']) ?? _string(json['country']),
      country: _string(geo['country_name']),
      region: _string(geo['region']),
      city: _string(geo['city']),
      timezone: _string(geo['timezone']),
      latitude: (geo['latitude'] as num?)?.toDouble(),
      longitude: (geo['longitude'] as num?)?.toDouble(),
      asn: _string(asn['asn']) ?? _asn(json['asn']),
      organization: _string(asn['name']) ?? _string(company['name']),
      isp: _string(company['name']),
      cidr: _string(asn['route']) ?? _string(json['network']),
      hostname: _string(json['hostname']),
      networkType: _string(asn['type']),
      isVpn: _bool(anonymous['is_vpn']) ?? _bool(anonymous['vpn']),
      isProxy: _bool(anonymous['is_proxy']) ?? _bool(anonymous['proxy']),
      isTor: _bool(anonymous['is_tor']) ?? _bool(anonymous['tor']),
      isRelay: _bool(anonymous['is_relay']) ?? _bool(anonymous['relay']),
      isHosting: _bool(anonymous['is_hosting']) ?? _bool(anonymous['hosting']),
      isResidentialProxy: _bool(anonymous['is_res_proxy']),
      isAnycast: _bool(json['is_anycast']) ?? _bool(json['anycast']),
      isMobile: _bool(json['is_mobile']),
      sources: const <String>['IPinfo'],
    );
  }

  static Future<IpProfile> _lookupAbuseIpDb(
    IpProfile base,
    String key,
    int maxAgeDays,
  ) async {
    final Uri uri = Uri.https(
      'api.abuseipdb.com',
      '/api/v2/check',
      <String, String>{
        'ipAddress': base.ip,
        'maxAgeInDays': '$maxAgeDays',
        'verbose': '',
      },
    );
    final Map<String, Object?> json = await _getJson(uri, <String, String>{
      'Accept': 'application/json',
      'Key': key.trim(),
    });
    final Map<String, Object?> data = _map(json['data']);
    return IpProfile(
      ip: base.ip,
      version: base.version,
      checkedAt: DateTime.now().toUtc(),
      countryCode: _string(data['countryCode']),
      isp: _string(data['isp']),
      hostname: _string(data['domain']),
      networkType: _string(data['usageType']),
      abuseConfidenceScore: (data['abuseConfidenceScore'] as num?)?.round(),
      totalReports: (data['totalReports'] as num?)?.round(),
      lastReportedAt: DateTime.tryParse(_string(data['lastReportedAt']) ?? ''),
      sources: const <String>['AbuseIPDB'],
    );
  }

  static Future<IpProfile> _lookupIpInfoPrivacy(
    IpProfile base,
    String token,
  ) async {
    final Uri uri = Uri.https(
      'api.ipinfo.io',
      '/lookup/${base.ip}/anonymous',
      <String, String>{'token': token.trim()},
    );
    final Map<String, Object?> json = await _getJson(
      uri,
      const <String, String>{'Accept': 'application/json'},
    );
    return IpProfile(
      ip: base.ip,
      version: base.version,
      checkedAt: DateTime.now().toUtc(),
      isVpn: _bool(json['is_vpn']) ?? _bool(json['vpn']),
      isProxy: _bool(json['is_proxy']) ?? _bool(json['proxy']),
      isTor: _bool(json['is_tor']) ?? _bool(json['tor']),
      isRelay: _bool(json['is_relay']) ?? _bool(json['relay']),
      isHosting: _bool(json['is_hosting']) ?? _bool(json['hosting']),
      isResidentialProxy: _bool(json['is_res_proxy']),
      sources: const <String>['IPinfo Privacy'],
    );
  }

  static Future<Map<String, Object?>> _getJson(
    Uri uri,
    Map<String, String> headers,
  ) async {
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..idleTimeout = const Duration(seconds: 10)
      ..findProxy = (Uri _) => 'DIRECT';
    try {
      final HttpClientRequest request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 12));
      headers.forEach(
        (String name, String value) => request.headers.set(name, value),
      );
      request.headers.set(HttpHeaders.userAgentHeader, 'NodeInspector/0.6.1');
      final HttpClientResponse response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      final List<int> bytes = await response
          .fold<List<int>>(<int>[], (List<int> data, List<int> chunk) {
            if (data.length + chunk.length > 512 * 1024) {
              throw const FormatException('响应超过 512 KB');
            }
            data.addAll(chunk);
            return data;
          })
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      final Object? decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('返回内容不是 JSON 对象');
      }
      return decoded;
    } finally {
      client.close(force: true);
    }
  }

  static Map<String, Object?> _map(Object? value) {
    return value is Map<String, Object?> ? value : <String, Object?>{};
  }

  static String? _string(Object? value) {
    if (value == null) return null;
    final String text = value.toString().trim();
    return text.isEmpty || text == 'null' ? null : text;
  }

  static String? _asn(Object? value) {
    final String? text = _string(value);
    if (text == null) return null;
    return text.toUpperCase().startsWith('AS') ? text : 'AS$text';
  }

  static bool? _bool(Object? value) => value is bool ? value : null;

  static String _safeError(Object error) {
    if (error is FormatException) return error.message;
    if (error is HttpException) return error.message;
    if (error is SocketException) return error.message;
    return error.runtimeType.toString();
  }
}
