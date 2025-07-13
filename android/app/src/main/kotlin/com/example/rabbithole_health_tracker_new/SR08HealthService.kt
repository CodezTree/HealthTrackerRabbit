package com.example.rabbithole_health_tracker_new

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat
import android.util.Log
import java.util.Timer
import java.util.TimerTask
import android.os.Handler
import android.os.Looper
import kotlinx.coroutines.*
import java.util.concurrent.ConcurrentHashMap
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import org.json.JSONObject
import kotlin.coroutines.resume
import kotlin.coroutines.suspendCoroutine
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import android.content.SharedPreferences
import java.io.IOException

class SR08HealthService : Service() {
    private var timer: Timer? = null
    private val NOTIFICATION_ID = 1
    private val CHANNEL_ID = "SR08HealthChannel"
    private val mainHandler = Handler(Looper.getMainLooper())
    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    // 연결 재시도 관련 변수
    private var reconnectAttempts = 0
    private val maxReconnectAttempts = 5
    private var isReconnecting = false
    
    // 수집된 데이터 임시 저장용
    private val collectedData = ConcurrentHashMap<String, Any>()
    
    // 데이터 수집 상태 관리
    private var isCollectingData = false
    private val requiredKeys = setOf("battery", "heartRate", "spo2", "stepCount", "chargingState")
    private var collectionStartTime = 0L
    private var dataAlreadySent = false
    
    // HTTP 클라이언트 및 API 관련
    private val httpClient = OkHttpClient()
    private val baseUrl = "https://www.taeanaihealth.or.kr"
    private val jsonMediaType = "application/json; charset=utf-8".toMediaType()
    private lateinit var sharedPreferences: SharedPreferences
    
    companion object {
        private const val TAG = "SR08HealthService"
        var isRunning = false
        private var lastKnownMacAddress: String? = null
        private var serviceInstance: SR08HealthService? = null
        
        fun setLastKnownMacAddress(macAddress: String) {
            lastKnownMacAddress = macAddress
        }
        
        // 수동으로 백그라운드 데이터 수집을 테스트하는 함수
        fun triggerManualDataCollection() {
            serviceInstance?.let { service ->
                service.serviceScope.launch {
                    Log.d(TAG, "수동 백그라운드 데이터 수집 테스트 시작")
                    try {
                        service.performHealthDataCollection()
                    } catch (e: Exception) {
                        Log.e(TAG, "수동 데이터 수집 테스트 중 오류: ${e.message}")
                    }
                }
            } ?: run {
                Log.w(TAG, "서비스가 실행되지 않아 수동 데이터 수집을 실행할 수 없음")
            }
        }
        
        // MainApplication에서 데이터를 받을 수 있도록 하는 함수
        fun onDataReceived(cmdKey: String, data: Any) {
            serviceInstance?.handleReceivedData(cmdKey, data)
        }
    }

    override fun onCreate() {
        super.onCreate()
        serviceInstance = this
        sharedPreferences = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!isRunning) {
            isRunning = true
            startPeriodicHealthMonitoring()
            Log.d(TAG, "백그라운드 건강 모니터링 서비스 시작")
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        stopPeriodicHealthMonitoring()
        serviceScope.cancel()
        isRunning = false
        serviceInstance = null
        Log.d(TAG, "백그라운드 건강 모니터링 서비스 종료")
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "SR08 Health Monitoring"
            val descriptionText = "30분마다 링에서 건강 데이터를 수집합니다"
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = descriptionText
            }
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification() = NotificationCompat.Builder(this, CHANNEL_ID)
        .setContentTitle("SR08 Health Tracker")
        .setContentText("정기적으로 건강 데이터를 수집 중...")
        .setPriority(NotificationCompat.PRIORITY_LOW)
        .setOngoing(true)
        .build()

    private fun startPeriodicHealthMonitoring() {
        timer = Timer().apply {
            schedule(object : TimerTask() {
                override fun run() {
                    serviceScope.launch {
                        try {
                            performHealthDataCollection()
                        } catch (e: Exception) {
                            Log.e(TAG, "건강 데이터 수집 중 오류 발생: ${e.message}")
                        }
                    }
                }
            }, 0, 10 * 60 * 1000) // 10분 간격으로 실행
        }
        Log.d(TAG, "10분 주기 건강 모니터링 타이머 시작")
    }

    private fun stopPeriodicHealthMonitoring() {
        timer?.cancel()
        timer = null
        Log.d(TAG, "건강 모니터링 타이머 중지")
    }

    /**
     * 메인 건강 데이터 수집 로직
     * 1. 연결 상태 확인 및 재연결
     * 2. GET0, GET81, GET10, GET77 순차 실행
     * 3. 데이터 로컬 저장
     * 4. API 전송
     */
    private suspend fun performHealthDataCollection() {
        Log.d(TAG, "건강 데이터 수집 시작")
        
        // 1. 연결 상태 확인 및 재연결
        if (!ensureDeviceConnection()) {
            Log.w(TAG, "디바이스 연결 실패 - 데이터 수집 건너뜀")
            return
        }
        
        // 2. 데이터 수집 초기화
        collectedData.clear()
        isCollectingData = true
        dataAlreadySent = false
        collectionStartTime = System.currentTimeMillis()
        
        // 3. 건강 데이터 순차 수집
        if (collectHealthDataSequentially()) {
            // 4. 수집 완료 대기 (최대 30초)
            waitForDataCollection()
            
            // 5. 로컬 저장
            saveCollectedDataLocally()
            
            // 6. API 전송 (데이터가 아직 전송되지 않은 경우에만)
            if (!dataAlreadySent) {
                Log.d(TAG, "데이터 수집 완료 후 API 전송 시작")
                sendDataToApi()
            } else {
                Log.d(TAG, "데이터 이미 전송됨 - 중복 전송 방지")
            }
        } else {
            Log.w(TAG, "건강 데이터 수집 실패")
        }
        
        isCollectingData = false
        Log.d(TAG, "건강 데이터 수집 완료")
    }
    
    /**
     * MainApplication에서 받은 데이터를 처리
     */
    private fun handleReceivedData(cmdKey: String, data: Any) {
        if (!isCollectingData) return
        
        try {
            val normalizedKey = cmdKey.replace(",", "")
            Log.d(TAG, "데이터 수신: $normalizedKey = $data")
            
            when (normalizedKey) {
                "GET0" -> {
                    // 배터리 정보 추출 (JSONObject에서)
                    if (data is JSONObject) {
                        val batteryCapacity = data.optString("battery_capacity", "-1").toIntOrNull()
                        if (batteryCapacity != null && batteryCapacity >= 0) {
                            collectedData["battery"] = batteryCapacity
                            Log.d(TAG, "배터리 데이터 저장: $batteryCapacity%")
                        }
                    }
                }
                "GET77" -> {
                    // 심박수 데이터 추출
                    if (data is JSONObject) {
                        val heartRate = when {
                            data.has("heart_rate") -> data.optInt("heart_rate", -1)
                            data.has("measure_heart_rate") -> {
                                val raw = data.optString("measure_heart_rate")
                                raw.split("|").getOrNull(1)?.toIntOrNull() ?: raw.toIntOrNull() ?: -1
                            }
                            else -> -1
                        }
                        if (heartRate >= 0) {
                            collectedData["heartRate"] = heartRate
                            Log.d(TAG, "심박수 데이터 저장: $heartRate bpm")
                        }
                    }
                }
                "GET81" -> {
                    // 혈중산소 데이터 추출
                    if (data is JSONObject) {
                        val spo2 = when {
                            data.has("spo2") -> data.optString("spo2").split("|").getOrNull(1)?.toIntOrNull() ?: -1
                            data.has("measure_blood_oxygen") -> {
                                val raw = data.optString("measure_blood_oxygen")
                                raw.split("|").getOrNull(1)?.toIntOrNull() ?: -1
                            }
                            else -> -1
                        }
                        if (spo2 >= 0) {
                            collectedData["spo2"] = spo2
                            Log.d(TAG, "혈중산소 데이터 저장: $spo2%")
                        }
                    }
                }
                "GET10" -> {
                    // 걸음수 데이터 추출
                    if (data is JSONObject) {
                        val arr = data.optJSONArray("array")
                        if (arr != null && arr.length() > 0) {
                            val latestEntry = arr.getJSONObject(arr.length() - 1)
                            val steps = latestEntry.optString("step", "0").toIntOrNull() ?: 0
                            collectedData["stepCount"] = steps
                            Log.d(TAG, "걸음수 데이터 저장: $steps steps")
                        }
                    }
                }
                "GET88" -> {
                    // 충전 상태 데이터 추출
                    if (data is JSONObject) {
                        val chargingState = data.optString("charging_state", "-1").toIntOrNull()
                        if (chargingState != null && chargingState >= 0) {
                            collectedData["chargingState"] = chargingState
                            val stateText = when (chargingState) {
                                0 -> "미충전"
                                1 -> "충전중"
                                2 -> "충전완료"
                                else -> "알 수 없음"
                            }
                            Log.d(TAG, "충전 상태 데이터 저장: $chargingState ($stateText)")
                        }
                    }
                }
            }
            
            // 모든 필수 데이터가 수집되었는지 확인
            checkAndTriggerDataSend()
            
        } catch (e: Exception) {
            Log.e(TAG, "데이터 처리 중 오류: ${e.message}")
        }
    }
    
    /**
     * 모든 필수 데이터가 수집되었는지 확인하고 전송 트리거
     */
    private fun checkAndTriggerDataSend() {
        val collectedKeys = collectedData.keys
        val hasAllRequired = requiredKeys.all { collectedKeys.contains(it) }
        
        Log.d(TAG, "데이터 수집 상태: ${collectedKeys.size}/${requiredKeys.size} - $collectedKeys")
        
        if (hasAllRequired && !dataAlreadySent) {
            Log.d(TAG, "모든 필수 데이터 수집 완료! 즉시 API 전송 시작")
            serviceScope.launch {
                sendDataToApi()
            }
        } else if (dataAlreadySent) {
            Log.d(TAG, "데이터 이미 전송됨 - 중복 전송 방지")
        }
    }
    
    /**
     * 데이터 수집 완료 대기 (최대 30초)
     */
    private suspend fun waitForDataCollection() {
        val timeout = 30000L // 30초
        val startTime = System.currentTimeMillis()
        
        while (isCollectingData && System.currentTimeMillis() - startTime < timeout) {
            val collectedKeys = collectedData.keys
            val hasAllRequired = requiredKeys.all { collectedKeys.contains(it) }
            
            if (hasAllRequired) {
                Log.d(TAG, "모든 데이터 수집 완료!")
                break
            }
            
            delay(500) // 0.5초마다 확인
        }
        
        if (System.currentTimeMillis() - startTime >= timeout) {
            Log.w(TAG, "데이터 수집 타임아웃 - 수집된 데이터: ${collectedData.keys}")
        }
    }

    /**
     * 디바이스 연결 상태 확인 및 재연결 시도
     */
    private suspend fun ensureDeviceConnection(): Boolean {
        // 이미 연결되어 있으면 바로 반환
        if (MainApplication.instance.isConnectedState()) {
            Log.d(TAG, "디바이스 이미 연결됨")
            reconnectAttempts = 0
            return true
        }
        
        // 재연결 시도
        return attemptReconnection()
    }

    /**
     * 재연결 시도 로직
     */
    private suspend fun attemptReconnection(): Boolean {
        if (lastKnownMacAddress == null) {
            Log.w(TAG, "저장된 MAC 주소가 없어 재연결할 수 없음")
            return false
        }
        
        if (isReconnecting) {
            Log.d(TAG, "이미 재연결 시도 중")
            return false
        }
        
        isReconnecting = true
        
        for (attempt in 1..maxReconnectAttempts) {
            Log.d(TAG, "재연결 시도 $attempt/$maxReconnectAttempts - MAC: $lastKnownMacAddress")
            
            try {
                // 연결 시도
                MainApplication.manager.connectGatt(lastKnownMacAddress!!, false)
                
                // 연결 대기 (최대 10초)
                var waitTime = 0
                while (!MainApplication.instance.isConnectedState() && waitTime < 10000) {
                    delay(500)
                    waitTime += 500
                }
                
                if (MainApplication.instance.isConnectedState()) {
                    Log.d(TAG, "재연결 성공!")
                    reconnectAttempts = 0
                    isReconnecting = false
                    return true
                }
                
            } catch (e: Exception) {
                Log.e(TAG, "재연결 시도 $attempt 실패: ${e.message}")
            }
            
            // 다음 시도 전 대기
            if (attempt < maxReconnectAttempts) {
                delay(2000) // 2초 대기
            }
        }
        
        isReconnecting = false
        reconnectAttempts = maxReconnectAttempts
        Log.e(TAG, "모든 재연결 시도 실패")
        return false
    }

    /**
     * GET0, GET10, GET77, GET81, GET88을 순차적으로 실행하여 건강 데이터 수집
     * GET0을 먼저 실행하여 배터리 정보를 우선 업데이트
     */
    private suspend fun collectHealthDataSequentially(): Boolean {
        collectedData.clear()
        
        try {
            // GET0: 디바이스 정보 (배터리 정보 포함) - 먼저 실행
            if (!executeCommandAndWait("GET0", "GET0")) {
                Log.e(TAG, "GET0 실행 실패")
                return false
            }
            
            delay(1000) // 1초 대기
            
            // GET10: 걸음수 데이터
            if (!executeCommandAndWait("GET10", "GET10")) {
                Log.e(TAG, "GET10 실행 실패")
                return false
            }
            
            delay(1000) // 1초 대기
            
            // GET77: 심박수 측정 시작
            if (!executeCommandAndWait("GET77", "GET77")) {
                Log.e(TAG, "GET77 실행 실패")
                return false
            }
            
            delay(1000) // 1초 대기
            
            // GET81: 혈중산소 측정 시작
            if (!executeCommandAndWait("GET81", "GET81")) {
                Log.e(TAG, "GET81 실행 실패")
                return false
            }
            
            delay(1000) // 1초 대기
            
            // GET88: 충전 상태 정보
            if (!executeCommandAndWait("GET88", "GET88")) {
                Log.e(TAG, "GET88 실행 실패")
                return false
            }
            
            // 기존 명령들 (주석처리)
            /*
            // GET14: 심박수 데이터
            if (!executeCommandAndWait("GET14", "GET14")) {
                Log.e(TAG, "GET14 실행 실패")
                return false
            }
            
            // GET23: 혈중산소농도 데이터
            if (!executeCommandAndWait("GET23", "GET23")) {
                Log.e(TAG, "GET23 실행 실패")
                return false
            }
            */
            
            Log.d(TAG, "모든 건강 데이터 수집 완료")
            return true
            
        } catch (e: Exception) {
            Log.e(TAG, "건강 데이터 수집 중 오류: ${e.message}")
            return false
        }
    }

    /**
     * 백그라운드 건강 데이터 수집을 위해 Flutter 메소드 채널 호출
     */
    private suspend fun executeCommandAndWait(command: String, expectedResponse: String): Boolean {
        return withContext(Dispatchers.Main) {
            try {
                when (command) {
                    "GET0" -> {
                        Log.d(TAG, "GET0 (디바이스 정보) 명령 실행 - 응답 대기")
                        return@withContext executeCommandWithResponse("GET0") {
                            MainApplication.manager.cmdGet0()
                        }
                    }
                    "GET10" -> {
                        Log.d(TAG, "GET10 (걸음수) 명령 실행 - 응답 대기")
                        return@withContext executeCommandWithResponse("GET10") {
                            MainApplication.manager.cmdGet10()
                        }
                    }
                    "GET77" -> {
                        Log.d(TAG, "GET77 (심박수 측정 시작) 명령 실행 - 응답 대기")
                        return@withContext executeCommandWithResponse("GET77") {
                            MainApplication.manager.cmdGet77()
                        }
                    }
                    "GET81" -> {
                        Log.d(TAG, "GET81 (혈중산소 측정 시작) 명령 실행 - 응답 대기")
                        return@withContext executeCommandWithResponse("GET81") {
                            MainApplication.manager.cmdGet81()
                        }
                    }
                    "GET88" -> {
                        Log.d(TAG, "GET88 (충전 상태 정보) 명령 실행 - 응답 대기")
                        return@withContext executeCommandWithResponse("GET88") {
                            MainApplication.manager.cmdGet88()
                        }
                    }
                    // 기존 명령들 (주석처리)
                    /*
                    "GET14" -> {
                        Log.d(TAG, "GET14 (심박수) 명령 실행")
                        MainApplication.manager.cmdGet14()
                    }
                    "GET23" -> {
                        Log.d(TAG, "GET23 (혈중산소) 명령 실행")
                        MainApplication.manager.cmdGet23()
                    }
                    */
                    else -> {
                        Log.e(TAG, "알 수 없는 명령: $command")
                        return@withContext false
                    }
                }
                
                Log.d(TAG, "$command 명령 실행 완료")
                return@withContext true
                
            } catch (e: Exception) {
                Log.e(TAG, "$command 명령 실행 오류: ${e.message}")
                return@withContext false
            }
        }
    }

    /**
     * 명령 실행 후 BLE 응답을 기다리는 함수
     */
    private suspend fun executeCommandWithResponse(
        expectedKey: String, 
        commandAction: () -> Unit
    ): Boolean {
        return suspendCoroutine { continuation ->
            var isCompleted = false
            val timeoutRunnable = Runnable {
                if (!isCompleted) {
                    isCompleted = true
                    Log.w(TAG, "$expectedKey 응답 타임아웃")
                    continuation.resume(false)
                }
            }
            
            try {
                // 응답 대기 콜백 등록
                MainApplication.instance.waitForCmdResponse(expectedKey) {
                    if (!isCompleted) {
                        isCompleted = true
                        mainHandler.removeCallbacks(timeoutRunnable)
                        Log.d(TAG, "$expectedKey 응답 수신 완료")
                        continuation.resume(true)
                    }
                }
                
                // 명령 실행
                commandAction()
                
                // 타임아웃 처리 (30초)
                mainHandler.postDelayed(timeoutRunnable, 30000)
                
            } catch (e: Exception) {
                if (!isCompleted) {
                    isCompleted = true
                    mainHandler.removeCallbacks(timeoutRunnable)
                    Log.e(TAG, "$expectedKey 명령 실행 중 오류: ${e.message}")
                    continuation.resume(false)
                }
            }
        }
    }

    /**
     * 수집된 데이터를 로컬 데이터베이스에 저장
     */
    private fun saveCollectedDataLocally() {
        try {
            Log.d(TAG, "수집된 데이터를 로컬에 저장")
            
            // 수집된 데이터 확인
            val heartRate = collectedData["heartRate"] as? Int ?: 0
            val spo2 = collectedData["spo2"] as? Int ?: 0
            val stepCount = collectedData["stepCount"] as? Int ?: 0
            val battery = collectedData["battery"] as? Int ?: 0
            val chargingState = collectedData["chargingState"] as? Int ?: 0
            val timestamp = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", java.util.Locale.getDefault()).apply {
                timeZone = java.util.TimeZone.getTimeZone("UTC")
            }.format(java.util.Date())
            
            // 유효한 데이터가 있는 경우에만 저장
            if (heartRate > 0 || spo2 > 0 || stepCount >= 0) {
                Log.d(TAG, "로컬 저장할 데이터: HR=$heartRate, SpO2=$spo2, Steps=$stepCount, Battery=$battery%, ChargingState=$chargingState")
                
                // 1차 시도: Flutter 측으로 로컬 저장 요청 전송
                var flutterSaveSuccess = false
                try {
                    MainApplication.instance.saveBackgroundHealthDataToLocal(
                        heartRate, spo2, stepCount, battery, chargingState, timestamp
                    )
                    flutterSaveSuccess = MainApplication.instance.hasEventSink()
                    Log.d(TAG, "Flutter 로컬 저장 시도 결과: $flutterSaveSuccess")
                } catch (e: Exception) {
                    Log.e(TAG, "Flutter 로컬 저장 실패: ${e.message}")
                }
                
                // 2차 시도: Flutter 저장 실패 시 네이티브 SQLite 직접 저장
                if (!flutterSaveSuccess) {
                    Log.d(TAG, "Flutter 저장 실패 - 네이티브 SQLite 직접 저장 시도")
                    val nativeSuccess = saveToNativeSQLite(heartRate, spo2, stepCount, battery, chargingState, timestamp)
                    Log.d(TAG, "네이티브 SQLite 저장 결과: $nativeSuccess")
                }
            } else {
                Log.w(TAG, "유효한 데이터가 없어 로컬 저장을 건너뜀")
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "로컬 데이터 저장 오류: ${e.message}")
        }
    }

    /**
     * 네이티브 SQLite 데이터베이스에 직접 저장
     */
    private fun saveToNativeSQLite(
        heartRate: Int,
        spo2: Int, 
        stepCount: Int,
        battery: Int,
        chargingState: Int,
        timestamp: String
    ): Boolean {
        return try {
            val db = this.openOrCreateDatabase("health_tracker.db", Context.MODE_PRIVATE, null)
            
            // 테이블 생성 (존재하지 않는 경우)
            db.execSQL("""
                CREATE TABLE IF NOT EXISTS health_entries (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    heart_rate INTEGER,
                    spo2 INTEGER,
                    step_count INTEGER,
                    battery INTEGER,
                    charging_state INTEGER,
                    timestamp TEXT,
                    created_at TEXT DEFAULT CURRENT_TIMESTAMP
                )
            """)
            
            // 데이터 삽입
            db.execSQL("""
                INSERT INTO health_entries (heart_rate, spo2, step_count, battery, charging_state, timestamp)
                VALUES (?, ?, ?, ?, ?, ?)
            """, arrayOf(heartRate, spo2, stepCount, battery, chargingState, timestamp))
            
            db.close()
            
            Log.d(TAG, "✅ 네이티브 SQLite 저장 성공: HR=$heartRate, SpO2=$spo2, Steps=$stepCount")
            true
        } catch (e: Exception) {
            Log.e(TAG, "❌ 네이티브 SQLite 저장 실패: ${e.message}")
            false
        }
    }
    
    /**
     * SharedPreferences에서 토큰 읽기
     */
    private fun getAccessToken(): String? {
        return sharedPreferences.getString("flutter.accessToken", null)
    }
    
    private fun getRefreshToken(): String? {
        return sharedPreferences.getString("flutter.refreshToken", null)
    }
    
    private fun getUserId(): String? {
        return sharedPreferences.getString("flutter.userId", null)
    }
    
    /**
     * SharedPreferences에 토큰 저장
     */
    private fun saveTokens(accessToken: String, refreshToken: String) {
        sharedPreferences.edit().apply {
            putString("flutter.accessToken", accessToken)
            putString("flutter.refreshToken", refreshToken)
            apply()
        }
    }
    
    /**
     * 토큰 리프레시 시도
     */
    private suspend fun refreshTokenIfNeeded(): Boolean {
        val userId = getUserId()
        val refreshToken = getRefreshToken()
        
        if (userId == null || refreshToken == null) {
            Log.w(TAG, "토큰 리프레시 불가: 저장된 토큰 또는 사용자 ID가 없음")
            return false
        }
        
        return try {
            val requestBody = JSONObject().apply {
                put("user_id", userId)
                put("refreshToken", refreshToken)
            }.toString().toRequestBody(jsonMediaType)
            
            val request = Request.Builder()
                .url("$baseUrl/users/refresh-token")
                .post(requestBody)
                .build()
            
            val response = httpClient.newCall(request).execute()
            
            if (response.isSuccessful) {
                response.body?.string()?.let { responseBody ->
                    val jsonResponse = JSONObject(responseBody)
                    val newAccessToken = jsonResponse.getString("accessToken")
                    val newRefreshToken = jsonResponse.getString("refreshToken")
                    
                    saveTokens(newAccessToken, newRefreshToken)
                    Log.d(TAG, "토큰 리프레시 성공")
                    true
                } ?: false
            } else {
                Log.e(TAG, "토큰 리프레시 실패: ${response.code}")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "토큰 리프레시 오류: ${e.message}")
            false
        }
    }

    /**
     * 수집된 건강 데이터를 API 서버로 전송
     */
    private suspend fun sendDataToApi() {
        try {
            // 중복 전송 방지 체크
            if (dataAlreadySent) {
                Log.d(TAG, "API 전송 중복 방지: 이미 전송됨")
                return
            }
            
            Log.d(TAG, "API로 데이터 전송 시작")
            dataAlreadySent = true // 전송 시작 시점에 플래그 설정
            
            // 필수 데이터 확인
            val heartRate = collectedData["heartRate"] as? Int ?: 0
            val spo2 = collectedData["spo2"] as? Int ?: 0
            val stepCount = collectedData["stepCount"] as? Int ?: 0
            val battery = collectedData["battery"] as? Int ?: 0
            val chargingState = collectedData["chargingState"] as? Int ?: 0
            val timestamp = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", java.util.Locale.getDefault()).apply {
                timeZone = java.util.TimeZone.getTimeZone("UTC")
            }.format(java.util.Date())
            
            if (heartRate <= 0 || spo2 <= 0 || stepCount < 0) {
                Log.w(TAG, "유효하지 않은 데이터가 있어 전송을 건너뜀: HR=$heartRate, SpO2=$spo2, Steps=$stepCount")
                return
            }
            
            val chargingStateText = when (chargingState) {
                0 -> "미충전"
                1 -> "충전중"
                2 -> "충전완료"
                else -> "알 수 없음"
            }
            
            Log.d(TAG, "전송할 데이터: HR=$heartRate, SpO2=$spo2, Steps=$stepCount, Battery=$battery%, ChargingState=$chargingState($chargingStateText)")
            
            // Flutter 앱이 실행 중인지 확인하고 전송 방식 결정
            val flutterSuccess = tryFlutterTransmission(heartRate, spo2, stepCount, battery, chargingState, timestamp)
            
            if (!flutterSuccess) {
                Log.d(TAG, "Flutter 전송 실패 - 직접 HTTP 요청으로 전송 시도")
                val httpSuccess = sendHealthDataDirectly(heartRate, spo2, stepCount, battery, chargingState, timestamp)
                
                if (httpSuccess) {
                    Log.d(TAG, "✅ 백그라운드 건강 데이터 직접 HTTP 전송 성공")
                } else {
                    Log.e(TAG, "❌ 백그라운드 건강 데이터 직접 HTTP 전송 실패")
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "API 전송 처리 오류: ${e.message}")
        }
    }
    
    /**
     * Flutter를 통한 데이터 전송 시도
     */
    private suspend fun tryFlutterTransmission(
        heartRate: Int,
        spo2: Int,
        stepCount: Int,
        battery: Int,
        chargingState: Int,
        timestamp: String
    ): Boolean {
        return withContext(Dispatchers.Main) {
            try {
                // Flutter 앱이 완전히 종료되었을 가능성이 높으므로 바로 false 반환
                // FlutterJNI detached 오류를 방지하기 위해 Flutter 전송을 건너뜀
                Log.d(TAG, "Flutter 앱 종료 상태로 판단 - 직접 HTTP 전송으로 우회")
                false
            } catch (e: Exception) {
                Log.e(TAG, "Flutter 전송 오류: ${e.message}")
                false
            }
        }
    }
    
    /**
     * 직접 HTTP 요청으로 건강 데이터 전송
     */
    private suspend fun sendHealthDataDirectly(
        heartRate: Int,
        spo2: Int,
        stepCount: Int,
        battery: Int,
        chargingState: Int,
        timestamp: String
    ): Boolean {
        val maxRetries = 3
        var attempt = 0
        
        while (attempt < maxRetries) {
            attempt++
            Log.d(TAG, "직접 HTTP 전송 시도 $attempt/$maxRetries")
            
            try {
                var accessToken = getAccessToken()
                val userId = getUserId()
                
                if (accessToken == null || userId == null) {
                    Log.e(TAG, "토큰 또는 사용자 ID가 없음")
                    return false
                }
                
                // 건강 데이터 JSON 구성
                val healthData = JSONObject().apply {
                    put("user_id", userId)
                    put("heart_rate", heartRate)
                    put("spo2", spo2)
                    put("step_count", stepCount)
                    put("body_temperature", 36.5)
                    put("blood_pressure", JSONObject().apply {
                        put("systolic", 120)
                        put("diastolic", 80)
                    })
                    put("blood_sugar", 98)
                    put("battery", battery)
                    put("charging_state", chargingState)
                    put("sleep_hours", 0.0)
                    put("sports_time", 0)
                    put("screen_status", 0)
                    put("timestamp", timestamp)
                }
                
                val requestBody = healthData.toString().toRequestBody(jsonMediaType)
                val request = Request.Builder()
                    .url("$baseUrl/users/data")
                    .addHeader("Authorization", "Bearer $accessToken")
                    .post(requestBody)
                    .build()
                
                val response = httpClient.newCall(request).execute()
                
                when {
                    response.isSuccessful -> {
                        Log.d(TAG, "건강 데이터 직접 전송 성공 (시도 $attempt/$maxRetries)")
                        return true
                    }
                    response.code == 401 -> {
                        // 토큰 만료 - 리프레시 시도
                        Log.d(TAG, "토큰 만료, 리프레시 시도")
                        if (refreshTokenIfNeeded()) {
                            Log.d(TAG, "토큰 리프레시 성공, 재시도")
                            attempt-- // 토큰 리프레시 성공 시 재시도 횟수에서 제외
                            continue
                        } else {
                            Log.e(TAG, "토큰 리프레시 실패")
                            return false
                        }
                    }
                    response.code >= 500 || response.code == 429 -> {
                        // 서버 오류 또는 요청 제한 - 재시도
                        if (attempt < maxRetries) {
                            Log.w(TAG, "서버 오류 (${response.code}), 재시도 대기 중...")
                            delay(attempt * 2000L) // 지수 백오프
                            continue
                        }
                        return false
                    }
                    else -> {
                        Log.e(TAG, "건강 데이터 전송 실패: ${response.code}")
                        return false
                    }
                }
                
            } catch (e: IOException) {
                Log.e(TAG, "네트워크 오류 (시도 $attempt/$maxRetries): ${e.message}")
                if (attempt < maxRetries) {
                    delay(attempt * 2000L) // 지수 백오프
                    continue
                }
                return false
            } catch (e: Exception) {
                Log.e(TAG, "건강 데이터 전송 오류 (시도 $attempt/$maxRetries): ${e.message}")
                if (attempt < maxRetries) {
                    delay(1000L)
                    continue
                }
                return false
            }
        }
        
        Log.e(TAG, "모든 재시도 실패 - 건강 데이터 전송 최종 실패")
        return false
    }

} 