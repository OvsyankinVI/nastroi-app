
import Foundation
import WatchConnectivity

struct WatchPerson: Identifiable, Codable {
    let id: String
    let name: String
    let mood: String
    let gender: String
    let avatarVariant: Int
    let activeStage: String?
    let helpfulActions: [String]
    let avoidActions: [String]
}

final class WatchPeopleStore: NSObject, ObservableObject, WCSessionDelegate {

    @Published var people: [WatchPerson] = []

    // MARK: - Mock data для симулятора / быстрых UI тестов
    #if DEBUG
    private let mockPeople: [WatchPerson] = [
        WatchPerson(
            id: "1",
            name: "Аня",
            mood: "happy",
            gender: "female",
            avatarVariant: 0,
            activeStage: "Хочет общения",
            helpfulActions: [
                "Обнять",
                "Спросить как дела",
                "Провести время вместе"
            ],
            avoidActions: [
                "Игнорировать",
                "Критиковать"
            ]
        ),

        WatchPerson(
            id: "2",
            name: "Макс",
            mood: "tired",
            gender: "male",
            avatarVariant: 1,
            activeStage: "Устал после работы",
            helpfulActions: [
                "Дать отдохнуть",
                "Сделать чай"
            ],
            avoidActions: [
                "Грузить задачами"
            ]
        ),

        WatchPerson(
            id: "3",
            name: "Лиза",
            mood: "sad",
            gender: "female",
            avatarVariant: 2,
            activeStage: "Нуждается в поддержке",
            helpfulActions: [
                "Выслушать",
                "Поддержать"
            ],
            avoidActions: [
                "Обесценивать чувства"
            ]
        )
    ]
    #endif

    override init() {
        super.init()

        #if DEBUG
        // Для симулятора сразу показываем UI
        self.people = mockPeople
        #endif

        activateSession()
    }

    // MARK: - Session setup
    private func activateSession() {
        guard WCSession.isSupported() else {
            print("WCSession not supported")
            return
        }

        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - Receive data from iPhone
    func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String : Any]
    ) {
        print("Received application context")

        guard let peopleJson = applicationContext["people"] as? String else {
            print("No people json found")
            return
        }

        updatePeople(from: peopleJson)
    }

    private func updatePeople(from jsonString: String) {
        guard let data = jsonString.data(using: .utf8) else {
            print("Failed to convert json string to data")
            return
        }

        do {
            let decoded = try JSONDecoder().decode(
                [WatchPerson].self,
                from: data
            )

            DispatchQueue.main.async {
                self.people = decoded
                print("Updated people on watch: \(decoded.count)")
            }

        } catch {
            print("JSON decode error: \(error)")
        }
    }

    // MARK: - Required WCSessionDelegate methods

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error = error {
            print("Watch session activation error: \(error.localizedDescription)")
        } else {
            print("Watch session activated")
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        print("Reachability changed: \(session.isReachable)")
    }
}
