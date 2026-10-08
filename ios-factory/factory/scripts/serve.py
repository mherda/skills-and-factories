#!/usr/bin/env python3
"""Serve the factory dashboard.

  python3 -I factory/scripts/serve.py [port] [--open]

Like `python3 -m http.server -d factory`, but sturdier for the dashboard,
which fires bursts of parallel requests. The stock server only queues five
pending connections, so on macOS the rest are refused and the page shows
"Failed to fetch". This one queues 128, answers with no-cache headers, and
doesn't log every request.
"""
import os
import socket
import sys
import webbrowser
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

FACTORY = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


class Handler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, format, *args):  # quiet: the dashboard polls every few seconds
        pass


class Server(ThreadingHTTPServer):
    request_queue_size = 128
    daemon_threads = True
    allow_reuse_address = True
    address_family = socket.AF_INET6

    def server_bind(self):
        # Dual stack, so "localhost" works whether the browser tries ::1 or 127.0.0.1 first.
        try:
            self.socket.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)
        except (AttributeError, OSError):
            pass
        super().server_bind()


def main(argv):
    port = next((int(a) for a in argv if a.isdigit()), 8765)
    try:
        httpd = Server(("::", port), partial(Handler, directory=FACTORY))
    except OSError as e:
        sys.exit(f"Port {port} is busy ({e.strerror}). Is the dashboard already running? Try another port.")
    url = f"http://localhost:{port}/dashboard.html"
    print(f"Factory dashboard: {url}  (Ctrl-C to stop)")
    if "--open" in argv:
        webbrowser.open(url)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main(sys.argv[1:])
