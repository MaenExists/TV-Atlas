#!/usr/bin/env python3
"""
web_server.py - TV Atlas Local Web TV Hub & Google Cast Server
Serves a high-performance 10-foot Leanback Web TV interface on the local network,
allowing any Smart TV (Google TV, Android TV, Tizen, webOS) or Chromecast device
to browse, tune, and stream channels using a standard TV remote control or phone.
"""

import os
import sys
import json
import socket
import urllib.parse
import urllib.request
import threading
from pathlib import Path
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler

import qrcode
import qrcode.image.svg

BASE_DIR = Path(__file__).resolve().parent
ASSETS_DIR = BASE_DIR / "assets"
WEB_DIR = ASSETS_DIR / "web_tv"
CATALOG_FILE = ASSETS_DIR / "world_catalog.json"
PRIORITY_FILE = ASSETS_DIR / "priority_streams.json"


def get_lan_ip():
    """Returns the primary local IPv4 address accessible on the LAN."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"


def generate_qr_svg(url):
    """Generates an SVG string of a QR code pointing to url."""
    try:
        factory = qrcode.image.svg.SvgPathImage
        qr = qrcode.QRCode(image_factory=factory, box_size=8, border=2)
        qr.add_data(url)
        qr.make(fit=True)
        img = qr.make_image()
        import io
        buf = io.BytesIO()
        img.save(buf)
        return buf.getvalue().decode("utf-8")
    except Exception as e:
        print(f"[TVAtlas Web] Error generating QR code: {e}", file=sys.stderr)
        return ""


class TVAtlasWebHandler(SimpleHTTPRequestHandler):
    """Handles static files, REST API requests, and stream proxying."""

    channels_data = []
    priority_data = []
    current_channel = {}
    lan_ip = "127.0.0.1"
    server_port = 8080

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(WEB_DIR), **kwargs)

    def log_message(self, format, *args):
        # Silence verbose asset requests, log only API
        if len(args) > 0 and "/api/" in str(args[0]):
            sys.stderr.write(f"[TVAtlas Web] {self.address_string()} - {format % args}\n")

    def end_headers(self):
        # Enable CORS for all responses to allow Smart TV browsers & Cast SDK to connect cleanly
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Range")
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(204)
        self.end_headers()

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        query = urllib.parse.parse_qs(parsed.query)

        # 1. API: Server Info & LAN Details
        if path == "/api/info":
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.end_headers()
            info = {
                "name": "TV Atlas Web Hub",
                "version": "1.2.0",
                "lan_ip": self.lan_ip,
                "port": self.server_port,
                "tv_url": f"http://{self.lan_ip}:{self.server_port}",
                "total_channels": len(self.channels_data),
                "current_channel": self.current_channel
            }
            self.wfile.write(json.dumps(info).encode("utf-8"))
            return

        # 2. API: QR Code SVG
        if path == "/api/qr":
            url = f"http://{self.lan_ip}:{self.server_port}"
            svg = generate_qr_svg(url)
            self.send_response(200)
            self.send_header("Content-Type", "image/svg+xml")
            self.send_header("Cache-Control", "max-age=3600")
            self.end_headers()
            self.wfile.write(svg.encode("utf-8"))
            return

        # 3. API: Top / Priority Verified Channels
        if path == "/api/priority":
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.end_headers()
            self.wfile.write(json.dumps(self.priority_data).encode("utf-8"))
            return

        # 4. API: Filtered Channel Search
        if path == "/api/channels":
            q = (query.get("q", [""])[0]).strip().lower()
            cat = (query.get("category", [""])[0]).strip().lower()
            country = (query.get("country", [""])[0]).strip().upper()
            try:
                limit = int(query.get("limit", [150])[0])
            except ValueError:
                limit = 150
            try:
                offset = int(query.get("offset", [0])[0])
            except ValueError:
                offset = 0

            # Priority first if no query and no category filter
            pool = self.channels_data
            if not q and not cat and not country:
                pool = self.priority_data + [c for c in self.channels_data if c not in self.priority_data]

            results = []
            for c in pool:
                name = c.get("name", "").lower()
                c_code = c.get("country", "").upper()
                c_name = c.get("countryName", "").lower()
                c_cat = c.get("category", "").lower()

                if country and c_code != country:
                    continue
                if cat and cat != "all" and cat not in c_cat:
                    continue
                if q:
                    if q not in name and q not in c_name and q != c_code.lower() and q not in c_cat:
                        continue
                results.append(c)

            paginated = results[offset:offset + limit]
            resp = {
                "total": len(results),
                "offset": offset,
                "limit": limit,
                "channels": paginated
            }
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.end_headers()
            self.wfile.write(json.dumps(resp).encode("utf-8"))
            return

        # 5. API: Stream Proxy (Bypasses CORS restrictions on Smart TV browsers)
        if path == "/api/proxy":
            target_url = query.get("url", [""])[0]
            if not target_url or not (target_url.startswith("http://") or target_url.startswith("https://")):
                self.send_response(400)
                self.end_headers()
                self.wfile.write(b"Invalid target URL")
                return

            try:
                req = urllib.request.Request(
                    target_url,
                    headers={
                        "User-Agent": "Mozilla/5.0 (SmartHub; SMART-TV; Linux/SmartTV) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 TVAtlas/1.2"
                    }
                )
                with urllib.request.urlopen(req, timeout=8) as resp:
                    status = resp.status
                    content_type = resp.headers.get("Content-Type", "application/octet-stream")
                    data = resp.read()

                    self.send_response(status)
                    self.send_header("Content-Type", content_type)
                    self.send_header("Content-Length", str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
                    return
            except Exception as e:
                self.send_response(502)
                self.end_headers()
                self.wfile.write(f"Proxy error: {e}".encode("utf-8"))
                return

        # 6. Default: Serve static files from assets/web_tv/
        return super().do_GET()


class WebTVServer:
    """Threaded HTTP server controller for TV Atlas Web Hub."""

    def __init__(self, port=8080):
        self.port = port
        self.server = None
        self.thread = None
        self.lan_ip = get_lan_ip()
        self.is_running = False

        # Load channels
        self.channels = []
        self.priority = []
        self._load_data()

    def _load_data(self):
        if CATALOG_FILE.exists():
            try:
                with open(CATALOG_FILE, "r", encoding="utf-8") as f:
                    self.channels = json.load(f)
            except Exception as e:
                print(f"[TVAtlas Web] Error reading catalog: {e}", file=sys.stderr)

        if PRIORITY_FILE.exists():
            try:
                with open(PRIORITY_FILE, "r", encoding="utf-8") as f:
                    self.priority = json.load(f)
            except Exception as e:
                print(f"[TVAtlas Web] Error reading priority streams: {e}", file=sys.stderr)

        TVAtlasWebHandler.channels_data = self.channels
        TVAtlasWebHandler.priority_data = self.priority
        TVAtlasWebHandler.lan_ip = self.lan_ip
        TVAtlasWebHandler.server_port = self.port

    def start(self):
        if self.is_running:
            return

        # Try designated port, or search next available
        p = self.port
        max_attempts = 10
        for _ in range(max_attempts):
            try:
                TVAtlasWebHandler.server_port = p
                self.server = ThreadingHTTPServer(("0.0.0.0", p), TVAtlasWebHandler)
                self.port = p
                break
            except OSError:
                p += 1

        if not self.server:
            print(f"[TVAtlas Web] Failed to bind HTTP server to port {self.port}", file=sys.stderr)
            return

        self.is_running = True
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        print(f"[TVAtlas Web] Hub active: http://{self.lan_ip}:{self.port} (0.0.0.0:{self.port})")

    def stop(self):
        if self.server:
            self.server.shutdown()
            self.server.server_close()
            self.server = None
        self.is_running = False

    def get_url(self):
        return f"http://{self.lan_ip}:{self.port}"

    def get_qr_svg(self):
        return generate_qr_svg(self.get_url())


_global_web_server = None


def get_web_server(port=8080):
    global _global_web_server
    if _global_web_server is None:
        _global_web_server = WebTVServer(port=port)
    return _global_web_server


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="TV Atlas Web TV Hub Server")
    parser.add_argument("--port", type=int, default=8080, help="Port to listen on (default: 8080)")
    args = parser.parse_args()

    server = WebTVServer(port=args.port)
    server.start()

    print("\n==========================================================")
    print("📺 TV ATLAS SMART TV & GOOGLE TV HUB ACTIVE")
    print(f"📡 Open this address in your Google TV / Smart TV browser:")
    print(f"👉 \033[1;36m{server.get_url()}\033[0m")
    print("==========================================================\n")
    print("Press Ctrl+C to terminate.")

    try:
        import time
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        server.stop()
        print("\n[TVAtlas Web] Hub stopped.")
