import { describe, expect, it } from "vitest";
import { createCategory, createDocument, createRecurringRule, deleteCategory, emptyDatabase, materializeRecurring, mergeDatabases, readDatabase, type WebDatabase } from "./repository";

function memoryStorage(value?: unknown): Storage {
  let raw = value ? JSON.stringify(value) : null;
  return { getItem: () => raw, setItem: (_key, next) => { raw = next; }, removeItem: () => { raw = null; }, clear: () => { raw = null; }, key: () => null, get length() { return raw ? 1 : 0; } } as Storage;
}

describe("v2 repository", () => {
  it("migrates a v1 local copy without losing accepted content", () => {
    const storage = memoryStorage({ schemaVersion: 1, intake: [], accepted: [] });
    const database = readDatabase(storage);
    expect(database.schemaVersion).toBe(2);
    expect(database.categories[0]?.isDefault).toBe(true);
  });

  it("moves documents to the default category when deleting a category", () => {
    let database = emptyDatabase();
    database = createCategory(database, "旅行", "#5c8cff");
    const category = database.categories.at(-1)!;
    database = createDocument(database, { title: "清单", categoryId: category.id });
    database = deleteCategory(database, category.id, true);
    expect(database.accepted[0]?.payload.categoryId).toBe(database.categories[0]?.id);
    expect(database.categories.find(x => x.id === category.id)?.deletedAt).toBeTruthy();
  });

  it("materializes one recurring history instance and merges it deterministically", () => {
    let database = emptyDatabase();
    database = createRecurringRule(database, { title: "喂猫", startDate: "2026-08-07", weekdays: [5] });
    const rule = database.recurringRules[0]!;
    const instance = materializeRecurring(database, rule, "2026-08-07", "completed");
    const merged = mergeDatabases(database, instance);
    expect(merged.accepted).toHaveLength(1);
    expect(merged.accepted[0]?.payload.ruleId).toBe(rule.id);
  });
});
