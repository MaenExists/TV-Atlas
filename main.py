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

from tv_backend import TVAtlasBackend


def main():
    signal.signal(signal.SIGINT, signal.SIG_DFL)

    QCoreApplication.setOrganizationName("TVAtlas")
    QCoreApplication.setApplicationName("TV-Atlas")

    app = QApplication(sys.argv)
    app.setWindowIcon(QIcon())

    # Backend
    backend = TVAtlasBackend(app)

    # Main QtQuick hardware-rendered view
    view = QQuickView()
    view.setTitle("TV Atlas")
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
