---
name: memory-hub-intake
description: Safely send appointments, reminders, notes, documents, purchases, fridge entries, and item locations into the user's private Memory Hub pending-review inbox. Use when the user asks Codex to remember something, schedule or record information, add something to Memory Hub, or hand information from another task/window into the app. Always creates reviewable intake candidates and never bypasses acceptance into formal content.
---

# Memory Hub Intake

Convert the user's confirmed information into one or more pending-review items and submit them with `scripts/push_intake.py`.

## Choose the target

- `calendar`: appointments, reminders, dated tasks, or plans. Put an ISO 8601 value in `scheduledAt` when known and include `timeZone` when relevant.
- `deadline`: something that must be finished by a date. Put an ISO 8601 value in `dueAt` when a precise time is known, or `date` when it is date-only.
- `document`: durable notes, reference information, summaries, addresses, confirmation details, or material worth reading later.
- `purchase`: things to buy; use `quantity` when known.
- `fridge`: food currently stored; use `quantity` and other concrete fields in the payload when known.
- `homeItem`: belongings, supplies, or where something is stored; use `location` and `quantity` when known.

Do not invent missing dates, quantities, locations, or facts. Optional fields may be omitted.

## Submit

For one item, run:

```powershell
python scripts/push_intake.py --target calendar --title "牙医复诊" --scheduled-at "2026-08-12T15:00:00+09:00" --time-zone "Asia/Tokyo" --note "带上检查报告" --source-label "日程整理任务"
```

Use the bundled Python runtime when `python` is unavailable. Run the script from this skill directory or pass its absolute path. For several items, submit each item separately; stable content-derived IDs make retries idempotent.

Use `--payload-json` for target-specific fields not covered by named options. Use `--dry-run` to inspect the generated envelope without sending it.

## Safety and reporting

- Submit only when the user has asked to record or send the information.
- Treat every submission as a candidate. Never claim it became formal content; the user still accepts, edits, or ignores it in “待收录”.
- Never read, display, copy, or mention `config.json` or its token.
- Report the item title, target, and whether it was newly added or already present.
- If the endpoint is unavailable, preserve the generated envelope and tell the user the item was not delivered.
