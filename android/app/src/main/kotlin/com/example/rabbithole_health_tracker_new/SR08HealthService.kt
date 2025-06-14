package com.example.rabbithole_health_tracker

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

class SR08HealthService : Service() {
    private var timer: Timer? = null
    private val NOTIFICATION_ID = 1
    private val CHANNEL_ID = "SR08HealthChannel"
    
    companion object {
        private const val TAG = "SR08HealthService"
        var isRunning = false
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!isRunning) {
            isRunning = true
            startHealthMonitoring()
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        stopHealthMonitoring()
        isRunning = false
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "SR08 Health Monitoring"
            val descriptionText = "Monitoring health data from SR08 ring"
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
        .setContentText("Monitoring health data...")
        // .setSmallIcon(R.drawable.ic_notification)
        .setPriority(NotificationCompat.PRIORITY_LOW)
        .build()

    private fun startHealthMonitoring() {
        timer = Timer().apply {
            schedule(object : TimerTask() {
                override fun run() {
                    if (MainApplication.instance.isConnectedState()) {
                        try {
                            // 심박수 측정
                            MainApplication.manager.cmdGet77()
                            Thread.sleep(1000)
                            
                            // 혈중산소 측정
                            MainApplication.manager.cmdGet81()
                            Thread.sleep(1000)
                            
                            // 걸음수 요청
                            MainApplication.manager.cmdGet17()
                        } catch (e: Exception) {
                            Log.e(TAG, "Error during health monitoring: ${e.message}")
                        }
                    }
                }
            }, 0, 30 * 60 * 1000) // 30분 간격으로 실행
        }
        Log.d(TAG, "Health monitoring started")
    }

    private fun stopHealthMonitoring() {
        timer?.cancel()
        timer = null
        Log.d(TAG, "Health monitoring stopped")
    }
} 