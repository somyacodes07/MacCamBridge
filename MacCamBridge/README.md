# MacCam Bridge — macOS Application

<p align="center">
  <img src="logo.svg" width="140" height="140" alt="MacCam Bridge Logo" />
</p>

The macOS application provides a high-performance **Camera Broadcast Sender** and **Camera Stream Receiver** built natively with SwiftUI, AVFoundation, VideoToolbox, and Network framework.

---

## Technical Features

- **Dual-Mode SwiftUI Application**: Easily toggle between **Camera Sender** and **Camera Receiver** using a polished monochrome segmented tab bar.
- **Hardware-Accelerated Encoding**: Zero-copy H.264 hardware encoding via macOS VideoToolbox (`VTCompressionSession`), streaming 1080p HD video at 30 FPS.
- **Hardware-Accelerated Decoding**: VideoToolbox hardware decoding (`VTDecompressionSession`) for real-time video playback in Receiver mode.
- **Low-Latency Rendering Engine**: Direct frame rendering via `AVSampleBufferDisplayLayer` and `NSViewRepresentable`.
- **mDNS / Bonjour Auto-Discovery**: Automatically browses local Wi-Fi/LAN networks for active camera senders (`_maccambridge._tcp`) using `NWBrowser`.
- **Custom Binary Streaming Protocol (`MCB1`)**: Binary framing layout with precision `CMTime` timestamps and H.264 SPS/PPS configuration parameters.

---

## Directory Structure

```text
MacCamBridge/
├── MacCamBridgeApp.swift          # Main SwiftUI App Entry Point
├── ContentView.swift              # Dual-Mode Monochrome HIG User Interface
├── CameraManager.swift            # AVCaptureSession Camera Pipeline Manager
├── CameraPreview.swift            # AVCaptureVideoPreviewLayer SwiftUI View
├── VideoFrameProcessor.swift      # Serial Background Delegate & Consumer Dispatch
├── H264Encoder.swift              # VideoToolbox VTCompressionSession Encoder
├── H264Decoder.swift              # VideoToolbox VTDecompressionSession Decoder
├── SampleBufferDisplayView.swift  # AVSampleBufferDisplayLayer SwiftUI Wrapper
├── BonjourBrowser.swift           # NWBrowser Local mDNS Service Auto-Discovery
├── StreamingServer.swift          # NWListener TCP / WebSocket Stream Server
├── StreamReceiver.swift           # NWConnection Stream Receiver & MCB1 Packet Demuxer
├── StreamProtocol.swift           # MCB1 Binary Frame Layout Definition
└── Assets.xcassets/               # App Icons & Color Assets
```

---

## Building & DMG Packaging

To compile and package the macOS release `.dmg` installer:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./build_mac_dmg.sh
```

The output disk image will be created at `MacCamBridge-macOS.dmg`.
