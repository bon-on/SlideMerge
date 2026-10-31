import Flutter
import AVFoundation
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var players: [AVAudioPlayer] = []

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    configureAudioChannel(pluginRegistry: engineBridge.pluginRegistry)
  }

  private func configureAudioChannel(pluginRegistry: FlutterPluginRegistry) {
    guard let registrar = pluginRegistry.registrar(forPlugin: "SlideMergeAudio") else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "slide_merge/audio",
      binaryMessenger: registrar.messenger()
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }

      switch call.method {
      case "play":
        let args = call.arguments as? [String: Any]
        if let asset = args?["asset"] as? String {
          let volume = (args?["volume"] as? Double).map { Float($0) } ?? 0.7
          self.playSound(asset: asset, volume: volume)
        }
        result(nil)
      case "disposeAudio":
        self.disposeAudio()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func configureAudioSession() {
    do {
      // Ambient respects the silent switch and keeps the user's music playing.
      try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
    }
  }

  private func playSound(asset: String, volume: Float) {
    configureAudioSession()
    guard let url = assetURL(for: asset) else {
      return
    }

    // Finished players are dropped so overlapping effects do not pile up.
    players.removeAll { !$0.isPlaying }
    do {
      let player = try AVAudioPlayer(contentsOf: url)
      player.volume = volume
      player.prepareToPlay()
      player.play()
      players.append(player)
    } catch {
    }
  }

  private func disposeAudio() {
    players.forEach { $0.stop() }
    players.removeAll()
  }

  private func assetURL(for asset: String) -> URL? {
    let assetKey = FlutterDartProject.lookupKey(forAsset: asset)
    let appFrameworkURL = Bundle.main.bundleURL
      .appendingPathComponent("Frameworks/App.framework/flutter_assets", isDirectory: true)
      .appendingPathComponent(assetKey)

    if FileManager.default.fileExists(atPath: appFrameworkURL.path) {
      return appFrameworkURL
    }

    return Bundle.main.resourceURL?.appendingPathComponent(assetKey)
  }
}
