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
        let timeline = Timeline(
            entries: [entry],
            policy: .after(Date().addingTimeInterval(60 * 15))
        )
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}

struct NastroiWatchWidgetExtensionEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        ZStack {
            // фон
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.purple.opacity(0.8),
                            Color.pink.opacity(0.5)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // аватар
            Image(systemName: "figure.stand")
                .resizable()
                .scaledToFit()
                .padding(6)
                .foregroundStyle(.white)
            Circle()
                .stroke(Color.white, lineWidth: 1)
        }
        .widgetAccentable(false)
        .containerBackground(.black, for: .widget)
    }
}

struct NastroiWatchWidgetExtension: Widget {
    let kind: String = "NastroiWatchWidgetExtension"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: Provider()
        ) { entry in
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
