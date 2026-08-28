import Foundation
import Network
import Combine

final class StreamServer: NSObject, ObservableObject, EncodedFrameSink {

    @Published private(set) var isRunning = false
    @Published private(set) var port: UInt16 = 8080
    @Published private(set) var clientCount = 0
    @Published private(set) var localIP: String = "127.0.0.1"
    @Published private(set) var usbIP: String = ""

    private let queue = DispatchQueue(
        label: "com.maccambridge.stream.server"
    )

    private var listener: NWListener?

    private var clients: [UUID: Client] = [:]

    private var latestSPS: Data?
    private var latestPPS: Data?

    private var frameCount = 0

    static func getAllLocalIPAddresses() -> (wifi: String, usb: String) {
        var wifiIP = "127.0.0.1"
        var usbIP = ""
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return (wifiIP, usbIP)
        }
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            guard let ifaAddr = ptr.pointee.ifa_addr else { continue }
            let addr = ifaAddr.pointee
            if (flags & (IFF_UP | IFF_RUNNING)) != 0 && (flags & IFF_LOOPBACK) == 0 {
                if addr.sa_family == UInt8(AF_INET) {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(ifaAddr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                        let ip = String(cString: hostname)
                        if ip.hasPrefix("169.254.") {
                            usbIP = ip
                        } else if !ip.hasPrefix("127.") {
                            wifiIP = ip
                        }
                    }
                }
            }
        }
        freeifaddrs(ifaddr)
        return (wifiIP, usbIP)
    }

    func start(
        port preferredPort: UInt16 = 8080
    ) {

        queue.async { [weak self] in

            guard let self = self else {
                return
            }

            guard self.listener == nil else {
                return
            }

            for p in preferredPort...(preferredPort + 10) {

                guard
                    let nwPort = NWEndpoint.Port(
                        rawValue: p
                    )
                else {
                    continue
                }

                do {
                    let parameters = NWParameters.tcp
                    parameters.allowLocalEndpointReuse = true

                    if let tcpOptions = parameters.defaultProtocolStack.transportProtocol as? NWProtocolTCP.Options {
                        tcpOptions.noDelay = true
                    }

                    let webSocketOptions = NWProtocolWebSocket.Options()
                    parameters.defaultProtocolStack.applicationProtocols.insert(
                        webSocketOptions,
                        at: 0
                    )

                    let listener = try NWListener(
                        using: parameters,
                        on: nwPort
                    )

                    listener.service = NWListener.Service(
                        name: Host.current().localizedName ?? "MacBook Camera",
                        type: "_maccambridge._tcp"
                    )

                    listener.newConnectionHandler = {
                        [weak self] connection in

                        self?.handleNewConnection(
                            connection
                        )
                    }

                    listener.stateUpdateHandler = {
                        [weak self] state in

                        self?.handleListenerState(
                            state
                        )
                    }

                    self.listener = listener

                    listener.start(
                        queue: self.queue
                    )

                    print("Stream listener binding on port \(p)")
                    break

                } catch {

                    print("Port \(p) in use or failed, trying next port...")
                }
            }
        }
    }

    func stop() {

        queue.async { [weak self] in

            guard let self = self else {
                return
            }

            self.listener?.cancel()
            self.listener = nil

            for client in self.clients.values {

                client.connection.cancel()
            }

            self.clients.removeAll()

            DispatchQueue.main.async {

                self.isRunning = false
                self.clientCount = 0
            }

            print(
                "Stream server stopped"
            )
        }
    }

    func handleEncodedFrame(
        _ frame: EncodedFrame
    ) {

        queue.async { [weak self] in

            guard let self = self else {
                return
            }

            self.frameCount += 1

            if
                frame.type == .keyFrame,
                let sps = frame.sps,
                let pps = frame.pps {

                self.latestSPS = sps
                self.latestPPS = pps
            }

            guard !self.clients.isEmpty else {
                return
            }

            switch frame.type {

            case .configuration:

                if
                    let sps = frame.sps,
                    let pps = frame.pps {

                    self.latestSPS = sps
                    self.latestPPS = pps
                }

            case .keyFrame:

                self.sendKeyFrame(
                    frame
                )

            case .deltaFrame:

                self.sendDeltaFrame(
                    frame
                )
            }
        }
    }

    private func handleListenerState(
        _ state: NWListener.State
    ) {

        switch state {

        case .ready:

            let actualPort =
                listener?.port?.rawValue ?? 8080

            let (wifi, usb) = StreamServer.getAllLocalIPAddresses()

            DispatchQueue.main.async {

                self.port = actualPort
                self.localIP = wifi
                self.usbIP = usb
                self.isRunning = true
            }

            print(
                "Stream server running on Wi-Fi: \(wifi):\(actualPort), USB-C: \(usb):\(actualPort)"
            )

        case .failed(let error):

            print(
                "Stream server failed: \(error)"
            )

            listener?.cancel()
            listener = nil

            DispatchQueue.main.async {

                self.isRunning = false
            }

        case .cancelled:

            DispatchQueue.main.async {

                self.isRunning = false
            }

        default:
            break
        }
    }

    private func handleNewConnection(
        _ connection: NWConnection
    ) {

        let id = UUID()

        let client = Client(
            id: id,
            connection: connection,
            server: self
        )

        clients[id] = client

        connection.stateUpdateHandler = {
            [weak self, weak client] state in

            guard let self = self else {
                return
            }

            self.queue.async {

                switch state {

                case .ready:

                    print(
                        "Client connected: \(id)"
                    )

                    client?.isConnected = true

                    if let client = client {
                        self.startReceive(for: client)
                    }

                    self.updateClientCount()

                case .failed(let error):

                    print(
                        "Client failed: \(error)"
                    )

                    self.removeClient(
                        id
                    )

                case .cancelled:

                    self.removeClient(
                        id
                    )

                default:
                    break
                }
            }
        }

        connection.start(
            queue: queue
        )
    }

    private func startReceive(for client: Client) {
        client.connection.receiveMessage { [weak self, weak client] data, context, isComplete, error in
            guard let self = self, let client = client else { return }

            if let error = error {
                print("Client \(client.id) receive error: \(error)")
                self.queue.async {
                    self.removeClient(client.id)
                }
                return
            }

            if client.connection.state == .ready {
                self.startReceive(for: client)
            }
        }
    }

    private func removeClient(
        _ id: UUID
    ) {

        guard clients.removeValue(
            forKey: id
        ) != nil else {
            return
        }

        print(
            "Client disconnected: \(id)"
        )

        updateClientCount()
    }

    private func updateClientCount() {

        let count = clients.count

        DispatchQueue.main.async {

            self.clientCount = count
        }
    }

    private func sendKeyFrame(
        _ frame: EncodedFrame
    ) {

        guard
            let sps = latestSPS,
            let pps = latestPPS
        else {

            print(
                "Skipping keyframe: SPS/PPS not available"
            )

            return
        }

        for client in clients.values {

            guard client.isConnected else {
                continue
            }

            if !client.isStreaming {

                let configurationPayload =
                    StreamPacket.configurationPayload(
                        sps: sps,
                        pps: pps
                    )

                let configurationPacket =
                    StreamPacket(
                        type: .configuration,
                        pts: frame.pts,
                        payload: configurationPayload
                    )

                send(
                    configurationPacket,
                    to: client
                )

                client.isStreaming = true

                print(
                    "Client \(client.id) received configuration"
                )
            }

            let keyFramePacket =
                StreamPacket(
                    type: .keyFrame,
                    pts: frame.pts,
                    payload: frame.data
                )

            send(
                keyFramePacket,
                to: client
            )
        }
    }

    private func sendDeltaFrame(
        _ frame: EncodedFrame
    ) {

        let packet =
            StreamPacket(
                type: .deltaFrame,
                pts: frame.pts,
                payload: frame.data
            )

        for client in clients.values {

            guard
                client.isConnected,
                client.isStreaming
            else {
                continue
            }

            send(
                packet,
                to: client
            )
        }
    }

    func handleClientError(_ id: UUID) {
        queue.async { [weak self] in
            self?.removeClient(id)
        }
    }

    private func send(
        _ packet: StreamPacket,
        to client: Client
    ) {
        client.enqueue(packet: packet)
    }
}

private final class Client {

    let id: UUID
    let connection: NWConnection

    var isConnected = false
    var isStreaming = false

    private var sendBuffer: [Data] = []
    private var isSending = false
    private let sendQueue = DispatchQueue(label: "com.maccambridge.client.send")

    weak var server: StreamServer?

    init(
        id: UUID,
        connection: NWConnection,
        server: StreamServer? = nil
    ) {
        self.id = id
        self.connection = connection
        self.server = server
    }

    func enqueue(packet: StreamPacket) {
        let data = packet.encoded()
        sendQueue.async { [weak self] in
            guard let self = self else { return }

            // Prevent P-frame reference corruption during network congestion:
            // If queue builds up, clear pending stale frames and request fresh Keyframe re-sync
            if self.sendBuffer.count > 40 {
                self.sendBuffer.removeAll()
                self.isStreaming = false
            }

            self.sendBuffer.append(data)
            self.processQueue()
        }
    }

    private func processQueue() {
        guard !isSending, !sendBuffer.isEmpty else {
            return
        }

        isSending = true
        let data = sendBuffer.removeFirst()

        let metadata = NWProtocolWebSocket.Metadata(opcode: .binary)
        let context = NWConnection.ContentContext(
            identifier: "binaryFrame",
            metadata: [metadata]
        )

        connection.send(
            content: data,
            contentContext: context,
            isComplete: true,
            completion: .contentProcessed { [weak self] error in
                guard let self = self else { return }

                self.sendQueue.async {
                    self.isSending = false

                    if let error = error {
                        print("Send error for client \(self.id): \(error)")
                        self.server?.handleClientError(self.id)
                    } else {
                        self.processQueue()
                    }
                }
            }
        )
    }
}
