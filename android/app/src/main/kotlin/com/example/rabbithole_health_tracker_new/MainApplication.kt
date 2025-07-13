package com.example.rabbithole_health_tracker_new

import android.app.Application
import com.smtlink.transferprotocolsdk.ble.BleTransferManager
import com.smtlink.transferprotocolsdk.ble.BTMGattCallBack
import com.smtlink.transferprotocolsdk.ble.AnalyticalDataCallBack
import android.bluetooth.BluetoothGatt
import org.json.JSONObject
import io.flutter.plugin.common.EventChannel
import android.os.Handler
import android.os.Looper
import android.util.Log
import java.util.*

class MainApplication : Application(), BTMGattCallBack, AnalyticalDataCallBack {
    companion object {
        lateinit var instance: MainApplication
        lateinit var manager: BleTransferManager
        private const val TAG = "MainApplication"
    }

    private var connectedState = false
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    // Queue-based waiting mechanism for sequential command flows.
    private data class WaitRequest(val key: String, val onComplete: () -> Unit)
    private val waitQueue: ArrayDeque<WaitRequest> = ArrayDeque()

    override fun onCreate() {
        super.onCreate()
        instance = this
        manager = BleTransferManager.initialized(this)
        manager.setBTMGattCallBack(this)
        manager.setAnalyticalDataCallBack(this)
    }

    fun isConnectedState(): Boolean {
        return connectedState
    }

    fun setConnectedState(state: Boolean) {
        connectedState = state
    }

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }
    
    fun hasEventSink(): Boolean {
        return eventSink != null
    }

    /**
     * Register a command response to wait for. Multiple requests are queued and
     * will be resolved in FIFO order, so 다른 패킷(SEND10 등)이 들어와도 순차 흐름이 유지됩니다.
     */
    fun waitForCmdResponse(expectedKey: String, onComplete: () -> Unit) {
        val norm = expectedKey.replace(",", "").uppercase(Locale.getDefault())
        waitQueue.add(WaitRequest(norm, onComplete))
    }

    // BTMGattCallBack 구현
    override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
        Log.d(TAG, "Connection state changed: status=$status, newState=$newState")
        sendConnectionState(newState)
    }

    override fun onConnected() {
        Log.d(TAG, "Device connected")
        connectedState = true
        sendConnectionState(2) // 2 = Connected
    }

    override fun onDisConnect() {
        Log.d(TAG, "Device disconnected")
        connectedState = false
        sendConnectionState(0) // 0 = Disconnected
    }

    // AnalyticalDataCallBack 구현
    override fun jsonObjectData(cmdKey: String, jsonObject: JSONObject) {
        Log.d(TAG, "Received data: cmdKey=$cmdKey, data=$jsonObject")
        
        // SR08HealthService로 데이터 전달 (백그라운드 데이터 수집용)
        try {
            SR08HealthService.onDataReceived(cmdKey, jsonObject)
        } catch (e: Exception) {
            Log.e(TAG, "SR08HealthService로 데이터 전달 중 오류: ${e.message}")
        }
        
        // If we are waiting for a sequence of expected responses, process queue head only.
        if (waitQueue.isNotEmpty()) {
            val head = waitQueue.peek()
            val normalizedKeyIncoming = cmdKey.replace(",", "").uppercase(Locale.getDefault())
            if (normalizedKeyIncoming == head.key) {
                waitQueue.remove()
                mainHandler.post { head.onComplete() }
            }
        }

        try {
            // 일부 펌웨어는 "GET,77" 형태로 콤마가 포함돼 전달되므로, 통일된 비교를 위해 제거
            val normalizedKey = cmdKey.replace(",", "")

            when (normalizedKey) {
                "GET10" -> { // 걸음수 데이터 (배열 형태)
                    val arr = jsonObject.optJSONArray("array")
                    if (arr != null && arr.length() > 0) {
                        // 가장 최신 데이터 (마지막 항목) 추출
                        val latestEntry = arr.getJSONObject(arr.length() - 1)
                        val steps = latestEntry.optString("step", "0").toIntOrNull() ?: 0
                        val date = latestEntry.optString("date", "")
                        
                        Log.d(TAG, "GET10 - 최신 걸음수: $steps (날짜: $date)")
                        sendHealthData("steps", steps)
                        
                        // 백그라운드 저장을 위한 데이터 전송
                        sendBackgroundData("steps", steps, date)
                    } else {
                        Log.w(TAG, "GET10 응답에서 걸음수 배열을 찾지 못했습니다: $jsonObject")
                    }
                }
                "GET14" -> { // 심박수 데이터 (배열 형태)
                    val arr = jsonObject.optJSONArray("array")
                    if (arr != null && arr.length() > 0) {
                        // 가장 최신 데이터 (마지막 항목) 추출
                        val latestEntry = arr.getJSONObject(arr.length() - 1)
                        val heartRate = latestEntry.optString("heart_rate", "0").toIntOrNull() ?: 0
                        val date = latestEntry.optString("date", "")
                        val time = latestEntry.optString("time", "")
                        
                        Log.d(TAG, "GET14 - 최신 심박수: $heartRate (날짜: $date, 시간: $time)")
                        sendHealthData("heart", heartRate)
                        
                        // 백그라운드 저장을 위한 데이터 전송
                        sendBackgroundData("heart", heartRate, "$date $time")
                    } else {
                        Log.w(TAG, "GET14 응답에서 심박수 배열을 찾지 못했습니다: $jsonObject")
                    }
                }
                "GET23" -> { // 혈중산소농도 데이터 (단일 객체)
                    val spo2 = jsonObject.optString("BOxygen", "0").toIntOrNull() ?: 0
                    val date = jsonObject.optString("date", "")
                    val time = jsonObject.optString("time", "")
                    
                    Log.d(TAG, "GET23 - 혈중산소: $spo2 (날짜: $date, 시간: $time)")
                    sendHealthData("oxygen", spo2)
                    
                    // 백그라운드 저장을 위한 데이터 전송
                    sendBackgroundData("oxygen", spo2, "$date $time")
                }
                "GET77" -> { // 심박수 (GET77 or GET,77) - "시간|값" 형태 포함 처리
                    val heartRate: Int = when {
                        jsonObject.has("heart_rate") -> jsonObject.optInt("heart_rate", -1)
                        jsonObject.has("measure_heart_rate") -> {
                            val raw = jsonObject.optString("measure_heart_rate")
                            // "HH:mm:ss|72" 형식 또는 그냥 숫자
                            val parsed = raw.split("|").getOrNull(1)?.toIntOrNull() ?: raw.toIntOrNull()
                            parsed ?: -1
                        }
                        else -> -1
                    }
                    if (heartRate >= 0) {
                        sendHealthData("heart", heartRate)
                    } else {
                        Log.w(TAG, "GET77 응답에서 심박수를 찾지 못했습니다: $jsonObject")
                    }
                }
                "GET81" -> { // 혈중산소 (GET81 or GET,81)
                    val bloodOxygenString: String? = when {
                        jsonObject.has("spo2") -> jsonObject.optString("spo2")
                        jsonObject.has("measure_blood_oxygen") -> jsonObject.optString("measure_blood_oxygen")
                        else -> "|"
                    }

                    val bloodOxygen = bloodOxygenString?.split("|")?.getOrNull(1)?.toIntOrNull() ?: -1
                    if (bloodOxygen != null && bloodOxygen >= 0) {
                        sendHealthData("oxygen", bloodOxygen)
                    } else {
                        Log.w(TAG, "GET81 응답에서 SpO2 값을 찾지 못했습니다: $jsonObject")
                    }
                }
                "GET17", "GET18" -> { // 걸음수 (펌웨어 버전에 따라 GET17/GET18 또는 GET,17/GET,18)
                    val steps: Int? = if (jsonObject.has("step_count")) {
                        jsonObject.optInt("step_count", -1)
                    } else {
                        null
                    }

                    if (steps != null && steps >= 0) {
                        sendHealthData("steps", steps)
                    } else {
                        Log.w(TAG, "$cmdKey 응답에서 걸음수를 찾지 못했습니다: $jsonObject")
                    }
                }
                "GET87" -> { // 종합 건강 모니터링 (배열)
                    val arr = jsonObject.optJSONArray("array")
                    if (arr != null) {
                        for (i in 0 until arr.length()) {
                            val item = arr.getJSONObject(i)
                                                // Flutter 로 그대로 전달 (문자열)
                    mainHandler.post {
                        try {
                            if (eventSink != null) {
                                eventSink?.success(mapOf(
                                    "type" to "health87",
                                    "entry" to item.toString()
                                ))
                            } else {
                                Log.w(TAG, "Flutter 이벤트 채널이 연결되지 않음 - health87 데이터 전송 실패")
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Flutter로 health87 데이터 전송 중 오류: ${e.message}")
                        }
                    }
                        }
                    } else {
                        Log.w(TAG, "GET87 배열이 비어있습니다: $jsonObject")
                    }
                }
                "GET0" -> { // 디바이스 정보 (battery_capacity 포함)
                    Log.d(TAG, "GET0 - 디바이스 정보 수신: $jsonObject")
                    
                    // 전체 데이터를 Flutter로 전송 (battery_capacity 추출을 위해)
                    mainHandler.post {
                        try {
                            if (eventSink != null) {
                                eventSink?.success(mapOf(
                                    "type" to "device_info",
                                    "data" to jsonObject.toString()
                                ))
                            } else {
                                Log.w(TAG, "Flutter 이벤트 채널이 연결되지 않음 - 디바이스 정보 전송 실패")
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Flutter로 디바이스 정보 전송 중 오류: ${e.message}")
                        }
                    }
                    
                    // 배터리 정보를 백그라운드 데이터로도 전송
                    val batteryCapacity = jsonObject.optString("battery_capacity", "-1").toIntOrNull()
                    if (batteryCapacity != null && batteryCapacity >= 0) {
                        val currentTime = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss", java.util.Locale.getDefault()).format(java.util.Date())
                        sendBackgroundData("battery", batteryCapacity, currentTime)
                        Log.d(TAG, "GET0 - 배터리 정보를 백그라운드 데이터로 전송: $batteryCapacity%")
                    }
                }
                "SEND24" -> { // 배터리 상태
                    Log.d(TAG, "Got Battery State (SEND24): $jsonObject")

                    // 몇몇 펌웨어는 battery, 일부는 battery_capacity 라는 문자열 필드를 사용함
                    val battery: Int = when {
                        jsonObject.has("battery") -> jsonObject.optInt("battery", -1)
                        jsonObject.has("battery_capacity") -> jsonObject.optString("battery_capacity", "-1").toIntOrNull() ?: -1
                        else -> -1
                    }

                    if (battery >= 0) sendHealthData("battery", battery)
                }
                "SEND23" -> { // 실시간 단일 SpO2
                    val spo2Str = jsonObject.optString("single_blood_oxygen", "-1")
                    val spo2 = spo2Str.toIntOrNull() ?: -1
                    if (spo2 >= 0) {
                        Log.d(TAG, "Got single blood oxygen: $spo2")
                        sendHealthData("oxygen", spo2)
                    } else {
                        Log.w(TAG, "Invalid single_blood_oxygen in SEND23: $jsonObject")
                    }
                }
                "SEND14" -> { // 실시간 단일 심박수
                    val hrStr = jsonObject.optString("single_heart_rate", "-1")
                    val hr = hrStr.toIntOrNull() ?: -1
                    if (hr >= 0) {
                        Log.d(TAG, "Got single heart rate: $hr")
                        sendHealthData("heart", hr)
                    } else {
                        Log.w(TAG, "Invalid single_heart_rate in SEND14: $jsonObject")
                    }
                }
                "SEND10" -> { // 오늘 누적 걸음수 등
                    val stepsStr = jsonObject.optString("step_count", "-1")
                    val steps = stepsStr.toIntOrNull() ?: -1
                    if (steps >= 0) {
                        Log.d(TAG, "Got daily step count: $steps")
                        sendHealthData("steps", steps)
                    } else {
                        Log.w(TAG, "Invalid step_count in SEND10: $jsonObject")
                    }
                    // distance, calorie 값도 필요하다면 여기서 추가 이벤트 전송 가능
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing data: ${e.message}")
        }
    }

    private fun sendHealthData(type: String, value: Int) {
        mainHandler.post {
            try {
                if (eventSink != null) {
                    eventSink?.success(mapOf(
                        "type" to type,
                        "value" to value
                    ))
                } else {
                    Log.w(TAG, "Flutter 이벤트 채널이 연결되지 않음 - $type 데이터 전송 실패")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Flutter로 $type 데이터 전송 중 오류: ${e.message}")
            }
        }
    }

    private fun sendConnectionState(state: Int) {
        mainHandler.post {
            try {
                if (eventSink != null) {
                    eventSink?.success(mapOf(
                        "type" to "connection",
                        "state" to state
                    ))
                } else {
                    Log.w(TAG, "Flutter 이벤트 채널이 연결되지 않음 - 연결 상태 전송 실패")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Flutter로 연결 상태 전송 중 오류: ${e.message}")
            }
        }
    }

    private fun sendBackgroundData(type: String, value: Int, timestamp: String) {
        mainHandler.post {
            try {
                if (eventSink != null) {
                    eventSink?.success(mapOf(
                        "type" to "background_data",
                        "data_type" to type,
                        "value" to value,
                        "timestamp" to timestamp
                    ))
                } else {
                    Log.w(TAG, "Flutter 이벤트 채널이 연결되지 않음 - 백그라운드 $type 데이터 전송 실패")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Flutter로 백그라운드 $type 데이터 전송 중 오류: ${e.message}")
            }
        }
    }

    fun sendBackgroundHealthDataToFlutter(
        heartRate: Int, 
        spo2: Int, 
        stepCount: Int, 
        battery: Int, 
        chargingState: Int, 
        timestamp: String
    ) {
        mainHandler.post {
            try {
                if (eventSink != null) {
                    eventSink?.success(mapOf(
                        "type" to "send_background_health_data",
                        "heartRate" to heartRate,
                        "spo2" to spo2,
                        "stepCount" to stepCount,
                        "battery" to battery,
                        "chargingState" to chargingState,
                        "timestamp" to timestamp
                    ))
                    Log.d(TAG, "백그라운드 건강 데이터를 Flutter로 전송 성공")
                } else {
                    Log.w(TAG, "Flutter 이벤트 채널이 연결되지 않음 - 백그라운드 데이터 전송 실패")
                    // 로컬 데이터베이스에 저장하여 나중에 전송할 수 있도록 처리
                    // TODO: 로컬 DB에 저장하는 로직 추가
                }
            } catch (e: Exception) {
                Log.e(TAG, "Flutter로 백그라운드 데이터 전송 중 오류: ${e.message}")
                // 오류 발생 시에도 로컬 데이터베이스에 저장
                // TODO: 로컬 DB에 저장하는 로직 추가
            }
        }
    }

    // 필수 콜백 구현
    override fun pushDataProgress(progress: Int, totalProgress: Int) {
        Log.d(TAG, "Push data progress: $progress/$totalProgress")
    }

    override fun pushDataProgressState(code: Int) {
        Log.d(TAG, "Push data state: $code")
    }

    override fun pushDataNotStartedLowBattery() {
        Log.d(TAG, "Low battery warning")
        mainHandler.post {
            try {
                if (eventSink != null) {
                    eventSink?.success(mapOf(
                        "type" to "battery",
                        "state" to "low"
                    ))
                } else {
                    Log.w(TAG, "Flutter 이벤트 채널이 연결되지 않음 - 저전력 경고 전송 실패")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Flutter로 저전력 경고 전송 중 오류: ${e.message}")
            }
        }
    }

    override fun getGpsDataProgress(progress: Int) {
        Log.d(TAG, "GPS data progress: $progress")
    }
}
