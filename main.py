#!/usr/bin/env python3
"""
main.py - Entry point for TV Atlas with Inbuilt Hardware-Accelerated Video Player
Uses QQuickView with direct hardware rendering, native embedded video surface,
and instant Fullscreen cinema mode controls.
"""

import sys
import os
import signal
from pathlib import Path

# Force xcb platform for clean subwindow embedding on Linux/Wayland (XWayland)
os.environ["QT_QPA_PLATFORM"] = "xcb"

from PySide6.QtWidgets import QApplication
from PySide6.QtQuick import QQuickView
from PySide6.QtGui import QWindow, QColor, QIcon, QResizeEvent
from PySide6.QtCore import QUrl, QCoreApplication, Qt, QPointF, QObject, QTimer, QSize, QEvent

import argparse
from tv_backend import TVAtlasBackend
import web_server


def main():
    signal.signal(signal.SIGINT, signal.SIG_DFL)

    parser = argparse.ArgumentParser(description="TV Atlas - Satellite Live Television Atlas")
    parser.add_argument("--tv", action="store_true", help="Launch in 10-foot Smart TV Leanback mode with D-Pad navigation")
    parser.add_argument("--web", "--server", action="store_true", dest="web_mode", help="Start standalone Web TV & Cast Hub on LAN (headless)")
    parser.add_argument("--port", type=int, default=8080, help="Web TV Hub port (default: 8080)")
    args, unknown = parser.parse_known_args()

    # Headless Web TV Hub mode
    if args.web_mode:
        server = web_server.get_web_server(port=args.port)
        server.start()
        print("\n==========================================================")
        print("📺 TV ATLAS SMART TV & GOOGLE TV WEB HUB")
        print(f"📡 Open this address in your Google TV / Smart TV browser:")
        print(f"👉 \033[1;36m{server.get_url()}\033[0m")
        print("==========================================================\n")
        print("Listening for Smart TV connections... Press Ctrl+C to terminate.")
        try:
            import time
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            server.stop()
            print("\n[TVAtlas Web] Stopped.")
            return

    QCoreApplication.setOrganizationName("TVAtlas")
    QCoreApplication.setApplicationName("TV-Atlas")

    app = QApplication(sys.argv)
    app.setWindowIcon(QIcon())

    # Backend
    backend = TVAtlasBackend(app)
    if args.tv:
        backend.setTvMode(True)

    # Main QtQuick hardware-rendered view
    view = QQuickView()
    view.setTitle("TV Atlas" if not args.tv else "TV Atlas // SMART_TV")
    if args.tv:
        view.resize(1280, 720)
    else:
        view.resize(980, 660)
    view.setMinimumSize(QSize(780, 520))
    view.setColor(QColor("#090a0c"))
    view.setResizeMode(QQuickView.SizeRootObjectToView)
    view.rootContext().setContextProperty("backend", backend)

    base_dir = Path(__file__).resolve().parent
    qml_file = base_dir / "qml" / "TVAtlas.qml"
    view.setSource(QUrl.fromLocalFile(str(qml_file)))

    # Native video viewport window embedded inside view
    video_win = QWindow(view)
    video_win.hide()

    def sync_video_geometry():
        if backend.isFullscreen:
            video_win.setGeometry(0, 48, view.width(), view.height() - 48)
            return

        root = view.rootObject()
        if not root:
            return
        slot = root.findChild(QObject, "videoContainerArea")
        if slot and slot.width() > 10 and slot.height() > 10:
            pt = slot.mapToItem(None, QPointF(0, 0))
            nx, ny = int(pt.x()) + 4, int(pt.y()) + 4
            nw, nh = int(slot.width()) - 8, int(slot.height()) - 8
            cur = video_win.geometry()
            if (cur.x(), cur.y(), cur.width(), cur.height()) != (nx, ny, nw, nh):
                video_win.setGeometry(nx, ny, nw, nh)

    def on_video_visibility(visible):
        if visible:
            sync_video_geometry()
            video_win.show()
            video_win.raise_()
        else:
            video_win.hide()

    backend.videoVisibilityChanged.connect(on_video_visibility)

    def on_fullscreen_changed(is_fs):
        if is_fs:
            view.showFullScreen()
            QTimer.singleShot(150, lambda: video_win.setGeometry(0, 48, view.width(), max(10, view.height() - 48)))
        else:
            view.showNormal()
            QTimer.singleShot(150, sync_video_geometry)

    backend.fullscreenChanged.connect(on_fullscreen_changed)

    class GlobalKeyFilter(QObject):
        def eventFilter(self, watched, event):
            if event.type() == QEvent.KeyPress:
                # Do not intercept shortcuts while the user is typing in the search input
                focus_item = view.activeFocusItem()
                if focus_item is not None:
                    cls = focus_item.metaObject().className()
                    if "Text" in cls or "Edit" in cls:
                        if event.key() == Qt.Key_Escape:
                            if backend.isFullscreen:
                                backend.setFullscreen(False)
                                return True
                        return False

                k = event.key()
                if k in (Qt.Key_F, Qt.Key_F11):
                    backend.toggleFullscreen()
                    return True
                elif k == Qt.Key_T:
                    backend.toggleTvMode()
                    return True
                elif k == Qt.Key_Escape:
                    if backend.isFullscreen:
                        backend.setFullscreen(False)
                        return True
                elif k == Qt.Key_Space:
                    backend.togglePlayPause()
                    return True
                elif k == Qt.Key_M:
                    backend.toggleMute()
                    return True
                elif backend.isTvMode:
                    if k == Qt.Key_Up:
                        backend.selectPreviousChannel()
                        return True
                    elif k == Qt.Key_Down:
                        backend.selectNextChannel()
                        return True
                    elif k in (Qt.Key_Return, Qt.Key_Enter, Qt.Key_Select):
                        backend.playSelectedChannel()
                        return True
            return False

    key_filter = GlobalKeyFilter(app)
    app.installEventFilter(key_filter)

    # Resize event hook on QQuickView
    orig_resize = view.resizeEvent
    def on_resize(event):
        if orig_resize:
            orig_resize(event)
        sync_video_geometry()
    view.resizeEvent = on_resize

    view.show()
    app.processEvents()

    # Pass the embedded window ID to backend for MPV playback
    backend.set_target_wid(int(video_win.winId()))
    sync_video_geometry()

    # Hook QML slot geometry signals for dynamic synchronization
    root = view.rootObject()
    if root:
        slot = root.findChild(QObject, "videoContainerArea")
        if slot:
            slot.yChanged.connect(sync_video_geometry)
            slot.xChanged.connect(sync_video_geometry)
            slot.widthChanged.connect(sync_video_geometry)
            slot.heightChanged.connect(sync_video_geometry)

    app.aboutToQuit.connect(backend.cleanup)
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
