import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(SimpleEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let entry = SimpleEntry(date: Date())
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60 * 15))))
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}

struct NastroiWatchWidgetExtensionEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.purple.opacity(0.35))
                .blur(radius: 8)

            Circle()
                .fill(Color.pink.opacity(0.22))
                .blur(radius: 4)

            Image("male_0_happy")
                .resizable()
                .scaledToFit()
                .padding(5)
        }
        .containerBackground(.black, for: .widget)
    }
}

struct NastroiWatchWidgetExtension: Widget {
    let kind: String = "NastroiWatchWidgetExtension"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            NastroiWatchWidgetExtensionEntryView(entry: entry)
        }
        .configurationDisplayName("Настрой")
        .description("Человечек с текущим настроем.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryRectangular
        ])
    }
}

#Preview(as: .accessoryCircular) {
    NastroiWatchWidgetExtension()
} timeline: {
    SimpleEntry(date: .now)
}
