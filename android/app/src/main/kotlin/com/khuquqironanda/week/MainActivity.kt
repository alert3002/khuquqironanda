package com.khuquqironanda.week

import android.app.Activity
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.khuquqironanda.week/screen_security"
    private var methodChannel: MethodChannel? = null
    private var captureCallback: Activity.ScreenCaptureCallback? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Манъи скриншот / сабти экран
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        )
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "enableSecureFlag" -> {
                    window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    registerCaptureCallback()
                    result.success(null)
                }
                "disableSecureFlag" -> {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    unregisterCaptureCallback()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun registerCaptureCallback() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return
        if (captureCallback != null) return
        val callback = Activity.ScreenCaptureCallback {
            methodChannel?.invokeMethod("onScreenCaptureAttempt", null)
        }
        captureCallback = callback
        registerScreenCaptureCallback(mainExecutor, callback)
    }

    private fun unregisterCaptureCallback() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return
        val callback = captureCallback ?: return
        try {
            unregisterScreenCaptureCallback(callback)
        } catch (_: Exception) {
        }
        captureCallback = null
    }

    override fun onDestroy() {
        unregisterCaptureCallback()
        super.onDestroy()
    }
}
