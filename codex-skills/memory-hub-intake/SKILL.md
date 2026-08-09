---
name: memory-hub-intake
description: Intelligently classify and safely send schedules, dated tasks, deadlines, durable notes, documents, purchases, fridge entries, and item locations into the user's private Memory Hub pending-review inbox. Use when the user asks Codex to remember, schedule, record, organize, or hand information from another task/window into Memory Hub. Split mixed information into reviewable candidates and never bypass acceptance into formal content.
---

# Memory Hub Intake

Convert the user's confirmed information into one or more pending-review items and submit them with `scripts/push_intake.py`.

## Classify before submitting

Extract confirmed facts first, then classify by purpose rather than by the mere presence of a date:

- `calendar`: something the user plans to do or attend at a particular time or on a particular day. Examples: appointments, meetings, reminders, dated tasks, and plans. Use `scheduledAt` when a time is known; otherwise use `payload.date`.
- `deadline`: the last acceptable completion time. Signals include 截止、最晚、到期、交付、报名结束、还剩. Use `dueAt` for a precise time or `payload.date` for a date-only deadline.
- `document`: durable information worth finding or reading later, including summaries, requirements, addresses, reference material, confirmation details, and decisions. A date mentioned inside reference material does not make it a calendar item.
- `purchase`: something to buy.
- `fridge`: food currently stored.
- `homeItem`: a belonging or where it is stored.

Never convert a deadline into a calendar task automatically. If the user gives both an execution plan and a final due date, create both candidates. If a message also contains durable reference material, create a document candidate only when that material remains useful independently; otherwise keep short context in the calendar or deadline `note`.

Example: “周一整理签证材料，8月20日前提交；要求护照复印件和白底照片。” becomes:

1. `calendar`: 周一整理签证材料
2. `deadline`: 提交签证材料，date 8月20日
3. `document`: 签证材料要求，only if the requirements should be retained for later reference

Resolve relative dates from the current date and the user's known timezone, and report the resolved absolute date. Do not invent a date. If a required deadline date is genuinely ambiguous or missing, ask one concise question before submitting that candidate; continue submitting any other unambiguous candidates.

## Choose the target

- `calendar`: appointments, reminders, dated tasks, or plans. Put an ISO 8601 value in `scheduledAt` when known, or a `YYYY-MM-DD` value in payload `date` for an all-day item. Include `timeZone` when relevant.
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

For a date-only deadline, run:

```powershell
python scripts/push_intake.py --target deadline --title "提交签证材料" --payload-json '{"date":"2026-08-20"}' --note "护照复印件和白底照片" --source-label "行程整理任务"
```

Use the bundled Python runtime when `python` is unavailable. Run the script from this skill directory or pass its absolute path. For several items, submit each item separately; stable content-derived IDs make retries idempotent.

Use `--payload-json` for target-specific fields not covered by named options. Use `--dry-run` to inspect the generated envelope without sending it. For mixed information, submit each independently useful candidate separately; stable content-derived IDs keep retries idempotent.

## Safety and reporting

- Submit only when the user has asked to record or send the information.
- Prefer automatic classification. Ask only when a missing or ambiguous fact would materially change the stored meaning.
- Treat every submission as a candidate. Never claim it became formal content; the user still accepts, edits, or ignores it in “待收录”.
- Never read, display, copy, or mention `config.json` or its token.
- Report the item title, target, and whether it was newly added or already present.
- If the endpoint is unavailable, preserve the generated envelope and tell the user the item was not delivered.
