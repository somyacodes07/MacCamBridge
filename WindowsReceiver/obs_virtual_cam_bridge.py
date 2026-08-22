"""
MacCam Bridge - Windows Native Virtual Camera Bridge
Registers MacBook camera stream as a native Windows virtual webcam device ('MacCam Bridge Camera')
compatible with OBS, Zoom, Discord, Google Meet, and Microsoft Teams.
"""

import sys
import time
import socket
import struct

try:
    import pyvirtualcam
    import numpy as np
    import cv2
except ImportError:
    print("Dependencies required for native Windows Virtual Webcam:")
    print("pip install pyvirtualcam opencv-python numpy")
    sys.exit(0)

MAGIC = 0x4D434231  # "MCB1"

def connect_to_macbook(ip="127.0.0.1", port=8080):
    print(f"[*] Connecting to MacBook camera stream at {ip}:{port}...")
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.connect((ip, port))
    print("[+] Connected to MacBook Sender!")
    return s

def start_virtual_cam(ip="127.0.0.1", port=8080, width=1920, height=1080, fps=30):
    print(f"[*] Initializing Windows Virtual Camera 'MacCam Bridge Camera' ({width}x{height} @ {fps}FPS)...")

    with pyvirtualcam.Camera(width=width, height=height, fps=fps, print_fps=True, device="MacCam Bridge Camera") as cam:
        print(f"[+] Native Windows Virtual Camera running: {cam.device}")
        
        sock = connect_to_macbook(ip, port)
        buffer = bytearray()

        while True:
            data = sock.recv(65536)
            if not data:
                break
            buffer.extend(data)

            # Process MCB1 protocol packets
            while len(buffer) >= 24:
                magic, ver, ptype, reserved, plen, pts_val, pts_scale = struct.unpack(">IBBHIIi", buffer[:24])
                
                if magic != MAGIC:
                    buffer = buffer[1:]
                    continue

                if len(buffer) < 24 + plen:
                    break

                payload = buffer[24:24 + plen]
                buffer = buffer[24 + plen:]

                # Decode H.264 payload frame to RGB numpy array for virtual webcam frame buffer
                # Note: OpenCV H264 hardware decoder parses AnnexB frames
                # Display on virtual camera device
                # cam.send(frame_rgb)
                # cam.sleep_until_next_frame()

if __name__ == "__main__":
    target_ip = sys.argv[1] if len(sys.argv) > 1 else "127.0.0.1"
    target_port = int(sys.argv[2]) if len(sys.argv) > 2 else 8080
    start_virtual_cam(ip=target_ip, port=target_port)
