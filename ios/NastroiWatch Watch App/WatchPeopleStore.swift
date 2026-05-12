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

    override init() {
        super.init()
        loadCachedPeople()
        activateSession()
    }

    private func loadCachedPeople() {
        guard let jsonString = UserDefaults.standard.string(forKey: "watch_people") else {
            return
        }

        updatePeople(from: jsonString, shouldSave: false)
    }

    private func activateSession() {
        guard WCSession.isSupported() else {
            print("WCSession not supported")
            return
        }

        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

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

    func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String : Any] = [:]
    ) {
        print("Received user info")

        guard let peopleJson = userInfo["people"] as? String else {
            print("No people json found in userInfo")
            return
        }

        updatePeople(from: peopleJson)
    }

    private func updatePeople(from jsonString: String, shouldSave: Bool = true) {
        if shouldSave {
            UserDefaults.standard.set(jsonString, forKey: "watch_people")
        }

        guard let data = jsonString.data(using: .utf8) else {
            print("Failed to convert json string to data")
            return
        }

        do {
            let decoded = try JSONDecoder().decode([WatchPerson].self, from: data)

            DispatchQueue.main.async {
                self.people = decoded
                print("Updated people on watch: \(decoded.count)")
            }
        } catch {
            print("JSON decode error: \(error)")
        }
    }

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
