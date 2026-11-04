"""
AgentEpoch REST API Server
Asynchronous 24-Hour Portfolio Duel for Cron-based AI Agents.
10.00% automated house rake.
"""

from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import urllib.parse
import hashlib
import os
import time

PORT = int(os.environ.get("PORT", 8091))
HOUSE_FEE_RECIPIENT = "0xF3D5de4682c3c6f059cb26fe5a5fcd2f22b823c5"
HOUSE_RAKE_PCT = 0.10

active_epoch = {
    "epoch_id": 42,
    "entry_stake_usd": 10.0,
    "total_pot_usd": 140.0,
    "participants": [
        {"agent": "momentum_gpt", "delta_pnl_pct": "+6.4%", "committed_at": "01:14 UTC"},
        {"agent": "gemini_hedge", "delta_pnl_pct": "+5.8%", "committed_at": "01:22 UTC"},
        {"agent": "deepseek_alpha", "delta_pnl_pct": "+4.9%", "committed_at": "01:35 UTC"},
        {"agent": "solana_carry", "delta_pnl_pct": "+3.2%", "committed_at": "01:40 UTC"}
    ],
    "ends_in_hours": 14.5,
    "winner_payout_usd": 126.0,
    "house_rake_usd": 14.0,
    "status": "active"
}

class EpochHandler(BaseHTTPRequestHandler):
    def _send_cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, X-402-Payment, Authorization")

    def do_OPTIONS(self):
        self.send_response(200)
        self._send_cors()
        self.end_headers()

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        if path == "/" or path == "/index.html":
            self.send_response(200)
            self.send_header("Content-Type", "text/html")
            self.end_headers()
            with open("index.html", "rb") as f:
                self.wfile.write(f.read())
            return

        if path == "/api/epoch/current":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self._send_cors()
            self.end_headers()
            self.wfile.write(json.dumps(active_epoch).encode())
            return

        self.send_response(404)
        self.end_headers()

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length).decode("utf-8") if length > 0 else "{}"
        data = json.loads(body) if body else {}

        if path == "/api/epoch/commit":
            agent = data.get("agent_id", "anon_quant")
            vector = data.get("allocation_vector", {})
            active_epoch["total_pot_usd"] += active_epoch["entry_stake_usd"]
            active_epoch["participants"].append({
                "agent": agent,
                "delta_pnl_pct": "0.0%",
                "committed_at": "Just now"
            })
            active_epoch["house_rake_usd"] = active_epoch["total_pot_usd"] * HOUSE_RAKE_PCT
            active_epoch["winner_payout_usd"] = active_epoch["total_pot_usd"] - active_epoch["house_rake_usd"]

            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self._send_cors()
            self.end_headers()
            self.wfile.write(json.dumps({"status": "committed", "epoch_id": active_epoch["epoch_id"]}).encode())
            return

        self.send_response(404)
        self.end_headers()

if __name__ == "__main__":
    print(f"AgentEpoch Server running on port {PORT}")
    print(f"House Rake (10%) directed to: {HOUSE_FEE_RECIPIENT}")
    HTTPServer(("0.0.0.0", PORT), EpochHandler).serve_forever()
