import 'media.dart';
import 'platform_capabilities.dart';

enum WallpaperFit { cover, contain, fill }

final class DisplayTarget {
  const DisplayTarget({
    required this.id,
    required this.name,
    required this.target,
  });
  final String id;
  final String name;
  final WallpaperTarget target;
}

abstract interface class WallpaperService {
  Future<PlatformCapabilities> capabilities();
  Future<List<DisplayTarget>> displays();
  Future<void> preview(WallpaperMedia media);
  Future<void> apply(
    WallpaperMedia media,
    DisplayTarget target,
    WallpaperFit fit,
  );
  Future<void> schedule();
  Future<void> stop();
}

final class SyncChange<T> {
  const SyncChange({
    required this.id,
    required this.updatedAt,
    this.value,
    this.deleted = false,
  });
  final String id;
  final DateTime updatedAt;
  final T? value;
  final bool deleted;
}

abstract interface class SyncService {
  Future<void> push<T>(String collection, List<SyncChange<T>> changes);
  Future<List<SyncChange<Map<String, Object?>>>> pull(
    String collection, {
    String? cursor,
  });
}
