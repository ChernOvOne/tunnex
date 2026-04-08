enum Protocol {
  vless('VLESS', 'vless'),
  vmess('VMess', 'vmess'),
  trojan('Trojan', 'trojan'),
  shadowsocks('Shadowsocks', 'ss');

  const Protocol(this.displayName, this.scheme);

  final String displayName;
  final String scheme;

  static Protocol? fromScheme(String scheme) {
    for (final p in values) {
      if (p.scheme == scheme.toLowerCase()) return p;
    }
    return null;
  }
}
