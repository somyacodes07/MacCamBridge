# MacCam Bridge - Windows 11 Receiver

The Windows Receiver application connects to the **MacCam Bridge Sender** (macOS application) over local Wi-Fi / LAN, receives the low-latency 1080p H.264 video stream, and displays it with hardware-accelerated rendering while exposing it as a virtual webcam for Windows applications like OBS Studio, Discord, Zoom, Google Meet, and Microsoft Teams.

---

## 🚀 Quick Start on Windows 11

### Option 1: Desktop Electron App
1. Install Node.js on Windows 11.
2. Open terminal in `WindowsReceiver` folder:
   ```cmd
   npm install
   npm start
   ```
3. Enter your MacBook IP address (e.g. `192.168.1.50`) and click **Connect**.

---

### Option 2: Browser Receiver (Zero Installation)
1. Open `index.html` in Microsoft Edge, Google Chrome, or Brave on Windows 11.
2. Enter your MacBook IP address and Port (`8080`).
3. Click **Connect** to start live low-latency preview.

---

### Option 3: OBS Studio & Windows Virtual Webcam ("MacCam Bridge Camera")
1. To expose the stream as a system-wide Windows webcam:
   ```cmd
   pip install pyvirtualcam opencv-python numpy
   python obs_virtual_cam_bridge.py <MACBOOK_IP> 8080
   ```
2. In Zoom, Discord, Teams, or OBS, select **MacCam Bridge Camera** as your active webcam!

---

## 🔒 Requirements
- Both MacBook and Windows 11 PC connected to the same Wi-Fi / Local Network.
- Firewall allowed for port `8080`.
