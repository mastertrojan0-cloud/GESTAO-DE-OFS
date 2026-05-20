"""
Servidor unificado: serve o frontend React (dist/) e faz proxy /api/* para o backend.
Uso: python serve.py
"""
import http.server
import urllib.request
import os

PORT = 3000
BACKEND = "http://localhost:8000"
DIST_DIR = os.path.join(os.path.dirname(__file__), "dist")

class ProxyHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIST_DIR, **kwargs)

    def do_GET(self):
        if self.path.startswith("/api/"):
            self._proxy("GET")
        else:
            # SPA fallback: serve index.html para rotas do React
            file_path = os.path.join(DIST_DIR, self.path.lstrip("/"))
            if os.path.isfile(file_path):
                super().do_GET()
            else:
                self.path = "/index.html"
                super().do_GET()

    def do_POST(self):
        if self.path.startswith("/api/"):
            self._proxy("POST")
        else:
            super().do_POST()

    def do_PUT(self):
        if self.path.startswith("/api/"):
            self._proxy("PUT")
        else:
            super().do_PUT()

    def do_PATCH(self):
        if self.path.startswith("/api/"):
            self._proxy("PATCH")
        else:
            super().do_PATCH()

    def do_DELETE(self):
        if self.path.startswith("/api/"):
            self._proxy("DELETE")
        else:
            super().do_DELETE()

    def _proxy(self, method):
        url = BACKEND + self.path
        body = None
        content_type = self.headers.get("Content-Type", "")
        if method in ("POST", "PUT", "PATCH"):
            length = int(self.headers.get("Content-Length", 0))
            if length > 0:
                body = self.rfile.read(length)

        req = urllib.request.Request(url, data=body, method=method)
        for key, value in self.headers.items():
            if key.lower() not in ("host", "content-length"):
                req.add_header(key, value)

        try:
            with urllib.request.urlopen(req) as resp:
                self.send_response(resp.status)
                for key, value in resp.getheaders():
                    if key.lower() != "transfer-encoding":
                        self.send_header(key, value)
                self.end_headers()
                self.wfile.write(resp.read())
        except urllib.error.HTTPError as e:
            self.send_response(e.code)
            self.end_headers()
            self.wfile.write(e.read())

if __name__ == "__main__":
    print(f"Frontend + API Proxy em http://localhost:{PORT}")
    print(f"  /       -> {DIST_DIR}")
    print(f"  /api/*  -> {BACKEND}")
    http.server.HTTPServer(("0.0.0.0", PORT), ProxyHandler).serve_forever()
