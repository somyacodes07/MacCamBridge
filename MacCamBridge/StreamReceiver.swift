import Foundation
import Network
import Combine
import CoreMedia

final class StreamReceiver: ObservableObject {

    @Published var isConnected = false
    @Published var statusText = "Disconnected"
    @Published var frameRate: Int = 0
    @Published var throughputMbps: Double = 0.0
    @Published var bytesReceived: Double = 0.0
    @Published var resolutionText: String = "1920x1080"
    @Published var latestSampleBuffer: CMSampleBuffer?

    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.maccambridge.receiver")
    private var totalBytes: Int64 = 0

    private var frameCounter: Int = 0
    private var bytesInWindow: Int64 = 0
    private var statsTimer: Timer?

    private let decoder = H264Decoder()

    init() {
        decoder.onDecodedFrame = { [weak self] buffer in
            DispatchQueue.main.async {
                self?.latestSampleBuffer = buffer
            }
        }
    }

    func connect(endpoint: NWEndpoint) {
        let parameters = NWParameters.tcp
        let webSocketOptions = NWProtocolWebSocket.Options()
        parameters.defaultProtocolStack.applicationProtocols.insert(webSocketOptions, at: 0)

        let conn = NWConnection(to: endpoint, using: parameters)
        self.connection = conn

        conn.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isConnected = true
                    self?.statusText = "Connected to \(endpoint)"
                    self?.startStatsTimer()
                case .failed(let error):
                    self?.isConnected = false
                    self?.statusText = "Connection Failed: \(error.localizedDescription)"
                    self?.stopStatsTimer()
                case .cancelled:
                    self?.isConnected = false
                    self?.statusText = "Disconnected"
                    self?.stopStatsTimer()
                default:
                    break
                }
            }
        }

        conn.start(queue: queue)
        receiveNextMessage(on: conn)
    }

    func connect(ip: String, port: UInt16) {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return }
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(ip), port: nwPort)
        connect(endpoint: endpoint)
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        decoder.invalidate()
        stopStatsTimer()

        DispatchQueue.main.async {
            self.isConnected = false
            self.statusText = "Disconnected"
            self.frameRate = 0
            self.throughputMbps = 0.0
            self.latestSampleBuffer = nil
        }
    }

    private func startStatsTimer() {
        stopStatsTimer()
        DispatchQueue.main.async {
            self.statsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.frameRate = self.frameCounter
                self.throughputMbps = (Double(self.bytesInWindow) * 8.0) / (1024.0 * 1024.0)

                self.frameCounter = 0
                self.bytesInWindow = 0
            }
        }
    }

    private func stopStatsTimer() {
        DispatchQueue.main.async {
            self.statsTimer?.invalidate()
            self.statsTimer = nil
        }
    }

    private func receiveNextMessage(on conn: NWConnection) {
        conn.receiveMessage { [weak self, weak conn] data, context, isComplete, error in
            guard let self = self, let conn = conn else { return }

            if let data = data, !data.isEmpty {
                self.totalBytes += Int64(data.count)
                self.bytesInWindow += Int64(data.count)

                DispatchQueue.main.async {
                    self.bytesReceived = Double(self.totalBytes) / (1024.0 * 1024.0)
                }

                self.processPacketData(data)
            }

            if error == nil && conn.state == .ready {
                self.receiveNextMessage(on: conn)
            }
        }
    }

    private func processPacketData(_ data: Data) {
        guard data.count >= 24 else { return }

        // Binary MCB1 Header layout:
        // Magic (4B), Version (1B), Type (1B), Reserved (2B), PayloadLen (4B), PTS Value (8B), PTS Timescale (4B)
        let magic = data.readUInt32(at: 0)
        guard magic == StreamPacket.magic else { return }

        let packetType = data[5]
        let payloadLen = Int(data.readUInt32(at: 8))
        let ptsValue = data.readInt64(at: 12)
        let ptsTimescale = data.readInt32(at: 20)

        guard data.count >= 24 + payloadLen else { return }
        let payload = data.subdata(in: 24..<(24 + payloadLen))
        let pts = CMTime(value: ptsValue, timescale: ptsTimescale)

        if packetType == StreamPacketType.configuration.rawValue {
            parseConfigurationPayload(payload)
        } else if packetType == StreamPacketType.keyFrame.rawValue || packetType == StreamPacketType.deltaFrame.rawValue {
            frameCounter += 1
            decoder.decode(nalData: payload, pts: pts)
        }
    }

    private func parseConfigurationPayload(_ payload: Data) {
        guard payload.count >= 8 else { return }
        let spsSize = Int(payload.readUInt32(at: 0))
        guard payload.count >= 4 + spsSize + 4 else { return }

        let sps = payload.subdata(in: 4..<(4 + spsSize))
        let ppsOffset = 4 + spsSize
        let ppsSize = Int(payload.readUInt32(at: ppsOffset))
        guard payload.count >= ppsOffset + 4 + ppsSize else { return }

        let pps = payload.subdata(in: (ppsOffset + 4)..<(ppsOffset + 4 + ppsSize))
        decoder.configure(sps: sps, pps: pps)
    }
}

private extension Data {
    func readUInt32(at offset: Int) -> UInt32 {
        let sub = self.subdata(in: offset..<(offset + 4))
        let value = sub.withUnsafeBytes { $0.load(as: UInt32.self) }
        return UInt32(bigEndian: value)
    }

    func readInt32(at offset: Int) -> Int32 {
        let sub = self.subdata(in: offset..<(offset + 4))
        let value = sub.withUnsafeBytes { $0.load(as: Int32.self) }
        return Int32(bigEndian: value)
    }

    func readInt64(at offset: Int) -> Int64 {
        let sub = self.subdata(in: offset..<(offset + 8))
        let value = sub.withUnsafeBytes { $0.load(as: Int64.self) }
        return Int64(bigEndian: value)
    }
}
