# MacCam Bridge

MacCam Bridge is a high-performance, low-latency cross-platform camera streaming suite that turns a **MacBook into a high-quality wireless webcam for Windows 11 and macOS receivers**.

The MacBook acts as the camera source (MacCam Bridge Sender), capturing and encoding 1080p HD video on the GPU via Apple VideoToolbox (H.264 hardware acceleration), and streaming over the local network (Wi-Fi/LAN) using Apple's Network framework and a custom binary streaming protocol (`MCB1`). The Windows PC / macOS client receives the video stream and renders it with hardware decoding while exposing it as a native virtual webcam for applications like OBS Studio, Discord, Zoom, Google Meet, and Microsoft Teams.

---

## Architecture Overview

```text
┌─────────────────────────────────────────────────────────────────────────┐
│                          MacCam Bridge Sender                           │
└─────────────────────────────────────────────────────────────────────────┘
                                     │
       ┌─────────────────────────────┴─────────────────────────────┐
       ▼                                                           ▼
[Local Camera Preview]                                   [Video Capture Engine]
AVCaptureVideoPreviewLayer                             AVCaptureVideoDataOutput
(SwiftUI / NSViewRepresentable)                        (NV12 420v PixelBuffers)
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
                                                       ┌───────────┴───────────┐
                                                       ▼                       ▼
                                              [EncoderDebugSink]      [StreamServer]
                                               (Console Metrics)     (NWListener / WS)
                                                                               │
                                                                               ▼
                                                                 ┌───────────────────────────┐
                                                                 │     Wi-Fi / Local LAN     │
                                                                 │ Binary Protocol ("MCB1")  │
                                                                 └───────────────────────────┘
                                                                               │
       ┌───────────────────────────────────────────────────────────────────────┴───────────────────────────────────────────────────────────────────────┐
       ▼                                                                                                                                               ▼
┌─────────────────────────────────────────────────────────┐                                                   ┌─────────────────────────────────────────────────────────┐
│                 macOS Receiver Client                   │                                                   │                 Windows 11 Receiver App                 │
├─────────────────────────────────────────────────────────┤                                                   ├─────────────────────────────────────────────────────────┤
│ • StreamReceiver (NWConnection WebSocket)              │                                                   │ • Electron / WebCodecs GPU H.264 Decoder                │
│ • VideoToolbox Hardware Decoder (VTDecompressionSession)│                                                   │ • mcb_protocol_decoder.js (Annex-B Demuxer)             │
│ • Low-Latency AVSampleBufferDisplayLayer Renderer       │                                                   │ • Native Virtual Webcam Driver ("MacCam Bridge Camera") │
└─────────────────────────────────────────────────────────┘                                                   └─────────────────────────────────────────────────────────┘
```

---

## Features & Highlights

- **Ultra-Premium Monochrome Interface**: Clean, minimal black-and-white visual design adhering to Apple HIG guidelines with zero emojis, custom segmented tab controls, and high-contrast typography.
- **Hardware-Accelerated H.264 Pipeline**: Zero-copy H.264 GPU encoding via macOS VideoToolbox (`VTCompressionSession`) streaming 1080p HD video at 30 FPS with low latency.
- **Hardware-Accelerated Video Receivers**: VideoToolbox hardware decoding (`VTDecompressionSession`) on macOS receivers and W3C WebCodecs GPU decoding on Windows 11 receivers.
- **Custom Binary Streaming Protocol (`MCB1`)**: Optimized binary framing format for low-overhead packet transport with precision `CMTime` presentation timestamps (PTS).
- **Network Server & Bonjour Discovery**: Built-in TCP/WebSocket `NWListener` server with dynamic port assignment (`8080-8090`), automatic local IP resolution, and mDNS Bonjour service advertisement (`_maccambridge._tcp`).
- **Direct System Virtual Webcam**: Exposes the live stream as a system-wide Virtual Webcam device ("MacCam Bridge Camera") for Discord, Zoom, Teams, OBS, and WhatsApp.

---

## Binary Stream Protocol (`MCB1`)

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

## Development Status & Completed Milestones

### Completed Milestones
- [x] **Native macOS SwiftUI App**: Dark mode Apple HIG interface with interactive mode switcher between Sender and Receiver.
- [x] **Camera Permissions & Sandbox Entitlements**: Granted entitlement access to MacBook built-in camera.
- [x] **Live Local Camera Preview**: Hardware-accelerated SwiftUI preview via `AVCaptureVideoPreviewLayer`.
- [x] **Video Frame Capture Pipeline**: `AVCaptureVideoDataOutput` delivering NV12 (`420v`) pixel buffers on dedicated serial background queue (`com.maccambridge.video`).
- [x] **Hardware VideoToolbox H.264 Encoder**: Real-time compression session (`1920x1080 @ 30 FPS`, `8 Mbps` target bitrate) with Annex B / NAL unit extraction.
- [x] **Frame Multiplexing & Debug Sink**: Decoupled consumer architecture (`EncodedFrameSink`, `FrameSinkMultiplexer`, `EncoderDebugSink`).
- [x] **Network Streaming Server**: `NWListener` TCP and WebSocket server with dynamic fallback port selection (`8080-8090`) and Bonjour broadcast (`_maccambridge._tcp`).
- [x] **Binary Streaming Protocol (`MCB1`)**: Packet encoding with `MCB1` headers, PTS synchronization, and initial SPS/PPS configuration handshake.
- [x] **Hardware H.264 Video Decoder & Renderer**: Integrated VideoToolbox `VTDecompressionSession` decoder and low-latency `AVSampleBufferDisplayLayer` video renderer on macOS.
- [x] **Local LAN Device Discovery**: Integrated mDNS / Bonjour network browsing (`NWBrowser` for `_maccambridge._tcp`) to auto-discover camera senders.
- [x] **Cross-Platform Windows 11 Receiver**: Electron desktop app with WebCodecs GPU H.264 hardware decoding and direct Windows Virtual Webcam integration.
- [x] **Monochrome Black & White Interface Overhaul**: Premium minimal HIG black-and-white visual design across both macOS and Windows applications.

---

## Development & Building

### macOS Sender & Receiver App
- **Requirements**: macOS 14.0+ (Apple Silicon or Intel), Xcode 15.0+ / Swift 5.9+
- **Build via Command Line**:
  ```bash
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
    -project MacCamBridge.xcodeproj \
    -scheme MacCamBridge \
    -configuration Debug build
  ```
- **Package Release DMG**:
  ```bash
  ./build_mac_dmg.sh
  ```

### Windows 11 Receiver App
- **Requirements**: Windows 11 / 10, Node.js 18+
- **Run Locally**:
  ```cmd
  cd WindowsReceiver
  npm install
  npm start
  ```
- **Package Portable EXE Installer**:
  ```cmd
  cd WindowsReceiver
  npm run build:portable
  ```

---

## License
MIT License
