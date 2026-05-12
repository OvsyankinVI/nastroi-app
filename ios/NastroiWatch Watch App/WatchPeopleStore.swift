import Foundation
import WatchConnectivity
import WidgetKit

private let appGroupId = "group.com.vlad.nastroi"
private let peopleStorageKey = "watch_people"

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
        loadSavedPeople()
        activateSession()
    }

    private func loadSavedPeople() {
        let groupDefaults = UserDefaults(suiteName: appGroupId)

        let jsonString =
            groupDefaults?.string(forKey: peopleStorageKey)
            ?? UserDefaults.standard.string(forKey: peopleStorageKey)

        guard let jsonString else {
            print("No saved people found")
            return
        }

        updatePeople(from: jsonString)
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
            print("No people json found in application context")
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

    private func updatePeople(from jsonString: String) {
        guard let data = jsonString.data(using: .utf8) else {
            print("Failed converting json to data")
            return
        }

        do {
            let decoded = try JSONDecoder().decode([WatchPerson].self, from: data)

            let groupDefaults = UserDefaults(suiteName: appGroupId)
            groupDefaults?.set(jsonString, forKey: peopleStorageKey)
            groupDefaults?.synchronize()

            UserDefaults.standard.set(jsonString, forKey: peopleStorageKey)
            UserDefaults.standard.synchronize()

            DispatchQueue.main.async {
                self.people = decoded
                print("Updated people on watch: \(decoded.count)")
                WidgetCenter.shared.reloadAllTimelines()
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
