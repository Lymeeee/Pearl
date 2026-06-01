import Cocoa
import FlutterMacOS
import WidgetKit

class MainFlutterWindow: NSWindow {
  private let appGroup = "group.cn.thebeike.app"
  private let dataKey = "upcoming_class_data"
  private let channelName = "cn.thebeike.app/widget"
  private let widgetKind = "cn.thebeike.app.widget"

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(
        name: channelName,
        binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] (call, result) in
        guard let self = self else {
            result(FlutterMethodNotImplemented)
            return
        }
        if call.method == "updateUpcomingClass" {
            if let json = call.arguments as? String {
                self.saveWidgetData(json)
                if #available(macOS 11.0, *) {
                    WidgetCenter.shared.reloadTimelines(ofKind: self.widgetKind)
                }
            }
            result(nil)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    super.awakeFromNib()
  }

  private func saveWidgetData(_ json: String) {
    if let defaults = UserDefaults(suiteName: appGroup) {
      defaults.set(json, forKey: dataKey)
      defaults.synchronize()
    }
    if let containerURL = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroup
    ) {
      let fileURL = containerURL.appendingPathComponent("\(dataKey).json")
      try? json.write(to: fileURL, atomically: true, encoding: .utf8)
    }
  }
}
