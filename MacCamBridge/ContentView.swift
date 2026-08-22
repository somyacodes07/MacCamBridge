import SwiftUI
import Combine
import Network

enum AppMode: String, CaseIterable, Identifiable {
    case sender = "Camera Sender"
    case receiver = "Camera Receiver"
    var id: String { self.rawValue }

    var iconName: String {
        switch self {
        case .sender: return "video.fill"
        case .receiver: return "macwindow.on.rectangle"
        }
    }
}

struct ContentView: View {

    @StateObject private var camera = CameraManager()
    @StateObject private var receiver = StreamReceiver()
    @StateObject private var bonjour = BonjourBrowser()

    @State private var selectedMode: AppMode = .sender
    @State private var receiverIP: String = "192.168.1.45"
    @State private var receiverPort: String = "8080"
    @State private var copiedIPAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar

            // Main View Content
            if selectedMode == .sender {
                senderView
            } else {
                receiverView
            }
        }
        .background(Color(red: 12/255, green: 12/255, blue: 14/255))
        .frame(minWidth: 840, minHeight: 620)
        .onAppear {
            bonjour.startBrowsing()
        }
        .onDisappear {
            bonjour.stopBrowsing()
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(
                            colors: [Color(red: 16/255, green: 185/255, blue: 129/255), Color(red: 5/255, green: 150/255, blue: 105/255)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 36, height: 36)

                    Image(systemName: "video.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("MacCam Bridge")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text(selectedMode == .sender ? "macOS Camera Broadcast Sender" : "macOS Camera Stream Receiver")
                        .font(.caption)
                        .foregroundColor(Color.gray)
                }
            }

            Spacer()

            // Custom Segmented Mode Selector (No Emoji & No Label Wrapping Bug)
            HStack(spacing: 4) {
                ForEach(AppMode.allCases) { mode in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedMode = mode
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: mode.iconName)
                                .font(.system(size: 13, weight: .semibold))

                            Text(mode.rawValue)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            selectedMode == mode ?
                            Color(red: 39/255, green: 39/255, blue: 42/255) :
                            Color.clear
                        )
                        .foregroundColor(selectedMode == mode ? .white : Color.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(Color(red: 24/255, green: 24/255, blue: 27/255))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(red: 18/255, green: 18/255, blue: 20/255))
        .border(width: 1, edges: [.bottom], color: Color.white.opacity(0.08))
    }

    // MARK: - Sender View

    private var senderView: some View {
        VStack(spacing: 16) {
            // Live Preview Card
            ZStack {
                CameraPreview(session: camera.session)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )

                if !camera.isRunning {
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.05))
                                .frame(width: 80, height: 80)

                            Image(systemName: "video.slash.fill")
                                .font(.system(size: 36))
                                .foregroundColor(Color.gray)
                        }

                        VStack(spacing: 4) {
                            Text("Camera Broadcast Off")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)

                            Text("Click 'Start Camera' below to broadcast 1080p stream over network")
                                .font(.caption)
                                .foregroundColor(Color.gray)
                        }
                    }
                } else {
                    VStack {
                        HStack {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color(red: 16/255, green: 185/255, blue: 129/255))
                                    .frame(width: 8, height: 8)

                                Text("LIVE BROADCAST")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.black.opacity(0.75))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))

                            Spacer()

                            Text("H.264 • 1080p30")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.black.opacity(0.75))
                                .clipShape(Capsule())
                        }
                        .padding(14)

                        Spacer()
                    }
                }
            }
            .padding([.horizontal, .top], 16)

            // Server Status Bar & Control Action Button
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    if camera.streamServer.isRunning {
                        HStack(spacing: 12) {
                            HStack(spacing: 6) {
                                Image(systemName: "network")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))

                                Text("\(camera.streamServer.localIP):\(camera.streamServer.port)")
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.white)

                                Button(action: {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString("\(camera.streamServer.localIP):\(camera.streamServer.port)", forType: .string)
                                    copiedIPAlert = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        copiedIPAlert = false
                                    }
                                }) {
                                    Image(systemName: copiedIPAlert ? "checkmark" : "doc.on.doc")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(copiedIPAlert ? Color(red: 16/255, green: 185/255, blue: 129/255) : Color.gray)
                                }
                                .buttonStyle(.plain)
                                .help("Copy Server Address")
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(red: 24/255, green: 24/255, blue: 27/255))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            HStack(spacing: 6) {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.gray)

                                Text("\(camera.streamServer.clientCount) client(s)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color.gray)
                            }
                        }
                    } else {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)

                            Text("Stream server stopped")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.red)
                        }
                    }
                }

                Spacer()

                if !camera.isRunning {
                    Button(action: { camera.start() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 13, weight: .bold))

                            Text("Start Camera")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(LinearGradient(
                            colors: [Color(red: 16/255, green: 185/255, blue: 129/255), Color(red: 5/255, green: 150/255, blue: 105/255)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: { camera.stop() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 13, weight: .bold))

                            Text("Stop Camera")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color(red: 239/255, green: 68/255, blue: 68/255).opacity(0.2))
                        .foregroundColor(Color(red: 248/255, green: 113/255, blue: 113/255))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(red: 239/255, green: 68/255, blue: 68/255).opacity(0.4), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(Color(red: 18/255, green: 18/255, blue: 20/255))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .padding([.horizontal, .bottom], 16)
        }
    }

    // MARK: - Receiver View

    private var receiverView: some View {
        VStack(spacing: 16) {
            // Connection Bar (Auto-Discovery & Manual IP Input)
            VStack(spacing: 12) {
                // Auto-Discovered Senders section
                if !bonjour.discoveredSenders.isEmpty {
                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))

                            Text("DISCOVERED CAMERAS:")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color.gray)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(bonjour.discoveredSenders) { sender in
                                    Button(action: {
                                        receiver.connect(endpoint: sender.endpoint)
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "video.fill")
                                                .font(.system(size: 11))

                                            Text(sender.name)
                                                .font(.system(size: 12, weight: .semibold))
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color(red: 39/255, green: 39/255, blue: 42/255))
                                        .foregroundColor(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.5), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Spacer()
                    }
                    .padding(.bottom, 4)

                    Divider()
                        .background(Color.white.opacity(0.08))
                }

                // Manual Input Bar
                HStack(spacing: 16) {
                    HStack(spacing: 10) {
                        Image(systemName: "network")
                            .font(.system(size: 14))
                            .foregroundColor(Color.gray)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("SENDER IP ADDRESS")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color.gray)

                            TextField("192.168.1.45", text: $receiverIP)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(red: 24/255, green: 24/255, blue: 27/255))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    HStack(spacing: 8) {
                        Image(systemName: "number")
                            .font(.system(size: 14))
                            .foregroundColor(Color.gray)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("PORT")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color.gray)

                            TextField("8080", text: $receiverPort)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)
                                .frame(width: 60)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(red: 24/255, green: 24/255, blue: 27/255))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Spacer()

                    if !receiver.isConnected {
                        Button(action: {
                            if let port = UInt16(receiverPort) {
                                receiver.connect(ip: receiverIP, port: port)
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 13, weight: .bold))

                                Text("Connect Stream")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(LinearGradient(
                                colors: [Color(red: 16/255, green: 185/255, blue: 129/255), Color(red: 5/255, green: 150/255, blue: 105/255)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(color: Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.3), radius: 6, x: 0, y: 3)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: { receiver.disconnect() }) {
                            HStack(spacing: 8) {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 13, weight: .bold))

                                Text("Disconnect")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color(red: 239/255, green: 68/255, blue: 68/255).opacity(0.2))
                            .foregroundColor(Color(red: 248/255, green: 113/255, blue: 113/255))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(red: 239/255, green: 68/255, blue: 68/255).opacity(0.4), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
            .background(Color(red: 18/255, green: 18/255, blue: 20/255))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .padding([.horizontal, .top], 16)

            // Video Playback Area & Hardware Decoder Output
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )

                if !receiver.isConnected {
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.05))
                                .frame(width: 80, height: 80)

                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 36))
                                .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                        }

                        VStack(spacing: 4) {
                            Text("Ready to Receive Stream")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)

                            Text("Select an auto-discovered camera or enter camera sender IP and port above")
                                .font(.caption)
                                .foregroundColor(Color.gray)
                        }
                    }
                } else {
                    // Live decoded video frame display using AVSampleBufferDisplayLayer
                    SampleBufferDisplayView(sampleBuffer: receiver.latestSampleBuffer)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Overlay receiver metrics
                    VStack {
                        HStack {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color(red: 16/255, green: 185/255, blue: 129/255))
                                    .frame(width: 8, height: 8)

                                Text("CONNECTED")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.black.opacity(0.75))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))

                            Spacer()

                            HStack(spacing: 12) {
                                Text("\(receiver.frameRate) FPS")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))

                                Text(String(format: "%.2f Mbps", receiver.throughputMbps))
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))

                                Text(String(format: "%.1f MB", receiver.bytesReceived))
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color.black.opacity(0.75))
                            .clipShape(Capsule())
                        }
                        .padding(14)

                        Spacer()
                    }
                }
            }
            .padding([.horizontal, .bottom], 16)
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
