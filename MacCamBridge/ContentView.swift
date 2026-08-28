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

            // Main Content Body
            if selectedMode == .sender {
                senderView
            } else {
                receiverView
            }
        }
        .background(Color.black)
        .frame(minWidth: 840, minHeight: 620)
        .onAppear {
            bonjour.startBrowsing()
        }
        .onDisappear {
            bonjour.stopBrowsing()
        }
    }

    // MARK: - Header Bar (Monochrome Black & White)

    private var headerBar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(red: 24/255, green: 24/255, blue: 27/255))
                        .frame(width: 38, height: 38)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )

                    Image("AppLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("MacCam Bridge")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)

                    Text(selectedMode == .sender ? "macOS Camera Broadcast Sender" : "macOS Camera Stream Receiver")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(red: 161/255, green: 161/255, blue: 170/255))
                }
            }

            Spacer()

            // Custom Segmented Mode Selector (Monochrome Pill Navigation)
            HStack(spacing: 4) {
                ForEach(AppMode.allCases) { mode in
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            selectedMode = mode
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: mode.iconName)
                                .font(.system(size: 12, weight: .semibold))

                            Text(mode.rawValue)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            selectedMode == mode ?
                            Color.white :
                            Color.clear
                        )
                        .foregroundColor(selectedMode == mode ? .black : Color(red: 161/255, green: 161/255, blue: 170/255))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(Color(red: 18/255, green: 18/255, blue: 20/255))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(red: 9/255, green: 9/255, blue: 11/255))
        .border(width: 1, edges: [.bottom], color: Color.white.opacity(0.08))
    }

    // MARK: - Sender View (Monochrome Black & White)

    private var senderView: some View {
        VStack(spacing: 16) {
            // Live Preview Container
            ZStack {
                CameraPreview(session: camera.session)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )

                if !camera.isRunning {
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.04))
                                .frame(width: 80, height: 80)
                                .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))

                            Image(systemName: "video.slash.fill")
                                .font(.system(size: 34))
                                .foregroundColor(Color(red: 113/255, green: 113/255, blue: 122/255))
                        }

                        VStack(spacing: 4) {
                            Text("Camera Broadcast Off")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)

                            Text("Click 'Start Camera' to broadcast 1080p stream over network")
                                .font(.system(size: 12))
                                .foregroundColor(Color(red: 161/255, green: 161/255, blue: 170/255))
                        }
                    }
                } else {
                    VStack {
                        HStack {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 7, height: 7)

                                Text("LIVE BROADCAST")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.black.opacity(0.85))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))

                            Spacer()

                            Text("H.264 • 1080p30")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.black.opacity(0.85))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
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
                                Image(systemName: "wifi")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)

                                Text("Wi-Fi: \(camera.streamServer.localIP):\(camera.streamServer.port)")
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
                                        .foregroundColor(copiedIPAlert ? .white : Color(red: 161/255, green: 161/255, blue: 170/255))
                                }
                                .buttonStyle(.plain)
                                .help("Copy Wi-Fi Address")
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(red: 24/255, green: 24/255, blue: 27/255))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))

                            if !camera.streamServer.usbIP.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "cable.connector")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)

                                    Text("USB-C: \(camera.streamServer.usbIP):\(camera.streamServer.port)")
                                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                        .foregroundColor(.white)

                                    Button(action: {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString("\(camera.streamServer.usbIP):\(camera.streamServer.port)", forType: .string)
                                    }) {
                                        Image(systemName: "doc.on.doc")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(Color(red: 161/255, green: 161/255, blue: 170/255))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Copy USB-C Wired Address")
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(red: 24/255, green: 24/255, blue: 27/255))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            }

                            HStack(spacing: 6) {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(red: 161/255, green: 161/255, blue: 170/255))

                                Text("\(camera.streamServer.clientCount) client(s)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(red: 161/255, green: 161/255, blue: 170/255))
                            }
                        }
                    } else {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(red: 113/255, green: 113/255, blue: 122/255))
                                .frame(width: 8, height: 8)

                            Text("Stream server stopped")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(red: 161/255, green: 161/255, blue: 170/255))
                        }
                    }
                }

                Spacer()

                // Solid White Primary Button vs Dark Bordered Secondary Button
                if !camera.isRunning {
                    Button(action: { camera.start() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 13, weight: .bold))

                            Text("Start Camera")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: Color.white.opacity(0.15), radius: 8, x: 0, y: 2)
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
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(Color(red: 24/255, green: 24/255, blue: 27/255))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
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

    // MARK: - Receiver View (Monochrome Black & White)

    private var receiverView: some View {
        VStack(spacing: 16) {
            // System Virtual Camera Control Card
            HStack(spacing: 14) {
                Image(systemName: "video.badge.plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Direct System Webcam Device (\"MacCam Bridge Camera\")")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)

                    Text("Exposes live stream directly to Discord, Zoom, OBS Studio, and Teams.")
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 161/255, green: 161/255, blue: 170/255))
                }

                Spacer()

                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("System Virtual Camera Output active", forType: .string)
                }) {
                    Text("Enable Direct System Webcam")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color(red: 24/255, green: 24/255, blue: 27/255))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(Color(red: 18/255, green: 18/255, blue: 20/255))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
            .padding([.horizontal, .top], 16)

            // Connection Bar (Auto-Discovery & Manual IP Input)
            VStack(spacing: 12) {
                // Auto-Discovered Senders section
                if !bonjour.discoveredSenders.isEmpty {
                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)

                            Text("DISCOVERED CAMERAS:")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(red: 161/255, green: 161/255, blue: 170/255))
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(bonjour.discoveredSenders) { sender in
                                    let isSelected = receiver.currentEndpointDescription == sender.name && (receiver.isConnected || receiver.isConnecting)
                                    Button(action: {
                                        receiver.connect(endpoint: sender.endpoint, customDescription: sender.name)
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: isSelected ? "checkmark.circle.fill" : "video.fill")
                                                .font(.system(size: 11))

                                            Text(sender.name)
                                                .font(.system(size: 12, weight: .semibold))
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(isSelected ? Color.white : Color(red: 39/255, green: 39/255, blue: 42/255))
                                        .foregroundColor(isSelected ? .black : .white)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(isSelected ? Color.white : Color.white.opacity(0.2), lineWidth: 1)
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
                            .foregroundColor(Color(red: 161/255, green: 161/255, blue: 170/255))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("SENDER IP ADDRESS")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(red: 161/255, green: 161/255, blue: 170/255))

                            TextField("192.168.1.45", text: $receiverIP)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)
                                .onSubmit {
                                    performManualConnect()
                                }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(red: 24/255, green: 24/255, blue: 27/255))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 1))

                    HStack(spacing: 8) {
                        Image(systemName: "number")
                            .font(.system(size: 14))
                            .foregroundColor(Color(red: 161/255, green: 161/255, blue: 170/255))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("PORT")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(red: 161/255, green: 161/255, blue: 170/255))

                            TextField("8080", text: $receiverPort)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)
                                .frame(width: 60)
                                .onSubmit {
                                    performManualConnect()
                                }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(red: 24/255, green: 24/255, blue: 27/255))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 1))

                    Spacer()

                    if receiver.isConnecting {
                        Button(action: { receiver.disconnect() }) {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 14, height: 14)

                                Text("Connecting...")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .padding(.horizontal, 22)
                            .padding(.vertical, 10)
                            .background(Color(red: 39/255, green: 39/255, blue: 42/255))
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    } else if !receiver.isConnected {
                        Button(action: {
                            performManualConnect()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 13, weight: .bold))

                                Text("Connect Stream")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .padding(.horizontal, 22)
                            .padding(.vertical, 10)
                            .background(Color.white)
                            .foregroundColor(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(color: Color.white.opacity(0.15), radius: 8, x: 0, y: 2)
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
                            .padding(.horizontal, 22)
                            .padding(.vertical, 10)
                            .background(Color(red: 24/255, green: 24/255, blue: 27/255))
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
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
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )

                if receiver.isConnecting {
                    VStack(spacing: 14) {
                        ProgressView()
                            .scaleEffect(1.3)
                            .padding(.bottom, 4)

                        VStack(spacing: 4) {
                            Text("Connecting to Camera Stream...")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)

                            Text(receiver.statusText)
                                .font(.system(size: 12))
                                .foregroundColor(Color(red: 161/255, green: 161/255, blue: 170/255))
                        }
                    }
                } else if !receiver.isConnected {
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.04))
                                .frame(width: 80, height: 80)
                                .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))

                            Image(systemName: receiver.errorMessage != nil ? "exclamationmark.triangle.fill" : "antenna.radiowaves.left.and.right")
                                .font(.system(size: 34))
                                .foregroundColor(receiver.errorMessage != nil ? Color(red: 239/255, green: 68/255, blue: 68/255) : .white)
                        }

                        VStack(spacing: 6) {
                            Text(receiver.errorMessage != nil ? "Connection Error" : "Ready to Receive Stream")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)

                            if let error = receiver.errorMessage {
                                Text(error)
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(red: 248/255, green: 113/255, blue: 113/255))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            } else {
                                Text("Select an auto-discovered camera or enter camera sender IP and port above")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(red: 161/255, green: 161/255, blue: 170/255))
                            }
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
                                    .fill(Color.white)
                                    .frame(width: 7, height: 7)

                                Text("CONNECTED")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.black.opacity(0.85))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))

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
                            .background(Color.black.opacity(0.85))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                        }
                        .padding(14)

                        Spacer()
                    }
                }
            }
            .padding([.horizontal, .bottom], 16)
        }
    }

    private func performManualConnect() {
        var ip = receiverIP.trimmingCharacters(in: .whitespacesAndNewlines)
        if ip.hasPrefix("ws://") {
            ip = String(ip.dropFirst(5))
        } else if ip.hasPrefix("wss://") {
            ip = String(ip.dropFirst(6))
        } else if ip.hasPrefix("http://") {
            ip = String(ip.dropFirst(7))
        } else if ip.hasPrefix("https://") {
            ip = String(ip.dropFirst(8))
        }

        var portVal: UInt16 = 8080
        if let colonIdx = ip.firstIndex(of: ":") {
            let hostStr = String(ip[..<colonIdx])
            let portStr = String(ip[ip.index(after: colonIdx)...])
            ip = hostStr
            receiverIP = hostStr
            if let parsedPort = UInt16(portStr) {
                portVal = parsedPort
                receiverPort = String(parsedPort)
            }
        } else if let portNum = UInt16(receiverPort.trimmingCharacters(in: .whitespacesAndNewlines)) {
            portVal = portNum
        }

        receiver.connect(ip: ip, port: portVal)
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
