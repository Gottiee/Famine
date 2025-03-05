from http.server import BaseHTTPRequestHandler, HTTPServer

class SimpleHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path == "/extract":
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length).decode("utf-8")
            print(f"{self.requestline}")
            for key, value in self.headers.items():
                print(f"{key}: {value}")
            print(f"\n{body}")
            print("\nEOF-----------------------\n")

HTTPServer(("0.0.0.0", 8000), SimpleHandler).serve_forever()
