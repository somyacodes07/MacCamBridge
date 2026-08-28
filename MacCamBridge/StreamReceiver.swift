import Foundation
import Network
import Combine
import CoreMedia

final class StreamReceiver: ObservableObject {

    @Published var isConnected = false
    @Published var isConnecting = false
    @Published var statusText = "Disconnected"
    @Published var errorMessage: String?
    @Published var frameRate: Int = 0
    @Published var throughputMbps: Double = 0.0
    @Published var bytesReceived: Double = 0.0
    @Published var resolutionText: String = "1920x1080"
    @Published var latestSampleBuffer: CMSampleBuffer?
    @Published var currentEndpointDescription: String = ""

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

    func connect(endpoint: NWEndpoint, customDescription: String? = nil) {
        disconnect()

        let endpointDesc: String
        if let custom = customDescription {
            endpointDesc = custom
        } else {
            switch endpoint {
            case .hostPort(let host, let port):
                endpointDesc = "\(host):\(port)"
            case .service(let name, _, _, _):
                endpointDesc = name
            default:
                endpointDesc = "\(endpoint)"
            }
        }

        DispatchQueue.main.async {
            self.isConnecting = true
            self.isConnected = false
            self.errorMessage = nil
            self.currentEndpointDescription = endpointDesc
            self.statusText = "Connecting to \(endpointDesc)..."
        }

        let parameters = NWParameters.tcp
        if let tcpOptions = parameters.defaultProtocolStack.transportProtocol as? NWProtocolTCP.Options {
            tcpOptions.noDelay = true
        }

        let webSocketOptions = NWProtocolWebSocket.Options()
        parameters.defaultProtocolStack.applicationProtocols.insert(webSocketOptions, at: 0)

        let conn = NWConnection(to: endpoint, using: parameters)
        self.connection = conn

        conn.stateUpdateHandler = { [weak self, weak conn] state in
            guard let self = self, let conn = conn else { return }
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self.isConnected = true
                    self.isConnecting = false
                    self.errorMessage = nil
                    self.statusText = "Connected to \(endpointDesc)"
                    self.startStatsTimer()
                    self.queue.async {
                        self.receiveNextMessage(on: conn)
                    }
                case .failed(let error):
                    self.isConnected = false
                    self.isConnecting = false
                    self.errorMessage = error.localizedDescription
                    self.statusText = "Connection Failed: \(error.localizedDescription)"
                    self.stopStatsTimer()
                case .waiting(let error):
                    self.statusText = "Waiting: \(error.localizedDescription)"
                case .cancelled:
                    self.isConnected = false
                    self.isConnecting = false
                    self.statusText = "Disconnected"
                    self.stopStatsTimer()
                default:
                    break
                }
            }
        }

        conn.start(queue: queue)
    }

    func connect(ip: String, port: UInt16) {
        var cleanIP = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanIP.hasPrefix("ws://") {
            cleanIP = String(cleanIP.dropFirst(5))
        } else if cleanIP.hasPrefix("wss://") {
            cleanIP = String(cleanIP.dropFirst(6))
        } else if cleanIP.hasPrefix("http://") {
            cleanIP = String(cleanIP.dropFirst(7))
        } else if cleanIP.hasPrefix("https://") {
            cleanIP = String(cleanIP.dropFirst(8))
        }

        var targetPort = port
        if let colonIndex = cleanIP.firstIndex(of: ":") {
            let hostPart = String(cleanIP[..<colonIndex])
            let portPart = String(cleanIP[cleanIP.index(after: colonIndex)...])
            cleanIP = hostPart
            if let parsedPort = UInt16(portPart) {
                targetPort = parsedPort
            }
        }

        guard !cleanIP.isEmpty else {
            DispatchQueue.main.async {
                self.errorMessage = "Please enter a valid IP address."
                self.statusText = "Invalid IP Address"
            }
            return
        }

        guard let nwPort = NWEndpoint.Port(rawValue: targetPort) else {
            DispatchQueue.main.async {
                self.errorMessage = "Invalid Port: \(targetPort)"
                self.statusText = "Invalid Port"
            }
            return
        }

        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(cleanIP), port: nwPort)
        connect(endpoint: endpoint, customDescription: "\(cleanIP):\(targetPort)")
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        decoder.invalidate()
        stopStatsTimer()

        DispatchQueue.main.async {
            self.isConnected = false
            self.isConnecting = false
            self.statusText = "Disconnected"
            self.frameRate = 0
            self.throughputMbps = 0.0
            self.latestSampleBuffer = nil
            self.currentEndpointDescription = ""
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

            if error == nil && self.connection === conn {
                switch conn.state {
                case .ready, .preparing, .setup:
                    self.receiveNextMessage(on: conn)
                default:
                    break
                }
            } else if let error = error {
                print("Receiver receive error: \(error)")
                DispatchQueue.main.async {
                    if self.connection === conn {
                        self.errorMessage = error.localizedDescription
                        self.statusText = "Receive Error: \(error.localizedDescription)"
                    }
                }
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
        guard offset + 4 <= count else { return 0 }
        let b0 = UInt32(self[offset])
        let b1 = UInt32(self[offset + 1])
        let b2 = UInt32(self[offset + 2])
        let b3 = UInt32(self[offset + 3])
        return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
    }

    func readInt32(at offset: Int) -> Int32 {
        return Int32(bitPattern: readUInt32(at: offset))
    }

    func readInt64(at offset: Int) -> Int64 {
        guard offset + 8 <= count else { return 0 }
        let high = UInt64(readUInt32(at: offset))
        let low = UInt64(readUInt32(at: offset + 4))
        let val = (high << 32) | low
        return Int64(bitPattern: val)
    }
}
