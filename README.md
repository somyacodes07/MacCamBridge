# MacCam Bridge

MacCam Bridge is a cross-platform application that allows a **MacBook to be used as a high-quality wireless webcam for a Windows 11 computer**.

The MacBook acts as the camera source (MacCam Bridge Sender), capturing and encoding video over the local network. The Windows PC receives the video stream and exposes it as a virtual webcam for use in applications like OBS, Discord, Zoom, Google Meet, and Microsoft Teams.

---

## 🏗️ Architecture Overview

```text
MacBook (Sender)
    │
    ├─► Built-in Camera (AVCaptureSession)
    ├─► AVCaptureVideoPreviewLayer (Local SwiftUI Preview)
    ├─► AVCaptureVideoDataOutput (CMSampleBuffer Pipeline)
    ├─► VideoFrameProcessor (Dedicated Serial Queue)
    ├─► VideoFrameConsumer Protocol Abstraction
    ├─► VideoToolbox H.264 Hardware Encoder
    └─► Network Streaming Layer (WebRTC / NWListener)
            │
            ▼ (Wi-Fi / Local Network)
Windows PC (Receiver)
    │
    ├─► WebRTC Video Receiver
    ├─► Live Preview
    └─► Virtual Webcam Output ("MacCam Bridge Camera")
```

---

## 📊 Current Development Status

### Completed Milestones
- [x] **Native macOS SwiftUI App**: Clean, responsive UI for starting and stopping the camera stream.
- [x] **Camera Permissions & Sandbox Configuration**: Granted entitlement access to MacBook built-in camera.
- [x] **Camera Detection & AVCaptureSession Setup**: Configured session with 1080p preset (`hd1920x1080`).
- [x] **Live Local Camera Preview**: Seamless SwiftUI live preview via `AVCaptureVideoPreviewLayer` and `NSViewRepresentable`.
- [x] **Video Frame Capture Pipeline**:
  - Integrated `AVCaptureVideoDataOutput` configured for 420v / NV12 pixel buffers.
  - Implemented `VideoFrameProcessor` adhering to `AVCaptureVideoDataOutputSampleBufferDelegate`.
  - Processed frames on dedicated serial background queue (`com.maccambridge.video`) off the main thread.
  - Created `VideoFrameConsumer` protocol abstraction for decoupling frame capture from encoding/streaming.
  - Added controlled diagnostic frame logging (frame index, dimensions, pixel format, timestamp, and FPS).
- [x] **Hardware Encoding Foundation**: Configured VideoToolbox H.264 hardware encoder pipeline.
- [x] **Hardware H.264 Video Decoder & Renderer**: Integrated VideoToolbox `VTDecompressionSession` decoder and low-latency `AVSampleBufferDisplayLayer` video renderer.
- [x] **Local LAN Device Discovery**: Integrated mDNS / Bonjour network browsing (`NWBrowser` for `_maccambridge._tcp`) to auto-discover camera senders.
- [x] **Polished Emoji-Free macOS UI**: Modern dark-mode Apple HIG interface using native SF Symbols, custom mode tab control, and dynamic live metrics.

### Next Planned Milestones
- [ ] WebRTC peer connection & signaling pipeline
- [ ] Windows receiver application
- [ ] Windows native virtual webcam driver integration

---

## 🛠️ Development & Building

### Requirements
- macOS 14.0+ (Tested on Apple Silicon / M4)
- Xcode 15+ / Swift 5.9+

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
