import 'package:flutter_test/flutter_test.dart';
import 'package:node_inspector_app/models/ip_profile.dart';
import 'package:node_inspector_app/models/node_deep_inspection.dart';

void main() {
  test('risk and purity stay unknown without risk evidence', () {
    final IpProfile profile = IpProfile(
      ip: '203.0.113.1',
      version: 4,
      checkedAt: DateTime.utc(2026),
    );

    expect(profile.riskScore, isNull);
    expect(profile.purityScore, isNull);
    expect(profile.riskLabel, '数据不足');
  });

  test('transparent risk signals produce a bounded reference score', () {
    final IpProfile profile = IpProfile(
      ip: '203.0.113.1',
      version: 4,
      checkedAt: DateTime.utc(2026),
      isVpn: true,
      isHosting: true,
      abuseConfidenceScore: 20,
    );

    expect(profile.riskScore, 70);
    expect(profile.purityScore, 30);
    expect(profile.riskLabel, '中风险');
  });

  test('deep inspection describes single and dual-stack exits', () {
    final IpProfile ipv4 = IpProfile(
      ip: '198.51.100.2',
      version: 4,
      checkedAt: DateTime.utc(2026),
    );
    final NodeDeepInspection ipv4Only = NodeDeepInspection(
      checkedAt: DateTime.utc(2026),
      ipv4: ipv4,
      ipv6Error: '请求超时',
    );
    final NodeDeepInspection dual = ipv4Only.copyWith(
      ipv6: IpProfile(
        ip: '2001:db8::2',
        version: 6,
        checkedAt: DateTime.utc(2026),
      ),
    );

    expect(ipv4Only.addressMode, '仅检测到 IPv4');
    expect(dual.addressMode, 'IPv4 / IPv6 双栈');
  });
}
