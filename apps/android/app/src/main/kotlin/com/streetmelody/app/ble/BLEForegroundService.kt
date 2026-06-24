package com.streetmelody.app.ble

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * バックグラウンドBLEスキャン用 Foreground Service
 * - OS がアプリをキルしてもBLEスキャンを継続させる
 */
class BLEForegroundService : Service() {

    private lateinit var bleManager: BLEManager
    private val channelId = "streetmelody_ble"

    override fun onCreate() {
        super.onCreate()
        bleManager = BLEManager(applicationContext)
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(1, buildNotification())
        bleManager.startBackgroundScan()
        return START_STICKY
    }

    override fun onDestroy() {
        bleManager.stopScan()
        bleManager.stopAdvertising()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            channelId,
            "StreetMelody 近距離検知",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "近くにいる人の推し曲を自動で検知しています"
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification =
        NotificationCompat.Builder(this, channelId)
            .setContentTitle("StreetMelody")
            .setContentText("近くにいる人の推し曲を検知中…")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
}
