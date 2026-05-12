import SwiftUI
import WidgetKit

private let appGroupId = "group.com.vlad.nastroi"
private let selectedPersonKey = "selected_widget_person_id"
private let widgetKind = "NastroiWatchWidgetExtension"

struct ContentView: View {
    @EnvironmentObject var watchStore: WatchPeopleStore

    @State private var selectedWidgetPersonId: String? =
        UserDefaults(suiteName: appGroupId)?.string(forKey: selectedPersonKey)
        ?? UserDefaults.standard.string(forKey: selectedPersonKey)

    var body: some View {
        NavigationStack {
            if watchStore.people.isEmpty {
                VStack(spacing: 12) {
                    Text("😴")
                        .font(.system(size: 40))

                    Text("Нет людей")
                        .font(.headline)

                    Text("Открой iPhone приложение и добавь людей")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                List(watchStore.people) { person in
                    NavigationLink {
                        PersonDetailView(person: person)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(person.name)
                                    .font(.headline)

                                Text(person.activeStage ?? moodLabel(person.mood))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }

                            Spacer()

                            if selectedWidgetPersonId == person.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .swipeActions {
                        Button("В виджет") {
                            selectForWidget(person)
                        }
                        .tint(.blue)
                    }
                    .contextMenu {
                        Button("Показать в виджете") {
                            selectForWidget(person)
                        }
                    }
                }
                .navigationTitle("Настрой")
            }
        }
    }

    private func selectForWidget(_ person: WatchPerson) {
        let groupDefaults = UserDefaults(suiteName: appGroupId)

        groupDefaults?.set(person.id, forKey: selectedPersonKey)
        groupDefaults?.synchronize()

        UserDefaults.standard.set(person.id, forKey: selectedPersonKey)
        UserDefaults.standard.synchronize()

        selectedWidgetPersonId = person.id

        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

struct PersonDetailView: View {
    let person: WatchPerson

    var body: some View {
        NavigationLink {
            RecommendationsListView(person: person)
        } label: {
            ScrollView {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(moodGlowColor(person.mood).opacity(0.35))
                            .blur(radius: 26)
                            .frame(width: 180, height: 180)

                        Circle()
                            .fill(moodGlowColor(person.mood).opacity(0.18))
                            .blur(radius: 12)
                            .frame(width: 135, height: 135)

                        Image(avatarImageName(person))
                            .resizable()
                            .scaledToFit()
                            .frame(width: 170, height: 170)
                    }
                    .padding(.top, 8)

                    Text(person.name)
                        .font(.headline)
                        .lineLimit(1)

                    Text(moodLabel(person.mood))
                        .font(.caption)
                        .foregroundColor(.gray)

                    if let activeStage = person.activeStage,
                       !activeStage.isEmpty {
                        Text(activeStage)
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
        }
        .buttonStyle(.plain)
    }
}

struct RecommendationsListView: View {
    let person: WatchPerson

    var body: some View {
        List {
            Section("Помогает") {
                ForEach(parsedActions(person.helpfulActions)) { action in
                    Text("\(action.emoji) \(action.text)")
                }
            }

            Section("Избегать") {
                ForEach(parsedActions(person.avoidActions)) { action in
                    Text("\(action.emoji) \(action.text)")
                }
            }
        }
        .navigationTitle("Советы")
    }
}

struct ParsedAction: Identifiable {
    let id = UUID()
    let emoji: String
    let text: String
}

func parsedActions(_ values: [String]) -> [ParsedAction] {
    values.compactMap { parseAction($0) }
}

func parseAction(_ value: String) -> ParsedAction? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

    if trimmed.isEmpty {
        return nil
    }

    if trimmed.hasPrefix("emoji::") {
        let parts = trimmed.components(separatedBy: "::")

        if parts.count >= 3 {
            return ParsedAction(
                emoji: parts[1],
                text: parts.dropFirst(2).joined(separator: "::")
            )
        }
    }

    return ParsedAction(
        emoji: "•",
        text: trimmed
    )
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

func avatarImageName(_ person: WatchPerson) -> String {
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
