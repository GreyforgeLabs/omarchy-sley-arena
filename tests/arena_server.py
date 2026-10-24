"""A local stand-in for the arena API, for tests/run.sh.

Serves /<scenario>/arena/api/ladder and /matches with fixture data shaped
like the real API (worker/src/ladder.ts and matches.ts), with per-scenario
delays and failures, and logs every request; /<scenario>/_log returns the
log as JSON. Listens on 127.0.0.1 only and prints the port on stdout.
"""

import json
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit


def bot(rank, bot_id, name, login, rating, house=False, wins=0, losses=0, draws=0):
    return {
        "rank": rank, "bot_id": bot_id, "name": name,
        "owner": {"login": login, "avatar": None},
        "written_by": "claude", "house": house, "version": 1,
        "rating": rating, "rd": 80.0, "conservative": rating - 160,
        "games": wins + losses + draws, "wins": wins, "losses": losses, "draws": draws,
    }


def filler(start, count):
    return [bot(start + i, 1000 + start + i, "Bot %d" % (start + i), "p%d" % (start + i), 1500 - i)
            for i in range(count)]


def seat(bot_id, name, score):
    return {"seat": 0, "bot_id": bot_id, "name": name, "score": score,
            "owner": {"login": "x", "avatar": None}, "written_by": "gpt", "house": False}


BASIC = [
    bot(1, 1, "House Claude", "GreyforgeLabs", 1700.2, house=True),
    bot(2, 2, "Ada House", "Ada", 1650.0, house=True),  # a house bot is never "mine"
    bot(3, 33, "Night Shuttle", "ada", 1612.4, wins=5, losses=2, draws=1),
] + filler(4, 4)

MATCHES = [
    {"id": 501, "mode": "duel", "winner": 0, "seats": [seat(33, "Night Shuttle", 12), seat(7, "Looper", 9)]},
    {"id": 502, "mode": "duel", "winner": None, "seats": [seat(33, "Night Shuttle", 4), seat(8, "Gambler", 4)]},
]

# scenario -> (ladder(mode, limit) -> (status, body, delay), matches status)
SCENARIOS = {
    "basic": (lambda mode, limit: (200, BASIC[:limit], 0), 200),
    "race": (lambda mode, limit: (200, [bot(9, 90, "Slow Duel", "ada", 1400)], 0.8) if mode == "duel"
             else (200, [bot(2, 91, "Fast Brawl", "ada", 1555)], 0), 200),
    "nomatches": (lambda mode, limit: (200, BASIC[:limit], 0), 500),
    "down": (lambda mode, limit: (502, None, 0), 200),
    "deep": (lambda mode, limit: (200, (filler(1, 229) + [bot(230, 230, "Deep Diver", "ada", 1201)] + filler(231, 20))[:limit], 0), 200),
}

LOG = {}
LOCK = threading.Lock()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def reply(self, status, body):
        data = json.dumps(body).encode() if body is not None else b"upstream error"
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        url = urlsplit(self.path)
        parts = url.path.strip("/").split("/")
        scenario = parts[0]
        if scenario not in SCENARIOS:
            return self.reply(404, {"error": "no scenario"})
        if parts[1:] == ["_log"]:
            with LOCK:
                return self.reply(200, LOG.get(scenario, []))
        with LOCK:
            LOG.setdefault(scenario, []).append("/" + "/".join(parts[3:]) + ("?" + url.query if url.query else ""))
        q = {k: v[0] for k, v in parse_qs(url.query).items()}
        ladder, matches_status = SCENARIOS[scenario]
        if parts[1:] == ["arena", "api", "ladder"]:
            status, bots, delay = ladder(q.get("mode", "duel"), int(q.get("limit", "500")))
            time.sleep(delay)
            return self.reply(status, {"mode": q.get("mode"), "bots": bots} if bots is not None else None)
        if parts[1:] == ["arena", "api", "matches"]:
            if matches_status != 200:
                return self.reply(matches_status, None)
            return self.reply(200, {"matches": MATCHES, "next_cursor": None})
        return self.reply(404, {"error": "not found"})


def main():
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    print(server.server_address[1], flush=True)
    server.serve_forever()


if __name__ == "__main__":
    sys.exit(main())
