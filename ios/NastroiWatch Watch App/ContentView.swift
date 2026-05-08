import SwiftUI

struct ContentView: View {
    @EnvironmentObject var watchStore: WatchPeopleStore

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
                        VStack(alignment: .leading) {
                            Text(person.name)
                                .font(.headline)

                            Text(person.activeStage ?? moodLabel(person.mood))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .navigationTitle("Настрой")
            }
        }
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

                    if let activeStage = person.activeStage, !activeStage.isEmpty {
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

struct RecommendationChip: View {
    let action: ParsedAction
    let isPositive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 1) {
                Text(action.emoji)
                    .font(.system(size: 18))

                Text(action.text)
                    .font(.system(size: 9))
                    .lineLimit(1)
            }
            .frame(width: 58, height: 38)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isPositive ? Color.yellow.opacity(0.18) : Color.red.opacity(0.18))
        )
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

func randomAction(from values: [String]) -> ParsedAction? {
    parsedActions(values).randomElement()
}

func parsedActions(_ values: [String]) -> [ParsedAction] {
    values.compactMap { parseAction($0) }
}

func parseAction(_ value: String) -> ParsedAction? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return nil }

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

func moodEmoji(_ mood: String) -> String {
    switch mood {
    case "happy": return "🙂"
    case "calm": return "😌"
    case "sad": return "😔"
    case "irritated": return "😠"
    case "tired": return "🥱"
    case "needsCare": return "🥺"
    default: return "🙂"
    }
}

func avatarImageName(_ person: WatchPerson) -> String {
    let moodKey: String

    switch person.mood {
    case "happy":
        moodKey = "happy"
    case "calm":
        moodKey = "calm"
    case "irritated":
        moodKey = "irritated"
    case "sad":
        moodKey = "sad"
    case "tired":
        moodKey = "tired"
    case "needsCare":
        moodKey = "needs_care"
    default:
        moodKey = "calm"
    }

    return "\(person.gender)_\(person.avatarVariant)_\(moodKey)"
}

func moodGlowColor(_ mood: String) -> Color {
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
