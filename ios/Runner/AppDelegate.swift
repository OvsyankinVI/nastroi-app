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
    }

    guard let registrar = self.registrar(
      forPlugin: "NastroiWatchSyncPlugin"
    ) else {
      return result
    }

    let channel = FlutterMethodChannel(
      name: "nastroi_watch_sync",
      binaryMessenger: registrar.messenger()
    )

    channel.setMethodCallHandler { [weak self] call, result in
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

      self?.syncPeopleToWatch(jsonString)
      result(nil)
    }

    return result
  }

  func didInitializeImplicitFlutterEngine(
    _ engineBridge: FlutterImplicitEngineBridge
  ) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private func syncPeopleToWatch(_ jsonString: String) {
    pendingPeopleJson = jsonString
    sendPendingPeopleToWatch()
  }

  private func sendPendingPeopleToWatch() {
    guard let jsonString = pendingPeopleJson else { return }
    guard let session = watchSession else { return }
    guard session.activationState == .activated else { return }
    guard session.isWatchAppInstalled else { return }

    do {
      try session.updateApplicationContext([
        "people": jsonString
      ])

      session.transferUserInfo([
        "people": jsonString
      ])
    } catch {
      // Intentionally ignored in release flow.
    }
  }

  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    sendPendingPeopleToWatch()
  }

  func sessionDidBecomeInactive(_ session: WCSession) {}

  func sessionDidDeactivate(_ session: WCSession) {
    WCSession.default.activate()
  }
}
