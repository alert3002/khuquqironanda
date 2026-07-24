import Flutter
import UIKit

#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
#if canImport(FirebaseCore)
    if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
      FirebaseApp.configure()
      if #available(iOS 10.0, *) {
        UNUserNotificationCenter.current().delegate = self
      }
      application.registerForRemoteNotifications()
#if canImport(FirebaseMessaging)
      Messaging.messaging().delegate = self as? MessagingDelegate
#endif
    }
#endif

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
#if canImport(FirebaseMessaging)
    Messaging.messaging().apnsToken = deviceToken
#endif
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
}
