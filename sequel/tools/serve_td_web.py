"""Local-only browser validation server. Public hosting is a separate step."""
import argparse, functools, http.server
p=argparse.ArgumentParser();p.add_argument('directory');p.add_argument('--port',type=int,default=8765);a=p.parse_args()
class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map={**http.server.SimpleHTTPRequestHandler.extensions_map,'.wasm':'application/wasm','.pck':'application/octet-stream'}
    def end_headers(self):
        self.send_header('Cache-Control','no-store')
        super().end_headers()
http.server.ThreadingHTTPServer(('127.0.0.1',a.port),functools.partial(Handler,directory=a.directory)).serve_forever()
