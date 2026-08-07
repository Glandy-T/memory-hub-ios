import type { AcceptedItem, AcceptedStatus, IntakeEnvelope, StoredIntakeItem } from "../domain/intake";

const STORAGE_KEY = "memory-hub.web.v1";
export const DEFAULT_CATEGORY_ID = "memory-hub-default-category";

export interface Category {
  id: string;
  name: string;
  color: string;
  order: number;
  isDefault?: boolean;
  updatedAt: string;
  deletedAt?: string;
}

export interface RecurringRule {
  id: string;
  title: string;
  startDate: string;
  endDate?: string;
  weekdays: number[];
  active: boolean;
  updatedAt: string;
  deletedAt?: string;
}

export type ThemePreference = "light" | "dark" | "system";
export interface WebPreferences {
  theme: ThemePreference;
  dailyCheck: "off" | "08:00" | "09:00";
  reminderPoolExcluded: string[];
  reminderHiddenDates: Record<string, string>;
  reminderSnoozedUntil: Record<string, string>;
  updatedAt: string;
}

export interface WebDatabase {
  schemaVersion: 2;
  intake: StoredIntakeItem[];
  accepted: AcceptedItem[];
  categories: Category[];
  recurringRules: RecurringRule[];
  preferences: WebPreferences;
}

const nowIso = () => new Date().toISOString();
const defaultCategory = (): Category => ({
  id: DEFAULT_CATEGORY_ID, name: "未分类", color: "#8F7CF6", order: 0, isDefault: true, updatedAt: new Date(0).toISOString()
});
const defaultPreferences = (): WebPreferences => ({
  theme: "light", dailyCheck: "off", reminderPoolExcluded: [], reminderHiddenDates: {}, reminderSnoozedUntil: {}, updatedAt: new Date(0).toISOString()
});

export const emptyDatabase = (): WebDatabase => ({
  schemaVersion: 2, intake: [], accepted: [], categories: [defaultCategory()], recurringRules: [], preferences: defaultPreferences()
});

const targets = new Set(["calendar", "document", "purchase", "fridge", "homeItem"]);
const intakeStatuses = new Set(["pending", "accepted", "ignored"]);
const acceptedStatuses = new Set(["active", "completed", "skipped", "deleted", "archived", "removed", "purchased"]);
const themes = new Set(["light", "dark", "system"]);

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
function validSource(value: unknown): boolean {
  return isRecord(value) && typeof value.kind === "string" && typeof value.label === "string" && value.label.trim().length > 0;
}
function validBaseItem(value: unknown): value is Record<string, unknown> {
  return isRecord(value) && typeof value.id === "string" && targets.has(value.target as string)
    && typeof value.title === "string" && value.title.trim().length > 0
    && (value.note === undefined || typeof value.note === "string") && isRecord(value.payload) && validSource(value.source);
}
function validStoredItem(value: unknown): value is StoredIntakeItem {
  return validBaseItem(value) && typeof value.envelopeId === "string" && typeof value.receivedAt === "string" && intakeStatuses.has(value.status as string);
}
function validAcceptedItem(value: unknown): value is AcceptedItem {
  return validBaseItem(value) && typeof value.acceptedAt === "string"
    && (value.status === undefined || acceptedStatuses.has(value.status as string))
    && (value.updatedAt === undefined || typeof value.updatedAt === "string")
    && (value.deletedAt === undefined || typeof value.deletedAt === "string");
}
function validCategory(value: unknown): value is Category {
  return isRecord(value) && typeof value.id === "string" && typeof value.name === "string" && typeof value.color === "string"
    && typeof value.order === "number" && typeof value.updatedAt === "string" && (value.deletedAt === undefined || typeof value.deletedAt === "string");
}
function validRule(value: unknown): value is RecurringRule {
  return isRecord(value) && typeof value.id === "string" && typeof value.title === "string" && typeof value.startDate === "string"
    && Array.isArray(value.weekdays) && value.weekdays.every((day) => Number.isInteger(day) && Number(day) >= 0 && Number(day) <= 6)
    && typeof value.active === "boolean" && typeof value.updatedAt === "string";
}
function validPreferences(value: unknown): value is WebPreferences {
  return isRecord(value) && themes.has(value.theme as string) && ["off", "08:00", "09:00"].includes(value.dailyCheck as string)
    && Array.isArray(value.reminderPoolExcluded) && isRecord(value.reminderHiddenDates) && isRecord(value.reminderSnoozedUntil)
    && typeof value.updatedAt === "string";
}

function migrate(value: unknown): WebDatabase | null {
  if (!isRecord(value) || !Array.isArray(value.intake) || !value.intake.every(validStoredItem)
    || !Array.isArray(value.accepted) || !value.accepted.every(validAcceptedItem)) return null;
  if (value.schemaVersion === 2 && Array.isArray(value.categories) && value.categories.every(validCategory)
    && Array.isArray(value.recurringRules) && value.recurringRules.every(validRule) && validPreferences(value.preferences)) {
    const database = value as unknown as WebDatabase;
    return database.categories.some((category) => category.id === DEFAULT_CATEGORY_ID)
      ? database : { ...database, categories: [defaultCategory(), ...database.categories] };
  }
  if (value.schemaVersion === 1) {
    const migrated = emptyDatabase();
    return { ...migrated, intake: value.intake as StoredIntakeItem[], accepted: value.accepted as AcceptedItem[] };
  }
  return null;
}

export function isWebDatabase(value: unknown): value is WebDatabase { return migrate(value) !== null; }
export function normalizeDatabase(value: unknown): WebDatabase | null { return migrate(value); }
export function readDatabase(storage: Storage = window.localStorage): WebDatabase {
  const raw = storage.getItem(STORAGE_KEY);
  if (!raw) return emptyDatabase();
  try { return migrate(JSON.parse(raw)) ?? emptyDatabase(); } catch { return emptyDatabase(); }
}
export function writeDatabase(database: WebDatabase, storage: Storage = window.localStorage): void {
  storage.setItem(STORAGE_KEY, JSON.stringify(database));
}

const intakeRank: Record<StoredIntakeItem["status"], number> = { pending: 0, ignored: 1, accepted: 2 };
function newer<T extends { id: string; updatedAt: string }>(items: T[]): T[] {
  const map = new Map<string, T>();
  for (const item of items) {
    const current = map.get(item.id);
    if (!current || item.updatedAt > current.updatedAt || (item.updatedAt === current.updatedAt && JSON.stringify(item) > JSON.stringify(current))) map.set(item.id, item);
  }
  return [...map.values()];
}
export function mergeDatabases(local: WebDatabase, remote: WebDatabase): WebDatabase {
  const intake = new Map<string, StoredIntakeItem>();
  for (const item of [...remote.intake, ...local.intake]) {
    const current = intake.get(item.id);
    if (!current || intakeRank[item.status] >= intakeRank[current.status]) intake.set(item.id, item);
  }
  const accepted = new Map<string, AcceptedItem>();
  for (const item of [...remote.accepted, ...local.accepted]) {
    const current = accepted.get(item.id); const stamp = item.updatedAt ?? item.acceptedAt; const currentStamp = current?.updatedAt ?? current?.acceptedAt ?? "";
    if (!current || stamp > currentStamp || (stamp === currentStamp && JSON.stringify(item) > JSON.stringify(current))) accepted.set(item.id, item);
  }
  for (const id of accepted.keys()) { const item = intake.get(id); if (item && item.status !== "accepted") intake.set(id, { ...item, status: "accepted" }); }
  const preferences = local.preferences.updatedAt >= remote.preferences.updatedAt ? local.preferences : remote.preferences;
  return { schemaVersion: 2, intake: [...intake.values()], accepted: [...accepted.values()],
    categories: newer([...remote.categories, ...local.categories]), recurringRules: newer([...remote.recurringRules, ...local.recurringRules]), preferences };
}

export function importEnvelope(database: WebDatabase, envelope: IntakeEnvelope): { database: WebDatabase; added: number } {
  const known = new Set([...database.intake.map((item) => item.id), ...database.accepted.map((item) => item.id)]); const receivedAt = nowIso();
  const incoming = envelope.items.filter((item) => !known.has(item.id)).map<StoredIntakeItem>((item) => ({ ...item, envelopeId: envelope.envelopeId, source: envelope.source, receivedAt, status: "pending" }));
  return { database: { ...database, intake: [...database.intake, ...incoming] }, added: incoming.length };
}
export function acceptIntake(database: WebDatabase, id: string): WebDatabase {
  const item = database.intake.find((candidate) => candidate.id === id && candidate.status === "pending"); if (!item) return database;
  const updatedAt = nowIso(); const payload = { ...item.payload };
  if (item.target === "document" && typeof payload.categoryId !== "string") payload.categoryId = DEFAULT_CATEGORY_ID;
  const accepted: AcceptedItem = { id: item.id, target: item.target, title: item.title, note: item.note, payload, source: item.source, acceptedAt: updatedAt, status: "active", updatedAt };
  return { ...database, intake: database.intake.map((candidate) => candidate.id === id ? { ...candidate, status: "accepted" } : candidate), accepted: [...database.accepted, accepted] };
}
export function ignoreIntake(database: WebDatabase, id: string): WebDatabase { return { ...database, intake: database.intake.map((item) => item.id === id ? { ...item, status: "ignored" } : item) }; }
export function updateIntake(database: WebDatabase, id: string, title: string, note?: string): WebDatabase {
  const clean = title.trim(); if (!clean) return database;
  return { ...database, intake: database.intake.map((item) => item.id === id ? { ...item, title: clean, note: note?.trim() || undefined } : item) };
}

export interface CalendarItemInput { title: string; note?: string; date: string; time?: string; }
function calendarPayload(input: CalendarItemInput): Record<string, unknown> {
  const payload: Record<string, unknown> = { date: input.date };
  if (input.time) { payload.time = input.time; payload.scheduledAt = new Date(`${input.date}T${input.time}:00`).toISOString(); payload.timeZone = Intl.DateTimeFormat().resolvedOptions().timeZone; }
  return payload;
}
function manualItem(target: AcceptedItem["target"], title: string, payload: Record<string, unknown>, note?: string): AcceptedItem {
  const stamp = nowIso(); return { id: crypto.randomUUID(), target, title: title.trim(), note: note?.trim() || undefined, payload, source: { kind: "manual", label: "Memory Hub" }, acceptedAt: stamp, updatedAt: stamp, status: "active" };
}
export function createCalendarItem(database: WebDatabase, input: CalendarItemInput): WebDatabase { if (!input.title.trim() || !input.date) return database; return { ...database, accepted: [...database.accepted, manualItem("calendar", input.title, calendarPayload(input), input.note)] }; }
export function updateCalendarItem(database: WebDatabase, id: string, input: CalendarItemInput): WebDatabase {
  if (!input.title.trim() || !input.date) return database; const updatedAt = nowIso();
  return { ...database, accepted: database.accepted.map((item) => item.id === id && item.target === "calendar" ? { ...item, title: input.title.trim(), note: input.note?.trim() || undefined, payload: calendarPayload(input), updatedAt } : item) };
}
export function acceptedStatus(item: AcceptedItem): AcceptedStatus { return item.status ?? "active"; }
export function setAcceptedStatus(database: WebDatabase, id: string, status: AcceptedStatus): WebDatabase {
  const updatedAt = nowIso(); return { ...database, accepted: database.accepted.map((item) => item.id === id ? { ...item, status, updatedAt, deletedAt: status === "deleted" ? updatedAt : undefined } : item) };
}
export function restoreAccepted(database: WebDatabase, id: string): WebDatabase { return setAcceptedStatus(database, id, "active"); }
export function purgeAccepted(database: WebDatabase, id: string): WebDatabase { return { ...database, accepted: database.accepted.filter((item) => item.id !== id) }; }

export interface DocumentInput { title: string; categoryId: string; note?: string; reminder?: boolean; records?: Array<{ id: string; body: string; createdAt: string; updatedAt: string }>; }
export function createDocument(database: WebDatabase, input: DocumentInput): WebDatabase {
  if (!input.title.trim()) return database; return { ...database, accepted: [...database.accepted, manualItem("document", input.title, { categoryId: input.categoryId || DEFAULT_CATEGORY_ID, reminder: Boolean(input.reminder), records: input.records ?? [] }, input.note)] };
}
export function updateDocument(database: WebDatabase, id: string, input: DocumentInput): WebDatabase {
  const updatedAt = nowIso(); return { ...database, accepted: database.accepted.map((item) => item.id === id && item.target === "document" ? { ...item, title: input.title.trim() || item.title, note: input.note?.trim() || undefined, payload: { ...item.payload, categoryId: input.categoryId, reminder: Boolean(input.reminder), records: input.records ?? item.payload.records ?? [] }, updatedAt } : item) };
}
export function addDocumentRecord(database: WebDatabase, id: string, body: string): WebDatabase {
  const clean = body.trim(); if (!clean) return database; const stamp = nowIso(); const item = database.accepted.find((entry) => entry.id === id); if (!item) return database;
  const records = Array.isArray(item.payload.records) ? item.payload.records : [];
  return updateDocument(database, id, { title: item.title, categoryId: String(item.payload.categoryId ?? DEFAULT_CATEGORY_ID), reminder: item.payload.reminder === true, records: [...records, { id: crypto.randomUUID(), body: clean, createdAt: stamp, updatedAt: stamp }] as DocumentInput["records"] });
}

export function createCategory(database: WebDatabase, name: string, color = "#5C8CFF"): WebDatabase { if (!name.trim()) return database; const updatedAt = nowIso(); return { ...database, categories: [...database.categories, { id: crypto.randomUUID(), name: name.trim(), color, order: database.categories.length, updatedAt }] }; }
export function updateCategory(database: WebDatabase, id: string, patch: Partial<Pick<Category, "name" | "color" | "order">>): WebDatabase { const updatedAt = nowIso(); return { ...database, categories: database.categories.map((item) => item.id === id ? { ...item, ...patch, name: patch.name?.trim() || item.name, updatedAt } : item) }; }
export function deleteCategory(database: WebDatabase, id: string, moveDocuments = true): WebDatabase {
  const category = database.categories.find((item) => item.id === id); if (!category || category.isDefault) return database; const updatedAt = nowIso();
  return { ...database, categories: database.categories.map((item) => item.id === id ? { ...item, deletedAt: updatedAt, updatedAt } : item), accepted: database.accepted.map((item) => {
    if (item.target !== "document" || item.payload.categoryId !== id) return item;
    return moveDocuments ? { ...item, payload: { ...item.payload, categoryId: DEFAULT_CATEGORY_ID }, updatedAt } : { ...item, status: "deleted", deletedAt: updatedAt, updatedAt, payload: { ...item.payload, deletedCategoryId: id } };
  }) };
}

export function createLifeItem(database: WebDatabase, target: "fridge" | "purchase" | "homeItem", title: string, payload: Record<string, unknown>, note?: string): WebDatabase { if (!title.trim()) return database; return { ...database, accepted: [...database.accepted, manualItem(target, title, payload, note)] }; }
export function updateLifeItem(database: WebDatabase, id: string, title: string, payload: Record<string, unknown>, note?: string): WebDatabase { const updatedAt = nowIso(); return { ...database, accepted: database.accepted.map((item) => item.id === id ? { ...item, title: title.trim() || item.title, note: note?.trim() || undefined, payload: { ...item.payload, ...payload }, updatedAt } : item) }; }
export function finishFridgeItem(database: WebDatabase, id: string, reason: string, addPurchase: boolean): WebDatabase {
  const item = database.accepted.find((entry) => entry.id === id); if (!item) return database; const updatedAt = nowIso(); let next = { ...database, accepted: database.accepted.map((entry) => entry.id === id ? { ...entry, status: "removed" as AcceptedStatus, updatedAt, payload: { ...entry.payload, removalReason: reason, removedAt: updatedAt } } : entry) };
  if (addPurchase) next = createLifeItem(next, "purchase", item.title, { quantity: item.payload.quantity ?? "" }, item.note); return next;
}

export function createRecurringRule(database: WebDatabase, input: Omit<RecurringRule, "id" | "updatedAt" | "active">): WebDatabase { if (!input.title.trim() || !input.startDate) return database; return { ...database, recurringRules: [...database.recurringRules, { ...input, id: crypto.randomUUID(), title: input.title.trim(), active: true, updatedAt: nowIso() }] }; }
export function updateRecurringRule(database: WebDatabase, id: string, patch: Partial<RecurringRule>): WebDatabase { const updatedAt = nowIso(); return { ...database, recurringRules: database.recurringRules.map((rule) => rule.id === id ? { ...rule, ...patch, id, updatedAt } : rule) }; }
export function materializeRecurring(database: WebDatabase, rule: RecurringRule, date: string, status: "completed" | "skipped" = "completed"): WebDatabase {
  const existing = database.accepted.find((item) => item.target === "calendar" && item.payload.ruleId === rule.id && item.payload.date === date);
  if (existing) return setAcceptedStatus(database, existing.id, status); const item = manualItem("calendar", rule.title, { date, ruleId: rule.id }, undefined); item.status = status; return { ...database, accepted: [...database.accepted, item] };
}

export function updatePreferences(database: WebDatabase, patch: Partial<Omit<WebPreferences, "updatedAt">>): WebDatabase { return { ...database, preferences: { ...database.preferences, ...patch, updatedAt: nowIso() } }; }

// Compatibility helpers keep callers on the item-level API while the v2 store
// retains typed category, document, life-item and preference records.
export const normalizedDatabase = (database: WebDatabase): WebDatabase => normalizeDatabase(database) ?? emptyDatabase();
export const setPreferences = updatePreferences;
export function createAccepted(database: WebDatabase, target: AcceptedItem["target"], title: string, note = "", payload: Record<string, unknown> = {}): WebDatabase {
  if (target === "document") return createDocument(database, { title, categoryId: String(payload.categoryId ?? DEFAULT_CATEGORY_ID), note, reminder: payload.reminder === true, records: Array.isArray(payload.records) ? payload.records as DocumentInput["records"] : [] });
  if (target === "fridge" || target === "purchase" || target === "homeItem") return createLifeItem(database, target, title, payload, note);
  return { ...database, accepted: [...database.accepted, manualItem(target, title, payload, note)] };
}
export function updateAccepted(database: WebDatabase, id: string, patch: Pick<AcceptedItem, "title" | "note" | "payload">): WebDatabase {
  const item = database.accepted.find((entry) => entry.id === id);
  if (!item) return database;
  if (item.target === "document") return updateDocument(database, id, { title: patch.title, note: patch.note, categoryId: String(patch.payload.categoryId ?? DEFAULT_CATEGORY_ID), reminder: patch.payload.reminder === true, records: Array.isArray(patch.payload.records) ? patch.payload.records as DocumentInput["records"] : [] });
  if (item.target === "fridge" || item.target === "purchase" || item.target === "homeItem") return updateLifeItem(database, id, patch.title, patch.payload, patch.note);
  const updatedAt = nowIso(); return { ...database, accepted: database.accepted.map((entry) => entry.id === id ? { ...entry, ...patch, updatedAt } : entry) };
}

function checksum(text: string): string { let hash = 2166136261; for (let i = 0; i < text.length; i += 1) { hash ^= text.charCodeAt(i); hash = Math.imul(hash, 16777619); } return (hash >>> 0).toString(16).padStart(8, "0"); }
export interface BackupEnvelope { format: "memory-hub-web-backup"; version: 1; createdAt: string; checksum: string; database: WebDatabase; }
export function exportBackup(database: WebDatabase): BackupEnvelope { const serialized = JSON.stringify(database); return { format: "memory-hub-web-backup", version: 1, createdAt: nowIso(), checksum: checksum(serialized), database }; }
export function parseBackup(text: string): { ok: true; database: WebDatabase } | { ok: false; message: string } {
  try { const value = JSON.parse(text) as Partial<BackupEnvelope>; const database = normalizeDatabase(value.database); if (value.format !== "memory-hub-web-backup" || value.version !== 1 || !database) return { ok: false, message: "备份格式或版本不受支持。" }; if (value.checksum !== checksum(JSON.stringify(value.database))) return { ok: false, message: "备份校验失败，文件可能不完整。" }; return { ok: true, database }; } catch { return { ok: false, message: "无法读取备份文件。" }; }
}

export const demoEnvelope: IntakeEnvelope = { schemaVersion: 1, envelopeId: "24751fb8-8109-4fe4-a785-842da1bdfcf4", createdAt: "2026-08-07T02:20:00.000Z", source: { kind: "codex", label: "旅行计划任务", threadId: "demo-travel" }, items: [{ id: "f7da2858-380b-4bb6-8db9-f22400644835", target: "calendar", title: "入住青岛海景酒店", note: "地址与订单信息已附上", payload: { scheduledAt: "2026-08-12T15:00:00+08:00", timeZone: "Asia/Shanghai" } }] };
export const demoPurchaseEnvelope: IntakeEnvelope = { schemaVersion: 1, envelopeId: "63e56964-53f-46cd-aa19-532505ec8c05", createdAt: "2026-08-07T02:28:00.000Z", source: { kind: "codex", label: "购物整理任务", threadId: "demo-shopping" }, items: [{ id: "59ec4208-e123-48f0-a32c-a8881c07002e", target: "purchase", title: "充电转换插头", payload: { quantity: "1" } }] };
