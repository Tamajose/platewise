"""Serve a PlateWise web demo on the loopback interface.

From a repository checkout, build the app first (`flutter build web --release`
in `app`) and run this script. In an extracted web demo package, run it from
inside the package. Pass a folder to serve a different build.
"""

import argparse
import errno
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import sys
from threading import Thread
import webbrowser

HERE = Path(__file__).resolve().parent
# A packaged demo keeps this script beside index.html. A checkout keeps the
# build under app/build/web.
DEFAULT_FOLDERS = [HERE, HERE.parent / "app" / "build" / "web"]


class DemoHandler(SimpleHTTPRequestHandler):
    extensions_map = {
        **SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
    }

    def end_headers(self):
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()


class DemoServer(ThreadingHTTPServer):
    allow_reuse_address = sys.platform != "win32"


def is_build(directory):
    return (directory / "index.html").is_file() and (directory / "flutter_bootstrap.js").is_file()


def main():
    parser = argparse.ArgumentParser(description="Open the PlateWise web demo locally.")
    parser.add_argument("directory", nargs="?", type=Path, help="Folder with the web build")
    parser.add_argument("--port", type=int, default=8011, help="Local port, or 0 for an available port")
    parser.add_argument("--no-browser", action="store_true", help="Print the URL without opening a browser")
    args = parser.parse_args()
    if not 0 <= args.port <= 65535:
        parser.error("Choose a port between 0 and 65535.")

    candidates = [args.directory.resolve()] if args.directory else DEFAULT_FOLDERS
    directory = next((folder for folder in candidates if is_build(folder)), None)
    if directory is None:
        parser.error(
            "No web build found. Run `flutter build web --release` in app, "
            "open the extracted demo folder, or pass the path to the build."
        )

    host = "127.0.0.1"
    handler = partial(DemoHandler, directory=str(directory))
    try:
        server = DemoServer((host, args.port), handler)
    except OSError as error:
        if error.errno != errno.EADDRINUSE and getattr(error, "winerror", None) != 10048:
            raise
        print(f"Port {args.port} is busy. Using an available port.", flush=True)
        server = DemoServer((host, 0), handler)

    with server:
        url = f"http://{host}:{server.server_port}/"
        print(f"PlateWise is running at {url}", flush=True)
        print(f"Serving {directory}", flush=True)
        print("Press Ctrl+C to stop.", flush=True)
        if not args.no_browser:
            Thread(target=webbrowser.open, args=(url,), daemon=True).start()
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass


if __name__ == "__main__":
    main()
