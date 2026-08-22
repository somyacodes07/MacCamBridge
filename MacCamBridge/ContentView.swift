import SwiftUI
import Combine
import Network

enum AppMode: String, CaseIterable, Identifiable {
    case sender = "📷 Camera Sender"
    case receiver = "📺 Camera Receiver"
    var id: String { self.rawValue }
}

struct ContentView: View {

    @StateObject private var camera = CameraManager()
    @StateObject private var receiver = StreamReceiver()

    @State private var selectedMode: AppMode = .sender
    @State private var receiverIP: String = "192.168.1.45"
    @State private var receiverPort: String = "8080"

    var body: some View {

        VStack(spacing: 0) {

            // Header Navigation & Mode Picker
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color(red: 16/255, green: 185/255, blue: 129/255))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("MacCam Bridge")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text(selectedMode == .sender ? "macOS Camera Broadcast Sender" : "macOS Camera Receiver")
                            .font(.caption)
                            .foregroundColor(Color.gray)
                    }
                }

                Spacer()

                Picker("Mode", selection: $selectedMode) {
                    ForEach(AppMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
            }
            .padding()
            .background(Color(red: 9/255, green: 9/255, blue: 11/255))
            .border(width: 1, edges: [.bottom], color: Color.white.opacity(0.08))

            // Main Content Area
            if selectedMode == .sender {
                senderView
            } else {
                receiverView
            }
        }
        .background(Color.black)
        .frame(minWidth: 780, minHeight: 600)
    }

    // MARK: - Sender View

    private var senderView: some View {
        VStack(spacing: 16) {
            ZStack {
                CameraPreview(session: camera.session)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )

                if !camera.isRunning {
                    VStack(spacing: 12) {
                        Image(systemName: "video.slash.fill")
                            .font(.system(size: 48))
                            .foregroundColor(Color.gray)

                        Text("Camera stream stopped")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                }
            }
            .padding()

            HStack {
                StreamStatusView(server: camera.streamServer)

                Spacer()

                if !camera.isRunning {
                    Button(action: { camera.start() }) {
                        Label("Start Camera", systemImage: "play.fill")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 16/255, green: 185/255, blue: 129/255))
                } else {
                    Button(action: { camera.stop() }) {
                        Label("Stop Camera", systemImage: "stop.fill")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
            .padding()
            .background(Color(red: 18/255, green: 18/255, blue: 20/255))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding([.horizontal, .bottom])
        }
    }

    // MARK: - Receiver View

    private var receiverView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("SENDER IP ADDRESS")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(Color.gray)

                    TextField("192.168.1.45", text: $receiverIP)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(Color(red: 24/255, green: 24/255, blue: 27/255))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("PORT")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(Color.gray)

                    TextField("8080", text: $receiverPort)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(Color(red: 24/255, green: 24/255, blue: 27/255))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .frame(width: 90)
                }

                Spacer()

                if !receiver.isConnected {
                    Button(action: {
                        if let port = UInt16(receiverPort) {
                            receiver.connect(ip: receiverIP, port: port)
                        }
                    }) {
                        Label("Connect Stream", systemImage: "play.fill")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 16/255, green: 185/255, blue: 129/255))
                } else {
                    Button(action: { receiver.disconnect() }) {
                        Label("Disconnect", systemImage: "stop.fill")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
            .padding()
            .background(Color(red: 18/255, green: 18/255, blue: 20/255))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding([.horizontal, .top])

            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )

                if !receiver.isConnected {
                    VStack(spacing: 12) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 48))
                            .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))

                        Text("Ready to receive stream")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("Enter camera sender IP and port above to connect")
                            .font(.caption)
                            .foregroundColor(Color.gray)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))

                        Text(receiver.statusText)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
            }
            .padding([.horizontal, .bottom])
        }
    }
}

private struct StreamStatusView: View {

    @ObservedObject var server: StreamServer

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if server.isRunning {
                Text("● Server active on \(server.localIP):\(server.port)")
                    .foregroundStyle(Color(red: 16/255, green: 185/255, blue: 129/255))
                    .fontWeight(.bold)

                Text("\(server.clientCount) client(s) connected")
                    .foregroundStyle(Color.gray)
                    .font(.caption)
            } else {
                Text("● Stream server stopped")
                    .foregroundStyle(.red)
            }
        }
    }
}

extension View {
    func border(width: CGFloat, edges: [Edge], color: Color) -> some View {
        overlay(EdgeBorder(width: width, edges: edges).foregroundColor(color))
    }
}

struct EdgeBorder: Shape {
    var width: CGFloat
    var edges: [Edge]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for edge in edges {
            var x: CGFloat {
                switch edge {
                case .top, .bottom, .leading: return rect.minX
                case .trailing: return rect.maxX - width
                }
            }
            var y: CGFloat {
                switch edge {
                case .top, .leading, .trailing: return rect.minY
                case .bottom: return rect.maxY - width
                }
            }
            var w: CGFloat {
                switch edge {
                case .top, .bottom: return rect.width
                case .leading, .trailing: return width
                }
            }
            var h: CGFloat {
                switch edge {
                case .top, .bottom: return width
                case .leading, .trailing: return rect.height
                }
            }
            path.addRect(CGRect(x: x, y: y, width: w, height: h))
        }
        return path
    }
}

#Preview {
    ContentView()
}

final class StreamReceiver: ObservableObject {

    @Published var isConnected = false
    @Published var statusText = "Disconnected"
    @Published var frameRate: Int = 0
    @Published var bytesReceived: Double = 0

    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.maccambridge.receiver")
    private var totalBytes: Int64 = 0

    func connect(ip: String, port: UInt16) {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return }
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(ip), port: nwPort)

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
                    self?.statusText = "Connected to \(ip):\(port)"
                case .failed(let error):
                    self?.isConnected = false
                    self?.statusText = "Connection Failed: \(error.localizedDescription)"
                case .cancelled:
                    self?.isConnected = false
                    self?.statusText = "Disconnected"
                default:
                    break
                }
            }
        }

        conn.start(queue: queue)
        receiveNextMessage(on: conn)
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        DispatchQueue.main.async {
            self.isConnected = false
            self.statusText = "Disconnected"
        }
    }

    private func receiveNextMessage(on conn: NWConnection) {
        conn.receiveMessage { [weak self, weak conn] data, context, isComplete, error in
            guard let self = self, let conn = conn else { return }

            if let data = data {
                self.totalBytes += Int64(data.count)
                DispatchQueue.main.async {
                    self.bytesReceived = Double(self.totalBytes) / (1024.0 * 1024.0)
                }
            }

            if error == nil && conn.state == .ready {
                self.receiveNextMessage(on: conn)
            }
        }
    }
}
