import Flutter
import UIKit

// MARK: - FIB Payment Callback Handler
// Payment callback handler implementation embedded directly in AppDelegate file to avoid linking issues
class FibPaymentCallbackHandler: NSObject, FlutterPlugin {
  private static var methodChannel: FlutterMethodChannel?
  
  static func register(with registrar: FlutterPluginRegistrar) {
    methodChannel = FlutterMethodChannel(name: "com.urocenter.fib_payment_callback", binaryMessenger: registrar.messenger())
    let instance = FibPaymentCallbackHandler()
    registrar.addMethodCallDelegate(instance, channel: methodChannel!)
  }
  
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "initializeCallbackHandler" {
      // Register for any payment notifications or callbacks here
      NotificationCenter.default.addObserver(
        forName: NSNotification.Name("FIBPaymentCallbackReceived"),
        object: nil,
        queue: nil
      ) { notification in
        if let paymentData = notification.userInfo {
          FibPaymentCallbackHandler.methodChannel?.invokeMethod("handlePaymentCallback", arguments: paymentData)
        }
      }
      
      result(nil)
    } else {
      result(FlutterMethodNotImplemented)
    }
  }
  
  // Method to manually handle a deep link from AppDelegate
  static func handleDeepLink(url: URL) {
    guard url.scheme == "urocenter", url.path == "/payment/callback" else {
      return
    }
    
    // Parse the URL query parameters
    if let components = URLComponents(url: url, resolvingAgainstBaseURL: true) {
      var parameters: [String: Any] = [:]
      
      for queryItem in components.queryItems ?? [] {
        if let value = queryItem.value {
          parameters[queryItem.name] = value
        }
      }
      
      if !parameters.isEmpty {
        // Send to Flutter through the method channel
        Self.methodChannel?.invokeMethod("handlePaymentCallback", arguments: parameters)
      }
    }
  }
}

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
    
    // Register FIB Payment Callback Handler
    if let registrar = self.registrar(forPlugin: "FibPaymentCallbackHandler") {
      FibPaymentCallbackHandler.register(with: registrar)
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Handle deep links when app is opened via URL
  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    // Forward deep link to Flutter
    handleDeepLink(url: url)
    
    // Handle payment callback if it's a payment URL
    if url.scheme == "urocenter" && url.path == "/payment/callback" {
      FibPaymentCallbackHandler.handleDeepLink(url: url)
    }
    
    return true
  }
  
  // Handle deep links when app is already running (iOS 9+)
  override func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([any UIUserActivityRestoring]?) -> Void) -> Bool {
    if userActivity.activityType == NSUserActivityTypeBrowsingWeb, let url = userActivity.webpageURL {
      handleDeepLink(url: url)
      
      // Handle payment callback if it's a payment URL
      if url.scheme == "urocenter" && url.path == "/payment/callback" {
        FibPaymentCallbackHandler.handleDeepLink(url: url)
      }
      
      return true
    }
    return false
  }
  
  // Helper method to send deep links to Flutter
  private func handleDeepLink(url: URL) {
    deepLinkChannel?.invokeMethod("handleDeepLink", arguments: url.absoluteString)
  }
}
