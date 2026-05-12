import Flutter
import UIKit
import WatchConnectivity

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, WCSessionDelegate {
  private var watchSession: WCSession?
  private var pendingPeopleJson: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let result = super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )

    if WCSession.isSupported() {
      let session = WCSession.default
      session.delegate = self
      session.activate()
      watchSession = session
      print("Watch session activation requested")
    }

      guard let registrar = self.registrar(
        forPlugin: "NastroiWatchSyncPlugin"
      ) else {
        print("Flutter registrar not found")
        return result
      }

      let channel = FlutterMethodChannel(
        name: "nastroi_watch_sync",
        binaryMessenger: registrar.messenger()
      )

      channel.setMethodCallHandler { [weak self] (
        call: FlutterMethodCall,
        result: @escaping FlutterResult
      ) in
      print("Flutter channel call: \(call.method)")

      guard call.method == "syncPeople" else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard let jsonString = call.arguments as? String else {
        result(
          FlutterError(
            code: "BAD_ARGS",
            message: "Expected JSON string",
            details: nil
          )
        )
        return
      }

      print("Received people json from Flutter")
      self?.syncPeopleToWatch(jsonString)
      result(nil)
    }

    print("Watch sync channel registered successfully")

    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

    private func syncPeopleToWatch(_ jsonString: String) {
      pendingPeopleJson = jsonString
      UserDefaults.standard.set(jsonString, forKey: "watch_people")

      print("Sync people requested. Count chars: \(jsonString.count)")

      sendPendingPeopleToWatch()
    }

    private func sendPendingPeopleToWatch() {
      guard let jsonString = pendingPeopleJson else {
    print("No pending people json")
    return
    }



    guard let session = watchSession else {
    print("No watch session")
    return
    }



    print("Watch session state: (session.activationState.rawValue)")
    print("Watch is paired: (session.isPaired)")
    print("Watch app installed: (session.isWatchAppInstalled)")
    print("Watch reachable: (session.isReachable)")



    guard session.activationState == .activated else {
    print("Watch session is not activated yet")
    return
    }



    do {
    try session.updateApplicationContext([
    "people": jsonString])



    session.transferUserInfo([
    "people": jsonString])



    print("Watch sync sent")
    } catch {
    print("Watch sync error: (error)")
    }
    }
    


  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    print("Watch session activated: \(activationState.rawValue), error: \(String(describing: error))")
    sendPendingPeopleToWatch()
  }

  func sessionDidBecomeInactive(_ session: WCSession) {}

  func sessionDidDeactivate(_ session: WCSession) {
    WCSession.default.activate()
  }
}
