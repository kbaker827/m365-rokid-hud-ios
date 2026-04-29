import Foundation
import CoreBluetooth

enum M365ConnectionState {
    case idle, scanning, connecting, connected, error(String)
}

struct ScooterDevice: Identifiable {
    let id: UUID
    let name: String
    let rssi: Int
    let peripheral: CBPeripheral
}

final class M365BleManager: NSObject, ObservableObject {
    // UART service (Nordic nRF)
    static let uartServiceUUID    = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    static let uartTxUUID         = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E") // write
    static let uartRxUUID         = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E") // notify

    @Published var state: M365ConnectionState = .idle
    @Published var discoveredDevices: [ScooterDevice] = []
    @Published var telemetry = ScooterTelemetry()
    @Published var connectedDevice: ScooterDevice?

    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var txChar: CBCharacteristic?
    private var rxChar: CBCharacteristic?
    private var receiveBuffer = Data()
    private var pollTimer: Timer?
    private var pollStep = 0

    var onTelemetryUpdate: ((ScooterTelemetry) -> Void)?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    func startScan() {
        guard centralManager.state == .poweredOn else { return }
        discoveredDevices.removeAll()
        state = .scanning
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        // Stop scan after 15s
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            guard case .scanning = self?.state else { return }
            self?.stopScan()
        }
    }

    func stopScan() {
        centralManager.stopScan()
        if case .scanning = state { state = .idle }
    }

    func connect(to device: ScooterDevice) {
        stopScan()
        state = .connecting
        peripheral = device.peripheral
        peripheral?.delegate = self
        centralManager.connect(device.peripheral, options: nil)
    }

    func disconnect() {
        stopPolling()
        if let p = peripheral { centralManager.cancelPeripheralConnection(p) }
        peripheral = nil; txChar = nil; rxChar = nil
        state = .idle; connectedDevice = nil
    }

    // MARK: - Polling

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.sendNextPoll()
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func sendNextPoll() {
        let attrs: [UInt8] = [
            NinebotProtocol.attrSpeed,
            NinebotProtocol.attrBattery,
            NinebotProtocol.attrTemp,
            NinebotProtocol.attrTripMileage,
            NinebotProtocol.attrTotalMileage,
            NinebotProtocol.attrRemainingKm,
            NinebotProtocol.attrErrorCode
        ]
        let attr = attrs[pollStep % attrs.count]
        pollStep += 1
        let frame = NinebotProtocol.makeReadFrame(attr: attr)
        write(frame)
    }

    private func write(_ data: Data) {
        guard let p = peripheral, let char = txChar else { return }
        p.writeValue(data, for: char, type: .withoutResponse)
    }

    // MARK: - Frame parsing

    private func handleReceive(_ data: Data) {
        receiveBuffer.append(data)

        // Try to find and consume frames
        while receiveBuffer.count >= 7 {
            guard let h0 = receiveBuffer.first, h0 == 0x55,
                  receiveBuffer.count >= 2, receiveBuffer[1] == 0xAA else {
                receiveBuffer.removeFirst()
                continue
            }
            let len = Int(receiveBuffer[2])
            let total = 2 + 1 + len + 2
            guard receiveBuffer.count >= total else { break }
            let frameData = receiveBuffer.prefix(total)
            receiveBuffer.removeFirst(total)
            processFrame(Data(frameData))
        }
    }

    private func processFrame(_ data: Data) {
        guard let parsed = NinebotProtocol.parseFrame(data) else { return }
        let p = parsed.payload
        switch parsed.attr {
        case NinebotProtocol.attrSpeed:
            if let v = NinebotProtocol.parseUInt16(p) { telemetry.speedKmh = Double(v) / 1000.0 }
        case NinebotProtocol.attrBattery:
            if let v = NinebotProtocol.parseUInt16(p) { telemetry.batteryPercent = Int(v) }
        case NinebotProtocol.attrTemp:
            if let v = NinebotProtocol.parseUInt16(p) { telemetry.tempCelsius = Double(v) / 10.0 }
        case NinebotProtocol.attrTripMileage:
            if let v = NinebotProtocol.parseUInt16(p) { telemetry.tripMeters = Int(v) }
        case NinebotProtocol.attrTotalMileage:
            if let v = NinebotProtocol.parseUInt32(p) { telemetry.totalKm = Double(v) / 1000.0 }
        case NinebotProtocol.attrRemainingKm:
            if let v = NinebotProtocol.parseUInt16(p) { telemetry.remainingKm = Double(v) / 100.0 }
        case NinebotProtocol.attrErrorCode:
            if let v = NinebotProtocol.parseUInt16(p) { telemetry.errorCode = Int(v) }
        default: break
        }
        onTelemetryUpdate?(telemetry)
    }
}

extension M365BleManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn && state == .idle { }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Unknown"
        // Filter for M365-like devices (Ninebot, Mi Scooter, etc.)
        let knownPrefixes = ["NBD", "Mi Scooter", "Xiaomi", "M365", "Ninebot"]
        guard knownPrefixes.contains(where: { name.hasPrefix($0) }) else { return }
        let device = ScooterDevice(id: peripheral.identifier, name: name, rssi: RSSI.intValue, peripheral: peripheral)
        if !discoveredDevices.contains(where: { $0.id == device.id }) {
            discoveredDevices.append(device)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([M365BleManager.uartServiceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        state = .error(error?.localizedDescription ?? "Connection failed")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        stopPolling()
        state = error == nil ? .idle : .error("Disconnected: \(error!.localizedDescription)")
        connectedDevice = nil
        txChar = nil; rxChar = nil
    }
}

extension M365BleManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == M365BleManager.uartServiceUUID {
            peripheral.discoverCharacteristics([M365BleManager.uartTxUUID, M365BleManager.uartRxUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for char in service.characteristics ?? [] {
            if char.uuid == M365BleManager.uartTxUUID { txChar = char }
            if char.uuid == M365BleManager.uartRxUUID {
                rxChar = char
                peripheral.setNotifyValue(true, for: char)
            }
        }
        if txChar != nil && rxChar != nil {
            let device = discoveredDevices.first { $0.id == peripheral.identifier }
                ?? ScooterDevice(id: peripheral.identifier, name: peripheral.name ?? "M365", rssi: 0, peripheral: peripheral)
            connectedDevice = device
            state = .connected
            startPolling()
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == M365BleManager.uartRxUUID,
              let value = characteristic.value else { return }
        handleReceive(value)
    }
}
