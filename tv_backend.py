#!/usr/bin/env python3
"""
tv_backend.py - Terminal / Sci-Fi Backend for TV Atlas
Handles 15,000+ worldwide channels, GeoJSON metadata, embedded MPV playback
inside the app window, favorites, recent history, and real-time socket control.
"""

import os
import sys
import json
import time
import socket
import subprocess
import threading
from pathlib import Path

from PySide6.QtCore import QObject, Signal, Slot, Property, QTimer

STATE_DIR = Path.home() / ".local" / "share" / "tv-atlas"
STATE_FILE = STATE_DIR / "state.json"
FAVORITES_FILE = STATE_DIR / "favorites.json"
CACHE_DIR = Path.home() / ".cache" / "tv-atlas"
MPV_SOCK = "/tmp/tv-atlas-mpv.sock"


class MPVController:
    """Manages an embedded MPV process via --wid and Unix socket IPC."""

    def __init__(self):
        self.proc = None
        self.sock_path = MPV_SOCK
        self._lock = threading.Lock()
        self.current_wid = None

    def is_running(self):
        return self.proc is not None and self.proc.poll() is None

    def send_command(self, cmd_list):
        if not self.is_running() or not os.path.exists(self.sock_path):
            return None
        with self._lock:
            try:
                s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                s.settimeout(1.0)
                s.connect(self.sock_path)
                msg = json.dumps({"command": cmd_list}) + "\n"
                s.sendall(msg.encode("utf-8"))
                resp = s.recv(4096).decode("utf-8", errors="ignore")
                s.close()
                return json.loads(resp.strip()) if resp.strip() else None
            except Exception:
                return None

    def play(self, url, wid=None, title="TV Atlas"):
        if wid is not None:
            self.current_wid = wid

        if self.is_running():
            # If MPV is already running, switch streams instantly without recreating window
            res = self.send_command(["loadfile", url, "replace"])
            if res:
                self.send_command(["set_property", "pause", False])
                return True

        # Stop previous if any
        self.stop()

        if os.path.exists(self.sock_path):
            try:
                os.unlink(self.sock_path)
            except Exception:
                pass

        # Launch MPV embedded inside the application's native video widget window ID
        cmd = [
            "mpv",
            f"--input-ipc-server={self.sock_path}",
            "--idle=yes",
            "--keep-open=yes",
            "--no-terminal",
            "--script-opts=osc-idlescreen=no",
            "--background-color=#03070c",
            "--demuxer-lavf-analyzeduration=1.5",
            "--demuxer-lavf-probesize=131072",
            "--cache=yes",
            "--demuxer-max-bytes=64MiB",
            "--demuxer-max-back-bytes=16MiB",
            "--demuxer-readahead-secs=30",
            "--hwdec=auto-safe",
            "--ytdl=no",
            "--network-timeout=10",
            "--stream-buffer-size=1MiB",
            "--user-agent=Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36",
            "--tls-verify=no",
            "--video-aspect-override=16:9",
            "--osc=yes",
            "--osd-level=1",
            "--input-default-bindings=yes",
            "--input-vo-keyboard=yes",
        ]

        if self.current_wid is not None:
            cmd.append(f"--wid={self.current_wid}")
            cmd.append("--vo=x11,gpu")
            cmd.append("--force-window=yes")

        cmd.append(url)

        sub_env = os.environ.copy()
        sub_env.pop("WAYLAND_DISPLAY", None)
        sub_env["DISPLAY"] = os.environ.get("DISPLAY", ":0")

        try:
            self.proc = subprocess.Popen(
                cmd,
                env=sub_env,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                preexec_fn=os.setsid
            )
            return True
        except Exception as e:
            print(f"[TVAtlas] Error starting embedded MPV: {e}", file=sys.stderr)
            return False

    def toggle_pause(self):
        return self.send_command(["cycle", "pause"])

    def stop(self):
        if self.proc is not None:
            try:
                self.send_command(["quit"])
                self.proc.terminate()
                self.proc.wait(timeout=0.4)
            except Exception:
                pass
            self.proc = None
        if os.path.exists(self.sock_path):
            try:
                os.unlink(self.sock_path)
            except Exception:
                pass

    def set_volume(self, vol):
        return self.send_command(["set_property", "volume", max(0, min(100, vol))])

    def toggle_mute(self):
        return self.send_command(["cycle", "mute"])


class TVAtlasBackend(QObject):
    stateChanged = Signal()
    currentChannelChanged = Signal()
    playbackStatusChanged = Signal()
    streamStatusChanged = Signal()
    activeCountryChanged = Signal()
    channelsChanged = Signal()
    favoritesChanged = Signal()
    recentChanged = Signal()
    videoVisibilityChanged = Signal(bool)
    fullscreenChanged = Signal(bool)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.mpv = MPVController()

        self._countries_json = "{}"
        self._all_channels = []
        self._display_channels = []
        self._world_signals = []
        self._priority_channels = []
        self._favorites = []
        self._recent = []

        self._current_channel = {}
        self._is_playing = False
        self._is_paused = False
        self._volume = 100
        self._is_muted = False
        self._active_country_code = ""
        self._active_country_name = ""
        self._search_query = ""
        self._stream_status_text = "// MONITOR STANDBY · AWAITING SIGNAL"
        self._mode = "world"  # "world", "country", "favorites", "recent", "search"
        self._target_wid = None
        self._is_fullscreen = False

        STATE_DIR.mkdir(parents=True, exist_ok=True)
        CACHE_DIR.mkdir(parents=True, exist_ok=True)

        self._load_state()
        self._load_data()

    def set_target_wid(self, wid):
        self._target_wid = wid

    # ---------------- State & Data ----------------

    def _load_state(self):
        # 1. Dedicated favorites storage
        if FAVORITES_FILE.exists():
            try:
                with open(FAVORITES_FILE, "r", encoding="utf-8") as f:
                    self._favorites = json.load(f)
            except Exception as e:
                print(f"[TVAtlas] Favorites read error: {e}", file=sys.stderr)

        # 2. General state (recent, volume, fallback favorites)
        if STATE_FILE.exists():
            try:
                with open(STATE_FILE, "r", encoding="utf-8") as f:
                    d = json.load(f)
                    if not self._favorites:
                        self._favorites = d.get("favorites", [])
                    self._recent = d.get("recent", [])
                    self._volume = d.get("volume", 100)
            except Exception as e:
                print(f"[TVAtlas] State read error: {e}", file=sys.stderr)

    def _save_state(self):
        # Atomically write favorites.json
        try:
            tmp_fav = STATE_DIR / "favorites.json.tmp"
            with open(tmp_fav, "w", encoding="utf-8") as f:
                json.dump(self._favorites, f, indent=2)
                f.flush()
                os.fsync(f.fileno())
            tmp_fav.replace(FAVORITES_FILE)
        except Exception as e:
            print(f"[TVAtlas] Favorites write error: {e}", file=sys.stderr)

        # Atomically write state.json
        try:
            tmp_state = STATE_DIR / "state.json.tmp"
            with open(tmp_state, "w", encoding="utf-8") as f:
                json.dump({
                    "favorites": self._favorites,
                    "recent": self._recent[:60],
                    "volume": self._volume
                }, f, indent=2)
                f.flush()
                os.fsync(f.fileno())
            tmp_state.replace(STATE_FILE)
        except Exception as e:
            print(f"[TVAtlas] State write error: {e}", file=sys.stderr)

    def _load_data(self):
        base_dir = Path(__file__).resolve().parent
        countries_file = base_dir / "assets" / "countries.json"
        catalog_file = base_dir / "assets" / "world_catalog.json"

        # Load GeoJSON string
        if countries_file.exists():
            with open(countries_file, "r", encoding="utf-8") as f:
                self._countries_json = f.read()

        # Load Catalog (15,444 channels)
        if catalog_file.exists():
            with open(catalog_file, "r", encoding="utf-8") as f:
                self._all_channels = json.load(f)
        else:
            self._all_channels = []

        # Prepare ALL channels as interactive signals for the 3D globe (15,444 channels)
        signals = []
        for s in self._all_channels:
            if s.get("lat") is not None and s.get("lon") is not None:
                try:
                    lat_val = float(s["lat"])
                    lon_val = float(s["lon"])
                    signals.append({
                        "uuid": str(s.get("id") or s.get("url") or s.get("name")),
                        "name": str(s.get("name", "Station")),
                        "country": str(s.get("countryName", s.get("country", ""))),
                        "countryCode": str(s.get("country", "")),
                        "latitude": lat_val,
                        "longitude": lon_val,
                        "category": str(s.get("category", "General")),
                        "quality": str(s.get("quality", "HD")),
                        "url": str(s.get("url", ""))
                    })
                except (ValueError, TypeError):
                    continue
        self._world_signals = signals

        # Boost verified working international stations to the top of World list
        priority_file = base_dir / "assets" / "priority_streams.json"
        priority_channels = []
        seen = set()

        # Add 2M Monde (Morocco 1080p high reliability stream)
        m2_channel = {
            "id": "2MMonde.ma",
            "name": "2M Monde",
            "country": "MA",
            "countryName": "Morocco",
            "category": "General",
            "quality": "1080p",
            "url": "https://d2qh3gh0k5vp3v.cloudfront.net/v1/master/3722c60a815c199d9c0ef36c5b73da68a62b09d1/cc-n6pess5lwbghr/2M_ES.m3u8",
            "lat": 31.7917,
            "lon": -7.0926
        }
        priority_channels.append(m2_channel)
        seen.add(m2_channel["url"])

        if priority_file.exists():
            try:
                with open(priority_file, "r", encoding="utf-8") as f:
                    p_list = json.load(f)
                    for pc in p_list:
                        u = pc.get("url")
                        if u and u not in seen:
                            seen.add(u)
                            priority_channels.append(pc)
            except Exception as e:
                print(f"[TVAtlas] Error loading priority streams: {e}", file=sys.stderr)

        regular_channels = [c for c in self._all_channels if c.get("url") not in seen]
        self._priority_channels = list(priority_channels)
        self._all_channels = priority_channels + regular_channels
        self._display_channels = list(self._all_channels[:500])

    # ---------------- Properties for QML ----------------

    @Property(str, notify=streamStatusChanged)
    def streamStatusText(self):
        return self._stream_status_text

    @Property(str, notify=stateChanged)
    def countriesJson(self):
        return self._countries_json

    @Property("QVariantList", notify=stateChanged)
    def worldSignals(self):
        return self._world_signals

    @Property("QVariantList", notify=channelsChanged)
    def channels(self):
        return self._display_channels

    @Property("QVariantMap", notify=currentChannelChanged)
    def currentChannel(self):
        return self._current_channel

    @Property(bool, notify=playbackStatusChanged)
    def isPlaying(self):
        return self._is_playing

    @Property(bool, notify=playbackStatusChanged)
    def isPaused(self):
        return self._is_paused

    @Property(int, notify=stateChanged)
    def volume(self):
        return self._volume

    @Property(bool, notify=stateChanged)
    def isMuted(self):
        return self._is_muted

    @Property(str, notify=activeCountryChanged)
    def activeCountryCode(self):
        return self._active_country_code

    @Property(str, notify=activeCountryChanged)
    def activeCountryName(self):
        return self._active_country_name

    @Property(int, notify=channelsChanged)
    def totalSignalCount(self):
        return len(self._all_channels)

    @Property("QVariantList", notify=favoritesChanged)
    def favorites(self):
        return self._favorites

    @Property("QVariantList", notify=recentChanged)
    def recent(self):
        return self._recent

    @Property(str, notify=stateChanged)
    def mode(self):
        return self._mode

    @Property(bool, notify=fullscreenChanged)
    def isFullscreen(self):
        return self._is_fullscreen

    # ---------------- Public QML Slots ----------------

    @Slot()
    def toggleFullscreen(self):
        self._is_fullscreen = not self._is_fullscreen
        self.fullscreenChanged.emit(self._is_fullscreen)

    @Slot(bool)
    def setFullscreen(self, val):
        if self._is_fullscreen != val:
            self._is_fullscreen = val
            self.fullscreenChanged.emit(self._is_fullscreen)

    @Slot(str, str)
    def selectCountry(self, code, name):
        """Filters channels to selected country and highlights on globe"""
        code = (code or "").upper()
        self._active_country_code = code
        self._active_country_name = name or code
        self._mode = "country"

        country_stations = [c for c in self._all_channels if c.get("country", "").upper() == code]
        self._display_channels = country_stations
        self.activeCountryChanged.emit()
        self.channelsChanged.emit()
        self.stateChanged.emit()

    @Slot()
    def showWorld(self):
        """Show global channels"""
        self._active_country_code = ""
        self._active_country_name = ""
        self._mode = "world"
        self._display_channels = list(self._all_channels[:500])
        self.activeCountryChanged.emit()
        self.channelsChanged.emit()
        self.stateChanged.emit()

    @Slot()
    def showFavorites(self):
        """Show starred channels"""
        self._mode = "favorites"
        self._display_channels = list(self._favorites)
        self.channelsChanged.emit()
        self.stateChanged.emit()

    @Slot()
    def showRecent(self):
        """Show recently played channels"""
        self._mode = "recent"
        self._display_channels = list(self._recent)
        self.channelsChanged.emit()
        self.stateChanged.emit()

    @Slot(str)
    def search(self, query):
        """Instant search across all 15,444 channels"""
        q = (query or "").strip().lower()
        self._search_query = q
        if not q:
            if self._active_country_code:
                self.selectCountry(self._active_country_code, self._active_country_name)
            else:
                self.showWorld()
            return

        self._mode = "search"
        results = []
        for c in self._all_channels:
            name = c.get("name", "").lower()
            country = c.get("countryName", "").lower()
            code = c.get("country", "").lower()
            cat = c.get("category", "").lower()

            if q in name or q in country or q == code or q in cat:
                results.append(c)
                if len(results) >= 300:
                    break

        self._display_channels = results
        self.channelsChanged.emit()
        self.stateChanged.emit()

    @Slot("QVariantMap")
    def playChannel(self, channel):
        """Plays channel embedded inside the application's video frame"""
        if not channel or not channel.get("url"):
            return

        url = channel["url"]
        name = channel.get("name", "TV Station")
        self._current_channel = dict(channel)
        self._is_playing = True
        self._is_paused = False

        self._stream_status_text = f"// TUNING: {name} · BUFFERING FEED"

        # Add to recent
        self._recent = [c for c in self._recent if c.get("url") != url]
        self._recent.insert(0, dict(channel))
        self._save_state()

        # Update active country
        code = channel.get("country", "")
        if code:
            self._active_country_code = code.upper()
            self._active_country_name = channel.get("countryName", code)
            self.activeCountryChanged.emit()

        self.currentChannelChanged.emit()
        self.playbackStatusChanged.emit()
        self.streamStatusChanged.emit()
        self.recentChanged.emit()
        self.videoVisibilityChanged.emit(True)

        # Launch / control MPV inside the app window
        self.mpv.play(url, wid=self._target_wid, title=name)
        self.mpv.set_volume(self._volume)

        # Telemetry updates (Never auto-route; report real status in-app)
        QTimer.singleShot(2500, lambda: self._update_stream_telemetry(dict(channel)))
        QTimer.singleShot(5500, lambda: self._update_stream_telemetry(dict(channel)))

    def _update_stream_telemetry(self, orig_channel):
        if not self._is_playing or self._is_paused:
            return
        if self._current_channel.get("url") != orig_channel.get("url"):
            return

        name = orig_channel.get("name", "Station")
        if not self.mpv.is_running():
            self._stream_status_text = f"// STREAM OFFLINE: {name} · DECODER STOPPED"
            self.streamStatusChanged.emit()
            return

        try:
            idle_res = self.mpv.send_command(["get_property", "idle-active"])
            time_res = self.mpv.send_command(["get_property", "playback-time"])
            is_idle = idle_res and idle_res.get("data") is True
            playback_time = time_res.get("data") if (time_res and "data" in time_res) else None

            # Get video resolution from demuxer
            w_res = self.mpv.send_command(["get_property", "video-params/w"])
            h_res = self.mpv.send_command(["get_property", "video-params/h"])
            w = w_res.get("data") if (w_res and "data" in w_res) else None
            h = h_res.get("data") if (h_res and "data" in h_res) else None

            if playback_time is not None and playback_time > 0:
                res_tag = f"{w}x{h}" if (w and h) else orig_channel.get("quality", "HD")
                self._stream_status_text = f"// LIVE STREAM: {name} · [{res_tag}] ACTIVE"
                self.streamStatusChanged.emit()
            elif is_idle:
                self._stream_status_text = f"// STREAM OFFLINE: {name} · FEED UNREACHABLE"
                self.streamStatusChanged.emit()
            else:
                self._stream_status_text = f"// LIVE STREAM: {name} · ACTIVE"
                self.streamStatusChanged.emit()
        except Exception:
            pass

    @Slot()
    def togglePlayPause(self):
        if not self._is_playing:
            if self._display_channels:
                self.playChannel(self._display_channels[0])
            return

        self._is_paused = not self._is_paused
        self.playbackStatusChanged.emit()
        self.mpv.toggle_pause()

    @Slot()
    def stop(self):
        self._is_playing = False
        self._is_paused = False
        self._stream_status_text = "// MONITOR STANDBY · AWAITING SIGNAL"
        self.streamStatusChanged.emit()
        self.playbackStatusChanged.emit()
        self.videoVisibilityChanged.emit(False)
        self.mpv.stop()

    @Slot()
    def nextStation(self):
        if not self._display_channels:
            return
        cur_url = self._current_channel.get("url")
        idx = -1
        for i, c in enumerate(self._display_channels):
            if c.get("url") == cur_url:
                idx = i
                break
        next_idx = (idx + 1) % len(self._display_channels)
        self.playChannel(self._display_channels[next_idx])

    @Slot()
    def previousStation(self):
        if not self._display_channels:
            return
        cur_url = self._current_channel.get("url")
        idx = 0
        for i, c in enumerate(self._display_channels):
            if c.get("url") == cur_url:
                idx = i
                break
        prev_idx = (idx - 1 + len(self._display_channels)) % len(self._display_channels)
        self.playChannel(self._display_channels[prev_idx])

    @Slot()
    def playRandom(self):
        """Picks a random channel anywhere on Earth and plays it"""
        import random
        pool = self._all_channels if self._all_channels else self._display_channels
        if pool:
            chosen = random.choice(pool)
            self.playChannel(chosen)

    @Slot(int)
    def setVolume(self, vol):
        self._volume = max(0, min(100, vol))
        self._is_muted = (self._volume == 0)
        self.stateChanged.emit()
        self._save_state()
        self.mpv.set_volume(self._volume)

    @Slot()
    def toggleMute(self):
        self._is_muted = not self._is_muted
        self.stateChanged.emit()
        self.mpv.toggle_mute()

    @Slot("QVariantMap")
    def toggleFavorite(self, channel):
        if not channel or not channel.get("url"):
            return
        url = channel["url"]
        exists = any(c.get("url") == url for c in self._favorites)
        if exists:
            self._favorites = [c for c in self._favorites if c.get("url") != url]
        else:
            self._favorites.insert(0, dict(channel))
        self._save_state()
        self.favoritesChanged.emit()

    @Slot(str, result=bool)
    def isFavorite(self, url):
        return any(c.get("url") == url for c in self._favorites)

    def cleanup(self):
        self.mpv.stop()
