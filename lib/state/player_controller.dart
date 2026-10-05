import 'dart:async';

import 'package:bilihear/core/api/api_exception.dart';
import 'package:bilihear/core/models/media_track.dart';
import 'package:bilihear/core/models/play_mode.dart';
import 'package:bilihear/core/models/player_state.dart';
import 'package:bilihear/data/services/player_service.dart';
import 'package:bilihear/state/auth_controller.dart';
import 'package:bilihear/state/library_controllers.dart';
import 'package:bilihear/state/local_history_controller.dart';
import 'package:bilihear/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mirror of the audio service state, consumed by the UI.
final NotifierProvider<PlayerController, PlayerState> playerStateProvider =
    NotifierProvider<PlayerController, PlayerState>(PlayerController.new);

/// Playback position, updated several times per second.
final StreamProvider<Duration> playbackPositionProvider =
    StreamProvider<Duration>((ref) {
      return ref.watch(audioServiceProvider).positionStream;
    });

/// Commands exposed to the widgets.
class PlayerController extends Notifier<PlayerState> {
  String? _lastRecordedTrackId;

  @override
  PlayerState build() {
    final service = ref.watch(audioServiceProvider);
    final subscription = service.stateStream.listen(_onServiceState);
    ref.onDispose(subscription.cancel);

    final initial = service.state;
    _lastRecordedTrackId = initial.currentTrack?.id;
    return initial;
  }

  BiliAudioService get _service => ref.read(audioServiceProvider);

  void _onServiceState(PlayerState next) {
    if (!ref.mounted) return;
    state = next;
    final track = next.currentTrack;
    // Only fully identified tracks are recorded; a placeholder would sit next
    // to the real part as a duplicate row.
    if (track == null ||
        !track.isResolved ||
        track.id == _lastRecordedTrackId) {
      return;
    }
    _lastRecordedTrackId = track.id;
    unawaited(_recordHistory(track));
  }

  /// Stores the played [track] in the on-device history, which is what the
  /// home page's 最近播放 is built from, and reports it to the Bilibili account
  /// as well when signed in.
  ///
  /// The local record is written in both cases on purpose: the home page always
  /// shows the tracks played in this app, signed in or not.
  Future<void> _recordHistory(MediaTrack track) async {
    final signedIn = ref.read(authControllerProvider).isLoggedIn;
    final localHistory = ref.read(localHistoryProvider.notifier);
    final cloudHistory = signedIn ? ref.read(historyRepositoryProvider) : null;

    await localHistory.record(track);
    if (cloudHistory == null) return;

    try {
      await cloudHistory.reportProgress(track: track);
      if (ref.mounted) ref.invalidate(historyProvider);
    } on BiliApiException {
      // Reporting to the cloud is best-effort: the local record above already
      // captured the playback.
    }
  }

  /// Loads a video (expanding every part) and hands it to the player, starting
  /// at [page].
  ///
  /// Only the queue is resolved here. Resolving the audio stream and buffering
  /// the first track continues in the background, so callers can react — for
  /// instance open the full player — as soon as the track is known instead of
  /// waiting for the network to deliver the media.
  Future<void> playVideo(String bvid, {int page = 1}) async {
    final detail = await ref
        .read(videoRepositoryProvider)
        .fetchDetail(bvid: bvid);
    final tracks = detail.toTracks();
    final index = tracks.indexWhere((track) => track.page == page);
    unawaited(_service.setQueue(tracks, startIndex: index < 0 ? 0 : index));
  }

  /// Plays an explicit list, e.g. every item of a favourite folder.
  ///
  /// As with [playVideo], the queue is handed over right away and the audio
  /// keeps loading afterwards.
  Future<void> playTracks(List<MediaTrack> tracks, {int startIndex = 0}) async {
    unawaited(_service.setQueue(tracks, startIndex: startIndex));
  }

  Future<void> togglePlay() =>
      state.playing ? _service.pause() : _service.play();

  Future<void> play() => _service.play();

  Future<void> pause() => _service.pause();

  Future<void> next() => _service.next();

  Future<void> previous() => _service.previous();

  Future<void> seek(Duration position) => _service.seek(position);

  Future<void> playAt(int index) => _service.playAt(index);

  Future<void> setMode(PlayMode mode) => _service.setPlayMode(mode);

  Future<void> cycleMode() => _service.cyclePlayMode();

  Future<void> removeAt(int index) => _service.removeFromQueue(index);

  Future<void> clear() => _service.clearQueue();
}
