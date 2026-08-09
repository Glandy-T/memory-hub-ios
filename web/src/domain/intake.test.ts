import { afterEach, describe, expect, it, vi } from "vitest";
import { acceptIntake, acceptedStatus, createCalendarItem, demoEnvelope, demoPurchaseEnvelope, emptyDatabase, importEnvelope, mergeDatabases, setAcceptedStatus, updateCalendarItem } from "../data/repository";
import { parseEnvelope, validateEnvelope } from "./intake";

afterEach(() => {
  vi.useRealTimers();
});

describe("Memory Hub intake contract", () => {
  it("accepts the version 1 envelope", () => {
    expect(validateEnvelope(demoEnvelope)).toEqual({ ok: true, value: demoEnvelope });
  });

  it("accepts a deadline candidate with an explicit due time", () => {
    const envelope = {
      ...demoEnvelope,
      items: [
        {
          ...demoEnvelope.items[0],
          id: "deadline-1",
          target: "deadline" as const,
          title: "提交材料",
          payload: { dueAt: "2026-08-14T18:00:00+09:00" }
        }
      ]
    };

    expect(validateEnvelope(envelope)).toEqual({ ok: true, value: envelope });
  });

  it("rejects a newer schema version", () => {
    const result = validateEnvelope({ ...demoEnvelope, schemaVersion: 2 });
    expect(result.ok).toBe(false);
  });

  it("rejects malformed JSON", () => {
    expect(parseEnvelope("not-json").ok).toBe(false);
  });

  it("deduplicates imported items by stable id", () => {
    const first = importEnvelope(emptyDatabase(), demoEnvelope);
    const second = importEnvelope(first.database, demoEnvelope);
    const third = importEnvelope(second.database, demoPurchaseEnvelope);
    expect(first.added).toBe(1);
    expect(second.added).toBe(0);
    expect(third.added).toBe(1);
    expect(third.database.intake).toHaveLength(2);
  });

  it("merges device copies without duplicating accepted content", () => {
    const imported = importEnvelope(emptyDatabase(), demoEnvelope).database;
    const accepted = acceptIntake(imported, demoEnvelope.items[0].id);
    const merged = mergeDatabases(imported, accepted);

    expect(merged.intake).toHaveLength(1);
    expect(merged.intake[0].status).toBe("accepted");
    expect(merged.accepted).toHaveLength(1);
  });

  it("creates and edits an optional-time calendar item", () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2026-08-08T03:00:00.000Z"));
    const created = createCalendarItem(emptyDatabase(), {
      title: "  整理资料  ",
      note: "  带上报告  ",
      date: "2026-08-09"
    });
    const item = created.accepted[0];

    expect(item).toMatchObject({ title: "整理资料", note: "带上报告", status: "active" });
    expect(item.payload).toEqual({ date: "2026-08-09" });

    const edited = updateCalendarItem(created, item.id, {
      title: "整理体检资料",
      date: "2026-08-09",
      time: "14:30"
    });
    expect(edited.accepted[0].payload).toMatchObject({ date: "2026-08-09", time: "14:30" });
    expect(edited.accepted[0].note).toBeUndefined();
  });

  it("persists resolution and lets the newer device copy win", () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2026-08-08T03:00:00.000Z"));
    const active = createCalendarItem(emptyDatabase(), { title: "事项", date: "2026-08-08" });
    const id = active.accepted[0].id;

    vi.setSystemTime(new Date("2026-08-08T03:01:00.000Z"));
    const completed = setAcceptedStatus(active, id, "completed");
    const merged = mergeDatabases(active, completed);

    expect(acceptedStatus(merged.accepted[0])).toBe("completed");
    expect(merged.accepted[0].updatedAt).toBe("2026-08-08T03:01:00.000Z");
  });
});
