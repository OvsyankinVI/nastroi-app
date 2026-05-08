import WidgetKit
import SwiftUI
import AppIntents

struct PersonWidgetData: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let mood: String
    let gender: String
    let avatarVariant: Int
    let activeStage: String?
}

struct NastroiPersonOption: AppEntity {
    let id: String
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Человек"
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static var defaultQuery = NastroiPersonQuery()
}

struct NastroiPersonQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [NastroiPersonOption] {
        loadPeople()
            .filter { identifiers.contains($0.id) }
            .map { NastroiPersonOption(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [NastroiPersonOption] {
        loadPeople().map {
            NastroiPersonOption(id: $0.id, name: $0.name)
        }
    }

    func defaultResult() async -> NastroiPersonOption? {
        loadPeople().first.map {
            NastroiPersonOption(id: $0.id, name: $0.name)
        }
    }

    private func loadPeople() -> [PersonWidgetData] {
        WidgetDataStore.loadPeople()
    }
}

struct SelectPersonIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Выбор человека"
    static var description = IntentDescription("Выбери человека для виджета")

    @Parameter(title: "Человек")
    var person: NastroiPersonOption?
}

enum WidgetDataStore {
    static let appGroupId = "group.com.vlad.nastroi"
    static let peopleKey = "widget_people"

    static func loadPeople() -> [PersonWidgetData] {
        let defaults = UserDefaults(suiteName: appGroupId)

        guard let jsonString = defaults?.string(forKey: peopleKey),
              let data = jsonString.data(using: .utf8) else {
            return []
        }

        do {
            return try JSONDecoder().decode([PersonWidgetData].self, from: data)
        } catch {
            print("Widget decode error: \(error)")
            return []
        }
    }
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            person: nil
        )
    }

    func snapshot(
        for configuration: SelectPersonIntent,
        in context: Context
    ) async -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            person: selectedPerson(for: configuration)
        )
    }

    func timeline(
        for configuration: SelectPersonIntent,
        in context: Context
    ) async -> Timeline<SimpleEntry> {
        let entry = SimpleEntry(
            date: Date(),
            person: selectedPerson(for: configuration)
        )

        return Timeline(
            entries: [entry],
            policy: .after(Date().addingTimeInterval(60 * 15))
        )
    }

    private func selectedPerson(
        for configuration: SelectPersonIntent
    ) -> PersonWidgetData? {
        let people = WidgetDataStore.loadPeople()

        if let selectedId = configuration.person?.id {
            return people.first { $0.id == selectedId } ?? people.first
        }

        return people.first
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let person: PersonWidgetData?
}

struct NastroiWidgetEntryView: View {
    var entry: Provider.Entry

var body: some View {
    ZStack {
        // Темный фон как в приложении
        Color(red: 0.05, green: 0.05, blue: 0.08)

        // glow за персонажем
        Circle()
            .fill(moodColor().opacity(0.35))
            .frame(width: 170, height: 170)
            .blur(radius: 35)
            .offset(y: -35)

        VStack(spacing: 0) {
            avatarView()
                .frame(width: 128, height: 118)
                .scaleEffect(1.18)
                .offset(y: -2)

            Text(personName())
                .font(.system(size: 13))
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .allowsTightening(true)
                .padding(.top, -2)

            if let stage = entry.person?.activeStage,
            !stage.isEmpty {
                Text(stage)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.68))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .allowsTightening(true)
                    .padding(.top, -2)
            }
        }
        .environment(\.dynamicTypeSize, .medium)
        .padding(.horizontal, 10)
    }
    .widgetURL(widgetUrl())
    .containerBackground(for: .widget) {
        Color.clear
    }
}

    private var content: some View {
        VStack(spacing: -2) {
            avatarView()
                .frame(width: 126, height: 116)
                .scaleEffect(1.28)
                .offset(y: -4)

            Text(personName())
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let stage = entry.person?.activeStage,
            !stage.isEmpty {
                Text(stage)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .offset(y: -2)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .widgetURL(widgetUrl())
    }

    @ViewBuilder
    private func avatarView() -> some View {
        if let image = avatarUIImage() {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Text(moodEmoji())
                .font(.system(size: 64))
        }
    }

    private func avatarUIImage() -> UIImage? {
        guard let person = entry.person else {
            return nil
        }

        let baseName = "\(person.gender)_\(person.avatarVariant)_\(moodAssetKey(person.mood))"

        if let image = UIImage(named: baseName) {
            return image
        }

        if let image = UIImage(named: "\(baseName).png") {
            return image
        }

        if let path = Bundle.main.path(forResource: baseName, ofType: "png") {
            return UIImage(contentsOfFile: path)
        }

        if let path = Bundle.main.path(
            forResource: "assets/avatars/\(baseName)",
            ofType: "png"
        ) {
            return UIImage(contentsOfFile: path)
        }

        return nil
    }

    private func moodAssetKey(_ mood: String) -> String {
        switch mood {
        case "happy":
            return "happy"
        case "calm":
            return "calm"
        case "sad":
            return "sad"
        case "irritated":
            return "irritated"
        case "tired":
            return "tired"
        case "needsCare":
            return "needs_care"
        default:
            return "calm"
        }
    }

    private func personName() -> String {
        entry.person?.name ?? "Добавь друга"
    }

    private func widgetUrl() -> URL? {
        guard let id = entry.person?.id else {
            return nil
        }

        return URL(string: "nastroi://person/\(id)")
    }

    private func moodColor() -> Color {
    guard let mood = entry.person?.mood else {
        return Color.purple
    }

    switch mood {
    case "happy":
        return Color.yellow

    case "calm":
        return Color.green

    case "sad":
        return Color.blue

    case "irritated":
        return Color.red

    case "tired":
        return Color.purple

    case "needsCare":
        return Color.pink

    default:
        return Color.purple
    }
}

    private func moodEmoji() -> String {
        guard let mood = entry.person?.mood else {
            return "🙂"
        }

        switch mood {
        case "happy":
            return "😄"
        case "calm":
            return "😌"
        case "sad":
            return "😔"
        case "irritated":
            return "😠"
        case "tired":
            return "🥱"
        case "needsCare":
            return "🥺"
        default:
            return "🙂"
        }
    }

    private func backgroundColor() -> LinearGradient {
        guard let mood = entry.person?.mood else {
            return gradient(
                Color(red: 0.10, green: 0.12, blue: 0.20),
                Color(red: 0.32, green: 0.22, blue: 0.44)
            )
        }

        switch mood {
        case "happy":
            return gradient(Color.orange, Color.yellow)
        case "calm":
            return gradient(Color.green, Color.teal)
        case "sad":
            return gradient(Color.blue, Color.indigo)
        case "irritated":
            return gradient(Color.red, Color.orange)
        case "tired":
            return gradient(Color.purple, Color.indigo)
        case "needsCare":
            return gradient(Color.pink, Color.red)
        default:
            return gradient(Color.gray, Color.black)
        }
    }

    private func gradient(
        _ c1: Color,
        _ c2: Color
    ) -> LinearGradient {
        LinearGradient(
            colors: [c1, c2],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct NastroiWidget: Widget {
    let kind: String = "NastroiWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectPersonIntent.self,
            provider: Provider()
        ) { entry in
            NastroiWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Nastroi")
        .description("Показывает состояние выбранного человека")
        .supportedFamilies([
            .systemSmall
        ])
    }
}