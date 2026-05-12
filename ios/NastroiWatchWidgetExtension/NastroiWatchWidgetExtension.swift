import WidgetKit
import SwiftUI
import UIKit

private let appGroupId = "group.com.vlad.nastroi"
private let peopleKey = "watch_people"
private let selectedPersonKey = "selected_widget_person_id"

struct WatchWidgetPerson: Identifiable, Codable {
    let id: String
    let name: String
    let mood: String
    let gender: String
    let avatarVariant: Int
    let activeStage: String?
    let helpfulActions: [String]
    let avoidActions: [String]
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), person: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(SimpleEntry(date: Date(), person: loadSelectedPerson()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        completion(
            Timeline(
                entries: [SimpleEntry(date: Date(), person: loadSelectedPerson())],
                policy: .after(Date().addingTimeInterval(60))
            )
        )
    }

    private func loadSelectedPerson() -> WatchWidgetPerson? {
        let groupDefaults = UserDefaults(suiteName: appGroupId)
        let jsonString =
            groupDefaults?.string(forKey: peopleKey)
            ?? UserDefaults.standard.string(forKey: peopleKey)

        guard
            let jsonString,
            let data = jsonString.data(using: .utf8),
            let people = try? JSONDecoder().decode([WatchWidgetPerson].self, from: data),
            !people.isEmpty
        else {
            return nil
        }

        let selectedId =
            groupDefaults?.string(forKey: selectedPersonKey)
            ?? UserDefaults.standard.string(forKey: selectedPersonKey)

        if let selectedId,
           let selected = people.first(where: { $0.id == selectedId }) {
            return selected
        }

        return people.first
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let person: WatchWidgetPerson?
}

struct NastroiWatchWidgetExtensionEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: gradientColors(for: entry.person?.mood),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Circle()
                .stroke(.white, lineWidth: 2)

            if let person = entry.person {
                Image(avatarImageName(person))
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .padding(2)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 42, height: 42)
        .containerBackground(.black, for: .widget)
    }

    private func avatarImageName(_ person: WatchWidgetPerson) -> String {
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

        let complicationName = "\(person.gender)_\(person.avatarVariant)_\(moodKey)_complication"
        let regularName = "\(person.gender)_\(person.avatarVariant)_\(moodKey)"

        if UIImage(named: complicationName) != nil {
            return complicationName
        }

        return regularName
    }

    private func gradientColors(for mood: String?) -> [Color] {
        switch mood {
        case "happy": return [.yellow, .orange]
        case "calm": return [.green, .cyan]
        case "sad": return [.blue, .indigo]
        case "irritated": return [.red, .orange]
        case "tired": return [.purple, .gray]
        case "needsCare": return [.pink, .purple]
        default: return [.purple, .pink, .orange]
        }
    }
}

struct NastroiWatchWidgetExtension: Widget {
    let kind: String = "NastroiWatchWidgetExtension"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            NastroiWatchWidgetExtensionEntryView(entry: entry)
        }
        .configurationDisplayName("Настрой")
        .description("Текущее состояние персонажа")
        .supportedFamilies([.accessoryCircular])
    }
}
