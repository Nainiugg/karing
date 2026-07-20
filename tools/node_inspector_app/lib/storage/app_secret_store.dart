import 'dart:convert';
import 'dart:io';

class AppApiSecrets {
  const AppApiSecrets({this.ipInfoToken = '', this.abuseIpDbKey = ''});

  final String ipInfoToken;
  final String abuseIpDbKey;

  bool get hasIpInfoToken => ipInfoToken.trim().isNotEmpty;
  bool get hasAbuseIpDbKey => abuseIpDbKey.trim().isNotEmpty;

  AppApiSecrets copyWith({String? ipInfoToken, String? abuseIpDbKey}) {
    return AppApiSecrets(
      ipInfoToken: ipInfoToken ?? this.ipInfoToken,
      abuseIpDbKey: abuseIpDbKey ?? this.abuseIpDbKey,
    );
  }
}

abstract interface class AppSecretStore {
  Future<AppApiSecrets> load();

  Future<void> save(AppApiSecrets secrets);
}

class MemoryAppSecretStore implements AppSecretStore {
  MemoryAppSecretStore([this.secrets = const AppApiSecrets()]);

  AppApiSecrets secrets;

  @override
  Future<AppApiSecrets> load() async => secrets;

  @override
  Future<void> save(AppApiSecrets value) async {
    secrets = value;
  }
}

class WindowsDpapiSecretStore implements AppSecretStore {
  WindowsDpapiSecretStore(this.file);

  final File file;

  static File defaultFile() {
    final Map<String, String> environment = Platform.environment;
    final String root =
        environment['APPDATA'] ?? environment['HOME'] ?? Directory.current.path;
    return File(
      '$root${Platform.pathSeparator}NodeInspector${Platform.pathSeparator}secrets.json',
    );
  }

  @override
  Future<AppApiSecrets> load() async {
    if (!await file.exists()) return const AppApiSecrets();
    if (!Platform.isWindows) {
      throw UnsupportedError('API 密钥安全存储目前只支持 Windows');
    }
    final Object? decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('密钥文件格式无效');
    }
    final String ipInfoBlob = decoded['ipInfoToken'] as String? ?? '';
    final String abuseBlob = decoded['abuseIpDbKey'] as String? ?? '';
    return AppApiSecrets(
      ipInfoToken: ipInfoBlob.isEmpty ? '' : await _unprotect(ipInfoBlob),
      abuseIpDbKey: abuseBlob.isEmpty ? '' : await _unprotect(abuseBlob),
    );
  }

  @override
  Future<void> save(AppApiSecrets secrets) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('API 密钥安全存储目前只支持 Windows');
    }
    await file.parent.create(recursive: true);
    final Map<String, Object?> payload = <String, Object?>{
      'schemaVersion': 1,
      'ipInfoToken': secrets.hasIpInfoToken
          ? await _protect(secrets.ipInfoToken.trim())
          : '',
      'abuseIpDbKey': secrets.hasAbuseIpDbKey
          ? await _protect(secrets.abuseIpDbKey.trim())
          : '',
    };
    final File temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(payload)}\n',
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }

  static Future<String> _protect(String value) async {
    const String script = r'''
$plain = [Console]::In.ReadToEnd()
$secure = ConvertTo-SecureString $plain -AsPlainText -Force
[Console]::Out.Write((ConvertFrom-SecureString $secure))
''';
    return _runPowerShell(script, value);
  }

  static Future<String> _unprotect(String value) async {
    const String script = r'''
$blob = [Console]::In.ReadToEnd().Trim()
$secure = ConvertTo-SecureString $blob
$pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try {
  [Console]::Out.Write([Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer))
} finally {
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
}
''';
    return _runPowerShell(script, value);
  }

  static Future<String> _runPowerShell(String script, String input) async {
    final Process process = await Process.start('powershell.exe', <String>[
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-Command',
      script,
    ], runInShell: false);
    final Future<String> stdout = process.stdout.transform(utf8.decoder).join();
    final Future<String> stderr = process.stderr.transform(utf8.decoder).join();
    process.stdin.write(input);
    await process.stdin.close();
    final int exitCode = await process.exitCode.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        process.kill();
        return -1;
      },
    );
    final String output = await stdout;
    final String error = await stderr;
    if (exitCode != 0 || output.trim().isEmpty) {
      throw StateError(
        error.trim().isEmpty ? 'Windows DPAPI 操作失败' : error.trim(),
      );
    }
    return output.trim();
  }
}
