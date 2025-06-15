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

class MainApplication : Application(), BTMGattCallBack, AnalyticalDataCallBack {
    companion object {
        lateinit var instance: MainApplication
        lateinit var manager: BleTransferManager
        private const val TAG = "MainApplication"
    }

    private var connectedState = false
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

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
        
        try {
            // 일부 펌웨어는 "GET,77" 형태로 콤마가 포함돼 전달되므로, 통일된 비교를 위해 제거
            val normalizedKey = cmdKey.replace(",", "")

            when (normalizedKey) {
                "GET77" -> { // 심박수 (GET77 or GET,77)
                    val heartRate: Int? = when {
                        jsonObject.has("heart_rate") -> jsonObject.optInt("heart_rate", -1)
                        jsonObject.has("measure_heart_rate") -> jsonObject.optString("measure_heart_rate").toIntOrNull() ?: -1
                        else -> -1
                    }
                    if (heartRate != null && heartRate >= 0) {
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
                                eventSink?.success(mapOf(
                                    "type" to "health87",
                                    "entry" to item.toString()
                                ))
                            }
                        }
                    } else {
                        Log.w(TAG, "GET87 배열이 비어있습니다: $jsonObject")
                    }
                }
                "GET88" -> { // 배터리 & 충전 상태
                    Log.d(TAG, "Got Battery State")
                    val battery = jsonObject.optInt("battery", -1)
                    val chargingState = jsonObject.optInt("charging_state", -1)
                    if (battery >= 0) sendHealthData("battery", battery)
                    if (chargingState >= 0) sendHealthData("chargingState", chargingState)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing data: ${e.message}")
        }
    }

    private fun sendHealthData(type: String, value: Int) {
        mainHandler.post {
            eventSink?.success(mapOf(
                "type" to type,
                "value" to value
            ))
        }
    }

    private fun sendConnectionState(state: Int) {
        mainHandler.post {
            eventSink?.success(mapOf(
                "type" to "connection",
                "state" to state
            ))
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
            eventSink?.success(mapOf(
                "type" to "battery",
                "state" to "low"
            ))
        }
    }

    override fun getGpsDataProgress(progress: Int) {
        Log.d(TAG, "GPS data progress: $progress")
    }
}
