#!/usr/bin/env python3
"""
Live SASE Lab Professional Architecture Server
Serves a professional interactive network topology on http://localhost:50080
"""
import http.server
import socketserver
import json
import os

PORT = 50080

class RequestHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/api/status':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(json.dumps({"status": "active", "alerts": 250}).encode('utf-8'))
        else:
            self.send_response(200)
            self.send_header('Content-Type', 'text/html')
            self.end_headers()
            html_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'sase_enterprise_dashboard.html')
            with open(html_path, 'r') as f:
                html_code = f.read()
            self.wfile.write(html_code.encode('utf-8'))

if __name__ == '__main__':
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("", PORT), RequestHandler) as httpd:
        print(f"[+] Professional Network Visualizer running on http://localhost:{PORT}")
        httpd.serve_forever()
