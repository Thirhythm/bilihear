import 'package:bilihear/core/models/equalizer_capabilities.dart';

/// Sound effects offered by the playback engine.
///
/// Implemented by the audio service on top of just_audio's Android audio
/// effect pipeline. The band layout is only known once the engine has been
/// activated by the first playback, so [loadCapabilities] may complete late.
abstract interface class AudioEffects {
  /// Band layout and gain range of the platform equalizer.
  Future<EqualizerCapabilities> loadCapabilities();

  /// Bypasses or engages the equalizer.
  Future<void> setEqualizerEnabled(bool enabled);

  /// Sets every band gain in decibels, low frequency first.
  ///
  /// The engine may report its band layout only later, in which case it keeps
  /// the gains and applies them (resampled to its bands) once it is ready.
  Future<void> setBandGains(List<double> gainsDecibels);

  /// Bypasses or engages the loudness enhancer.
  Future<void> setLoudnessEnabled(bool enabled);

  /// Sets the loudness enhancer target gain in decibels.
  Future<void> setLoudnessGain(double gainDecibels);
}
