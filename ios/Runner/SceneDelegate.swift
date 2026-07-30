import Flutter
import UIKit
import UserNotifications

/// Captures a push-notification deep-link at cold-start (before Dart is
/// running) and stashes it under a SharedPreferences key that
/// `ColdRouteReader` (Dart) consumes on the first frame.
class SceneDelegate: FlutterSceneDelegate {
  /// MUST match `ColdRouteReader._dartKey` in the Dart layer, with the
  /// `flutter.` prefix (that's how the shared_preferences plugin
  /// namespaces UserDefaults entries on iOS).
  static let coldRouteKey = "flutter.fzy_cold_launch_target"

  // Keys the push payload may carry the deep-link under. Ordered by
  // observed frequency in real campaigns so the fast path exits early.
  private static let payloadKeys: [String] = [
    "deep_link",
    "target",
    "url",
    "deeplink",
    "link",
  ]

  // Containers a payload may wrap the deep-link fields inside. Some
  // campaign platforms nest `{data: {...}}`, others `{payload: {...}}`.
  private static let nestedContainers: [String] = [
    "payload",
    "data",
  ]

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    guard let response = connectionOptions.notificationResponse else { return }
    let payload = response.notification.request.content.userInfo
    guard let route = Self.extractRoute(from: payload) else { return }

    let store = UserDefaults.standard
    store.set(route, forKey: Self.coldRouteKey)
    store.synchronize()

    #if DEBUG
    NSLog("[FFR.ROUTE] captured cold-start push destination")
    #endif
  }

  private static func extractRoute(
    from payload: [AnyHashable: Any]
  ) -> String? {
    if let direct = firstNonEmptyString(in: payload) {
      return direct
    }
    for container in nestedContainers {
      guard let nested = payload[container] as? [AnyHashable: Any] else {
        continue
      }
      if let value = firstNonEmptyString(in: nested) {
        return value
      }
    }
    return nil
  }

  private static func firstNonEmptyString(
    in dictionary: [AnyHashable: Any]
  ) -> String? {
    for key in payloadKeys {
      guard let raw = dictionary[key] as? String else { continue }
      let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
      if !trimmed.isEmpty { return trimmed }
    }
    return nil
  }
}
