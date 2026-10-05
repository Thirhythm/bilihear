/// Playback order modes offered by the player.
enum PlayMode {
  /// Plays the queue once and stops at the end.
  sequential('顺序播放'),

  /// Repeats the whole queue.
  listLoop('列表循环'),

  /// Repeats the current track.
  singleLoop('单曲循环'),

  /// Shuffles the queue and keeps playing.
  shuffle('随机播放');

  const PlayMode(this.label);

  final String label;

  bool get isShuffle => this == PlayMode.shuffle;

  /// Restores a persisted mode, falling back to [PlayMode.listLoop].
  static PlayMode fromStorage(String? value) => PlayMode.values.firstWhere(
    (mode) => mode.name == value,
    orElse: () => PlayMode.listLoop,
  );

  /// Cycles to the next mode in the order shown in the UI.
  PlayMode get next =>
      PlayMode.values[(index + 1) % PlayMode.values.length];
}
