/// Enforces the optional `allowedDomains` whitelist for network sources.
///
/// Matching is host-based and supports leading-dot wildcards: an entry of
/// `example.com` matches `example.com` and any sub-domain
/// (`cdn.example.com`), while `cdn.example.com` matches only that exact host.
class DomainGuard {
  const DomainGuard._();

  /// Returns `true` when [uri] is permitted under [allowedDomains].
  ///
  /// A `null` or empty whitelist permits everything. Comparison is
  /// case-insensitive.
  static bool isAllowed(Uri uri, List<String>? allowedDomains) {
    if (allowedDomains == null || allowedDomains.isEmpty) return true;
    final host = uri.host.toLowerCase();
    if (host.isEmpty) return false;
    for (final raw in allowedDomains) {
      final allowed = raw.toLowerCase().trim();
      if (allowed.isEmpty) continue;
      if (host == allowed) return true;
      // Sub-domain match: host ends with ".<allowed>".
      if (host.endsWith('.$allowed')) return true;
    }
    return false;
  }
}
