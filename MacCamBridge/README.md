# MacCam Bridge

<p align="center">
  <img src="logo.svg" width="160" height="160" alt="MacCam Bridge Logo" />
</p>

MacCam Bridge is a high-performance, low-latency cross-platform video streaming system that turns a **MacBook into a wireless webcam source for Windows 11 and macOS receivers**.

The MacBook captures camera frames via `AVCaptureSession`, encodes them on the GPU via Apple VideoToolbox (H.264 hardware acceleration), and streams them over the local network (Wi-Fi/LAN) using Apple's Network framework and a custom binary streaming protocol (`MCB1`).

---

## 🏗️ Architecture Overview

```text
               ┌─────────────────────────────────────────────────────────────┐
               │                     MacCam Bridge Sender                    │
               └─────────────────────────────────────────────────────────────┘
                                              │
               ┌──────────────────────────────┴──────────────────────────────┐
               ▼                                                             ▼
     [Local Camera Preview]                                       [Video Capture Engine]
    AVCaptureVideoPreviewLayer                                  AVCaptureVideoDataOutput
   (SwiftUI / NSViewRepresentable)                               (NV12 420v PixelBuffers)
                                                                             │
                                                                             ▼
                                                                  [VideoFrameProcessor]
                                                                (Background Serial Queue)
                                                                             │
                                                                             ▼
                                                                   [H264Encoder Engine]
                                                                VideoToolbox VTCompression
                                                                (1080p30 @ 8 Mbps Bitrate)
                                                                             │
                                                                             ▼
                                                                [FrameSinkMultiplexer]
                                                                ┌────────────┴───────────┐
                                                                ▼                        ▼
                                                       [EncoderDebugSink]       [StreamServer]
                                                        (Console Metrics)      (NWListener / WS)
                                                                                         │
                                                                                         ▼
                                                                           ┌─────────────────────────┐
                                                                           │   Wi-Fi / Local LAN     │
                                                                           │ Binary Protocol ("MCB1")│
                                                                           └─────────────────────────┘
                                                                                         │
               ┌─────────────────────────────────────────────────────────────────────────┘
               ▼
┌───────────────────────────────┐
│     MacCam Bridge Receiver    │
├───────────────────────────────┤
│ • StreamReceiver (NWConnection)│
│ • MCB1 Packet Demuxer         │
│ • Live Data & Frame Metrics   │
└───────────────────────────────┘
```

---

## ⚡ Features & Capabilities

- **Dual Mode SwiftUI Application**: Switch between **Camera Sender** and **Camera Receiver** modes within a single clean, dark-mode native interface.
- **Hardware-Accelerated Encoding**: Zero-copy H.264 encoding via macOS VideoToolbox (`VTCompressionSession`), streaming 1080p HD video at 30 FPS with low latency.
- **Custom Binary Streaming Protocol (`MCB1`)**: Optimized binary framing format for low-overhead packet transport with precision `CMTime` presentation timestamps (PTS).
- **Network Server & Bonjour Discovery**: Built-in TCP/WebSocket `NWListener` server with dynamic port assignment (`8080-8090`), automatic local IP resolution, and mDNS Bonjour service advertisement (`_maccambridge._tcp`).
- **Dynamic Configuration Handshake**: Automatically extracts and broadcasts H.264 Sequence Parameter Sets (SPS) and Picture Parameter Sets (PPS) to newly connected clients before streaming frames.
- **Real-Time Diagnostics & Metrics**: Stream throughput monitoring (MB received, FPS logging, and connection status tracking).

---

## 📡 Binary Stream Protocol (`MCB1`)

Network payloads are packed into binary frame packets using the following memory layout:

| Field | Type | Size | Description |
| :--- | :--- | :--- | :--- |
| **Magic** | `UInt32` (Big-Endian) | 4 Bytes | Protocol Identifier (`0x4D434231` / ASCII `"MCB1"`) |
| **Version** | `UInt8` | 1 Byte | Protocol Version (`1`) |
| **Packet Type** | `UInt8` | 1 Byte | `1` = Configuration (SPS/PPS), `2` = KeyFrame (IDR), `3` = DeltaFrame (P-Frame) |
| **Reserved** | `UInt16` | 2 Bytes | Alignment Padding (`0x0000`) |
| **Payload Length** | `UInt32` (Big-Endian) | 4 Bytes | Byte length of the following payload data |
| **PTS Value** | `Int64` (Big-Endian) | 8 Bytes | `CMTime.value` presentation timestamp |
| **PTS Timescale** | `Int32` (Big-Endian) | 4 Bytes | `CMTime.timescale` time unit definition |
| **Payload Data** | `Data` | N Bytes | Raw NAL Unit data (or SPS/PPS length-prefixed configuration structure) |

---

## 📊 Current Development Status

### Completed Milestones
- [x] **Native macOS SwiftUI App**: Dark mode UI with interactive mode switcher between Sender and Receiver.
- [x] **Camera Permissions & Sandbox Entitlements**: Configured macOS camera entitlement and info plist permissions.
- [x] **Live Local Camera Preview**: Hardware-accelerated SwiftUI preview via `AVCaptureVideoPreviewLayer`.
- [x] **Video Frame Capture Pipeline**: `AVCaptureVideoDataOutput` delivering NV12 (`420v`) pixel buffers on dedicated serial background queue (`com.maccambridge.video`).
- [x] **Hardware VideoToolbox H.264 Encoder**: Real-time compression session (`1920x1080 @ 30 FPS`, `8 Mbps` target bitrate) with Annex B / NAL unit extraction.
- [x] **Frame Multiplexing & Debug Sink**: Decoupled consumer architecture (`EncodedFrameSink`, `FrameSinkMultiplexer`, `EncoderDebugSink`).
- [x] **Network Streaming Server**: `NWListener` TCP and WebSocket server with automatic fallback port selection (`8080-8090`) and Bonjour broadcast (`_maccambridge._tcp`).
- [x] **Binary Streaming Protocol Implementation**: Packet encoding (`StreamPacket`) with `MCB1` headers, PTS synchronization, and initial SPS/PPS configuration handshake.
- [x] **macOS Stream Receiver**: Network client (`StreamReceiver`) capable of connecting to sender streams and displaying live throughput stats.
- [x] **Hardware H.264 Video Decoder (`VTDecompressionSession`)**: Real-time H.264 video decoding pipeline converting elementary NAL units into `CMSampleBuffer`s.
- [x] **Low-Latency Video Renderer (`AVSampleBufferDisplayLayer`)**: Live frame display engine rendering decoded video on the Receiver UI.
- [x] **Automatic mDNS Bonjour Service Discovery**: `NWBrowser` client scanning `_maccambridge._tcp` to discover local camera servers on Wi-Fi/LAN.
- [x] **Polished Emoji-Free macOS UI**: Modern dark-mode Apple HIG interface using native SF Symbols, custom mode tab control, and dynamic live metrics.

### Next Planned Milestones
- [ ] WebRTC PeerConnection integration for NAT traversal.
- [ ] Windows 11 Receiver client application.
- [ ] Windows DirectShow / Media Foundation Virtual Webcam Driver integration.

---

## 🛠️ Development & Building

### Requirements
- macOS 14.0+ (Apple Silicon or Intel)
- Xcode 15.0+ / Swift 5.9+

### Build via Command Line
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project MacCamBridge.xcodeproj \
  -scheme MacCamBridge \
  -configuration Debug build
```

---

## 📜 License
MIT License

