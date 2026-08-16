package app.shadow.mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Registered after super, so the webview_flutter plugin is already
        // attached to the engine — the bridge looks the WebView up through
        // that plugin's own external API and would find nothing before it.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            TrackerBlockingBridge.CHANNEL,
        ).setMethodCallHandler(TrackerBlockingBridge(flutterEngine))
    }
}
