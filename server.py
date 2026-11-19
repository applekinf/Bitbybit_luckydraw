#!/usr/bin/env python3
# May chu nho chay bai hoc tai http://localhost:8765 (dung cho Mac, Windows, Linux)
# - Phat video YouTube ngay trong bai
# - Luu cau hinh vao data/config.json; anh/video tai len vao images/custom, images/icons, videos
import http.server, os, sys, json, re, shutil, socket, threading, unicodedata, urllib.parse, webbrowser, mimetypes, time

PORT = 8765
ROOT = os.path.dirname(os.path.abspath(__file__))
ALLOW_DIRS = {"images/custom", "images/icons", "videos"}
MIME = {".html": "text/html; charset=utf-8", ".js": "application/javascript; charset=utf-8", ".css": "text/css; charset=utf-8",
        ".json": "application/json; charset=utf-8", ".txt": "text/plain; charset=utf-8", ".mp4": "video/mp4", ".m4v": "video/mp4",
        ".webm": "video/webm", ".mov": "video/quicktime", ".mp3": "audio/mpeg", ".jpg": "image/jpeg", ".jpeg": "image/jpeg",
        ".png": "image/png", ".webp": "image/webp", ".svg": "image/svg+xml", ".gif": "image/gif"}

def safe_name(n):
    n = os.path.basename(n or "file")
    n = "".join(c for c in unicodedata.normalize("NFD", n) if unicodedata.category(c) != "Mn")
    n = re.sub(r"[^A-Za-z0-9._-]", "_", n)[-80:]
    return n if n and not n.startswith(".") else "file" + n

def stamp(): return time.strftime("%H:%M:%S")

class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass

    def send_json(self, code, obj):
        b = json.dumps(obj).encode("utf-8")
        self.send_response(code); self.send_header("Content-Type", "application/json"); self.send_header("Content-Length", str(len(b)))
        self.end_headers(); self.wfile.write(b)

    def do_POST(self):
        u = urllib.parse.urlparse(self.path); n = int(self.headers.get("Content-Length") or 0)
        try:
            if u.path == "/api/config":
                body = self.rfile.read(n); json.loads(body.decode("utf-8"))
                d = os.path.join(ROOT, "data"); os.makedirs(d, exist_ok=True); cfg = os.path.join(d, "config.json")
                if os.path.exists(cfg): shutil.copyfile(cfg, os.path.join(d, "config.backup.json"))
                with open(cfg, "wb") as f: f.write(body)
                print(f"  [{stamp()}] Da luu cau hinh"); return self.send_json(200, {"ok": True})
            if u.path == "/api/upload":
                q = urllib.parse.parse_qs(u.query); sub = q.get("dir", ["images/custom"])[0]
                if sub not in ALLOW_DIRS: sub = "images/custom"
                name = safe_name(q.get("name", ["file"])[0]); d = os.path.join(ROOT, *sub.split("/")); os.makedirs(d, exist_ok=True)
                target = os.path.join(d, name)
                if os.path.exists(target):
                    b, e = os.path.splitext(name); name = f"{b}_{time.strftime('%Y%m%d%H%M%S')}{e}"; target = os.path.join(d, name)
                left = n
                with open(target, "wb") as f:
                    while left > 0:
                        chunk = self.rfile.read(min(1 << 20, left))
                        if not chunk: break
                        f.write(chunk); left -= len(chunk)
                rel = sub + "/" + name; print(f"  [{stamp()}] Da luu file: {rel}"); return self.send_json(200, {"path": rel})
            self.send_json(404, {"error": "not found"})
        except Exception as ex:
            print("  Loi:", ex); self.send_json(500, {"error": str(ex)})

    def do_GET(self):
        p = urllib.parse.unquote(urllib.parse.urlparse(self.path).path).lstrip("/") or "index.html"
        full = os.path.realpath(os.path.join(ROOT, p))
        if not full.startswith(os.path.realpath(ROOT) + os.sep) or not os.path.isfile(full):
            self.send_response(404); self.send_header("Content-Length", "0"); self.end_headers(); return
        size = os.path.getsize(full); start, end = 0, size - 1
        rg = re.match(r"bytes=(\d*)-(\d*)", self.headers.get("Range") or "")
        ext = os.path.splitext(full)[1].lower(); ctype = MIME.get(ext) or mimetypes.guess_type(full)[0] or "application/octet-stream"
        if rg:
            if rg.group(1): start = int(rg.group(1))
            if rg.group(2): end = min(int(rg.group(2)), size - 1)
            if not rg.group(1) and rg.group(2): start, end = max(0, size - int(rg.group(2))), size - 1
            self.send_response(206); self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
        else:
            self.send_response(200)
        self.send_header("Content-Type", ctype); self.send_header("Accept-Ranges", "bytes"); self.send_header("Cache-Control", "no-cache")
        self.send_header("Content-Length", str(end - start + 1)); self.end_headers()
        if self.command == "HEAD": return
        try:
            with open(full, "rb") as f:
                f.seek(start); left = end - start + 1
                while left > 0:
                    chunk = f.read(min(1 << 18, left))
                    if not chunk: break
                    self.wfile.write(chunk); left -= len(chunk)
        except (BrokenPipeError, ConnectionResetError): pass

    do_HEAD = do_GET

def main():
    url = f"http://localhost:{PORT}/index.html"
    try:
        srv = http.server.ThreadingHTTPServer(("127.0.0.1", PORT), H)
    except OSError:
        print(f"Cong {PORT} dang duoc dung (co the bai hoc dang chay roi). Mo trinh duyet..."); webbrowser.open(url); return
    print("\n  CHUYEN TAU XUYEN VIET dang chay tai: http://localhost:%d" % PORT)
    print("  Moi thay doi duoc luu vao thu muc:", ROOT)
    print("  Giu cua so nay mo trong luc day. Dong cua so (hoac bam Ctrl+C) de tat.\n")
    if "--no-browser" not in sys.argv: threading.Timer(0.8, webbrowser.open, [url]).start()
    try: srv.serve_forever()
    except KeyboardInterrupt: print("\nDa tat bai hoc.")

if __name__ == "__main__": main()
