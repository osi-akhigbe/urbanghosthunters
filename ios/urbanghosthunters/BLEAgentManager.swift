//
//  BLEAgentManager.swift
//  urbanghosthunters
//

import Foundation
import CoreBluetooth

// UUID that all UGH agents advertise — unique to this app
private let UGH_SERVICE_UUID = CBUUID(string: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")

@Observable
@MainActor
final class BLEAgentManager: NSObject {
    static let shared = BLEAgentManager()

    var nearbyAgents: [String] = []
    var isScanning = false
    var errorText: String?

    private var centralManager: CBCentralManager!
    private var peripheralManager: CBPeripheralManager!
    private var discoveredAgents: [String: Date] = [:]
    private var cleanupTimer: Timer?

    private override init() {
        super.init()
        centralManager = CBCentralManager(delegate: nil, queue: .main)
        peripheralManager = CBPeripheralManager(delegate: nil, queue: .main)
    }

    func start() {
        centralManager.delegate = self
        peripheralManager.delegate = self
        isScanning = true
        startCleanupTimer()
    }

    func stop() {
        if centralManager.isScanning {
            centralManager.stopScan()
        }
        peripheralManager.stopAdvertising()
        cleanupTimer?.invalidate()
        isScanning = false
        nearbyAgents = []
        discoveredAgents = [:]
    }

    // Remove agents not seen in last 10 seconds
    private func startCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let now = Date()
                self.discoveredAgents = self.discoveredAgents.filter {
                    now.timeIntervalSince($0.value) < 10
                }
                self.nearbyAgents = Array(self.discoveredAgents.keys)
            }
        }
    }
}

// MARK: - Central (Scanner)
extension BLEAgentManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn:
                central.scanForPeripherals(
                    withServices: [UGH_SERVICE_UUID],
                    options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
                )
            case .poweredOff:
                self.errorText = "Bluetooth is off"
            case .unauthorized:
                self.errorText = "Bluetooth permission denied"
            default:
                break
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didDiscover peripheral: CBPeripheral,
                                    advertisementData: [String: Any],
                                    rssi RSSI: NSNumber) {
        Task { @MainActor in
            let agentId = peripheral.identifier.uuidString
            self.discoveredAgents[agentId] = Date()
            self.nearbyAgents = Array(self.discoveredAgents.keys)
        }
    }
}

// MARK: - Peripheral (Advertiser)
extension BLEAgentManager: CBPeripheralManagerDelegate {
    nonisolated func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        Task { @MainActor in
            if peripheral.state == .poweredOn {
                peripheral.startAdvertising([
                    CBAdvertisementDataServiceUUIDsKey: [UGH_SERVICE_UUID],
                    CBAdvertisementDataLocalNameKey: "UGHAgent"
                ])
            }
        }
    }
}
