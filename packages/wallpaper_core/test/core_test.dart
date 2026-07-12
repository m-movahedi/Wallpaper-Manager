import 'dart:math';

import 'package:test/test.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

WallpaperMedia media(String id) => WallpaperMedia(
  id: id,
  sourceId: 'source',
  sourceKind: SourceKind.rss,
  type: MediaType.image,
  uri: Uri.parse('https://images.example/$id.jpg'),
  dimensions: const MediaDimensions(1920, 1080),
  contentHash: 'hash-$id',
  availability: MediaAvailability.cloud,
);

void main() {
  group('feed security policy', () {
    const policy = RemoteFeedPolicy();

    test('accepts public HTTPS feeds', () {
      expect(
        policy.validateEndpoint(Uri.parse('https://example.com/feed.xml')),
        isA<ProviderValid>(),
      );
    });

    test('rejects insecure and private endpoints', () {
      expect(
        policy.validateEndpoint(Uri.parse('http://example.com/feed')),
        isA<ProviderInvalid>(),
      );
      expect(
        policy.validateEndpoint(Uri.parse('https://192.168.1.4/feed')),
        isA<ProviderInvalid>(),
      );
      expect(
        policy.validateEndpoint(Uri.parse('https://localhost/feed')),
        isA<ProviderInvalid>(),
      );
    });
  });

  group('rotation selection', () {
    final items = [media('a'), media('b'), media('c')];

    test('ordered rotation advances and wraps', () {
      final selector = RotationSelector(random: Random(1));
      expect(
        selector
            .select(
              candidates: items,
              mode: RotationMode.ordered,
              currentId: 'b',
            )
            ?.id,
        'c',
      );
      expect(
        selector
            .select(
              candidates: items,
              mode: RotationMode.ordered,
              currentId: 'c',
            )
            ?.id,
        'a',
      );
    });

    test('no-repeat excludes recent items when possible', () {
      final selected = RotationSelector(random: Random(1)).select(
        candidates: items,
        mode: RotationMode.noRepeat,
        recentIds: {'a', 'b'},
      );
      expect(selected?.id, 'c');
    });
  });

  test('iOS exposes its user-mediated limitation', () {
    expect(PlatformCapabilities.ios.unattendedChanges, isFalse);
    expect(
      PlatformCapabilities.ios.supports(
        MediaType.video,
        WallpaperTarget.lockScreen,
      ),
      isFalse,
    );
    expect(PlatformCapabilities.ios.explanation, contains('Shortcuts'));
  });
}
