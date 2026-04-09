import 'dart:convert';
import 'dart:io';

/// Discovers domains/IPs used by running Windows applications
class AppScannerWindows {
  AppScannerWindows._();

  /// Known app → domain mappings
  static const Map<String, List<String>> knownApps = {
    'telegram': ['telegram.org', 't.me', 'telegram.me', 'telesco.pe'],
    'discord': ['discord.com', 'discord.gg', 'discordapp.com', 'discord.media'],
    'slack': ['slack.com', 'slack-edge.com', 'slack-msgs.com'],
    'spotify': ['spotify.com', 'scdn.co', 'spotifycdn.com'],
    'steam': ['steampowered.com', 'steamcommunity.com', 'steamstatic.com', 'steamcdn-a.akamaihd.net'],
    'chrome': [], // all traffic
    'firefox': [], // all traffic
    'edge': [], // all traffic
    'opera': [], // all traffic
    'brave': [], // all traffic
    'whatsapp': ['whatsapp.com', 'whatsapp.net', 'wa.me'],
    'viber': ['viber.com', 'viber.media'],
    'zoom': ['zoom.us', 'zoomgov.com'],
    'teams': ['teams.microsoft.com', 'teams.live.com'],
    'notion': ['notion.so', 'notion.com'],
    'figma': ['figma.com', 'figma.net'],
    'github': ['github.com', 'github.io', 'githubusercontent.com', 'githubassets.com'],
    'vscode': ['vscode.dev', 'visualstudio.com', 'gallerycdn.vsassets.io'],
    'chatgpt': ['openai.com', 'chatgpt.com', 'oaiusercontent.com'],
    'claude': ['claude.ai', 'anthropic.com'],
  };

  /// Get list of installed apps (from running processes)
  static Future<List<AppInfo>> getRunningApps() async {
    try {
      final result = await Process.run('powershell', ['-Command',
        '[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; '
        'Get-Process | Where-Object {\$_.MainWindowTitle -ne ""} | Select-Object ProcessName, Id, MainWindowTitle | ConvertTo-Csv -NoTypeInformation'
      ], stdoutEncoding: const Utf8Codec(allowMalformed: true),
         stderrEncoding: const Utf8Codec(allowMalformed: true),
      ).timeout(const Duration(seconds: 10));

      if (result.exitCode != 0) return [];

      final lines = (result.stdout as String).split('\n').skip(1); // skip header
      final apps = <AppInfo>[];
      final seen = <String>{};

      for (final line in lines) {
        final parts = line.split('","');
        if (parts.length < 3) continue;
        final name = parts[0].replaceAll('"', '').trim().toLowerCase();
        final pid = int.tryParse(parts[1].replaceAll('"', '').trim()) ?? 0;
        final title = parts[2].replaceAll('"', '').trim();
        if (name.isEmpty || seen.contains(name)) continue;
        seen.add(name);

        apps.add(AppInfo(
          processName: name,
          pid: pid,
          windowTitle: title,
          knownDomains: knownApps[name] ?? [],
        ));
      }

      return apps;
    } catch (_) {
      return [];
    }
  }

  /// Scan connections of a specific process to discover domains
  static Future<List<String>> scanProcessConnections(int pid) async {
    try {
      final result = await Process.run('powershell', ['-Command',
        "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; "
        "Get-NetTCPConnection -OwningProcess $pid -ErrorAction SilentlyContinue | "
        "Where-Object {\$_.RemoteAddress -ne '127.0.0.1' -and \$_.RemoteAddress -ne '::1' -and \$_.RemoteAddress -ne '0.0.0.0'} | "
        "Select-Object -ExpandProperty RemoteAddress -Unique"
      ], stdoutEncoding: const Utf8Codec(allowMalformed: true),
      ).timeout(const Duration(seconds: 5));

      if (result.exitCode != 0) return [];

      final ips = (result.stdout as String)
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && l != '::')
          .take(20) // max 20 IPs to avoid hanging
          .toList();

      // Simple reverse DNS (with timeout per IP)
      final domains = <String>{};
      for (final ip in ips) {
        try {
          final reverse = await Process.run('nslookup', [ip])
              .timeout(const Duration(seconds: 2));
          final output = reverse.stdout as String;
          final nameMatch = RegExp(r'Name:\s+(\S+)').firstMatch(output);
          if (nameMatch != null) {
            final host = nameMatch.group(1)!;
            final parts = host.split('.');
            if (parts.length >= 2) {
              domains.add('${parts[parts.length - 2]}.${parts[parts.length - 1]}');
            }
          } else {
            domains.add(ip);
          }
        } catch (_) {
          domains.add(ip);
        }
      }

      return domains.toList();
    } catch (_) {
      return [];
    }
  }
}

class AppInfo {
  final String processName;
  final int pid;
  final String windowTitle;
  final List<String> knownDomains;
  List<String> scannedDomains;

  AppInfo({
    required this.processName,
    required this.pid,
    required this.windowTitle,
    required this.knownDomains,
    this.scannedDomains = const [],
  });

  String get displayName => windowTitle.isNotEmpty ? windowTitle : processName;
  List<String> get allDomains => {...knownDomains, ...scannedDomains}.toList();
}
