// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

/// Loopback defaults. A build without `--dart-define` keeps these so the
/// emulator and the local stack stay unchanged.
const loopbackPolicyUrl = 'http://127.0.0.1:18018';
const loopbackHomeserver = 'http://127.0.0.1:18008';

/// Policy origin, including an optional path prefix. No trailing slash.
const buildPolicyUrl = String.fromEnvironment(
  'HOOBIRD_POLICY_BASE',
  defaultValue: loopbackPolicyUrl,
);

/// Matrix Client-Server base. The SDK appends `/_matrix/...`.
const buildHomeserver = String.fromEnvironment(
  'HOOBIRD_HOMESERVER',
  defaultValue: loopbackHomeserver,
);

/// True when this binary was compiled for a server other than loopback.
/// A pinned build ignores a previously saved loopback address.
bool get buildEndpointsPinned =>
    buildPolicyUrl != loopbackPolicyUrl || buildHomeserver != loopbackHomeserver;

bool loopbackHost(String host) {
  switch (host.toLowerCase()) {
    case '127.0.0.1':
    case 'localhost':
    case '::1':
      return true;
    default:
      return false;
  }
}

/// HTTPS everywhere except HTTP to this device's own loopback.
/// Userinfo is rejected so a URL cannot carry a password.
String? endpointRejection(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || !uri.hasScheme || uri.host.isEmpty || uri.hasFragment) {
    return 'Die Serveradresse ist ungültig.';
  }
  if (uri.userInfo.isNotEmpty) {
    return 'Die Serveradresse darf keine Zugangsdaten enthalten.';
  }
  if (uri.scheme == 'https') return null;
  if (uri.scheme == 'http' && loopbackHost(uri.host)) return null;
  return 'Nur HTTPS ist erlaubt. Klartext-HTTP bleibt auf 127.0.0.1 und localhost beschränkt.';
}

bool sameEndpoint(String a, String b) {
  String normalized(String raw) {
    final uri = Uri.parse(raw.trim());
    final path = uri.path.replaceAll(RegExp(r'/+$'), '');
    return uri.replace(path: path, query: '', fragment: '').toString();
  }

  return normalized(a) == normalized(b);
}

String resolvedEndpoint(String? stored, String fallback) {
  if (buildEndpointsPinned) return fallback;
  if (stored == null || stored.trim().isEmpty) return fallback;
  if (endpointRejection(stored) != null) return fallback;
  return stored.trim();
}

/// Join [path] onto a policy base. A base of `https://host/policy` and a path
/// of `/_hoobird/v1/login` becomes `https://host/policy/_hoobird/v1/login`.
Uri policyRequestUri(String baseUrl, String path, {Map<String, String>? query}) {
  final base = Uri.parse(baseUrl.trim().replaceAll(RegExp(r'/+$'), ''));
  return base.replace(
    path: '${base.path}$path',
    queryParameters: query,
  );
}
