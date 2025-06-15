package com.example.rabbithole_health_tracker_new

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
import android.util.Log
import java.util.*

class MainActivity: FlutterActivity() {
    companion object {
        private const val TAG = "MainActivity"
    }

    private val METHOD_CHANNEL = "com.example.sr08_sdk/methods"
    private val EVENT_CHANNEL = "com.example.sr08_sdk/events"
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private lateinit var timer: Timer

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
                        startHealthMonitoring()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("MONITORING_FAILED", e.message, null)
                    }
                }
                "measureHealthData" -> {
                    try {
                        MainApplication.manager.cmdGet77()
                        mainHandler.postDelayed({
                            MainApplication.manager.cmdGet81()
                            mainHandler.postDelayed({
                                MainApplication.manager.cmdGet18()
                            }, 1000)
                        }, 1000)
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
                "enableAutoMonitoring" -> {
                    val on = call.argument<Int>("state") ?: 1
                    try {
                        MainApplication.manager.cmdSet89(on)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ENABLE_AUTO_FAILED", e.message, null)
                    }
                }
                "requestCurrentData" -> {
                    try {
                        MainApplication.manager.cmdGet17()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("CURRENT_DATA_FAILED", e.message, null)
                    }
                }
                "requestBatteryStatus" -> {
                    try {
                        MainApplication.manager.cmdGet88()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("BATTERY_DATA_FAILED", e.message, null)
                    }
                }
                "requestHalfHourHeartData" -> {
                    val ts = (call.argument<Number>("timestamp")?.toLong()) ?: run {
                        // default: today 00:00:00
                        val cal = java.util.Calendar.getInstance()
                        cal.set(java.util.Calendar.HOUR_OF_DAY, 0)
                        cal.set(java.util.Calendar.MINUTE, 0)
                        cal.set(java.util.Calendar.SECOND, 0)
                        cal.set(java.util.Calendar.MILLISECOND, 0)
                        cal.timeInMillis / 1000
                    }
                    try {
                        MainApplication.manager.cmdGet80(ts)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("GET80_FAILED", e.message, null)
                    }
                }
                "initialSetup" -> {
                    try {
                        MainApplication.manager.cmdGet66()
                        mainHandler.postDelayed({
                            MainApplication.manager.cmdSet15(1)
                            mainHandler.postDelayed({
                                MainApplication.manager.cmdSet46(0)
                                mainHandler.postDelayed({
                                    MainApplication.manager.cmdSet45(this@MainActivity)
                                    mainHandler.postDelayed({
                                        MainApplication.manager.cmdGet0()
                                        mainHandler.postDelayed({
                                            MainApplication.manager.cmdSet89(1)
                                        }, 500)
                                    }, 500)
                                }, 500)
                            }, 500)
                        }, 500)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INIT_SETUP_FAILED", e.message, null)
                    }
                }
                "instantHealthMeasurement" -> {
                    try {
                        MainApplication.manager.cmdGet77()
                        mainHandler.postDelayed({
                            MainApplication.manager.cmdGet81()
                            mainHandler.postDelayed({
                                MainApplication.manager.cmdGet18()
                            }, 1000)
                        }, 1000)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTANT_MEASURE_FAILED", e.message, null)
                    }
                }
                "requestMonitoringData" -> {
                    try {
                        MainApplication.manager.cmdGet87()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("GET87_FAILED", e.message, null)
                    }
                }
                "resetDeviceData" -> {
                    try {
                        // MainApplication.manager.cmdSet90()
                        MainApplication.manager.cmdGet66()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SET90_FAILED", e.message, null)
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

    private fun startHealthMonitoring() {
        timer = Timer().apply {
            schedule(object : TimerTask() {
                override fun run() {
                    if (MainApplication.instance.isConnectedState()) {
                        try {
                            // 순차(지연) 호출 – 3초 간격 예
                            MainApplication.manager.cmdGet77()
                            mainHandler.postDelayed({
                                MainApplication.manager.cmdGet81()
                                mainHandler.postDelayed({
                                    MainApplication.manager.cmdGet18()
                                }, 1000)
                            }, 1000)
                        } catch (e: Exception) {
                            Log.e(TAG, "Error during health monitoring: ${e.message}")
                        }
                    }
                }
            }, 0, 30 * 60 * 1000)   // 30 분마다 반복
        }
    }

    // (onConnected 콜백은 MainApplication에서 처리합니다)
}