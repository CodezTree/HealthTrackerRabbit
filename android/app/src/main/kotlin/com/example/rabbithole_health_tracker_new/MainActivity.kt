package com.example.rabbithole_health_tracker

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import android.os.Handler
import android.os.Looper
import com.smtlink.transferprotocolsdk.Protocols
import com.smtlink.transferprotocolsdk.ble.BTMGattCallBack
import com.smtlink.transferprotocolsdk.ble.AnalyticalDataCallBack
import org.json.JSONObject
import android.content.Intent
import android.os.Build

class MainActivity: FlutterActivity() {
    private val METHOD_CHANNEL = "com.example.sr08_sdk/methods"
    private val EVENT_CHANNEL = "com.example.sr08_sdk/events"
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Method Channel 설정
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "connectDevice" -> {
                    val macAddress = call.argument<String>("macAddress")
                    if (macAddress != null) {
                        try {
                            MainApplication.manager.connectGatt(macAddress, false)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("CONNECTION_FAILED", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "MAC address is required", null)
                    }
                }
                "disconnectDevice" -> {
                    val macAddress = call.argument<String>("macAddress")
                    if (macAddress != null) {
                        try {
                            MainApplication.manager.disconnectGatt(macAddress, false)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("DISCONNECT_FAILED", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "MAC address is required", null)
                    }
                }
                "startHealthMonitoring" -> {
                    try {
                        // 심박수 측정 시작
                        MainApplication.manager.cmdGet77()
                        // 혈중산소 측정 시작
                        MainApplication.manager.cmdGet81()
                        // 현재 걸음수 요청
                        MainApplication.manager.cmdGet17()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("MONITORING_FAILED", e.message, null)
                    }
                }
                "measureHealthData" -> {
                    try {
                        // 심박수 측정 시작
                        MainApplication.manager.cmdGet77()
                        // 혈중산소 측정 시작
                        MainApplication.manager.cmdGet81()
                        // 현재 걸음수 요청
                        MainApplication.manager.cmdGet17()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("MEASUREMENT_FAILED", e.message, null)
                    }
                }
                "startBackgroundService" -> {
                    try {
                        if (!SR08HealthService.isRunning) {
                            val serviceIntent = Intent(this, SR08HealthService::class.java)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(serviceIntent)
                            } else {
                                startService(serviceIntent)
                            }
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        result.error("SERVICE_START_FAILED", e.message, null)
                    }
                }
                "stopBackgroundService" -> {
                    try {
                        if (SR08HealthService.isRunning) {
                            stopService(Intent(this, SR08HealthService::class.java))
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        result.error("SERVICE_STOP_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Event Channel 설정
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    eventSink = events
                    MainApplication.instance.setEventSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    MainApplication.instance.setEventSink(null)
                }
            }
        )
    }

    private fun sendHealthData(type: String, value: Int) {
        mainHandler.post {
            eventSink?.success(mapOf(
                "type" to type,
                "value" to value
            ))
        }
    }
}