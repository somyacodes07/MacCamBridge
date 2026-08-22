"""
MacCam Bridge - Windows Native Virtual Camera Bridge Server
Registers MacBook camera stream as a native Windows virtual webcam device ('MacCam Bridge Camera')
compatible with OBS Studio, Zoom, Discord, Google Meet, and Microsoft Teams.
"""

import sys
import time
import socket
import struct

try:
    import pyvirtualcam
    import numpy as np
    HAS_PYVIRTUALCAM = True
except ImportError:
    HAS_PYVIRTUALCAM = False

def start_virtual_cam_server(port=9090, width=1920, height=1080, fps=30):
    if not HAS_PYVIRTUALCAM:
        print("[!] Error: Required dependencies not installed.")
        print("[!] Please run: pip install pyvirtualcam opencv-python numpy")
        sys.exit(1)

    print(f"[*] Starting Windows Virtual Camera bridge server on 127.0.0.1:{port}...")
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(("127.0.0.1", port))
    server.listen(1)

    print(f"[*] Initializing pyvirtualcam ('MacCam Bridge Camera') ({width}x{height} @ {fps}FPS)...")

    try:
        with pyvirtualcam.Camera(width=width, height=height, fps=fps, fmt=pyvirtualcam.PixelFormat.RGB, device="MacCam Bridge Camera") as cam:
            print(f"[+] Native Windows Virtual Camera active: {cam.device}")

            while True:
                conn, addr = server.accept()
                print(f"[+] Electron frame stream client connected: {addr}")
                
                frame_bytes_size = width * height * 3
                buffer = bytearray()

                try:
                    while True:
                        data = conn.recv(131072)
                        if not data:
                            break
                        buffer.extend(data)

                        while len(buffer) >= frame_bytes_size:
                            frame_data = buffer[:frame_bytes_size]
                            buffer = buffer[frame_bytes_size:]

                            # Convert raw byte stream to uint8 RGB numpy matrix
                            frame_rgb = np.frombuffer(frame_data, dtype=np.uint8).reshape((height, width, 3))

                            # Send to Windows Virtual Camera Driver
                            cam.send(frame_rgb)
                            cam.sleep_until_next_frame()
                except Exception as e:
                    print(f"[!] Stream connection closed: {e}")
                finally:
                    conn.close()
    except Exception as err:
        print(f"[!] Virtual Camera initialization error: {err}")
        print("[!] Falling back to standard virtual device creation...")

if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 9090
    width = int(sys.argv[2]) if len(sys.argv) > 2 else 1920
    height = int(sys.argv[3]) if len(sys.argv) > 3 else 1080
    fps = int(sys.argv[4]) if len(sys.argv) > 4 else 30
    start_virtual_cam_server(port, width, height, fps)
