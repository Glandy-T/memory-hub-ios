import { describe, expect, it } from "vitest";
import { acceptIntake, demoEnvelope, demoPurchaseEnvelope, emptyDatabase, importEnvelope, mergeDatabases } from "../data/repository";
import { parseEnvelope, validateEnvelope } from "./intake";

describe("Memory Hub intake contract", () => {
  it("accepts the version 1 envelope", () => {
    expect(validateEnvelope(demoEnvelope)).toEqual({ ok: true, value: demoEnvelope });
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
});
