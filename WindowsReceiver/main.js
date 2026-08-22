const { app, BrowserWindow, ipcMain, Tray, Menu } = require('electron');
const path = require('path');
const os = require('os');
const net = require('net');
const { spawn } = require('child_process');

let mainWindow = null;
let tray = null;
let virtualCamProcess = null;

function getLocalSubnets() {
    const interfaces = os.networkInterfaces();
    const subnets = [];

    for (const name of Object.keys(interfaces)) {
        for (const iface of interfaces[name]) {
            if (iface.family === 'IPv4' && !iface.internal) {
                const parts = iface.address.split('.');
                if (parts.length === 4) {
                    subnets.push(parts.slice(0, 3).join('.'));
                }
            }
        }
    }
    return [...new Set(subnets)];
}

async function scanLanPort(ip, port, timeout = 250) {
    return new Promise((resolve) => {
        const socket = new net.Socket();
        socket.setTimeout(timeout);

        socket.on('connect', () => {
            socket.destroy();
            resolve({ ip, port, status: 'open' });
        });

        socket.on('timeout', () => {
            socket.destroy();
            resolve(null);
        });

        socket.on('error', () => {
            socket.destroy();
            resolve(null);
        });

        socket.connect(port, ip);
    });
}

async function performLanScan() {
    const subnets = getLocalSubnets();
    const ports = [8080, 8081, 8082, 8083, 8084, 8085];
    const foundDevices = [];
    const scanPromises = [];

    for (const subnet of subnets) {
        for (let i = 1; i <= 254; i++) {
            const ip = `${subnet}.${i}`;
            for (const port of ports) {
                scanPromises.push(scanLanPort(ip, port));
            }
        }
    }

    const results = await Promise.all(scanPromises);
    for (const res of results) {
        if (res) {
            foundDevices.push(res);
        }
    }

    return foundDevices;
}

function createWindow() {
    mainWindow = new BrowserWindow({
        width: 1180,
        height: 800,
        minWidth: 900,
        minHeight: 650,
        title: "MacCam Bridge - Windows 11 Receiver",
        frame: false,
        titleBarStyle: 'hidden',
        backgroundColor: "#080d1a",
        webPreferences: {
            nodeIntegration: true,
            contextIsolation: false
        }
    });

    mainWindow.loadFile('index.html');

    mainWindow.on('closed', () => {
        mainWindow = null;
    });
}

// IPC Event Handlers
ipcMain.handle('scan-lan', async () => {
    try {
        const devices = await performLanScan();
        return { success: true, devices };
    } catch (err) {
        return { success: false, error: err.message };
    }
});

ipcMain.handle('start-virtual-cam', async (event, { ip, port }) => {
    if (virtualCamProcess) {
        return { success: true, message: 'Already running' };
    }

    try {
        const scriptPath = path.join(__dirname, 'obs_virtual_cam_bridge.py');
        virtualCamProcess = spawn('python', [scriptPath, ip, port]);

        virtualCamProcess.on('exit', () => {
            virtualCamProcess = null;
        });

        return { success: true };
    } catch (err) {
        return { success: false, error: err.message };
    }
});

ipcMain.handle('stop-virtual-cam', async () => {
    if (virtualCamProcess) {
        virtualCamProcess.kill();
        virtualCamProcess = null;
    }
    return { success: true };
});

ipcMain.on('window-minimize', () => {
    if (mainWindow) mainWindow.minimize();
});

ipcMain.on('window-maximize', () => {
    if (mainWindow) {
        if (mainWindow.isMaximized()) {
            mainWindow.unmaximize();
        } else {
            mainWindow.maximize();
        }
    }
});

ipcMain.on('window-close', () => {
    if (mainWindow) mainWindow.close();
});

app.whenReady().then(() => {
    createWindow();

    app.on('activate', () => {
        if (BrowserWindow.getAllWindows().length === 0) {
            createWindow();
        }
    });
});

app.on('window-all-closed', () => {
    if (virtualCamProcess) {
        virtualCamProcess.kill();
    }
    if (process.platform !== 'darwin') {
        app.quit();
    }
});
