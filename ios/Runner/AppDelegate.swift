import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  // Deep link method channel
  private var deepLinkChannel: FlutterMethodChannel?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Set up method channel for deep links
    let controller = window?.rootViewController as! FlutterViewController
    deepLinkChannel = FlutterMethodChannel(name: "com.urocenter.deeplinks", binaryMessenger: controller.binaryMessenger)
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Handle deep links when app is opened via URL
  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    // Forward deep link to Flutter
    handleDeepLink(url: url)
    return true
  }
  
  // Handle deep links when app is already running (iOS 9+)
  override func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([any UIUserActivityRestoring]?) -> Void) -> Bool {
    if userActivity.activityType == NSUserActivityTypeBrowsingWeb, let url = userActivity.webpageURL {
      handleDeepLink(url: url)
      return true
    }
    return false
  }
  
  // Helper method to send deep links to Flutter
  private func handleDeepLink(url: URL) {
    deepLinkChannel?.invokeMethod("handleDeepLink", arguments: url.absoluteString)
  }
}
