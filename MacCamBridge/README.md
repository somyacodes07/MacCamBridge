# 🍏 MacCam Bridge — Native macOS Application

<p align="center">
  <img src="Assets.xcassets/AppLogo.imageset/logo.png" width="120" height="120" alt="MacCam Bridge Logo" />
</p>

The native **macOS Application** is built with SwiftUI, AVFoundation, VideoToolbox, and Network framework. It acts as both a **Camera Broadcast Sender** (encoding 1080p HD video on the Apple Silicon / Intel GPU) and a **Camera Stream Receiver**.

---

## ⚡ Technical Features

- **Dual-Mode SwiftUI Interface**: Seamlessly switch between **Camera Broadcast Sender** and **Camera Receiver** using Apple HIG monochrome pitch-dark obsidian styling.
- **VideoToolbox GPU H.264 Encoder**: Zero-copy 1080p 60FPS H.264 hardware encoding (`VTCompressionSession`) targeting 8 Mbps bitrate.
- **VideoToolbox GPU H.264 Decoder**: Hardware decompression (`VTDecompressionSession`) rendered directly via `AVSampleBufferDisplayLayer`.
- **Bonjour mDNS Auto-Discovery**: Automatic network advertisement (`_maccambridge._tcp`) and background network scanning via `NWBrowser`.
- **Multi-IP Auto-Detection**: Detects both local Wi-Fi (`192.168.x.x`) and **USB-C Direct Link (`169.254.x.x`)** with 1-click address copy.
- **Custom Binary Streaming Protocol (`MCB1`)**: Low-overhead packet framing format with precision `CMTime` timestamps and NAL unit demuxing.

---

## 📁 Source Code Architecture

```text
MacCamBridge/
├── MacCamBridgeApp.swift          # Main SwiftUI App Lifecycle Entry Point
├── ContentView.swift              # Dual-Mode Pitch-Dark Obsidian UI & Controls
├── CameraManager.swift            # AVCaptureSession Camera Manager & Device Selection
├── CameraPreview.swift            # AVCaptureVideoPreviewLayer SwiftUI NSViewRepresentable
├── VideoFrameProcessor.swift      # Serial Background Delegate & Consumer Pipeline
├── H264Encoder.swift              # VideoToolbox VTCompressionSession H.264 Encoder
├── H264Decoder.swift              # VideoToolbox VTDecompressionSession H.264 Decoder
├── SampleBufferDisplayView.swift  # AVSampleBufferDisplayLayer Low-Latency Renderer
├── BonjourBrowser.swift           # NWBrowser Local mDNS Service Auto-Discovery
├── StreamingServer.swift          # NWListener TCP / WebSocket Multi-IP Server
├── StreamReceiver.swift           # NWConnection Receiver & MCB1 Demuxer
└── StreamProtocol.swift           # MCB1 Binary Protocol Header Definition
```

---

## 🛠️ Building & Packaging DMG

Compile and build the release disk image (`MacCamBridge-macOS.dmg`):

```bash
cd ..
./build_mac_dmg.sh
```
