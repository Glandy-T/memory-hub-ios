#!/usr/bin/env python3
import argparse
import datetime as dt
import json
import sys
import urllib.error
import urllib.request
import uuid
from pathlib import Path

TARGETS = ("calendar", "document", "purchase", "fridge", "homeItem")
CONFIG_PATH = Path(__file__).resolve().parents[1] / "config.json"


def parse_args():
    parser = argparse.ArgumentParser(description="Send one candidate to Memory Hub intake.")
    parser.add_argument("--target", choices=TARGETS, required=True)
    parser.add_argument("--title", required=True)
    parser.add_argument("--note")
    parser.add_argument("--scheduled-at")
    parser.add_argument("--time-zone")
    parser.add_argument("--quantity")
    parser.add_argument("--location")
    parser.add_argument("--payload-json", default="{}")
    parser.add_argument("--source-label", default="Codex")
    parser.add_argument("--thread-id")
    parser.add_argument("--item-id")
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def build_envelope(args):
    title = args.title.strip()
    if not title:
        raise ValueError("title cannot be empty")
    payload = json.loads(args.payload_json)
    if not isinstance(payload, dict):
        raise ValueError("payload-json must be an object")

    named_payload = {
        "scheduledAt": args.scheduled_at,
        "timeZone": args.time_zone,
        "quantity": args.quantity,
        "location": args.location,
    }
    payload.update({key: value for key, value in named_payload.items() if value})

    source = {"kind": "codex", "label": args.source_label.strip() or "Codex"}
    if args.thread_id:
        source["threadId"] = args.thread_id

    identity = json.dumps({
        "target": args.target,
        "title": title,
        "note": args.note.strip() if args.note else None,
        "payload": payload,
        "source": source,
    }, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    item_id = args.item_id or str(uuid.uuid5(uuid.NAMESPACE_URL, f"memory-hub:{identity}"))
    envelope_id = str(uuid.uuid5(uuid.NAMESPACE_URL, f"memory-hub-envelope:{item_id}"))

    item = {"id": item_id, "target": args.target, "title": title, "payload": payload}
    if args.note and args.note.strip():
        item["note"] = args.note.strip()

    return {
        "schemaVersion": 1,
        "envelopeId": envelope_id,
        "createdAt": dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00", "Z"),
        "source": source,
        "items": [item],
    }


def load_config():
    try:
        config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise RuntimeError("Memory Hub intake is not configured on this computer") from error
    if not isinstance(config.get("url"), str) or not isinstance(config.get("token"), str):
        raise RuntimeError("Memory Hub intake configuration is invalid")
    return config


def send(envelope):
    config = load_config()
    body = json.dumps(envelope, ensure_ascii=False).encode("utf-8")
    request = urllib.request.Request(
        config["url"].rstrip("/") + "/api/intake",
        data=body,
        method="POST",
        headers={
            "Authorization": "Bearer " + config["token"],
            "Content-Type": "application/json; charset=utf-8",
            "User-Agent": "MemoryHubCodexSkill/1.0",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        message = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Memory Hub rejected the intake ({error.code}): {message}") from error
    except urllib.error.URLError as error:
        raise RuntimeError("Memory Hub intake endpoint is unavailable") from error


def main():
    args = parse_args()
    try:
        envelope = build_envelope(args)
        if args.dry_run:
            print(json.dumps(envelope, ensure_ascii=False, indent=2))
            return 0
        result = send(envelope)
        print(json.dumps({
            "ok": True,
            "added": result.get("added", 0),
            "itemId": envelope["items"][0]["id"],
            "title": envelope["items"][0]["title"],
            "target": envelope["items"][0]["target"],
        }, ensure_ascii=False))
        return 0
    except (ValueError, RuntimeError, json.JSONDecodeError) as error:
        print(json.dumps({"ok": False, "message": str(error)}, ensure_ascii=False), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
