/**
 * The Windows and Linux shell.
 *
 * Deliberately thin: no node integration in the page, no remote content, no
 * network at all. The diary lives in the renderer's IndexedDB inside this app's
 * own profile, and the only way data leaves is a file the person exports.
 */
const { app, BrowserWindow, shell, Menu } = require('electron');
const path = require('node:path');

function createWindow() {
  const win = new BrowserWindow({
    width: 480,
    height: 860,
    minWidth: 360,
    minHeight: 560,
    title: 'Tratto',
    autoHideMenuBar: true,
    backgroundColor: '#faf8f5',
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  });

  win.loadFile(path.join(__dirname, '..', 'dist', 'index.html'));

  // Nothing in this app should ever open a second window, and any link that
  // tries goes to the real browser instead.
  win.webContents.setWindowOpenHandler(({ url }) => {
    if (url.startsWith('https://')) shell.openExternal(url);
    return { action: 'deny' };
  });
  win.webContents.on('will-navigate', (event, url) => {
    if (!url.startsWith('file://')) {
      event.preventDefault();
      if (url.startsWith('https://')) shell.openExternal(url);
    }
  });
}

app.whenReady().then(() => {
  Menu.setApplicationMenu(null);
  createWindow();
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
