import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    private let appGroup = "group.cn.thebeike.app"
    private let dataKey = "upcoming_class_data"
    private let channelName = "cn.thebeike.app/widget"
    private let widgetKind = "cn.thebeike.app.widget"

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: engineBridge.applicationRegistrar.messenger()
        )
        channel.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else {
                result(FlutterMethodNotImplemented)
                return
            }
            if call.method == "updateUpcomingClass" {
                if let json = call.arguments as? String {
                    self.saveWidgetData(json)
                    if #available(iOS 14.0, *) {
                        WidgetCenter.shared.reloadTimelines(ofKind: self.widgetKind)
                    }
                }
                result(nil)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private func saveWidgetData(_ json: String) {
        // Write to App Group UserDefaults
        if let defaults = UserDefaults(suiteName: appGroup) {
            defaults.set(json, forKey: dataKey)
            defaults.synchronize()
        }
        // Also write directly to the App Group container as a file fallback
        if let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroup
        ) {
            let fileURL = containerURL.appendingPathComponent("\(dataKey).json")
            try? json.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }
}
