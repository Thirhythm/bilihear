import 'package:bilihear/core/api/bili_client.dart';
import 'package:bilihear/data/repositories/auth_repository.dart';
import 'package:bilihear/data/repositories/fav_repository.dart';
import 'package:bilihear/data/repositories/history_repository.dart';
import 'package:bilihear/data/repositories/local_favorites_repository.dart';
import 'package:bilihear/data/repositories/local_history_repository.dart';
import 'package:bilihear/data/repositories/search_repository.dart';
import 'package:bilihear/data/repositories/settings_repository.dart';
import 'package:bilihear/data/repositories/video_repository.dart';
import 'package:bilihear/data/services/audio_effects.dart';
import 'package:bilihear/data/services/player_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The three providers below are overridden in `main()` once the asynchronous
/// bootstrap (cookie jar, audio service) has finished.

final Provider<BiliClient> biliClientProvider = Provider<BiliClient>(
  (ref) => throw StateError('biliClientProvider must be overridden in main()'),
);

final Provider<SharedPreferences> sharedPreferencesProvider =
    Provider<SharedPreferences>(
      (ref) => throw StateError(
        'sharedPreferencesProvider must be overridden in main()',
      ),
    );

final Provider<BiliAudioService> audioServiceProvider =
    Provider<BiliAudioService>(
      (ref) => throw StateError('audioServiceProvider must be overridden'),
    );

/// Sound-effect surface of the audio service, split out so tests can fake the
/// engine without constructing a real [BiliAudioService].
final Provider<AudioEffects> audioEffectsProvider = Provider<AudioEffects>(
  (ref) => ref.watch(audioServiceProvider),
);

// --- Repositories ---------------------------------------------------------

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>(
      (ref) => AuthRepository(ref.watch(biliClientProvider)),
    );

final Provider<VideoRepository> videoRepositoryProvider =
    Provider<VideoRepository>(
      (ref) => VideoRepository(ref.watch(biliClientProvider)),
    );

final Provider<SearchRepository> searchRepositoryProvider =
    Provider<SearchRepository>(
      (ref) => SearchRepository(ref.watch(biliClientProvider)),
    );

final Provider<FavRepository> favRepositoryProvider = Provider<FavRepository>(
  (ref) => FavRepository(ref.watch(biliClientProvider)),
);

final Provider<HistoryRepository> historyRepositoryProvider =
    Provider<HistoryRepository>(
      (ref) => HistoryRepository(ref.watch(biliClientProvider)),
    );

/// On-device play history, used while no Bilibili session is active.
final Provider<LocalHistoryRepository> localHistoryRepositoryProvider =
    Provider<LocalHistoryRepository>(
      (ref) => LocalHistoryRepository(ref.watch(sharedPreferencesProvider)),
    );

/// On-device favourites, used while no Bilibili session is active.
final Provider<LocalFavoritesRepository> localFavoritesRepositoryProvider =
    Provider<LocalFavoritesRepository>(
      (ref) => LocalFavoritesRepository(ref.watch(sharedPreferencesProvider)),
    );

/// On-device app preferences.
final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>(
      (ref) => SettingsRepository(ref.watch(sharedPreferencesProvider)),
    );
