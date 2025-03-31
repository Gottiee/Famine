from http.server import BaseHTTPRequestHandler, HTTPServer

infection = True

class SimpleHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path == "/extract":
            content_length = int(self.headers.get("Content-Length", 0))
            raw_body = self.rfile.read(content_length)  # Lire en binaire
            print(f"{self.requestline}")

            for key, value in self.headers.items():
                print(f"{key}: {value}")

            try:
                body = raw_body.decode("utf-8")
                print(f"\n{body}")  # Affiche le texte si valide
            except UnicodeDecodeError:
                print("\n[BINARY DATA DETECTED] - Le contenu n'est pas du texte lisible.")

            print("\nEOF-----------------------\n")

    def do_GET(self):
        if self.path == "/infection":
            global infection
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"OK" if infection else b"KO")
            print("\n-----------------------\n")

HTTPServer(("0.0.0.0", 8000), SimpleHandler).serve_forever()