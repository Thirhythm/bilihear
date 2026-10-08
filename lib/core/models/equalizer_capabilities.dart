/// A frequency band of the platform equalizer, in hertz.
class EqualizerBand {
  const EqualizerBand({
    required this.lowerFrequency,
    required this.upperFrequency,
    required this.centerFrequency,
  });

  final double lowerFrequency;
  final double upperFrequency;
  final double centerFrequency;
}

/// Band layout and gain range reported by the playback engine.
class EqualizerCapabilities {
  const EqualizerCapabilities({
    required this.minDecibels,
    required this.maxDecibels,
    required this.bands,
  });

  /// The five bands of a typical Android equalizer, offered for editing while
  /// the engine still reports no layout of its own.
  static const EqualizerCapabilities reference = EqualizerCapabilities(
    minDecibels: -15,
    maxDecibels: 15,
    bands: [
      EqualizerBand(
        lowerFrequency: 30,
        upperFrequency: 120,
        centerFrequency: 60,
      ),
      EqualizerBand(
        lowerFrequency: 120,
        upperFrequency: 450,
        centerFrequency: 230,
      ),
      EqualizerBand(
        lowerFrequency: 450,
        upperFrequency: 1800,
        centerFrequency: 910,
      ),
      EqualizerBand(
        lowerFrequency: 1800,
        upperFrequency: 7000,
        centerFrequency: 3600,
      ),
      EqualizerBand(
        lowerFrequency: 7000,
        upperFrequency: 20000,
        centerFrequency: 14000,
      ),
    ],
  );

  /// Smallest band gain the engine accepts.
  final double minDecibels;

  /// Largest band gain the engine accepts.
  final double maxDecibels;

  /// Bands ordered from low to high frequency.
  final List<EqualizerBand> bands;
}
