import CoreBluetooth
import Foundation
import Combine

// MARK: - BLE定数

private enum BLEConstants {
    /// MelodyLien 専用サービスUUID（本番は Apple Developer で取得した UUID を使用）
    static let serviceUUID = CBUUID(string: "E7A1B2C3-D4E5-F6A7-B8C9-D0E1F2A3B4C5")
    /// ユーザーID を乗せるキャラクタリスティックUUID
    static let userIDCharUUID = CBUUID(string: "A1B2C3D4-E5F6-A7B8-C9D0-E1F2A3B4C5D6")
    static let scanInterval: TimeInterval = 15      // バックグラウンド: 15秒おきにスキャン
    static let cooldownHours: TimeInterval = 6 * 3600
}

// MARK: - BLEManager

/// BLE近距離検知の管理クラス
/// - アプリ起動中: 高精度スキャン
/// - バックグラウンド: 省電力・低頻度スキャン
final class BLEManager: NSObject, ObservableObject {

    // MARK: Published state

    @Published private(set) var isScanning = false
    @Published private(set) var nearbyUsers: [NearbyUser] = []
    @Published private(set) var pendingEncounters: [String] = []  // 未確認のencounterID

    // MARK: Private

    private var centralManager: CBCentralManager!
    private var peripheralManager: CBPeripheralManager!
    private var cancellables = Set<AnyCancellable>()

    /// 同一ユーザーとの交換クールダウン管理
    /// key: userID, value: 最終交換日時
    private var lastExchangeMap: [String: Date] = [:]

    /// 1時間の出会い人数カウント
    private var hourlyEncounterCount = 0
    private var hourlyCountResetDate = Date()

    private let repository: MelodyRepository

    init(repository: MelodyRepository) {
        self.repository = repository
        super.init()
        centralManager  = CBCentralManager(delegate: self, queue: .main,
                                           options: [CBCentralManagerOptionRestoreIdentifierKey: "MelodyLienCentral"])
        peripheralManager = CBPeripheralManager(delegate: self, queue: .main,
                                                options: [CBPeripheralManagerOptionRestoreIdentifierKey: "MelodyLienPeripheral"])
    }

    // MARK: - Public API

    func startScan() {
        guard centralManager.state == .poweredOn else { return }
        isScanning = true
        centralManager.scanForPeripherals(
            withServices: [BLEConstants.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    func stopScan() {
        centralManager.stopScan()
        isScanning = false
    }

    func startAdvertising(userId: String) {
        guard peripheralManager.state == .poweredOn else { return }
        let service = CBMutableService(type: BLEConstants.serviceUUID, primary: true)
        let data = userId.data(using: .utf8) ?? Data()
        let characteristic = CBMutableCharacteristic(
            type: BLEConstants.userIDCharUUID,
            properties: [.read, .broadcast],
            value: data,
            permissions: .readable
        )
        service.characteristics = [characteristic]
        peripheralManager.add(service)
        peripheralManager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [BLEConstants.serviceUUID],
            CBAdvertisementDataLocalNameKey: "MelodyLien"
        ])
    }

    // MARK: - Encounter logic

    private func canExchange(with userId: String) -> Bool {
        // 同一ユーザー 6時間制限
        if let last = lastExchangeMap[userId],
           Date().timeIntervalSince(last) < BLEConstants.cooldownHours {
            return false
        }
        // 1時間 10人制限
        resetHourlyCountIfNeeded()
        return hourlyEncounterCount < 10
    }

    private func resetHourlyCountIfNeeded() {
        if Date().timeIntervalSince(hourlyCountResetDate) > 3600 {
            hourlyEncounterCount = 0
            hourlyCountResetDate = Date()
        }
    }

    private func handleDiscoveredUser(_ userId: String, rssi: Int) {
        guard canExchange(with: userId) else { return }

        lastExchangeMap[userId] = Date()
        hourlyEncounterCount += 1

        Task {
            do {
                let encounterId = try await repository.createEncounter(with: userId)
                await MainActor.run {
                    pendingEncounters.append(encounterId)
                }
            } catch {
                print("[BLE] createEncounter failed: \(error)")
            }
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            startScan()
        case .poweredOff, .resetting:
            stopScan()
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        // アドバタイズデータからユーザーIDを読み取る
        // （実装では peripheral.readValue で取得する）
        let tempUserId = peripheral.identifier.uuidString
        handleDiscoveredUser(tempUserId, rssi: RSSI.intValue)
    }

    func centralManager(_ central: CBCentralManager,
                        willRestoreState dict: [String: Any]) {
        // バックグラウンド復帰時の状態復元
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            for p in peripherals {
                let userId = p.identifier.uuidString
                handleDiscoveredUser(userId, rssi: -70)
            }
        }
    }
}

// MARK: - CBPeripheralManagerDelegate

extension BLEManager: CBPeripheralManagerDelegate {

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            // アドバタイズは AppViewModel から userId 確定後に呼ぶ
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                           willRestoreState dict: [String: Any]) {}
}
