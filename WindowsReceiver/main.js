const { app, BrowserWindow, ipcMain, Tray, Menu, nativeImage } = require('electron');
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

async function scanLanPort(ip, port, timeout = 200) {
    return new Promise((resolve) => {
        const socket = new net.Socket();
        socket.setTimeout(timeout);

        socket.on('connect', () => {
            socket.end();
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
    const ports = [8080, 8081];
    const foundDevices = [];

    for (const subnet of subnets) {
        const batchSize = 32;
        for (let i = 1; i <= 254; i += batchSize) {
            const scanPromises = [];
            for (let j = i; j < i + batchSize && j <= 254; j++) {
                const ip = `${subnet}.${j}`;
                for (const port of ports) {
                    scanPromises.push(scanLanPort(ip, port));
                }
            }
            const results = await Promise.all(scanPromises);
            for (const res of results) {
                if (res) foundDevices.push(res);
            }
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
        show: false,
        backgroundColor: "#000000",
        icon: path.join(__dirname, 'icon.ico'),
        webPreferences: {
            nodeIntegration: true,
            contextIsolation: false
        }
    });

    mainWindow.loadFile('index.html');

    mainWindow.once('ready-to-show', () => {
        mainWindow.show();
        mainWindow.focus();
    });

    // Fallback force show
    setTimeout(() => {
        if (mainWindow && !mainWindow.isVisible()) {
            mainWindow.show();
        }
    }, 1000);

    mainWindow.on('closed', () => {
        mainWindow = null;
    });
}

function createTray() {
    try {
        const iconPath = path.join(__dirname, 'icon.ico');
        tray = new Tray(iconPath);

        const contextMenu = Menu.buildFromTemplate([
            {
                label: 'Show MacCam Bridge',
                click: () => {
                    if (mainWindow) {
                        mainWindow.show();
                        mainWindow.focus();
                    } else {
                        createWindow();
                    }
                }
            },
            {
                label: 'Minimize to Taskbar Tray',
                click: () => {
                    if (mainWindow) mainWindow.hide();
                }
            },
            { type: 'separator' },
            {
                label: 'Quit MacCam Bridge',
                click: () => {
                    if (virtualCamProcess) virtualCamProcess.kill();
                    app.quit();
                }
            }
        ]);

        tray.setToolTip('MacCam Bridge — Windows 11 Receiver');
        tray.setContextMenu(contextMenu);

        tray.on('double-click', () => {
            if (mainWindow) {
                if (mainWindow.isVisible()) {
                    mainWindow.focus();
                } else {
                    mainWindow.show();
                }
            }
        });
    } catch (e) {
        console.error('Failed to create system tray:', e);
    }
}

// IPC Handlers
ipcMain.handle('scan-lan', async () => {
    try {
        const devices = await performLanScan();
        return { success: true, devices };
    } catch (err) {
        return { success: false, error: err.message };
    }
});

ipcMain.handle('start-virtual-cam', async (event, { width, height, fps }) => {
    if (virtualCamProcess) {
        return { success: true, message: 'Already running' };
    }

    try {
        const scriptPath = path.join(__dirname, 'obs_virtual_cam_bridge.py');
        const pyCmd = process.platform === 'win32' ? 'python' : 'python3';
        virtualCamProcess = spawn(pyCmd, [scriptPath, '9090', String(width || 1920), String(height || 1080), String(fps || 30)]);

        virtualCamProcess.stdout?.on('data', (data) => console.log(`[VirtualCam Py]: ${data}`));
        virtualCamProcess.stderr?.on('data', (data) => console.error(`[VirtualCam Py Err]: ${data}`));

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
    createTray();

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
