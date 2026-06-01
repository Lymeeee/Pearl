import Flutter
import UIKit
import WidgetKit

class SceneDelegate: FlutterSceneDelegate {
    private let appGroup = "group.cn.thebeike.app"
    private let dataKey = "upcoming_class_data"
    private let channelName = "cn.thebeike.app/widget"
    private let widgetKind = "cn.thebeike.app.widget"

    override func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        // Set the window reference on FlutterSceneDelegate before super,
        // so FlutterPluginSceneLifeCycleDelegate can track the engine
        // via sceneDelegate.window.rootViewController.
        if let windowScene = scene as? UIWindowScene,
           self.window == nil {
            self.window = windowScene.windows.first
        }

        super.scene(scene, willConnectTo: session, options: connectionOptions)

        // If no window exists yet, create one with a FlutterViewController.
        if self.window == nil,
           let windowScene = scene as? UIWindowScene {
            let flutterVC = FlutterViewController()
            self.window = UIWindow(windowScene: windowScene)
            self.window?.rootViewController = flutterVC
            self.window?.makeKeyAndVisible()
        }

        guard let rootVC = self.window?.rootViewController as? FlutterViewController else {
            return
        }

        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: rootVC.engine.binaryMessenger
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
