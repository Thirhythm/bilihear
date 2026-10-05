import 'package:flutter/foundation.dart';

import 'media_track.dart';
import 'play_mode.dart';

/// Immutable snapshot of everything the player UI needs except the progress
/// position, which changes many times per second and is exposed separately.
@immutable
class PlayerState {
  const PlayerState({
    this.queue = const [],
    this.currentIndex = -1,
    this.mode = PlayMode.listLoop,
    this.playing = false,
    this.buffering = false,
    this.duration = Duration.zero,
    this.error,
  });

  final List<MediaTrack> queue;
  final int currentIndex;
  final PlayMode mode;
  final bool playing;
  final bool buffering;
  final Duration duration;
  final String? error;

  MediaTrack? get currentTrack =>
      currentIndex >= 0 && currentIndex < queue.length ? queue[currentIndex] : null;

  bool get hasTrack => currentTrack != null;

  bool get hasNext => queue.length > 1;

  @override
  bool operator ==(Object other) =>
      other is PlayerState &&
      listEquals(other.queue, queue) &&
      other.currentIndex == currentIndex &&
      other.mode == mode &&
      other.playing == playing &&
      other.buffering == buffering &&
      other.duration == duration &&
      other.error == error;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(queue),
    currentIndex,
    mode,
    playing,
    buffering,
    duration,
    error,
  );
}
