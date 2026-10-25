"""A local stand-in for the arena API, for tests/run.sh.

Serves /<scenario>/arena/api/ladder and /matches with fixture data shaped
like the real API (worker/src/ladder.ts and matches.ts), with per-scenario
delays and failures, and logs every request; /<scenario>/_log returns the
log as JSON. Listens on 127.0.0.1 only and prints the port on stdout.

Parameters are checked like the Worker's validate.ts: mode is duel|brawl,
the ladder limit is 1..1000 (default 500) and the matches limit 1..100
(default 20); anything else answers 400 with the Worker's error body, so a
widget request the real API would refuse fails here too.
"""

import json
import re
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


def seat(n, bot_id, name, score):
    return {"seat": n, "bot_id": bot_id, "version_id": bot_id * 10, "version": 1, "name": name,
            "owner": {"login": "x", "avatar": None}, "written_by": "gpt", "house": False,
            "score": score, "rating_before": 1500.0, "rating_after": 1500.0}


def match(match_id, winner, seats):
    return {"id": match_id, "season_id": 1, "mode": "duel", "ruleset": "S1-duel", "featured": False,
            "winner": winner, "created_at": "2026-10-21T06:22:40.000Z",
            "replay_url": "/arena/api/matches/%d/replay" % match_id, "seats": seats}


SEASON = {"id": 1, "name": "Season 1", "status": "live"}

BASIC = [
    bot(1, 1, "House Claude", "GreyforgeLabs", 1700.2, house=True),
    bot(2, 2, "Ada House", "Ada", 1650.0, house=True),  # a house bot is never "mine"
    bot(3, 33, "Night Shuttle", "ada", 1612.4, wins=5, losses=2, draws=1),
] + filler(4, 4)

MATCHES = [
    match(501, 0, [seat(0, 33, "Night Shuttle", 12), seat(1, 7, "Looper", 9)]),
    match(502, None, [seat(0, 33, "Night Shuttle", 4), seat(1, 8, "Gambler", 4)]),
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


class BadParam(Exception):
    pass


def mode_param(q):
    mode = q.get("mode") or "duel"
    if mode not in ("duel", "brawl"):
        raise BadParam("mode must be duel or brawl.")
    return mode


def limit_param(q, default, maximum):
    value = q.get("limit")
    if not value:
        return default
    if not re.fullmatch(r"\d{1,4}", value) or not 1 <= int(value) <= maximum:
        raise BadParam("limit must be 1 to %d." % maximum)
    return int(value)


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
        try:
            if parts[1:] == ["arena", "api", "ladder"]:
                mode, limit = mode_param(q), limit_param(q, 500, 1000)
                status, bots, delay = ladder(mode, limit)
                time.sleep(delay)
                body = {"season": SEASON, "mode": mode, "written_by": None, "bots": bots}
                return self.reply(status, body if bots is not None else None)
            if parts[1:] == ["arena", "api", "matches"]:
                mode_param(q)
                limit = limit_param(q, 20, 100)
                if matches_status != 200:
                    return self.reply(matches_status, None)
                bot_id = int(q["bot"]) if q.get("bot", "").isdigit() else None
                rows = [m for m in MATCHES if bot_id is None or any(s["bot_id"] == bot_id for s in m["seats"])]
                return self.reply(200, {"matches": rows[:limit], "next_cursor": None})
        except BadParam as e:
            return self.reply(400, {"error": str(e), "code": "bad_param"})
        return self.reply(404, {"error": "No such endpoint.", "code": "not_found"})


def main():
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    print(server.server_address[1], flush=True)
    server.serve_forever()


if __name__ == "__main__":
    sys.exit(main())
