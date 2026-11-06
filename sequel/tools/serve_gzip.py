"""Web 版の確認用サーバー：GitHub Pages と同じく .pck を gzip で送る。 python3 -I sequel/tools/serve_gzip.py sequel/web （ポート 8765）"""
import gzip, http.server, os, sys
os.chdir(sys.argv[1])
class H(http.server.SimpleHTTPRequestHandler):
    def send_head(self):
        path = self.translate_path(self.path.split('?')[0])
        if path.endswith('.pck') and 'gzip' in self.headers.get('Accept-Encoding', ''):
            data = gzip.compress(open(path, 'rb').read(), 1)
            self.send_response(200)
            self.send_header('Content-Type', 'application/octet-stream')
            self.send_header('Content-Encoding', 'gzip')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            import io; return io.BytesIO(data)
        return super().send_head()
http.server.ThreadingHTTPServer(('', 8765), H).serve_forever()
