package com.melodylien.app.ble

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothManager
import android.bluetooth.le.*
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

// MARK: - BLE定数

private object BLEConstants {
    val SERVICE_UUID: UUID = UUID.fromString("E7A1B2C3-D4E5-F6A7-B8C9-D0E1F2A3B4C5")
    val USER_ID_CHAR_UUID: UUID = UUID.fromString("A1B2C3D4-E5F6-A7B8-C9D0-E1F2A3B4C5D6")
    const val COOLDOWN_MS = 6 * 60 * 60 * 1000L   // 6時間
    const val HOURLY_MAX = 10
    const val SCAN_PERIOD_MS = 10_000L              // バックグラウンド: 10秒スキャン
    const val SCAN_PAUSE_MS = 50_000L              // バックグラウンド: 50秒休止
}

// MARK: - BLEManager

/**
 * BLE近距離検知マネージャー
 * - フォアグラウンド: 高精度スキャン
 * - バックグラウンド: BLEForegroundService 経由で省電力・低頻度スキャン
 */
@SuppressLint("MissingPermission")
class BLEManager(private val context: Context) {

    private val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
    private val adapter: BluetoothAdapter? get() = bluetoothManager.adapter
    private val scanner: BluetoothLeScanner? get() = adapter?.bluetoothLeScanner
    private val advertiser: BluetoothLeAdvertiser? get() = adapter?.bluetoothLeAdvertiser
    private val handler = Handler(Looper.getMainLooper())

    // State
    private val _isScanning = MutableStateFlow(false)
    val isScanning: StateFlow<Boolean> = _isScanning

    private val _pendingEncounterIds = MutableStateFlow<List<String>>(emptyList())
    val pendingEncounterIds: StateFlow<List<String>> = _pendingEncounterIds

    /** 同一ユーザーとの最終交換時刻 */
    private val lastExchangeMap = ConcurrentHashMap<String, Long>()

    /** 1時間あたりの出会い人数 */
    private var hourlyCount = 0
    private var hourlyCountResetAt = System.currentTimeMillis()

    // MARK: - Scanning

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val deviceId = result.device.address
            handleDiscoveredDevice(deviceId, result.rssi)
        }

        override fun onBatchScanResults(results: MutableList<ScanResult>) {
            results.forEach { handleDiscoveredDevice(it.device.address, it.rssi) }
        }
    }

    private val scanFilters = listOf(
        ScanFilter.Builder()
            .setServiceUuid(ParcelUuid(BLEConstants.SERVICE_UUID))
            .build()
    )

    private val scanSettings = ScanSettings.Builder()
        .setScanMode(ScanSettings.SCAN_MODE_LOW_POWER)
        .setReportDelay(0)
        .build()

    fun startScan() {
        if (_isScanning.value) return
        scanner?.startScan(scanFilters, scanSettings, scanCallback)
        _isScanning.value = true
    }

    fun stopScan() {
        scanner?.stopScan(scanCallback)
        _isScanning.value = false
    }

    /** バックグラウンド用: 一定間隔でスキャン/休止を繰り返す */
    fun startBackgroundScan() {
        scheduleScan()
    }

    private fun scheduleScan() {
        startScan()
        handler.postDelayed({
            stopScan()
            handler.postDelayed({ scheduleScan() }, BLEConstants.SCAN_PAUSE_MS)
        }, BLEConstants.SCAN_PERIOD_MS)
    }

    // MARK: - Advertising

    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {}
        override fun onStartFailure(errorCode: Int) {}
    }

    fun startAdvertising(userId: String) {
        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_POWER)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_LOW)
            .setConnectable(true)
            .build()

        val data = AdvertiseData.Builder()
            .addServiceUuid(ParcelUuid(BLEConstants.SERVICE_UUID))
            .setIncludeDeviceName(false)
            .build()

        advertiser?.startAdvertising(settings, data, advertiseCallback)
    }

    fun stopAdvertising() {
        advertiser?.stopAdvertising(advertiseCallback)
    }

    // MARK: - Encounter logic

    private fun canExchange(deviceId: String): Boolean {
        resetHourlyCountIfNeeded()
        if (hourlyCount >= BLEConstants.HOURLY_MAX) return false
        val last = lastExchangeMap[deviceId] ?: 0L
        return System.currentTimeMillis() - last > BLEConstants.COOLDOWN_MS
    }

    private fun resetHourlyCountIfNeeded() {
        if (System.currentTimeMillis() - hourlyCountResetAt > 3_600_000L) {
            hourlyCount = 0
            hourlyCountResetAt = System.currentTimeMillis()
        }
    }

    private fun handleDiscoveredDevice(deviceId: String, rssi: Int) {
        if (!canExchange(deviceId)) return
        lastExchangeMap[deviceId] = System.currentTimeMillis()
        hourlyCount++
        // TODO: API 経由で encounter を作成し pendingEncounterIds に追加
    }
}
