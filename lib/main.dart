import 'package:audio_service/audio_service.dart';
import 'package:bilihear/app.dart';
import 'package:bilihear/core/api/bili_client.dart';
import 'package:bilihear/data/repositories/video_repository.dart';
import 'package:bilihear/data/services/player_service.dart';
import 'package:bilihear/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Restores the cookie jar and prepares the anonymous device identity.
  final client = await BiliClient.create();
  final preferences = await SharedPreferences.getInstance();

  // audio_service must own the player so playback survives in the background
  // and the system notification can control it.
  final audioService = await AudioService.init<BiliAudioService>(
    builder: () => BiliAudioService(
      videoRepository: VideoRepository(client),
      preferences: preferences,
    ),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'thirhythm.bilihear.audio',
      androidNotificationChannelName: '哔哩听见 音频播放',
      androidNotificationChannelDescription: '显示正在播放的音频并提供播放控制',
      androidNotificationOngoing: false,
      // Keeping the service in the foreground while paused avoids
      // ForegroundServiceStartNotAllowedException on Android 12+.
      androidStopForegroundOnPause: false,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        biliClientProvider.overrideWithValue(client),
        sharedPreferencesProvider.overrideWithValue(preferences),
        audioServiceProvider.overrideWithValue(audioService),
      ],
      child: const BiliHearApp(),
    ),
  );
}
