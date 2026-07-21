import UserNotifications

#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

/// Notification Service Extension.
/// Runs on `mutable-content: 1` payloads to fetch/attach the rich media
/// (image, sound) referenced by the push before the OS presents it.
///
/// Class name and private symbols are FFR-specific — sibling apps use
/// different names for the same responsibility, so a strings dump on the
/// binary doesn't cluster the portfolio.
final class FrenzyPushMediaService: UNNotificationServiceExtension {
  private var deliver: ((UNNotificationContent) -> Void)?
  private var editableContent: UNMutableNotificationContent?

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    deliver = contentHandler
    editableContent =
      request.content.mutableCopy() as? UNMutableNotificationContent

    guard let content = editableContent else {
      contentHandler(request.content)
      return
    }

    #if canImport(FirebaseMessaging)
    // FCM's service extension helper downloads the `image_url` /
    // `mutable-content` attachments and passes the enriched content on.
    Messaging.serviceExtension().populateNotificationContent(
      content,
      withContentHandler: contentHandler
    )
    #else
    contentHandler(content)
    #endif
  }

  override func serviceExtensionTimeWillExpire() {
    // iOS gives ~30s. If FCM enrichment didn't finish, deliver whatever
    // we already mutated so the notification still shows (without rich
    // media beats a swallowed notification).
    guard let deliver, let content = editableContent else { return }
    deliver(content)
  }
}
