import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:bilihear/core/api/api_exception.dart';
import 'package:bilihear/core/api/bili_client.dart';
import 'package:bilihear/core/models/equalizer_capabilities.dart';
import 'package:bilihear/core/models/equalizer_preset.dart';
import 'package:bilihear/core/models/media_track.dart';
import 'package:bilihear/core/models/play_mode.dart';
import 'package:bilihear/core/models/player_state.dart';
import 'package:bilihear/core/utils/image_url.dart';
import 'package:bilihear/data/repositories/video_repository.dart';
import 'package:bilihear/data/services/audio_effects.dart';
// just_audio also exports a `PlayerState`, which collides with our model.
import 'package:just_audio/just_audio.dart' hide PlayerState;
import 'package:shared_preferences/shared_preferences.dart';

/// The application's audio handler.
///
/// It drives a single [AudioPlayer] and maintains the play queue itself instead
/// of relying on just_audio's playlist, because a Bilibili play URL only stays
/// valid for two hours: resolving every track up front would be wasteful and
/// would break long queues.
///
/// This class is the single source of truth for playback and broadcasts:
/// * [stateStream] for the Flutter UI,
/// * `playbackState` / `mediaItem` / `queue` for the system notification.
class BiliAudioService extends BaseAudioHandler
    with SeekHandler
    implements AudioEffects {
  BiliAudioService({
    required VideoRepository videoRepository,
    required SharedPreferences preferences,
  }) : _videos = videoRepository,
       _prefs = preferences {
    unawaited(_configureSession());
    _restore();
    // Brings the engine up silently so the equalizer reports its band layout
    // (and any queued band gains can be applied) before anything is played.
    unawaited(_warmUpEngine());
    _subscriptions.addAll([
      _player.playbackEventStream.listen((_) => playbackState.add(_buildPlaybackState())),
      _player.errorStream.listen(_onPlaybackError),
      _player.processingStateStream.listen(_onProcessingState),
      _player.playingStream.listen((_) => _emit()),
    ]);
  }

  static const String _queueKey = 'player_queue_v1';
  static const String _indexKey = 'player_index_v1';
  static const String _modeKey = 'player_mode_v1';

  static const Map<String, String> _streamHeaders = {
    'User-Agent': BiliClient.userAgent,
    'Referer': 'https://www.bilibili.com/',
  };

  /// Re-resolving a single track is allowed once after a playback error.
  static const int _maxAutoRetries = 1;

  final AndroidEqualizer _equalizer = AndroidEqualizer();
  final AndroidLoudnessEnhancer _loudnessEnhancer = AndroidLoudnessEnhancer();
  late final AudioPlayer _player = AudioPlayer(
    audioPipeline: AudioPipeline(
      androidAudioEffects: [_equalizer, _loudnessEnhancer],
    ),
  );

  /// Equalizer bands, filled once the platform reports its band layout.
  List<AndroidEqualizerBand> _equalizerBands = const [];

  /// Gain range of the platform equalizer, `null` until its layout is known.
  AndroidEqualizerParameters? _equalizerParameters;

  /// Last requested band gains, kept until there are bands to apply them to.
  List<double> _bandGains = const [];

  /// Whether the engine is loaded with the current queue entry. `false` while
  /// it still holds the silent warm-up source or nothing at all.
  bool _trackLoaded = false;

  final VideoRepository _videos;
  final SharedPreferences _prefs;
  final Random _random = Random();

  final StreamController<PlayerState> _stateController =
      StreamController<PlayerState>.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  List<MediaTrack> _queue = [];
  List<int> _shuffleOrder = [];
  int _currentIndex = -1;
  PlayMode _mode = PlayMode.listLoop;
  bool _buffering = false;
  Duration _duration = Duration.zero;
  String? _error;
  int _autoRetries = 0;
  ProcessingState _lastProcessingState = ProcessingState.idle;
  bool _disposed = false;
  PlayerState _lastState = const PlayerState();

  // --- Public state -------------------------------------------------------

  /// Stream of UI state (queue, index, mode, playing, …).
  Stream<PlayerState> get stateStream => _stateController.stream;

  /// Fine grained position stream, kept separate to avoid rebuilding the whole
  /// UI several times per second.
  Stream<Duration> get positionStream => _player.positionStream;

  Stream<Duration?> get durationStream => _player.durationStream;

  PlayerState get state => PlayerState(
    queue: List.unmodifiable(_queue),
    currentIndex: _currentIndex,
    mode: _mode,
    playing: _player.playing,
    buffering: _buffering,
    duration: _duration,
    error: _error,
  );

  PlayMode get mode => _mode;

  MediaTrack? get currentTrack =>
      _currentIndex >= 0 && _currentIndex < _queue.length
      ? _queue[_currentIndex]
      : null;

  // --- Queue management ---------------------------------------------------

  /// Replaces the queue and optionally starts playing [startIndex].
  Future<void> setQueue(
    List<MediaTrack> tracks, {
    int startIndex = 0,
    bool autoPlay = true,
  }) async {
    _queue = List.of(tracks);
    _currentIndex = _queue.isEmpty ? -1 : startIndex.clamp(0, _queue.length - 1);
    _trackLoaded = false;
    _duration = currentTrack?.duration ?? Duration.zero;
    _error = null;
    _autoRetries = 0;
    _rebuildShuffleOrder(lead: _currentIndex >= 0 ? _currentIndex : null);
    _broadcastQueue();
    final track = currentTrack;
    if (track != null) {
      _broadcastMediaItem(track, _duration);
      _persist();
    }
    _emit();

    if (autoPlay && track != null) {
      await _loadCurrent();
    } else {
      playbackState.add(_buildPlaybackState());
    }
  }

  /// Plays the queue entry at [index] (user initiated).
  Future<void> playAt(int index) async {
    if (index < 0 || index >= _queue.length) return;
    if (_mode.isShuffle) _rebuildShuffleOrder(lead: index);
    await _playAt(index);
  }

  /// Queues [track] to play directly after the current entry.
  ///
  /// A track the queue already holds is moved rather than added, so an entry
  /// never appears twice — including the queue that consists of the current
  /// entry alone, where there is no next to move ahead of. Returns `false` when
  /// nothing had to be queued because [track] is the entry playing right now.
  Future<bool> insertNext(MediaTrack track) async {
    if (_queue.isEmpty || _currentIndex < 0) {
      // Nothing is loaded that could come next, so the request simply becomes
      // the queue and starts playing right away.
      await setQueue([track]);
      return false;
    }
    final plan = planPlayNext(_queue, _currentIndex, track);
    if (plan == null) return false;

    _queue = plan.queue;
    _currentIndex = plan.currentIndex;
    _rebuildShuffleOrder(lead: _currentIndex);
    final queued = _currentIndex + 1;
    if (_mode.isShuffle) {
      // In shuffle the successor comes from the order, not the list, so the
      // queued entry is lifted right behind the current one there as well.
      _shuffleOrder
        ..remove(queued)
        ..insert(_shuffleOrder.indexOf(_currentIndex) + 1, queued);
    }
    _broadcastQueue();
    _persist();
    _emit();
    return true;
  }

  /// Skips to the next track according to the current [PlayMode].
  Future<void> next() => _playNext();

  /// Skips to the previous track (or restarts the current one).
  Future<void> previous() => _playPrevious();

  Future<void> setPlayMode(PlayMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    if (mode.isShuffle) {
      _rebuildShuffleOrder(lead: _currentIndex >= 0 ? _currentIndex : null);
    }
    await _prefs.setString(_modeKey, mode.name);
    _emit();
  }

  Future<void> cyclePlayMode() => setPlayMode(_mode.next);

  /// Removes one entry from the queue, keeping playback coherent.
  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _queue.length) return;
    final removesCurrent = index == _currentIndex;
    _queue.removeAt(index);
    if (_queue.isEmpty) {
      await clearQueue();
      return;
    }
    if (index < _currentIndex) {
      _currentIndex--;
    } else if (removesCurrent) {
      _currentIndex = _currentIndex.clamp(0, _queue.length - 1);
    }
    _rebuildShuffleOrder(lead: _currentIndex);
    _broadcastQueue();
    _persist();
    _emit();
    if (removesCurrent) await _loadCurrent();
  }

  /// Stops playback and empties the queue.
  Future<void> clearQueue() async {
    await _player.stop();
    _queue = [];
    _shuffleOrder = [];
    _currentIndex = -1;
    _trackLoaded = false;
    _duration = Duration.zero;
    _error = null;
    _broadcastQueue();
    mediaItem.add(null);
    await _prefs.remove(_queueKey);
    await _prefs.remove(_indexKey);
    playbackState.add(_buildPlaybackState());
    _emit();
  }

  Future<void> dispose() async {
    _disposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _player.dispose();
    await _stateController.close();
  }

  // --- AudioHandler overrides --------------------------------------------

  @override
  Future<void> play() async {
    if (_queue.isEmpty) return;
    await _resume();
  }

  /// Starts playback, loading the current queue entry first when the engine is
  /// not holding it yet — e.g. while it still holds the silent warm-up source.
  Future<void> _resume() async {
    if (_trackLoaded &&
        _player.audioSource != null &&
        _player.processingState != ProcessingState.completed) {
      await _player.play();
      return;
    }
    await _loadCurrent();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _playNext();

  @override
  Future<void> skipToPrevious() => _playPrevious();

  @override
  Future<void> skipToQueueItem(int index) => playAt(index);

  @override
  Future<void> stop() async {
    await _player.stop();
    await _player.seek(Duration.zero);
    _emit();
  }

  // --- Sound effects ------------------------------------------------------

  @override
  Future<EqualizerCapabilities> loadCapabilities() async {
    final parameters = await _equalizer.parameters;
    _equalizerParameters = parameters;
    _equalizerBands = parameters.bands;
    await _applyBandGains();
    return EqualizerCapabilities(
      minDecibels: parameters.minDecibels,
      maxDecibels: parameters.maxDecibels,
      bands: [
        for (final band in parameters.bands)
          EqualizerBand(
            lowerFrequency: band.lowerFrequency,
            upperFrequency: band.upperFrequency,
            centerFrequency: band.centerFrequency,
          ),
      ],
    );
  }

  @override
  Future<void> setEqualizerEnabled(bool enabled) =>
      _equalizer.setEnabled(enabled);

  @override
  Future<void> setBandGains(List<double> gainsDecibels) async {
    _bandGains = List.of(gainsDecibels);
    await _applyBandGains();
  }

  /// Pushes the requested gains onto the equalizer bands. Before the platform
  /// reports its layout there is nothing to push to, so the values are applied
  /// once [loadCapabilities] (or the engine itself) reveals the bands.
  Future<void> _applyBandGains() async {
    final parameters = _equalizerParameters;
    if (parameters == null) return;
    final gains = EqualizerPreset.resampleGains(
      _bandGains,
      _equalizerBands.length,
    );
    for (var i = 0; i < _equalizerBands.length; i++) {
      final gain = gains[i].clamp(
        parameters.minDecibels,
        parameters.maxDecibels,
      );
      await _equalizerBands[i].setGain(gain.toDouble());
    }
  }

  /// Learns the equalizer layout in the background so the settings page can
  /// show the device bands right away. The silent source is never played and
  /// is replaced by [_loadCurrent] on the first playback.
  Future<void> _warmUpEngine() async {
    try {
      await _player.setAudioSource(
        SilenceAudioSource(duration: const Duration(seconds: 1)),
      );
      await loadCapabilities();
    } catch (_) {
      // A platform without silence sources (or effect support) simply keeps
      // the reference band layout; playback is unaffected.
    }
  }

  @override
  Future<void> setLoudnessEnabled(bool enabled) =>
      _loudnessEnhancer.setEnabled(enabled);

  @override
  Future<void> setLoudnessGain(double gainDecibels) =>
      _loudnessEnhancer.setTargetGain(gainDecibels);

  // --- Internal playback --------------------------------------------------

  /// Requests the correct audio focus behaviour for music playback.
  Future<void> _configureSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  Future<void> _loadCurrent({bool autoplay = true}) async {
    final track = currentTrack;
    if (track == null) return;

    _buffering = true;
    _error = null;
    _emit();

    try {
      final resolvedIndex = await _resolveIndexIfNeeded(_currentIndex);
      if (resolvedIndex != _currentIndex) {
        _currentIndex = resolvedIndex;
        _broadcastQueue();
      }
      final resolved = _queue[_currentIndex];
      final source = await _videos.fetchPlaybackSource(
        bvid: resolved.bvid,
        cid: resolved.cid,
      );
      final best = source.best;
      if (best == null) {
        throw const BiliApiException(code: -1, message: '该视频没有可用的音频流');
      }
      final uri = Uri.tryParse(best.url);
      if (uri == null) {
        throw const BiliApiException(code: -1, message: '音频地址无效');
      }

      await _player.setAudioSource(
        AudioSource.uri(uri, headers: _streamHeaders),
      );
      _trackLoaded = true;

      _duration = source.duration ?? resolved.duration;
      if (_duration <= Duration.zero) {
        _duration = _player.duration ?? Duration.zero;
      }
      _buffering = false;
      _autoRetries = 0;
      _broadcastMediaItem(resolved, _duration);
      _persist();
      _emit();
      playbackState.add(_buildPlaybackState());

      if (autoplay) await _player.play();
    } on BiliApiException catch (error) {
      _buffering = false;
      _error = error.message;
      _emit();
    } catch (error) {
      _buffering = false;
      _error = '播放失败：$error';
      _emit();
    }
  }

  /// Expands a queue entry that only carries a `bvid` (search / favourite
  /// results) into every part of that video.
  Future<int> _resolveIndexIfNeeded(int index) async {
    if (index < 0 || index >= _queue.length) return index;
    final track = _queue[index];
    if (track.cid > 0) return index;

    final detail = await _videos.fetchDetail(bvid: track.bvid);
    final parts = detail.toTracks();
    if (parts.isEmpty) {
      throw const BiliApiException(code: -404, message: '该视频没有可播放的分P');
    }
    _queue.removeAt(index);
    _queue.insertAll(index, parts);
    _rebuildShuffleOrder(lead: index);
    return index;
  }

  Future<void> _playAt(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    _emit();
    await _loadCurrent();
  }

  Future<void> _playNext() async {
    if (_queue.isEmpty) return;
    if (_queue.length == 1) {
      await _player.seek(Duration.zero);
      await _resume();
      return;
    }
    final index = _nextIndex();
    if (index == null) return;
    await _playAt(index);
  }

  Future<void> _playPrevious() async {
    if (_queue.isEmpty) return;
    // Matches the usual music player behaviour: restart when past 3 seconds.
    if (_player.position > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
      return;
    }
    final index = _previousIndex();
    if (index == null || index == _currentIndex) {
      await _player.seek(Duration.zero);
      return;
    }
    await _playAt(index);
  }

  int? _nextIndex() {
    switch (_mode) {
      case PlayMode.sequential:
        return _currentIndex + 1 < _queue.length ? _currentIndex + 1 : null;
      case PlayMode.listLoop:
      case PlayMode.singleLoop:
        return (_currentIndex + 1) % _queue.length;
      case PlayMode.shuffle:
        final position = _shuffleOrder.indexOf(_currentIndex);
        if (position < 0) {
          _rebuildShuffleOrder();
          return _shuffleOrder.first;
        }
        if (position + 1 >= _shuffleOrder.length) {
          _rebuildShuffleOrder(lead: _currentIndex);
          return _shuffleOrder.length > 1 ? _shuffleOrder[1] : _shuffleOrder.first;
        }
        return _shuffleOrder[position + 1];
    }
  }

  int? _previousIndex() {
    switch (_mode) {
      case PlayMode.sequential:
        return _currentIndex > 0 ? _currentIndex - 1 : _currentIndex;
      case PlayMode.listLoop:
      case PlayMode.singleLoop:
        return (_currentIndex - 1 + _queue.length) % _queue.length;
      case PlayMode.shuffle:
        final position = _shuffleOrder.indexOf(_currentIndex);
        return position <= 0 ? _currentIndex : _shuffleOrder[position - 1];
    }
  }

  Future<void> _handleCompletion() async {
    switch (_mode) {
      case PlayMode.singleLoop:
        await _player.seek(Duration.zero);
        await _player.play();
      case PlayMode.sequential:
        if (_currentIndex + 1 < _queue.length) {
          await _playAt(_currentIndex + 1);
        } else {
          // End of the queue: stop cleanly so a later `play` restarts it.
          await _player.pause();
          await _player.seek(Duration.zero);
          _emit();
        }
      case PlayMode.listLoop:
      case PlayMode.shuffle:
        await _playNext();
    }
  }

  void _rebuildShuffleOrder({int? lead}) {
    final order = List<int>.generate(_queue.length, (i) => i)..shuffle(_random);
    if (lead != null && lead >= 0 && order.contains(lead)) {
      order.remove(lead);
      order.insert(0, lead);
    }
    _shuffleOrder = order;
  }

  void _onProcessingState(ProcessingState state) {
    if (!_trackLoaded) {
      // The silent warm-up load is not something the UI should show as
      // buffering, and it never completes a track.
      _lastProcessingState = state;
      return;
    }
    final buffering =
        state == ProcessingState.loading || state == ProcessingState.buffering;
    if (buffering != _buffering) {
      _buffering = buffering;
      _emit();
    }
    final justCompleted =
        state == ProcessingState.completed &&
        _lastProcessingState != ProcessingState.completed;
    _lastProcessingState = state;
    if (justCompleted) unawaited(_handleCompletion());
  }

  Future<void> _onPlaybackError(PlayerException error) async {
    if (_disposed || _queue.isEmpty) return;
    if (_autoRetries < _maxAutoRetries) {
      _autoRetries++;
      // Play URLs expire after two hours, so a single refresh usually fixes it.
      await _loadCurrent();
      return;
    }
    _buffering = false;
    _error = error.message ?? '播放失败';
    _emit();
  }

  // --- Broadcasting -------------------------------------------------------

  void _emit() {
    if (_disposed) return;
    final next = state;
    if (next == _lastState) return;
    _lastState = next;
    _stateController.add(next);
  }

  void _broadcastQueue() {
    queue.add([
      for (final track in _queue) _toMediaItem(track, track.duration),
    ]);
  }

  void _broadcastMediaItem(MediaTrack track, Duration duration) {
    mediaItem.add(_toMediaItem(track, duration));
  }

  MediaItem _toMediaItem(MediaTrack track, Duration duration) => MediaItem(
    id: track.id,
    title: track.displayTitle,
    artist: track.artist,
    album: track.partTitle ?? '',
    duration: duration > Duration.zero ? duration : null,
    artUri: _artUri(track.cover),
    extras: {'bvid': track.bvid, 'cid': track.cid},
  );

  Uri? _artUri(String cover) {
    final resolved = ImageUrl.resolve(cover, width: 512);
    return resolved == null ? null : Uri.tryParse(resolved);
  }

  PlaybackState _buildPlaybackState() => PlaybackState(
    controls: [
      MediaControl.skipToPrevious,
      if (_player.playing) MediaControl.pause else MediaControl.play,
      MediaControl.skipToNext,
    ],
    systemActions: const {MediaAction.seek},
    androidCompactActionIndices: const [0, 1, 2],
    processingState: _mapProcessingState(_player.processingState),
    playing: _player.playing,
    updatePosition: _player.position,
    bufferedPosition: _player.bufferedPosition,
    speed: _player.speed,
    queueIndex: _currentIndex >= 0 ? _currentIndex : null,
  );

  AudioProcessingState _mapProcessingState(ProcessingState state) =>
      switch (state) {
        ProcessingState.idle => AudioProcessingState.idle,
        ProcessingState.loading => AudioProcessingState.loading,
        ProcessingState.buffering => AudioProcessingState.buffering,
        ProcessingState.ready => AudioProcessingState.ready,
        ProcessingState.completed => AudioProcessingState.completed,
      };

  // --- Persistence --------------------------------------------------------

  void _restore() {
    _mode = PlayMode.fromStorage(_prefs.getString(_modeKey));

    final raw = _prefs.getString(_queueKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _queue = [
            for (final item in decoded)
              if (item is Map)
                MediaTrack.fromJson(item.map((k, v) => MapEntry('$k', v))),
          ];
        }
      } on FormatException {
        _queue = [];
      }
    }

    final savedIndex = _prefs.getInt(_indexKey) ?? -1;
    _currentIndex = savedIndex >= 0 && savedIndex < _queue.length
        ? savedIndex
        : (_queue.isEmpty ? -1 : 0);
    _duration = currentTrack?.duration ?? Duration.zero;
    _rebuildShuffleOrder(lead: _currentIndex >= 0 ? _currentIndex : null);
    _broadcastQueue();

    final track = currentTrack;
    if (track != null) _broadcastMediaItem(track, _duration);
    playbackState.add(_buildPlaybackState());
    _lastState = state;
  }

  Future<void> _persist() async {
    await _prefs.setString(
      _queueKey,
      jsonEncode([for (final track in _queue) track.toJson()]),
    );
    await _prefs.setInt(_indexKey, _currentIndex);
  }
}

/// Reordered queue together with the index the current entry ends up at.
typedef PlayNextPlan = ({List<MediaTrack> queue, int currentIndex});

/// Rewrites [queue] so the entry [track] plays directly after the entry at
/// [currentIndex], moving it there when the queue already holds that video
/// part.
///
/// Returns `null` when the request cannot change anything: [track] is the entry
/// that is playing, which cannot be moved behind itself.
PlayNextPlan? planPlayNext(
  List<MediaTrack> queue,
  int currentIndex,
  MediaTrack track,
) {
  assert(currentIndex >= 0 && currentIndex < queue.length);
  final existing = queue.indexWhere((item) => item.partKey == track.partKey);
  if (existing == currentIndex) return null;

  final next = List.of(queue);
  if (existing < 0) {
    next.insert(currentIndex + 1, track);
    return (queue: next, currentIndex: currentIndex);
  }
  final moved = next.removeAt(existing);
  // Taking an entry from before the current one shifts that one down a slot.
  final index = existing < currentIndex ? currentIndex - 1 : currentIndex;
  next.insert(index + 1, moved);
  return (queue: next, currentIndex: index);
}
