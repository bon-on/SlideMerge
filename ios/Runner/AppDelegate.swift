import Flutter
import AVFoundation
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var players: [AVAudioPlayer] = []
  private var musicPlayer: AVAudioPlayer?
  // True while the music loop should be audible (startLoop until stopLoop),
  // so it can resume after a call or Siri interrupted the audio session.
  private var musicWanted = false
  private var interruptionObserver: NSObjectProtocol?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    interruptionObserver = NotificationCenter.default.addObserver(
      forName: AVAudioSession.interruptionNotification,
      object: AVAudioSession.sharedInstance(),
      queue: .main
    ) { [weak self] notification in
      self?.handleInterruption(notification)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func handleInterruption(_ notification: Notification) {
    guard
      let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
      let type = AVAudioSession.InterruptionType(rawValue: raw)
    else {
      return
    }
    if type == .ended, musicWanted, let player = musicPlayer, !player.isPlaying {
      configureAudioSession()
      player.play()
    }
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
      case "startLoop":
        let args = call.arguments as? [String: Any]
        if let asset = args?["asset"] as? String {
          let volume = (args?["volume"] as? Double).map { Float($0) } ?? 0.4
          self.startLoop(asset: asset, volume: volume)
        }
        result(nil)
      case "stopLoop":
        self.stopLoop()
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

  private func startLoop(asset: String, volume: Float) {
    stopLoop()
    configureAudioSession()
    guard let url = assetURL(for: asset) else {
      return
    }

    do {
      let player = try AVAudioPlayer(contentsOf: url)
      player.numberOfLoops = -1
      player.volume = volume
      player.prepareToPlay()
      player.play()
      musicPlayer = player
      musicWanted = true
    } catch {
    }
  }

  private func stopLoop() {
    musicWanted = false
    musicPlayer?.stop()
    musicPlayer = nil
  }

  private func disposeAudio() {
    stopLoop()
    players.forEach { $0.stop() }
    players.removeAll()
  }

  private func assetURL(for asset: String) -> URL? {
    let assetKey = FlutterDartProject.lookupKey(forAsset: asset)
    // The lookup key is already relative to the app bundle
    // (Frameworks/App.framework/flutter_assets/...).
    let url = Bundle.main.bundleURL.appendingPathComponent(assetKey)
    return FileManager.default.fileExists(atPath: url.path) ? url : nil
  }
}
