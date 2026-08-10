# Memory Hub ADHD Design Roadmap

## Scope and baseline

- Deliverable: Figma-first product design. Do not add these features to the app in this phase.
- Formal theme: the approved light theme only — white canvas, restrained rainbow pigment, blue-gray text, optical surfaces, and the existing four-item navigation.
- Dark theme is paused. Dark or colorful references may inform structure and interaction, but every formal screen is translated back to the light baseline.
- Product role: a quiet external memory for daily life, not a productivity score, medical treatment, chatbot, streak system, or KPI dashboard.
- Safety: external information always enters pending review; destructive actions are reversible; unfinished work is never framed as failure.

## Problem model

The design addresses four recurring friction points:

1. **记不住** — thoughts, dates, documents, item locations, and purchases need a low-friction capture path.
2. **难启动** — large or vague tasks need one visible next action and optional breakdown.
3. **看不见时间** — plans need visual duration, transitions, and realistic remaining capacity.
4. **被打断后回不去** — the product must preserve the current step and a short return note.

This framing is consistent with NIMH descriptions of adult ADHD difficulties involving organization, remembering daily tasks, time management, planning, and completing large projects. NIMH also recommends writing down reminders and breaking large tasks into smaller steps. The app does not claim to diagnose or treat ADHD.

## Information architecture

Keep the existing four top-level destinations:

1. **首页** — today card carousel, quick capture, current focus, reminders, fridge and item entry cards.
2. **日历** — month view, day agenda, deadlines, routines, visual day timeline, and gentle replanning.
3. **分类** — document categories, documents, reminder-pool editing, archive, and trash.
4. **我的** — pending review, notification rules, backup/export, appearance, accessibility, and app information.

ADHD-specific capabilities are contextual, not a fifth destination:

- Quick capture opens from the home screen and accepts text first; voice/photo are designed as optional extensions.
- Task breakdown and focus open from a task.
- Visual timeline and capacity live under calendar/day detail.
- Interruption recovery appears when returning to a paused task.
- Cross-links attach documents, deadlines, items, or locations to a task without duplicating the source record.

## Feature set and screen groups

### A. Capture and pending review

- Quick capture: empty, text entered, date/entity suggestions, saved confirmation.
- Pending-review inbox: mixed candidates, filter, batch selection, destination/category choice.
- Candidate detail: schedule, deadline, document, durable note, purchase, fridge, item location.
- Conflict and incomplete states: missing date, ambiguous destination, duplicate candidate, offline/retry.

### B. Start and focus

- Task detail with optional note, time, duration, deadline, links, and one next action.
- “拆成几步” editor with low/medium/high detail and fully editable suggestions.
- Single-task focus: current step, visual remaining time, pause, add time, finish early.
- Interruption recovery: paused state, “离开前做到哪里”, resume, reschedule, or return later.
- Reduced-motion and reduced-transparency variants documented, not separate product modes.

### C. Time and replanning

- Day timeline: scheduled items, flexible items, open space, now indicator, transition buffer.
- Day capacity: remaining usable time shown as plain language, not a performance percentage.
- “今天放不下”: move to tomorrow, choose a date, put back in inbox, or dismiss with undo.
- Deadline detail: due date, remaining calendar time, related task/document, and reminder policy.
- Routine bundle: reusable steps and estimated duration, without streaks or compliance scores.

### D. External memory links

- Attach a document, item, location, or deadline from task detail.
- Related-memory sheet with search and recent items.
- “出门前” bundle showing the task, required document, and item location in one calm view.
- Missing/moved/deleted-source states preserve a readable snapshot and offer relinking.

### E. Existing product completion in light theme

- Home, calendar, categories, document list/detail/editing, fridge, purchases, item locations, search, profile/settings, archive, trash, reminder pool, backup/export, notifications, app update, and all empty/error/confirmation states.
- Existing dark frames remain as historical work; formal light frames are the implementation source of truth.

## Interaction rules

- One primary action per screen or sheet.
- Initial forms show only required fields; advanced fields expand on demand.
- Home task cards keep the approved horizontal carousel and vertical complete/ignore gestures, with accessible menu alternatives.
- Use bottom sheets for focused edits, action sheets for compact choices, and full pages for browsing or multi-step organization.
- Every destructive action offers undo or enters trash; every import shows its destination before acceptance.
- Motion uses semantic timing rather than one global duration: micro feedback 160–200 ms, sheets 320–360 ms, card snapping 280–340 ms, and interruption recovery no longer than 420 ms. Reduced motion removes flight/scale/spring while keeping state text and undo.
- No glass-on-glass nesting. Liquid-glass treatment is reserved for navigation and transient controls; content cards use a calmer standard optical surface.

## Completion gates

The design phase is complete only when:

- every screen group above has happy, empty, loading, error, offline, destructive, and accessibility-relevant states where applicable;
- every major interaction has a source and an adaptation note;
- all formal screens use the light tokens and the same navigation/type/radius system;
- touch targets, contrast, dynamic text, reduced motion, reduced transparency, and non-color status cues are documented;
- the reference/decision matrix and component inventory are present in Figma and the repository;
- screenshots and visual audit find no obvious hierarchy, spacing, theme, or navigation conflicts;
- Figma, repository documentation, and remote archive are saved and synchronized.

## Formal Figma delivery map

The light-theme implementation source of truth is the Figma file `K2hgHAGExCF40ZtPtMY91x`:

| Page | Purpose | Key nodes |
| --- | --- | --- |
| `08 · 设计基础（浅色正式）` | semantic colors, type, spacing, radius, surfaces, motion and accessibility foundations | page `387:131`, root `387:132` |
| `08.1 · 组件库` | navigation, rows, cards, dialog, button, input, toggle, chip, task, timeline and inline banner variants | page `285:2`; new sets `385:222`–`385:228` |
| `11 · ADHD 功能规划与依据` | scope, IA, rejected patterns and reference/adaptation traceability | page `383:131`, traceability section `422:131` |
| `12 · 浅色正式 · 核心` | approved home, calendar, categories, settings, fridge, item locations and document flows | page `392:131` |
| `13 · ADHD · 捕捉与待收录` | quick capture, typed candidates, batch review, ambiguity, duplicate, offline and undo | page `397:131` |
| `14 · ADHD · 启动与专注` | next action, editable breakdown, focus, pause, return checkpoint and quiet completion | page `400:131` |
| `15 · ADHD · 时间与重排` | day timeline, capacity, scheduling, deadlines, routines and conflict recovery | page `402:131` |
| `16 · ADHD · 外部记忆链接` | task-to-document/item/location/deadline links, search, bundles and broken-link recovery | page `406:131` |
| `17 · 状态与无障碍` | empty/offline/error/permission states, large text, reduced motion/transparency and device data | page `408:131` |
| `18 · 首次使用与系统流程` | low-burden onboarding, privacy boundary, unified editor, reminder-pool editing and trash | page `411:131` |
| `19 · 动效与交互规格` | six authored motion demonstrations plus gesture alternatives and motion tokens | page `414:131`; motion sections `414:132`, `416:188`, token board `417:238` |

Delivery count: 51 formal 430×932 mobile screens, 6 authored motion demonstrations, 7 new component variant sets, and 65 scoped/code-syntax-enabled variables. Historical dark pages remain untouched and are not an implementation reference for this phase.

## Audit record — 2026-08-10

- Every new formal screen uses `Noto Sans SC`; the only `Inter` instances in the motion page come from clones of the previously approved home composition.
- New pages contain no unnamed nodes and no default text below 12 pt. Existing 10–11 pt status glyphs and compact metadata remain limited to the pre-existing core screens and are not primary actions.
- All gesture-only interactions have visible menu/button alternatives. Color is never the sole status cue.
- Empty, offline, failed sync, denied permission, ambiguous input, duplicate input, broken link, destructive action, trash recovery, large text, reduced motion and reduced transparency are represented.
- Apple-style glass is reserved for navigation and transient controls; content uses a calmer optical surface, avoiding nested glass.
- Motion tracks were written and read back successfully in Figma. A low-resolution carousel MP4 was exported; automated frame extraction was unavailable in the Windows environment, so track data plus resting-state screenshots are the retained verification artifacts.
