import WidgetKit
import SwiftUI

struct WatchWidgetPerson: Codable {
    let id: String
    let name: String
    let mood: String
    let gender: String
    let avatarVariant: Int
    let activeStage: String?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), person: mockPerson)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(SimpleEntry(date: Date(), person: loadPerson()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let entry = SimpleEntry(date: Date(), person: loadPerson())
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60 * 15))))
    }

    private func loadPerson() -> WatchWidgetPerson {
        guard
            let jsonString = UserDefaults.standard.string(forKey: "watch_people"),
            let data = jsonString.data(using: .utf8),
            let people = try? JSONDecoder().decode([WatchWidgetPerson].self, from: data),
            let first = people.first
        else {
            return mockPerson
        }

        return first
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let person: WatchWidgetPerson
}

struct NastroiWatchWidgetExtensionEntryView: View {
    @Environment(\.widgetFamily) var family

    let entry: SimpleEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularPersonComplication(person: entry.person)

        case .accessoryRectangular:
            RectangularPersonWidget(person: entry.person)

        case .accessoryInline:
            Text("\(entry.person.name) \(moodLabel(entry.person.mood))")

        default:
            CircularPersonComplication(person: entry.person)
        }
    }
}

struct CircularPersonComplication: View {
    let person: WatchWidgetPerson

    var body: some View {
        ZStack {
            Circle()
                .fill(moodGlowColor(person.mood).opacity(0.45))
                .blur(radius: 7)

            Image(avatarImageName(person))
                .resizable()
                .scaledToFit()
                .padding(3)
        }
        .containerBackground(.black, for: .widget)
    }
}

struct RectangularPersonWidget: View {
    let person: WatchWidgetPerson

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(moodGlowColor(person.mood).opacity(0.4))
                    .blur(radius: 7)

                Image(avatarImageName(person))
                    .resizable()
                    .scaledToFit()
                    .padding(2)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .font(.caption2)
                    .lineLimit(1)

                Text(person.activeStage ?? moodLabel(person.mood))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
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
        .description("Показывает настрой человека на циферблате.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

let mockPerson = WatchWidgetPerson(
    id: "1",
    name: "Аня",
    mood: "happy",
    gender: "female",
    avatarVariant: 0,
    activeStage: "Радостно"
)

func avatarImageName(_ person: WatchWidgetPerson) -> String {
    let moodKey: String

    switch person.mood {
    case "happy": moodKey = "happy"
    case "calm": moodKey = "calm"
    case "irritated": moodKey = "irritated"
    case "sad": moodKey = "sad"
    case "tired": moodKey = "tired"
    case "needsCare": moodKey = "needs_care"
    default: moodKey = "calm"
    }

    return "\(person.gender)_\(person.avatarVariant)_\(moodKey)"
}

func moodLabel(_ mood: String) -> String {
    switch mood {
    case "happy": return "Радостно"
    case "calm": return "Спокойно"
    case "sad": return "Грустно"
    case "irritated": return "Раздражён"
    case "tired": return "Устал"
    case "needsCare": return "Нужна забота"
    default: return mood
    }
}

func moodGlowColor(_ mood: String) -> Color {
    switch mood {
    case "happy": return .yellow
    case "calm": return .green
    case "sad": return .blue
    case "irritated": return .red
    case "tired": return .purple
    case "needsCare": return .pink
    default: return .purple
    }
}

#Preview(as: .accessoryCircular) {
    NastroiWatchWidgetExtension()
} timeline: {
    SimpleEntry(date: .now, person: mockPerson)
}
