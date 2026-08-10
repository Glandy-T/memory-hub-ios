# Memory Hub Design References and Decisions

This file records what is borrowed, what is changed, and where it is used. References are design evidence, not templates to copy.

| Source | Useful idea | Memory Hub adaptation | Used in |
| --- | --- | --- | --- |
| [Wellness, Aging Care, Mood & Meds Tracking](https://www.behance.net/gallery/242023175/UIUX-for-Wellness-Aging-Care-Mood-Meds-Tracking-app) | Calm editorial hierarchy and readable wellness information | Keep generous hierarchy and quiet typography; remove medical-dashboard density and translate to blue-gray text on the approved pigment background | Global layout, settings, detail pages |
| [Aqara Smart Home App](https://www.behance.net/gallery/210003217/Aqara-Smart-Home-App-UI-UX-Design) | Controlled color zoning and modular household information | Use color as recognition and atmosphere, not as a grid of device cards | Fridge, item locations, category accents |
| [FocusMind ADHD App](https://www.behance.net/gallery/248132323/FocusMind-ADHD-App-UIUX) | Small steps, focus sessions, flexible reminders | Keep editable breakdown and focus; remove coaching/pressure language and AI-dependency | Breakdown, focus, reminder rules |
| [Focus Planner for ADHD](https://www.behance.net/gallery/16769909/Focus-Planner-for-ADHD) | Movable plans, reduced navigation, 3-day awareness | Translate sticky-note physicality into rescheduling sheets and a compact day strip; avoid drag-only controls | Day timeline, gentle replanning |
| [One More Minute](https://www.behance.net/gallery/242580187/One-More-Minute-Anti-Procrastination-UXUI-App) | Non-judgmental interruption and conscious continuation | Use a calm return checkpoint rather than blocking or guilt | Interruption recovery |
| [Daily Planner App UI](https://www.behance.net/gallery/144937033/Daily-Planner-App-UI) | Reschedule based on time left | Make rescheduling user-confirmed and reversible; show capacity as plain language | “今天放不下”, day capacity |
| [Daily Planner Mobile App — Smart Task & Schedule Manager](https://www.behance.net/gallery/234158119/Daily-Planner-Mobile-App-Smart-Task-Schedule-Manager) | Clear mobile task hierarchy and schedule grouping | Keep the hierarchy and calm grouping; remove productivity-dashboard density and translate it to the established optical surfaces | Timeline, unified task editor, onboarding examples |
| [TaskFlow — Minimal Task Management App](https://www.behance.net/gallery/244125653/TaskFlow-Minimal-Task-Management-App-UIUX) | Minimal entry, clear task states and low-friction completion | Use clarity and compact task states for cross-object results and memory links; retain Memory Hub's own rainbow material and data model | Global search, external memory links |
| [Task Management App for People with ADHD](https://www.behance.net/gallery/206965135/Task-Management-App-For-People-With-ADHD-Case-Study) | ADHD-specific task framing and explicit UX rationale | Use it as comparative evidence only; prefer source-backed non-judgmental language and avoid claims that colors treat symptoms | Product boundary and rejected patterns |
| [Structured](https://structured.app/) | One visual timeline, inbox, focus and flexible replanning | Put the timeline under calendar/day detail and keep the existing home carousel | Timeline, capture inbox |
| [Tiimo](https://www.tiimoapp.com/product) | Visual time, flexible structure, routines, focus timer | Use visual duration and returnable routines without mood scoring or customization overload | Timeline, routines, focus |
| [Goblin Tools Magic ToDo](https://goblin.tools/ToDo) | Adjustable task-breakdown detail | Offer three plain-language breakdown depths; all suggestions remain editable and optional | “拆成几步” |
| [Apple HIG: Materials](https://developer.apple.com/design/human-interface-guidelines/materials) | Glass is a functional navigation/control layer and should be used sparingly | Bottom navigation and transient controls use liquid-glass cues; content uses standard optical surfaces to avoid glass-on-glass clutter | Design system, navigation, sheets |
| [Apple HIG](https://developer.apple.com/design/human-interface-guidelines) | Hierarchy, harmony, consistency, adaptive accessibility | Preserve platform placement/behavior and Memory Hub semantics; test reduced transparency/motion | Global system and accessibility |
| [Apple: Customize onscreen motion](https://support.apple.com/en-ca/guide/iphone/iph0b691d3ed/ios) | Platform Reduce Motion behavior and settings model | Provide a product-level preview and map translations/scales to short fades without removing state feedback | Accessibility settings, motion alternatives |
| [NIMH: ADHD in Adults](https://www.nimh.nih.gov/health/publications/adhd-what-you-need-to-know) | Authoritative problem framing: organization, memory, time, planning, large-task completion | Use as scope evidence only; make no treatment or diagnosis claims | Product rationale |
| [NIMH: ADHD overview](https://www.nimh.nih.gov/health/publications/attention-deficit-hyperactivity-disorder-what-you-need-to-know) | Write reminders, prioritize time-sensitive tasks, break large tasks into manageable steps | Quick capture, deadlines, and editable next actions | Capture, deadlines, breakdown |

## Rejected patterns

- Chatbot-first planning, because it hides structure and conflicts with the product’s quiet external-memory role.
- Streaks, scores, overdue shame, or congratulatory confetti.
- A new ADHD dashboard or fifth navigation destination.
- Dense all-in-one setup forms.
- Glass applied to every content row or nested glass surfaces.
- Color-only categories/statuses or gesture-only destructive actions.
- Automatic external writes that bypass pending review.

## Feature-to-source traceability

| Figma group | Primary evidence | What was adapted | What was deliberately not carried over |
| --- | --- | --- | --- |
| `12 · 浅色正式 · 核心` | Wellness/Aging Care, Aqara, Apple Materials | editorial hierarchy, household modularity, controlled color and optical layering | medical dashboard density, device grid, brand palette |
| `13 · 捕捉与待收录` | Structured inbox, existing Memory Hub intake contract | text-first capture, review before formal write, visible destination and undo | chatbot-first capture and automatic writes |
| `14 · 启动与专注` | FocusMind, Goblin Tools, One More Minute | adjustable breakdown, one visible next action, pause note and return checkpoint | scoring, coaching pressure, blocking and confetti |
| `15 · 时间与重排` | Tiimo, Structured, Daily Planner references | visual timeline, transition buffer, plain-language capacity and reversible replanning | red countdown pressure, full-day optimization and streaks |
| `16 · 外部记忆链接` | Aqara modular organization, TaskFlow clarity, Memory Hub object model | consistent cross-object rows, references instead of copies, broken-link recovery | duplicate records and new information silos |
| `17–18 · 系统流程` | Apple HIG, Apple accessibility settings, Wellness hierarchy | just-in-time permission, accessible variants, simple account connection, reversible deletion | up-front permission walls and one-off pairing as the primary path |
| `19 · 动效与交互规格` | Apple motion/material guidance and the approved home interaction | direct manipulation, short semantic motion, visible gesture alternatives and reduced-motion mapping | decorative loops, whole-page zoom, bouncy completion and color-only feedback |
