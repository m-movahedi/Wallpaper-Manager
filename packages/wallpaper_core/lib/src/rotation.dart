import 'dart:math';

import 'media.dart';

enum RotationMode { ordered, random, noRepeat }

final class RotationPolicy {
  RotationPolicy({required this.mode, required this.interval, this.pausedUntil})
    : assert(!interval.isNegative && interval > Duration.zero);

  final RotationMode mode;
  final Duration interval;
  final DateTime? pausedUntil;

  bool isPaused(DateTime now) =>
      pausedUntil != null && now.isBefore(pausedUntil!);
}

final class RotationSelector {
  RotationSelector({Random? random}) : _random = random ?? Random.secure();
  final Random _random;

  WallpaperMedia? select({
    required List<WallpaperMedia> candidates,
    required RotationMode mode,
    String? currentId,
    Set<String> recentIds = const {},
  }) {
    if (candidates.isEmpty) return null;
    return switch (mode) {
      RotationMode.ordered => _ordered(candidates, currentId),
      RotationMode.random => candidates[_random.nextInt(candidates.length)],
      RotationMode.noRepeat => _noRepeat(candidates, recentIds),
    };
  }

  WallpaperMedia _ordered(List<WallpaperMedia> items, String? currentId) {
    final current = items.indexWhere((item) => item.id == currentId);
    return items[(current + 1) % items.length];
  }

  WallpaperMedia _noRepeat(List<WallpaperMedia> items, Set<String> recentIds) {
    final available = items
        .where((item) => !recentIds.contains(item.id))
        .toList();
    final pool = available.isEmpty ? items : available;
    return pool[_random.nextInt(pool.length)];
  }
}
