import Flutter
import UIKit
import UserNotifications

/// Captures a push-notification deep-link at cold-start (before Dart is
/// running) and stashes it under a SharedPreferences key that
/// `ColdRouteReader` (Dart) consumes on the first frame.
class SceneDelegate: FlutterSceneDelegate {
  // MUST match `ColdRouteReader._dartKey` in the Dart layer, prefixed
  // with `flutter.` (that's how the shared_preferences plugin namespaces
  // its UserDefaults entries on iOS).
  static let coldRouteKey = "flutter.ffr_launch_route"

  private static let payloadKeys = [
    "deep_link",
    "target",
    "url",
    "deeplink",
    "link",
  ]
  private static let nestedContainers = ["payload", "data"]

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    guard let response = connectionOptions.notificationResponse else { return }
    guard
      let route = Self.extractRoute(from: response.notification.request.content.userInfo)
    else { return }

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
    if let direct = pluck(from: payload) { return direct }
    for container in nestedContainers {
      if let nested = payload[container] as? [AnyHashable: Any],
         let value = pluck(from: nested) {
        return value
      }
    }
    return nil
  }

  private static func pluck(
    from dictionary: [AnyHashable: Any]
  ) -> String? {
    for key in payloadKeys {
      guard let raw = dictionary[key] as? String else { continue }
      let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
      if !trimmed.isEmpty { return trimmed }
    }
    return nil
  }
}
