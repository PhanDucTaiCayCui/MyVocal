package com.tai.myvocab

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.tai.myvocab/share"
    private var methodChannel: MethodChannel? = null
    private var initialSharedText: String? = null
    private var initialAction: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent, isInitial = true)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialText" -> {
                        val text = initialSharedText
                        initialSharedText = null
                        result.success(text)
                    }
                    "getInitialAction" -> {
                        val act = initialAction
                        initialAction = null
                        result.success(act)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent, isInitial = false)
    }

    private fun handleIntent(intent: Intent?, isInitial: Boolean) {
        if (intent == null) return
        var sharedText: String? = null

        if (Intent.ACTION_SEND == intent.action && "text/plain" == intent.type) {
            sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
        } else if (Intent.ACTION_PROCESS_TEXT == intent.action && "text/plain" == intent.type) {
            sharedText = intent.getStringExtra(Intent.EXTRA_PROCESS_TEXT)
        } else if ("ACTION_OPEN_REVIEW" == intent.action) {
            if (isInitial || methodChannel == null) {
                initialAction = "ACTION_OPEN_REVIEW"
            } else {
                methodChannel?.invokeMethod("onOpenReview", null)
            }
            return
        }

        if (!sharedText.isNullOrBlank()) {
            if (isInitial || methodChannel == null) {
                initialSharedText = sharedText
            } else {
                methodChannel?.invokeMethod("onSharedText", sharedText)
            }
        }
    }
}
