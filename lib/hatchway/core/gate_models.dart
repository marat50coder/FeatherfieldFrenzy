// Gate routing states + backend reply model. Deliberately named
// differently from sibling apps' templates to avoid cross-binary symbol
// clustering (see `gray_part_mixing_review`).

enum GateRoute {
  game,
  web,
  unset;

  String get storageValue => switch (this) {
    GateRoute.game => 'game',
    GateRoute.web => 'web',
    GateRoute.unset => 'unset',
  };

  static GateRoute parse(String? value) => switch (value) {
    'web' || 'portal' => GateRoute.web,
    'game' || 'native' => GateRoute.game,
    _ => GateRoute.unset,
  };
}

class GateReply {
  const GateReply({
    required this.accepted,
    this.url,
    this.expiresAt,
    this.reason,
  });

  factory GateReply.fromJson(Map<String, dynamic> json) {
    final rawExpiry = json['expires'];
    return GateReply(
      accepted: json['ok'] == true,
      url: json['url'] is String ? json['url'] as String : null,
      expiresAt: rawExpiry is num
          ? rawExpiry.toInt()
          : int.tryParse(rawExpiry?.toString() ?? ''),
      reason: json['message']?.toString(),
    );
  }

  factory GateReply.rejected(String reason) =>
      GateReply(accepted: false, reason: reason);

  final bool accepted;
  final String? url;
  final int? expiresAt;
  final String? reason;

  bool get hasDestination => accepted && (url?.isNotEmpty ?? false);
}

sealed class GateDestination {
  const GateDestination();
}

final class GameSurface extends GateDestination {
  const GameSurface();
}

final class WebSurface extends GateDestination {
  const WebSurface(this.url, {this.coldLaunch = false});

  final String url;
  final bool coldLaunch;
}

final class OfflineSurface extends GateDestination {
  const OfflineSurface({required this.returnToGame});

  final bool returnToGame;
}
