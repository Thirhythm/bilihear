/// A named set of band gains applied to the equalizer in one tap.
///
/// The tables cover the five reference bands of a typical Android equalizer
/// (60 Hz, 230 Hz, 910 Hz, 3.6 kHz and 14 kHz). Devices reporting another band
/// count get the values interpolated by [gainsFor].
class EqualizerPreset {
  const EqualizerPreset(this.id, this.label, this.gains);

  /// Band count the preset tables are written for.
  static const int referenceBandCount = 5;

  /// Id of the free-form profile edited through the band sliders.
  static const String customId = 'custom';

  /// Id of the neutral profile.
  static const String flatId = 'flat';

  /// Profiles offered in the picker, in display order.
  static const List<EqualizerPreset> values = [
    flat,
    pop,
    rock,
    jazz,
    classical,
    bassBoost,
    vocal,
  ];

  static const EqualizerPreset flat = EqualizerPreset(flatId, '标准', [
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
  ]);

  static const EqualizerPreset pop = EqualizerPreset('pop', '流行', [
    -1.0,
    0.0,
    2.0,
    1.0,
    -1.0,
  ]);

  static const EqualizerPreset rock = EqualizerPreset('rock', '摇滚', [
    3.0,
    2.0,
    -1.0,
    1.0,
    3.0,
  ]);

  static const EqualizerPreset jazz = EqualizerPreset('jazz', '爵士', [
    3.0,
    1.0,
    -1.0,
    1.0,
    2.0,
  ]);

  static const EqualizerPreset classical = EqualizerPreset('classical', '古典', [
    2.0,
    0.0,
    -1.0,
    1.0,
    2.0,
  ]);

  static const EqualizerPreset bassBoost = EqualizerPreset('bass', '低音增强', [
    6.0,
    4.0,
    0.0,
    -1.0,
    0.0,
  ]);

  static const EqualizerPreset vocal = EqualizerPreset('vocal', '人声增强', [
    -3.0,
    -1.0,
    3.0,
    3.0,
    0.0,
  ]);

  /// The profile shown while the band sliders are edited by hand. Its gains
  /// always come from the stored settings instead of this placeholder table.
  static const EqualizerPreset custom = EqualizerPreset(customId, '自定义', [
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
  ]);

  final String id;
  final String label;

  /// Band gains in decibels, low frequency first.
  final List<double> gains;

  bool get isCustom => id == customId;

  /// Restores a persisted profile, falling back to [flat].
  static EqualizerPreset byId(String? id) {
    for (final preset in values) {
      if (preset.id == id) return preset;
    }
    return id == customId ? custom : flat;
  }

  /// The preset table resampled to [bandCount] bands.
  List<double> gainsFor(int bandCount) => resampleGains(gains, bandCount);

  /// Stretches or squeezes [gains] to [bandCount] values by linear
  /// interpolation; an empty table becomes a flat response.
  static List<double> resampleGains(List<double> gains, int bandCount) {
    if (bandCount <= 0) return const [];
    if (gains.isEmpty) return List.filled(bandCount, 0.0);
    if (gains.length == bandCount) return List.of(gains);
    if (bandCount == 1) return [gains.first];

    final result = <double>[];
    for (var i = 0; i < bandCount; i++) {
      final position = i * (gains.length - 1) / (bandCount - 1);
      final low = position.floor();
      final high = position.ceil();
      final t = position - low;
      result.add(gains[low] + (gains[high] - gains[low]) * t);
    }
    return result;
  }
}
