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
            when (cmdKey) {
                "GET77" -> { // 심박수
                    val heartRate = jsonObject.getInt("heart_rate")
                    sendHealthData("heart", heartRate)
                }
                "GET81" -> { // 혈중산소
                    val spo2 = jsonObject.getInt("spo2")
                    sendHealthData("oxygen", spo2)
                }
                "GET17" -> { // 걸음수
                    val steps = jsonObject.getInt("step_count")
                    sendHealthData("steps", steps)
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
