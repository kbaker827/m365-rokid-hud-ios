import Foundation

// Ninebot BLE serial protocol (M365 / Xiaomi scooter)
// Frame: [0x55][0xAA][len][src][dst][cmd][attr][payload...][crc16_lo][crc16_hi]
enum NinebotProtocol {
    static let header: [UInt8] = [0x55, 0xAA]

    // Known addresses
    static let addrPC: UInt8    = 0x20
    static let addrBLE: UInt8   = 0x21
    static let addrMaster: UInt8 = 0x23

    // Commands
    static let cmdRead: UInt8  = 0x01
    static let cmdWrite: UInt8 = 0x03

    // Attribute registers (ESC)
    static let attrSpeed: UInt8      = 0x64  // km/h * 1000
    static let attrBattery: UInt8    = 0x22  // SoC %
    static let attrErrorCode: UInt8  = 0x1B
    static let attrTemp: UInt8       = 0x68  // °C * 10
    static let attrTripMileage: UInt8 = 0x18 // m
    static let attrTotalMileage: UInt8 = 0x29 // m
    static let attrRemainingKm: UInt8 = 0x25

    static func makeReadFrame(src: UInt8 = addrPC, dst: UInt8 = addrMaster, attr: UInt8, length: UInt8 = 2) -> Data {
        var payload: [UInt8] = [attr, length]
        return frame(src: src, dst: dst, cmd: cmdRead, payload: payload)
    }

    static func frame(src: UInt8, dst: UInt8, cmd: UInt8, payload: [UInt8]) -> Data {
        let len = UInt8(payload.count + 2) // +2 for cmd + dst count as part of body
        var body: [UInt8] = [len, src, dst, cmd] + payload
        let crc = crc16(body)
        var packet: [UInt8] = header + body + [UInt8(crc & 0xFF), UInt8((crc >> 8) & 0xFF)]
        return Data(packet)
    }

    static func crc16(_ data: [UInt8]) -> UInt16 {
        var crc: UInt16 = 0
        for byte in data { crc = crc &+ UInt16(byte) }
        return crc ^ 0xFFFF
    }

    // Parse a response frame — returns nil if invalid
    static func parseFrame(_ data: Data) -> (src: UInt8, dst: UInt8, cmd: UInt8, attr: UInt8, payload: Data)? {
        let bytes = [UInt8](data)
        guard bytes.count >= 7,
              bytes[0] == 0x55, bytes[1] == 0xAA else { return nil }
        let len = Int(bytes[2])
        guard bytes.count >= 2 + len + 2 else { return nil }
        let src = bytes[3]
        let dst = bytes[4]
        let cmd = bytes[5]
        let attr = bytes[6]
        let payloadEnd = 7 + max(0, len - 4)
        guard payloadEnd <= bytes.count - 2 else { return nil }
        let payload = Data(bytes[7..<payloadEnd])
        return (src, dst, cmd, attr, payload)
    }

    static func parseUInt16(_ data: Data, offset: Int = 0) -> UInt16? {
        guard data.count >= offset + 2 else { return nil }
        return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    static func parseUInt32(_ data: Data, offset: Int = 0) -> UInt32? {
        guard data.count >= offset + 4 else { return nil }
        let lo = UInt32(data[offset]) | (UInt32(data[offset + 1]) << 8)
        let hi = UInt32(data[offset + 2]) | (UInt32(data[offset + 3]) << 8)
        return lo | (hi << 16)
    }
}

struct ScooterTelemetry {
    var speedKmh: Double = 0
    var batteryPercent: Int = 0
    var tempCelsius: Double = 0
    var tripMeters: Int = 0
    var totalKm: Double = 0
    var remainingKm: Double = 0
    var errorCode: Int = 0
}
