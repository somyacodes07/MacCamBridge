import Foundation
import Network
import Combine

final class StreamServer: NSObject, ObservableObject, EncodedFrameSink {

    @Published private(set) var isRunning = false
    @Published private(set) var port: UInt16 = 8080
    @Published private(set) var clientCount = 0

    private let queue = DispatchQueue(
        label: "com.maccambridge.stream.server"
    )

    private var listener: NWListener?

    private var clients: [UUID: Client] = [:]

    private var latestSPS: Data?
    private var latestPPS: Data?

    private var frameCount = 0

    func start(
        port: UInt16 = 8080
    ) {

        queue.async { [weak self] in

            guard let self = self else {
                return
            }

            guard self.listener == nil else {
                return
            }

            guard
                let nwPort = NWEndpoint.Port(
                    rawValue: port
                )
            else {
                print("Invalid server port")

                return
            }

            do {
                let parameters = NWParameters.tcp
                parameters.allowLocalEndpointReuse = true

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

            } catch {

                print(
                    "Failed to start stream server: \(error)"
                )
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

            DispatchQueue.main.async {

                self.port = actualPort
                self.isRunning = true
            }

            print(
                "Stream server running on port \(actualPort)"
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
            connection: connection
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

    private func send(
        _ packet: StreamPacket,
        to client: Client
    ) {

        let data = packet.encoded()

        client.connection.send(
            content: data,
            contentContext: .defaultMessage,
            isComplete: true,
            completion: .contentProcessed {
                [weak self, weak client] error in

                if let error = error {

                    print(
                        "Send failed: \(error)"
                    )

                    guard
                        let self = self,
                        let client = client
                    else {
                        return
                    }

                    self.queue.async {

                        self.removeClient(
                            client.id
                        )
                    }
                }
            }
        )
    }
}

private final class Client {

    let id: UUID
    let connection: NWConnection

    var isConnected = false
    var isStreaming = false

    init(
        id: UUID,
        connection: NWConnection
    ) {

        self.id = id
        self.connection = connection
    }
}
