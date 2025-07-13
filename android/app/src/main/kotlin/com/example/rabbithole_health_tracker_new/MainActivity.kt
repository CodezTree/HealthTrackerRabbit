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
import android.content.Context
import android.os.Build
import android.util.Log
import java.util.*

class MainActivity: FlutterActivity() {
    companion object {
        private const val TAG = "MainActivity"
    }

    private val METHOD_CHANNEL = "com.example.rabbithole_health_tracker_new/health"
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
                            // MAC 주소를 백그라운드 서비스에서 사용할 수 있도록 저장
                            SR08HealthService.setLastKnownMacAddress(macAddress)
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
                        // 주기적 모니터링 제거됨 - 백그라운드 서비스만 사용
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("MONITORING_FAILED", e.message, null)
                    }
                }
                "measureHealthData" -> {
                    try {
                        performMeasureHealthSequence(result)
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
                        // 수신 버튼

                        // MainApplication.manager.cmdGet23() - 혈중산소
                        MainApplication.manager.cmdGet0()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("CURRENT_DATA_FAILED", e.message, null)
                    }
                }
                "requestBackgroundHealthData" -> {
                    try {
                        // 백그라운드에서 사용할 GET10, GET14, GET23 순차 실행
                        performBackgroundDataSequence(result)
                    } catch (e: Exception) {
                        result.error("BACKGROUND_DATA_FAILED", e.message, null)
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
                        performMeasureHealthSequence(result)
                    } catch (e: Exception) {
                        result.error("MEASUREMENT_FAILED", e.message, null)
                    }
                }
                "requestMonitoringData" -> {
                    try {
                        // 회전버튼 
                        MainApplication.manager.cmdGet0();
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
                "setLastKnownMacAddress" -> {
                    try {
                        val macAddress = call.argument<String>("macAddress")
                        if (macAddress != null) {
                            SR08HealthService.setLastKnownMacAddress(macAddress)
                            result.success(true)
                        } else {
                            result.error("MAC_ADDRESS_NULL", "MAC address is null", null)
                        }
                    } catch (e: Exception) {
                        result.error("SET_MAC_FAILED", e.message, null)
                    }
                }
                "testBackgroundDataCollection" -> {
                    try {
                        SR08HealthService.triggerManualDataCollection()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("TEST_BACKGROUND_FAILED", e.message, null)
                    }
                }
                "sendBackgroundHealthData" -> {
                    try {
                        val heartRate = call.argument<Int>("heartRate") ?: 0
                        val spo2 = call.argument<Int>("spo2") ?: 0
                        val stepCount = call.argument<Int>("stepCount") ?: 0
                        val battery = call.argument<Int>("battery") ?: 0
                        val chargingState = call.argument<Int>("chargingState") ?: 0
                        val timestamp = call.argument<String>("timestamp") ?: ""
                        
                        Log.d(TAG, "백그라운드 건강 데이터 전송 요청: HR=$heartRate, SpO2=$spo2, Steps=$stepCount, Battery=$battery")
                        
                        // Flutter의 ApiService.sendHealthData를 호출하기 위해 이벤트로 전송
                        MainApplication.instance.sendBackgroundHealthDataToFlutter(
                            heartRate, spo2, stepCount, battery, chargingState, timestamp
                        )
                        
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SEND_BACKGROUND_DATA_FAILED", e.message, null)
                    }
                }
                "saveBackgroundHealthData" -> {
                    try {
                        val heartRate = call.argument<Int>("heartRate") ?: 0
                        val spo2 = call.argument<Int>("spo2") ?: 0
                        val stepCount = call.argument<Int>("stepCount") ?: 0
                        val battery = call.argument<Int>("battery") ?: 0
                        val chargingState = call.argument<Int>("chargingState") ?: 0
                        val timestamp = call.argument<String>("timestamp") ?: ""
                        
                        Log.d(TAG, "백그라운드 건강 데이터 로컬 저장 요청: HR=$heartRate, SpO2=$spo2, Steps=$stepCount, Battery=$battery%, ChargingState=$chargingState")
                        
                        // Flutter의 LocalDbService를 호출하기 위해 이벤트로 전송
                        MainApplication.instance.saveBackgroundHealthDataToLocal(
                            heartRate, spo2, stepCount, battery, chargingState, timestamp
                        )
                        
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SAVE_BACKGROUND_DATA_FAILED", e.message, null)
                    }
                }
                "getNativeHealthData" -> {
                    try {
                        val limit = call.argument<Int>("limit") ?: 100
                        val healthData = getNativeHealthData(limit)
                        result.success(healthData)
                    } catch (e: Exception) {
                        result.error("GET_NATIVE_DATA_FAILED", e.message, null)
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

    // 주기적 모니터링 함수 제거됨 - 백그라운드 서비스만 사용

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
                Step(action = { manager.cmdSet89(0) }),          // SET89 assumed no response
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

    /**
     * Measures heart rate, SpO2, and steps in strict order.
     * GET77 → wait → GET81 → wait → GET18.
     */
    private fun performMeasureHealthSequence(result: MethodChannel.Result) {
        val manager = MainApplication.manager

        data class Step(val action: () -> Unit, val expectedKey: String)

        val steps = listOf(
            Step(action = { manager.cmdGet77() }, expectedKey = "GET77"),
            Step(action = { manager.cmdGet81() }, expectedKey = "GET81"),
            Step(action = { manager.cmdGet18() }, expectedKey = "GET18"),
        )

        fun execute(index: Int) {
            if (index >= steps.size) {
                result.success(true)
                return
            }

            val step = steps[index]
            MainApplication.instance.waitForCmdResponse(step.expectedKey) {
                execute(index + 1)
            }
            step.action.invoke()
        }

        execute(0)
    }

    /**
     * 백그라운드에서 실행할 건강 데이터 수집 시퀀스
     * GET10 (걸음수) → wait → GET14 (심박수) → wait → GET23 (혈중산소).
     */
    private fun performBackgroundDataSequence(result: MethodChannel.Result) {
        val manager = MainApplication.manager

        data class Step(val action: () -> Unit, val expectedKey: String)

        val steps = listOf(
            Step(action = { manager.cmdGet14() }, expectedKey = "GET14"),
            Step(action = { manager.cmdGet10() }, expectedKey = "GET10"),
            Step(action = { manager.cmdGet23() }, expectedKey = "GET23"),
        )

        fun execute(index: Int) {
            if (index >= steps.size) {
                result.success(true)
                return
            }

            val step = steps[index]
            MainApplication.instance.waitForCmdResponse(step.expectedKey) {
                execute(index + 1)
            }
            step.action.invoke()
        }

        execute(0)
    }
    
    /**
     * 네이티브 SQLite에서 건강 데이터 읽기
     */
    private fun getNativeHealthData(limit: Int): List<Map<String, Any>> {
        val healthData = mutableListOf<Map<String, Any>>()
        
        try {
            val db = this.openOrCreateDatabase("health_tracker.db", Context.MODE_PRIVATE, null)
            
            // 테이블 존재 확인
            val cursor = db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='health_entries'", null)
            val tableExists = cursor.count > 0
            cursor.close()
            
            if (!tableExists) {
                Log.d(TAG, "네이티브 health_entries 테이블이 존재하지 않음")
                db.close()
                return healthData
            }
            
            // 데이터 조회 (최신 순으로 제한)
            val dataCursor = db.rawQuery("""
                SELECT id, heart_rate, spo2, step_count, battery, charging_state, timestamp, created_at
                FROM health_entries 
                ORDER BY created_at DESC 
                LIMIT ?
            """, arrayOf(limit.toString()))
            
            while (dataCursor.moveToNext()) {
                val entry = mapOf(
                    "id" to dataCursor.getInt(0),
                    "heartRate" to dataCursor.getInt(1),
                    "spo2" to dataCursor.getInt(2),
                    "stepCount" to dataCursor.getInt(3),
                    "battery" to dataCursor.getInt(4),
                    "chargingState" to dataCursor.getInt(5),
                    "timestamp" to dataCursor.getString(6),
                    "createdAt" to dataCursor.getString(7)
                )
                healthData.add(entry)
            }
            
            dataCursor.close()
            db.close()
            
            Log.d(TAG, "네이티브 건강 데이터 ${healthData.size}개 조회 완료")
            
        } catch (e: Exception) {
            Log.e(TAG, "네이티브 건강 데이터 조회 실패: ${e.message}")
        }
        
        return healthData
    }

    // (onConnected 콜백은 MainApplication에서 처리합니다)
}