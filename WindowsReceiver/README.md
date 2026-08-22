# 🪟 MacCam Bridge — Windows 11 Receiver Application

<p align="center">
  <img src="logo.svg" width="120" height="120" alt="MacCam Bridge Logo" />
</p>

The **Windows 11 Receiver Application** connects to the **MacCam Bridge Sender** (macOS application) over local Wi-Fi or high-speed USB-C direct link, decodes 1080p H.264 video streams on the Windows GPU using W3C WebCodecs, and exposes the feed as a native Virtual Webcam for Windows applications like OBS Studio, Discord, Zoom, Google Meet, and Microsoft Teams.

---

## ⚡ Technical Features

- **Electron Pitch-Dark Obsidian UI**: Native Windows 11 frameless interface with custom titlebar, hidden scrollbars, and **System Tray Taskbar Toolbar integration**.
- **W3C WebCodecs GPU Decoding**: Hardware-accelerated H.264 GPU decoding (`VideoDecoder`) achieving sub-5ms rendering latency.
- **Keyframe Stream Synchronization**: Macroblock-free streaming engine (`hasReceivedFirstKeyframe`) preventing all pixelation and smearing.
- **Direct System Virtual Webcam**: Integrated `pyvirtualcam` frame engine registering **`"MacCam Bridge Camera"`** natively for Windows applications.
- **1-Click VirtualCam Driver Auto-Installer**: Automatically detects missing Python dependencies and installs `pyvirtualcam`, `opencv-python`, and `numpy` with 1 click.
- **Interactive Transport Mode Selector**: Easily switch between `[ 📶 Wi-Fi Wireless Mode ]` and `[ ⚡ USB-C Cable Mode ]`.
- **Live USB-C Cable Auto-Detection**: Automatically detects when a USB-C to USB-C cable is connected between MacBook and PC (`169.254.x.x`) and populates the IP field.

---

## 📁 Source Code Architecture

```text
WindowsReceiver/
├── main.js                  # Electron Main Process, Window Management & IPC Handlers
├── index.html               # Receiver UI & W3C WebCodecs GPU Video Renderer
├── mcb_protocol_decoder.js  # MCB1 Binary Protocol Header Demuxer & Annex-B Parser
├── obs_virtual_cam_bridge.py# Direct Windows Virtual Webcam Frame Socket Server
├── package.json             # Electron Build Config & NSIS Installer Target
├── icon.ico                 # Application System Icon
├── logo.svg                 # Header Bar Logo
└── build_windows_exe.sh     # Executable & NSIS Setup Installer Builder
```

---

## 🛠️ Building Windows Executable & Setup Installer

Package both **NSIS Setup Wizard Installers** (`MacCam-Bridge-Setup-Windows-x64-1.0.0.exe`) and Standalone Portable EXEs:

```bash
./build_windows_exe.sh
```
The resulting executables will be output to the `dist/` directory.
