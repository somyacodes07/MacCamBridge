# MacCam Bridge — Windows 11 Receiver Application

The Windows Receiver application connects to the **MacCam Bridge Sender** (macOS application) over local Wi-Fi / LAN, receives low-latency 1080p H.264 video streams, and decodes them on the GPU using W3C WebCodecs while exposing the feed as a native system-wide Virtual Webcam for Windows applications like OBS Studio, Discord, Zoom, Google Meet, and Microsoft Teams.

---

## Technical Features

- **Electron Desktop Application**: Native Windows 11 frameless dark-mode interface with custom title bar and monochrome HIG styling.
- **Hardware-Accelerated WebCodecs Decoder**: Decodes incoming `MCB1` H.264 packets on the Windows GPU using Chromium WebCodecs (`VideoDecoder`), achieving sub-15ms rendering latency.
- **Binary Protocol Demuxer (`mcb_protocol_decoder.js`)**: Parses raw WebSocket binary payloads, reconstructs Annex-B NAL units, and feeds keyframes and P-frames to the decoder.
- **Automatic LAN Scanner**: Scans local Wi-Fi IPv4 subnets for active MacBook camera senders operating on ports `8080-8085`.
- **System-Wide Virtual Webcam Integration**: Exposes camera stream directly to Windows applications via `pyvirtualcam` (`MacCam Bridge Camera`).

---

## Quick Start on Windows 11

### 1. Run Desktop Receiver App
Open Command Prompt / PowerShell in `WindowsReceiver` directory:

```cmd
npm install
npm start
```

### 2. Connect to MacBook Stream (Wi-Fi or USB-C Cable)
- **Wi-Fi Mode**: Click **Scan LAN** to automatically discover your MacBook camera stream, or type your MacBook IP address (e.g. `192.168.1.45`) and port (`8080`).
- **USB-C Wired Mode (0ms Latency)**: Plug a USB-C to USB-C cable between MacBook and PC. macOS and Windows automatically establish a high-speed Thunderbolt / USB Ethernet link (e.g. `169.254.x.x`). Click **Scan LAN** or enter the USB IP address shown on Mac app.

### 3. Enable System Virtual Webcam
Click **Enable Direct System Webcam** to expose the stream as a system webcam device ("MacCam Bridge Camera") for Discord, Zoom, Teams, and OBS Studio.

---

## Building Executable Installer (.exe)

To build a standalone portable executable or NSIS installer:

```cmd
npm run build:portable
```

The output executable will be placed in the `dist/` directory (e.g. `dist/MacCam Bridge 1.0.0.exe`).
