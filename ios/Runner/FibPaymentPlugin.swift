import Flutter
import UIKit
import FIBPaymentSDK

public class FibPaymentPlugin: NSObject, FlutterPlugin, FIBPaymentManagerDelegate {
    private let fibPaymentManager: FIBPaymentManagerType
    private var pendingResult: FlutterResult?
    
    init(fibPaymentManager: FIBPaymentManagerType = FIBPaymentManager()) {
        self.fibPaymentManager = fibPaymentManager
        super.init()
        fibPaymentManager.delegate = self
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.urocenter.fib_payment", binaryMessenger: registrar.messenger())
        let instance = FibPaymentPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initiatePayment":
            guard let args = call.arguments as? [String: Any],
                  let amount = args["amount"] as? Double,
                  let currencyCode = args["currencyCode"] as? String,
                  let description = args["description"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                return
            }
            
            // Determine which FIB apps are installed
            let fibApplicationURLs = self.getInstalledFibApps()
            if fibApplicationURLs.isEmpty {
                result(FlutterError(code: "NO_FIB_APPS", message: "No FIB apps are installed", details: nil))
                return
            }
            
            // Save result for later use in delegate methods
            self.pendingResult = result
            
            // Configure payment view
            let fibView = PayWithFIBView()
            fibView.configure(fibApplicationURLs: fibApplicationURLs, delegate: self)
            
            // Present the view to select FIB app
            if let viewController = UIApplication.shared.keyWindow?.rootViewController {
                viewController.present(fibView, animated: true)
            }
            
        case "checkPaymentStatus":
            guard let args = call.arguments as? [String: Any],
                  let paymentId = args["paymentId"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                return
            }
            
            fibPaymentManager.checkPaymentStatus(paymentID: paymentId) { status in
                result(status?.rawValue)
            }
            
        case "cancelPayment":
            guard let args = call.arguments as? [String: Any],
                  let paymentId = args["paymentId"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                return
            }
            
            fibPaymentManager.cancelPayment(paymentID: paymentId)
            result(true)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - FIBPaymentManagerDelegate
    
    public func paymentCanceled(paymentID: String) {
        pendingResult?(FlutterError(code: "PAYMENT_CANCELED", message: "Payment was canceled", details: nil))
        pendingResult = nil
    }
    
    public func paymentCompleted(paymentID: String) {
        pendingResult?(paymentID)
        pendingResult = nil
    }
    
    // MARK: - Helpers
    
    private func getInstalledFibApps() -> [FIBApplicationURLType] {
        var installedApps = [FIBApplicationURLType]()
        
        if let personalAppURL = URL(string: "FIBPersonal://"), UIApplication.shared.canOpenURL(personalAppURL) {
            installedApps.append(.personalURL("FIBPersonal://"))
        }
        
        if let businessAppURL = URL(string: "FIBBusiness://"), UIApplication.shared.canOpenURL(businessAppURL) {
            installedApps.append(.businessURL("FIBBusiness://"))
        }
        
        if let corporateAppURL = URL(string: "FIBCorporate://"), UIApplication.shared.canOpenURL(corporateAppURL) {
            installedApps.append(.corporateURL("FIBCorporate://"))
        }
        
        return installedApps
    }
} 