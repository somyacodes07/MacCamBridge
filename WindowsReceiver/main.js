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

function getUsbIpAddress() {
    const interfaces = os.networkInterfaces();
    for (const name of Object.keys(interfaces)) {
        for (const iface of interfaces[name]) {
            if (iface.family === 'IPv4' && !iface.internal) {
                if (iface.address.startsWith('169.254.')) {
                    return iface.address;
                }
            }
        }
    }
    return null;
}

ipcMain.handle('get-usb-ip', async () => {
    return { usbIp: getUsbIpAddress() };
});

ipcMain.handle('start-virtual-cam', async (event, { width, height, fps }) => {
    if (virtualCamProcess) {
        return { success: true, message: 'Already running' };
    }

    return new Promise((resolve) => {
        const scriptPath = path.join(__dirname, 'obs_virtual_cam_bridge.py');
        const commands = process.platform === 'win32' ? ['python', 'py', 'python3'] : ['python3', 'python'];
        let cmdIndex = 0;
        let lastErr = '';

        function trySpawn() {
            if (cmdIndex >= commands.length) {
                resolve({ 
                    success: false, 
                    error: `Virtual camera launch failed (${lastErr}). Click 'Auto-Install Driver' to fix.` 
                });
                return;
            }

            const pyCmd = commands[cmdIndex++];
            const proc = spawn(pyCmd, [scriptPath, '9090', String(width || 1920), String(height || 1080), String(fps || 30)]);
            let hasStarted = false;
            let stderrData = '';

            proc.stderr?.on('data', (data) => {
                const str = data.toString();
                stderrData += str;
                console.error(`[VirtualCam Py Err]: ${str}`);
            });

            proc.stdout?.on('data', (data) => {
                const str = data.toString();
                console.log(`[VirtualCam Py]: ${str}`);
                if (str.includes('Virtual Cam Active') || str.includes('Listening')) {
                    hasStarted = true;
                    virtualCamProcess = proc;
                    resolve({ success: true });
                }
            });

            proc.on('error', (err) => {
                lastErr = err.message;
                trySpawn();
            });

            proc.on('exit', (code) => {
                if (!hasStarted) {
                    lastErr = stderrData || `Exited with code ${code}`;
                    trySpawn();
                } else {
                    virtualCamProcess = null;
                }
            });

            setTimeout(() => {
                if (!hasStarted && proc.exitCode === null) {
                    hasStarted = true;
                    virtualCamProcess = proc;
                    resolve({ success: true });
                }
            }, 1500);
        }

        trySpawn();
    });
});

ipcMain.handle('install-vcam-deps', async () => {
    return new Promise((resolve) => {
        const commands = process.platform === 'win32' ? ['python', 'py', 'python3'] : ['python3', 'python'];
        let cmdIndex = 0;

        function tryInstall() {
            if (cmdIndex >= commands.length) {
                resolve({ success: false, error: 'Python not found on system PATH. Please install Python 3.10+ from python.org.' });
                return;
            }

            const pyCmd = commands[cmdIndex++];
            const proc = spawn(pyCmd, ['-m', 'pip', 'install', 'pyvirtualcam', 'opencv-python', 'numpy']);
            let output = '';

            proc.stdout?.on('data', d => output += d);
            proc.stderr?.on('data', d => output += d);

            proc.on('error', () => tryInstall());

            proc.on('exit', (code) => {
                if (code === 0) {
                    resolve({ success: true, message: 'Virtual Camera driver dependencies installed successfully!' });
                } else {
                    tryInstall();
                }
            });
        }

        tryInstall();
    });
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
