import Foundation
import CoreMedia

enum StreamPacketType: UInt8 {
    case configuration = 1
    case keyFrame = 2
    case deltaFrame = 3
}

struct StreamPacket {

    static let magic: UInt32 = 0x4D434231 // "MCB1"
    static let version: UInt8 = 1

    let type: StreamPacketType
    let pts: CMTime
    let payload: Data

    func encoded() -> Data {

        var data = Data()

        data.appendUInt32(StreamPacket.magic)
        data.append(StreamPacket.version)
        data.append(type.rawValue)
        data.appendUInt16(0)

        data.appendUInt32(
            UInt32(payload.count)
        )

        data.appendInt64(pts.value)
        data.appendInt32(pts.timescale)

        data.append(payload)

        return data
    }

    static func configurationPayload(
        sps: Data,
        pps: Data
    ) -> Data {

        var data = Data()

        data.appendUInt32(
            UInt32(sps.count)
        )

        data.append(sps)

        data.appendUInt32(
            UInt32(pps.count)
        )

        data.append(pps)

        return data
    }
}

extension Data {

    mutating func appendUInt16(
        _ value: UInt16
    ) {

        var bigEndian = value.bigEndian

        Swift.withUnsafeBytes(of: &bigEndian) {
            append(contentsOf: $0)
        }
    }

    mutating func appendUInt32(
        _ value: UInt32
    ) {

        var bigEndian = value.bigEndian

        Swift.withUnsafeBytes(of: &bigEndian) {
            append(contentsOf: $0)
        }
    }

    mutating func appendInt32(
        _ value: Int32
    ) {

        var bigEndian = value.bigEndian

        Swift.withUnsafeBytes(of: &bigEndian) {
            append(contentsOf: $0)
        }
    }

    mutating func appendInt64(
        _ value: Int64
    ) {

        var bigEndian = value.bigEndian

        Swift.withUnsafeBytes(of: &bigEndian) {
            append(contentsOf: $0)
        }
    }
}
