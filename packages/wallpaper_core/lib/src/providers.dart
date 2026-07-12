import 'media.dart';

final class ProviderCapabilities {
  const ProviderCapabilities({
    required this.requiresAuthorization,
    required this.supportsPagination,
    required this.supportsVideo,
    required this.cloudSyncAllowed,
  });

  final bool requiresAuthorization;
  final bool supportsPagination;
  final bool supportsVideo;
  final bool cloudSyncAllowed;
}

final class ProviderPage {
  const ProviderPage(this.items, {this.nextCursor});
  final List<WallpaperMedia> items;
  final String? nextCursor;
}

sealed class ProviderValidation {
  const ProviderValidation();
}

final class ProviderValid extends ProviderValidation {
  const ProviderValid();
}

final class ProviderInvalid extends ProviderValidation {
  const ProviderInvalid(this.message);
  final String message;
}

abstract interface class WallpaperProvider {
  SourceKind get kind;
  ProviderCapabilities get capabilities;

  Future<void> authorize();
  Future<ProviderValidation> validate(WallpaperSource source);
  Future<ProviderPage> refresh(WallpaperSource source, {String? cursor});
  Future<void> revoke();
}

final class RemoteFeedPolicy {
  const RemoteFeedPolicy({
    this.maxResponseBytes = 5 * 1024 * 1024,
    this.timeout = const Duration(seconds: 15),
  });

  final int maxResponseBytes;
  final Duration timeout;

  ProviderValidation validateEndpoint(Uri? endpoint) {
    if (endpoint == null)
      return const ProviderInvalid('A feed URL is required.');
    if (endpoint.scheme != 'https') {
      return const ProviderInvalid('Feeds must use HTTPS.');
    }
    if (endpoint.host.isEmpty || _isPrivateHost(endpoint.host)) {
      return const ProviderInvalid(
        'Private and local network hosts are not allowed.',
      );
    }
    return const ProviderValid();
  }

  bool _isPrivateHost(String host) {
    final value = host.toLowerCase();
    if (value == 'localhost' || value.endsWith('.local')) return true;
    final octets = value.split('.').map(int.tryParse).toList();
    if (octets.length != 4 || octets.any((part) => part == null)) return false;
    final a = octets[0]!;
    final b = octets[1]!;
    return a == 10 ||
        a == 127 ||
        (a == 169 && b == 254) ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 && b == 168);
  }
}
