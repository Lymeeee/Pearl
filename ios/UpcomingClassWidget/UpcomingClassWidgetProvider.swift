import WidgetKit
import SwiftUI

struct ClassEntry: TimelineEntry {
    let date: Date
    let hasClass: Bool
    let className: String
    let timeRange: String
    let location: String
    let teacher: String
}

struct Provider: TimelineProvider {
    private let appGroup = "group.cn.thebeike.app"
    private let dataKey = "upcoming_class_data"

    func placeholder(in context: Context) -> ClassEntry {
        ClassEntry(
            date: Date(),
            hasClass: true,
            className: "高等数学",
            timeRange: "09:00 - 10:30",
            location: "教学楼A101",
            teacher: "张老师"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ClassEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClassEntry>) -> Void) {
        let entry = loadEntry()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date().addingTimeInterval(5 * 60)
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }

    private var noClassMessage: String {
        let weekday = Calendar.current.component(.weekday, from: Date())
        let isWeekend = weekday == 1 || weekday == 7
        return isWeekend ? "周末愉快～" : "今日课毕，宜休闲玩耍"
    }

    private func loadEntry() -> ClassEntry {
        if let dict = readWidgetData() {
            let hasClass = dict["hasClass"] as? Bool ?? false
            return ClassEntry(
                date: Date(),
                hasClass: hasClass,
                className: dict["className"] as? String ?? noClassMessage,
                timeRange: dict["timeRange"] as? String ?? "",
                location: dict["location"] as? String ?? "",
                teacher: dict["teacher"] as? String ?? ""
            )
        }
        // No data found — App Group may not be provisioned yet,
        // or the app hasn't sent widget data.
        return ClassEntry(
            date: Date(),
            hasClass: true,
            className: "等待数据同步…",
            timeRange: "打开App后自动更新",
            location: "",
            teacher: ""
        )
    }

    /// Tries to read widget data from UserDefaults first,
    /// then falls back to a JSON file in the App Group container.
    private func readWidgetData() -> [String: Any]? {
        // Try UserDefaults first
        if let defaults = UserDefaults(suiteName: appGroup),
           let json = defaults.string(forKey: dataKey),
           let data = json.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return dict
        }
        // Fallback: read from App Group container file
        if let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroup
        ) {
            let fileURL = containerURL.appendingPathComponent("\(dataKey).json")
            if let json = try? String(contentsOf: fileURL, encoding: .utf8),
               let data = json.data(using: .utf8),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return dict
            }
        }
        return nil
    }
}
