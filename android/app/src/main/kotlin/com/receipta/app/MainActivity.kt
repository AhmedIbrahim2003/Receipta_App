package com.receipta.app

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val METHOD_CHANNEL = "receipta/hce"
        private const val EVENT_CHANNEL = "receipta/hce/events"
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHOD_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startHce" -> {
                    // `code` is the backend-issued claim token from
                    // POST /api/claims - not generated on-device.
                    val code = call.argument<String>("code")
                    if (code.isNullOrEmpty()) {
                        result.error(
                            "INVALID_ARGS",
                            "startHce requires a non-empty code",
                            null
                        )
                    } else {
                        ReceiptHostApduService.setActiveClaimCode(code)
                        result.success(null)
                    }
                }
                "stopHce" -> {
                    ReceiptHostApduService.setActiveClaimCode(null)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EVENT_CHANNEL
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                // processCommandApdu runs on a binder thread; hop to main
                // before touching the Flutter EventSink.
                ReceiptHostApduService.onTapSuccess = { code ->
                    mainHandler.post {
                        events.success(
                            mapOf(
                                "event" to "tapSuccess",
                                "code" to code
                            )
                        )
                    }
                }
            }

            override fun onCancel(arguments: Any?) {
                ReceiptHostApduService.onTapSuccess = null
            }
        })
    }
}
