import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Registered after the generated registrant, because it resolves web views
    // out of the webview_flutter plugin's instance manager and that plugin has
    // to exist first.
    TrackerBlocking.register(
      with: engineBridge.pluginRegistry,
      messenger: engineBridge.applicationRegistrar.messenger()
    )
  }
}
