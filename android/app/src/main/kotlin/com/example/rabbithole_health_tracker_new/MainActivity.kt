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
                        MainApplication.manager.cmdGet10()
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
                        performInitialSetupSequence(result)
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

    /**
     * Executes the initial setup commands in strict sequence.
     * Each subsequent command is sent only after the previous one's response is received.
     */
    private fun performInitialSetupSequence(result: MethodChannel.Result) {
        // Helper that contains the original sequential logic.
        fun startSequence() {
            val manager = MainApplication.manager

            data class Step(val action: () -> Unit, val expectedKey: String? = null)

            val steps = listOf(
                Step(action = { manager.cmdGet66() }, expectedKey = "GET66"),
                Step(action = { manager.cmdSet15(1) }),          // SET15 assumed no explicit response
                Step(action = { manager.cmdSet46(0) }),          // SET46 assumed no response
                Step(action = { manager.cmdSet45(this) }),       // SET45 assumed no response
                Step(action = { manager.cmdGet0() }, expectedKey = "GET0"),
                Step(action = { manager.cmdSet89(1) }),          // SET89 assumed no response
            )

            fun executeStep(index: Int) {
                if (index >= steps.size) {
                    result.success(true)
                    return
                }

                val step = steps[index]

                if (step.expectedKey != null) {
                    // Wait until the specified response arrives, then move on
                    MainApplication.instance.waitForCmdResponse(step.expectedKey) {
                        executeStep(index + 1)
                    }
                    step.action.invoke()
                } else {
                    // No response expected – send command and immediately continue (slight delay for safety)
                    step.action.invoke()
                    mainHandler.postDelayed({ executeStep(index + 1) }, 400)
                }
            }

            executeStep(0)
        }

        // If already connected, run the sequence immediately. Otherwise, wait (up to 10s).
        if (MainApplication.instance.isConnectedState()) {
            startSequence()
            return
        }

        val startTime = System.currentTimeMillis()
        val timeoutMs = 10_000L
        val checkIntervalMs = 200L

        fun waitForConnection() {
            if (MainApplication.instance.isConnectedState()) {
                startSequence()
            } else if (System.currentTimeMillis() - startTime >= timeoutMs) {
                result.error("INIT_SETUP_FAILED", "Timeout waiting for device to connect", null)
            } else {
                mainHandler.postDelayed({ waitForConnection() }, checkIntervalMs)
            }
        }

        waitForConnection()
    }

    // (onConnected 콜백은 MainApplication에서 처리합니다)
}