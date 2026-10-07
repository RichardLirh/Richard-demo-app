package com.raiot.richard_demo_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.net.Uri

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val preferences = getSharedPreferences("demo_connection", MODE_PRIVATE)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.raiot.richard.demo/settings")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "load" -> result.success(mapOf(
                        "endpoint" to preferences.getString("endpoint", null),
                        "token" to preferences.getString("token", null)
                    ))
                    "save" -> {
                        val endpoint = call.argument<String>("endpoint")
                        val token = call.argument<String>("token")
                        if (endpoint.isNullOrBlank() || token.isNullOrBlank()) {
                            result.error("INVALID_CONFIG", "Endpoint and token are required", null)
                        } else {
                            preferences.edit().putString("endpoint", endpoint).putString("token", token).apply()
                            result.success(null)
                        }
                    }
                    "openUrl" -> {
                        val uri = Uri.parse(call.argument<String>("url") ?: "")
                        if (uri.scheme !in listOf("http", "https") || uri.host.isNullOrBlank()) {
                            result.error("INVALID_URL", "Only HTTP session URLs are supported", null)
                        } else {
                            try {
                                startActivity(Intent(Intent.ACTION_VIEW, uri))
                                result.success(null)
                            } catch (_: android.content.ActivityNotFoundException) {
                                result.error("NO_BROWSER", "No browser is available", null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
