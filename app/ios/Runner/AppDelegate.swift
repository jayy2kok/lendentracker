import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    excludePrivateDocumentsFromBackup()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func excludePrivateDocumentsFromBackup() {
    guard let documents = FileManager.default.urls(
      for: .documentDirectory,
      in: .userDomainMask
    ).first else { return }

    let excluded = URLResourceValues(isExcludedFromBackup: true)
    try? (documents as NSURL).setResourceValues(excluded)
    if let files = try? FileManager.default.contentsOfDirectory(
      at: documents,
      includingPropertiesForKeys: nil
    ) {
      for file in files {
        try? (file as NSURL).setResourceValues(excluded)
      }
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
