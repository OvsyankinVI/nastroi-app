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

        completion(
            Timeline(
                entries: [entry],
                policy: .after(Date().addingTimeInterval(900))
            )
        )
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
                .fill(
                    LinearGradient(
                        colors: [.purple, .pink, .orange],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Circle()
                .stroke(.white, lineWidth: 2)

            Image("male_0_happy_complication", bundle: .main)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .padding(2)
        }
        .frame(width: 42, height: 42)
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
        .description("Текущее состояние персонажа")
        .supportedFamilies([
            .accessoryCircular
        ])
    }
}

#Preview(as: .accessoryCircular) {
    NastroiWatchWidgetExtension()
} timeline: {
    SimpleEntry(date: .now)
}
