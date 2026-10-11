# 📺 TV Atlas — Smart TV & Google TV Setup Guide

TV Atlas is designed from the ground up to be a **dual-mode application**: a powerful satellite broadcast map on your desktop, and a convenient **10-foot Leanback TV experience** in your living room.

If you use a **Smart TV running Google TV** (or Android TV, Sony, TCL, Hisense, Xiaomi, Philips, Chromecast with Google TV, Samsung Tizen, LG webOS) and don't know much about compiling apps, this guide walks you through the 4 easiest ways to enjoy TV Atlas on your TV.

---

## ⚡ Quick Summary: Pick Your Method

| Method | Setup Time | What You Need | Best For |
| :--- | :---: | :--- | :--- |
| **1. TV Web Hub** | **10 seconds** | TV Browser (*TV Bro* or *Downloader*) | Instant couch viewing without installing anything |
| **2. Google Cast** | **1 tap** | Phone / Laptop on the same Wi-Fi | Sending a stream directly to your Google TV |
| **3. Native Google TV App** | **2 minutes** | Google TV *Downloader* app | Having TV Atlas directly on your Google TV home screen |
| **4. HDMI Leanback Mode** | **Instant** | Laptop / PC connected to TV via HDMI | Ultimate hardware-accelerated 4K MPV playback |

---

## Method 1: The 10-Second TV Web Hub (No Installation Required)

Every Smart TV with Google comes with a web browser or can install one for free from the Google Play Store.

### Steps:
1. **Start TV Atlas on your computer**:
   ```bash
   ./tv-atlas
   ```
   *(Or if you only want the TV server running in the background without opening the computer window, run `./tv-atlas --web`).*

2. **Note your TV Address**:
   Look at the on-screen badge or terminal:
   ```text
   📺 TV ADDRESS: http://192.168.x.x:8080
   ```
   *(You can also click the `[📡 CAST]` button in the top bar of TV Atlas to see the large QR code and IP address).*

3. **Open the browser on your Google TV**:
   - Open **TV Bro** (recommended — free on Google Play Store for Google TV), **Downloader**, or **JioPages**.
   - Type your TV Address (e.g., `http://192.168.1.50:8080`).

4. **Enjoy with your TV remote**:
   - Use the **Arrow keys (▲ ▼ ◄ ►)** on your TV remote to browse channels.
   - Press **[OK / ENTER]** to tune into any channel and watch live in fullscreen.
   - Press **[BACK]** to return to the channel grid.

---

## Method 2: 1-Click Google Cast (Chromecast)

Since your Smart TV runs Google TV, it has **Chromecast built-in**:

1. Open `http://<your-computer-ip>:8080` in Chrome on your phone, tablet, or laptop.
2. Select any channel.
3. Tap the **Google Cast icon** in the top-right header or video player.
4. Select your **Google TV** from the device list.
5. The broadcast immediately starts streaming in full resolution on your TV!

---

## Method 3: Native Google TV App (Installed on your TV)

If you want TV Atlas to appear directly on your Google TV home screen alongside your favorite apps (like YouTube and Netflix):

### How to install on Google TV using the Downloader app:
1. On your Google TV, open the **Google Play Store**, search for **Downloader by AFTVnews**, and install it.
2. Open **Downloader** on your TV.
3. In the URL box, enter the direct link to the TV Atlas Google TV APK from our GitHub Releases:
   ```text
   https://github.com/MaenExists/TV-Atlas/releases/latest/download/tv-atlas-googletv-debug.apk
   ```
4. Click **Go**. Downloader will download the APK and prompt you to install.
5. *(If prompted, allow Downloader to "Install unknown apps" in Google TV Settings -> Privacy -> Security).*
6. Click **Install**, then click **Open**.
7. **TV Atlas** is now installed directly on your Google TV with its official Leanback banner!

### For Developers (via ADB over Wi-Fi):
```bash
adb connect <your-tv-ip>:5555
cd android
./gradlew installDebug
```

---

## Method 4: HDMI Couch Leanback Mode (`--tv`)

If you have your laptop, mini-PC, or HTPC hooked up to your Smart TV via an HDMI cable:

1. Launch TV Atlas in dedicated TV mode:
   ```bash
   ./tv-atlas --tv
   ```
   *(Or press the `T` key or click the `[📺 TV]` button at any time in the app).*

2. **What TV Mode does**:
   - Automatically upscales typography (18px-24px) for comfortable 10-foot viewing distance.
   - Enables high-contrast **electric cyan glowing focus rings** on active channel cards.
   - Gives you 100% keyboard, TV air mouse, and D-Pad remote control without touching a mouse.

---

## 🎮 TV Remote & Keyboard Controls Cheat Sheet

| Button on TV Remote | Keyboard Key | Action |
| :---: | :---: | :--- |
| **▲ / ▼** | `Up / Down` | Scroll through channels in list |
| **◄ / ►** | `Left / Right` | Switch between World / News / Sports / Favorites tabs or rotate globe |
| **OK / SELECT** | `Enter / Return` | Tune highlighted channel immediately |
| **BACK** | `Escape` | Exit fullscreen playback / close dialogs |
| **PLAY / PAUSE** | `Space` | Pause or resume live feed |
| **MUTE** | `M` | Mute / Unmute audio |
| **YELLOW / F** | `F / F11` | Toggle Cinema Fullscreen mode |
| **T** | `T` | Toggle between Desktop and TV Leanback mode |
| **?** | `?` | Show on-screen remote control guide |

---

## 🛠️ Troubleshooting

- **"My TV says connection refused when opening http://...:8080"**:
  Make sure your computer and your Google TV are connected to the same Wi-Fi router / local network.
- **"I don't know my computer's local IP address"**:
  Open TV Atlas on your computer and click the `[📡 CAST]` button in the top bar. The exact URL and a scannable QR code are displayed directly on your screen.
- **"Can I run the TV server on my Linux PC in the background 24/7?"**:
  Yes! Just run `./tv-atlas --web` (or create a systemd service). It uses less than 15MB of RAM in headless mode.

---

<div align="center">

`Property of Maen`

</div>

