enum MediaType { image, video }

enum MediaAvailability { local, cloud, both, unavailable }

enum SourceKind { rss, atom, json, googlePhotos, localAlbum }

final class MediaDimensions {
  const MediaDimensions(this.width, this.height)
    : assert(width > 0),
      assert(height > 0);

  final int width;
  final int height;

  double get aspectRatio => width / height;
}

final class WallpaperMedia {
  const WallpaperMedia({
    required this.id,
    required this.sourceId,
    required this.sourceKind,
    required this.type,
    required this.uri,
    required this.dimensions,
    required this.contentHash,
    required this.availability,
    this.duration,
    this.title,
    this.attribution,
  }) : assert(type == MediaType.video || duration == null);

  final String id;
  final String sourceId;
  final SourceKind sourceKind;
  final MediaType type;
  final Uri uri;
  final MediaDimensions dimensions;
  final Duration? duration;
  final String contentHash;
  final MediaAvailability availability;
  final String? title;
  final String? attribution;
}

final class WallpaperSource {
  const WallpaperSource({
    required this.id,
    required this.name,
    required this.kind,
    required this.enabled,
    this.endpoint,
    this.deviceId,
  });

  final String id;
  final String name;
  final SourceKind kind;
  final bool enabled;
  final Uri? endpoint;
  final String? deviceId;

  bool get isDeviceLocal => kind == SourceKind.localAlbum;
}
