/// A Bilibili account, either the signed-in user or an uploader.
class BiliUser {
  const BiliUser({
    required this.mid,
    required this.name,
    this.face,
    this.sign,
    this.level = 0,
    this.vipStatus = 0,
    this.coins = 0,
    this.following,
    this.follower,
  });

  final int mid;
  final String name;
  final String? face;
  final String? sign;
  final int level;
  final int vipStatus;
  final double coins;
  final int? following;
  final int? follower;

  bool get isVip => vipStatus == 1;

  /// Parses the `data` object of `/x/web-interface/nav`.
  factory BiliUser.fromNav(Map<dynamic, dynamic> json) {
    final levelInfo = json['level_info'];
    return BiliUser(
      mid: _int(json['mid']),
      name: '${json['uname'] ?? '未知用户'}',
      face: _string(json['face']),
      sign: _string(json['sign']),
      level: levelInfo is Map ? _int(levelInfo['current_level']) : 0,
      vipStatus: _int(json['vipStatus']),
      coins: _double(json['money']),
    );
  }

  BiliUser copyWith({
    int? following,
    int? follower,
    String? sign,
    double? coins,
  }) => BiliUser(
    mid: mid,
    name: name,
    face: face,
    sign: sign ?? this.sign,
    level: level,
    vipStatus: vipStatus,
    coins: coins ?? this.coins,
    following: following ?? this.following,
    follower: follower ?? this.follower,
  );

  static int _int(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  static double _double(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  static String? _string(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return value;
  }
}
