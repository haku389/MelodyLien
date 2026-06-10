#!/usr/bin/env python3
"""
MelodyLien 開発サーバー
- Cache-Control: no-store を全レスポンスに付与
- index.html の <script> と JS ファイルの import 文にタイムスタンプを付与
  → ESModule キャッシュを完全に防ぐ
"""
import http.server
import os
import re
import time

ROOT = os.path.dirname(os.path.abspath(__file__))

def add_ts(content_str, ts):
    """
    JS の import/export 文と HTML の script src に ?t=<ts> を付与する。
    すでに ?t= がある場合は更新。
    """
    # import './foo.js'  →  import './foo.js?t=...'
    # export { } from './foo.js'
    content_str = re.sub(
        r'(from\s+["\'])(\.{1,2}/[^"\'?]+\.js)(\?[^"\']*)?(["\'])',
        lambda m: f'{m.group(1)}{m.group(2)}?t={ts}{m.group(4)}',
        content_str
    )
    # import './foo.js' (side-effect)
    content_str = re.sub(
        r'(import\s+["\'])(\.{1,2}/[^"\'?]+\.js)(\?[^"\']*)?(["\'])',
        lambda m: f'{m.group(1)}{m.group(2)}?t={ts}{m.group(4)}',
        content_str
    )
    # HTML <script src="./src/app.js">
    content_str = re.sub(
        r'(src=["\'])(\.{1,2}/[^"\'?]+\.js)(\?[^"\']*)?(["\'])',
        lambda m: f'{m.group(1)}{m.group(2)}?t={ts}{m.group(4)}',
        content_str
    )
    return content_str


class DevHandler(http.server.SimpleHTTPRequestHandler):

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()

    def do_GET(self):
        # パスからクエリを除去してファイルパスを解決
        path_only = self.path.split("?")[0]

        if path_only in ("/", "/index.html"):
            self._serve_text(os.path.join(ROOT, "index.html"), "text/html; charset=utf-8")
        elif path_only.endswith(".js"):
            fs_path = os.path.join(ROOT, path_only.lstrip("/"))
            if os.path.isfile(fs_path):
                self._serve_text(fs_path, "application/javascript; charset=utf-8")
            else:
                super().do_GET()
        else:
            super().do_GET()

    def _serve_text(self, fs_path, content_type):
        ts = int(time.time() * 1000)
        with open(fs_path, "rb") as f:
            content = f.read().decode("utf-8")
        content = add_ts(content, ts)
        body = content.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        pass  # ログ抑制


if __name__ == "__main__":
    http.server.test(HandlerClass=DevHandler, port=5174, bind="127.0.0.1")
