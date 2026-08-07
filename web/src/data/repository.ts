import type { AcceptedItem, AcceptedStatus, IntakeEnvelope, StoredIntakeItem } from "../domain/intake";

const STORAGE_KEY = "memory-hub.web.v1";

export interface WebDatabase {
  schemaVersion: 1;
  intake: StoredIntakeItem[];
  accepted: AcceptedItem[];
}

export const emptyDatabase = (): WebDatabase => ({ schemaVersion: 1, intake: [], accepted: [] });

const targets = new Set(["calendar", "document", "purchase", "fridge", "homeItem"]);
const intakeStatuses = new Set(["pending", "accepted", "ignored"]);
const acceptedStatuses = new Set(["active", "completed", "skipped", "deleted"]);

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function validSource(value: unknown): boolean {
  return isRecord(value) && typeof value.kind === "string" && typeof value.label === "string" && value.label.trim().length > 0;
}

function validBaseItem(value: unknown): value is Record<string, unknown> {
  return isRecord(value)
    && typeof value.id === "string"
    && targets.has(value.target as string)
    && typeof value.title === "string"
    && value.title.trim().length > 0
    && (value.note === undefined || typeof value.note === "string")
    && isRecord(value.payload)
    && validSource(value.source);
}

function validStoredItem(value: unknown): boolean {
  return validBaseItem(value)
    && typeof value.envelopeId === "string"
    && typeof value.receivedAt === "string"
    && intakeStatuses.has(value.status as string);
}

function validAcceptedItem(value: unknown): boolean {
  return validBaseItem(value)
    && typeof value.acceptedAt === "string"
    && (value.status === undefined || acceptedStatuses.has(value.status as string))
    && (value.updatedAt === undefined || typeof value.updatedAt === "string")
    && (value.deletedAt === undefined || typeof value.deletedAt === "string");
}

export function isWebDatabase(value: unknown): value is WebDatabase {
  if (typeof value !== "object" || value === null) return false;
  const database = value as Partial<WebDatabase>;
  return database.schemaVersion === 1
    && Array.isArray(database.intake)
    && database.intake.every(validStoredItem)
    && Array.isArray(database.accepted)
    && database.accepted.every(validAcceptedItem);
}

export function readDatabase(storage: Storage = window.localStorage): WebDatabase {
  const raw = storage.getItem(STORAGE_KEY);
  if (!raw) return emptyDatabase();
  try {
    const value = JSON.parse(raw) as Partial<WebDatabase>;
    if (!isWebDatabase(value)) {
      return emptyDatabase();
    }
    return value;
  } catch {
    return emptyDatabase();
  }
}

export function writeDatabase(database: WebDatabase, storage: Storage = window.localStorage): void {
  storage.setItem(STORAGE_KEY, JSON.stringify(database));
}

const intakeStatusRank: Record<StoredIntakeItem["status"], number> = {
  pending: 0,
  ignored: 1,
  accepted: 2
};

export function mergeDatabases(local: WebDatabase, remote: WebDatabase): WebDatabase {
  const intake = new Map<string, StoredIntakeItem>();
  for (const item of [...remote.intake, ...local.intake]) {
    const current = intake.get(item.id);
    if (!current || intakeStatusRank[item.status] >= intakeStatusRank[current.status]) {
      intake.set(item.id, item);
    }
  }

  const accepted = new Map<string, AcceptedItem>();
  for (const item of [...remote.accepted, ...local.accepted]) {
    const current = accepted.get(item.id);
    const itemTimestamp = item.updatedAt ?? item.acceptedAt;
    const currentTimestamp = current ? current.updatedAt ?? current.acceptedAt : "";
    if (!current || itemTimestamp >= currentTimestamp) accepted.set(item.id, item);
  }

  for (const id of accepted.keys()) {
    const item = intake.get(id);
    if (item && item.status !== "accepted") intake.set(id, { ...item, status: "accepted" });
  }

  return {
    schemaVersion: 1,
    intake: [...intake.values()],
    accepted: [...accepted.values()]
  };
}

export function importEnvelope(database: WebDatabase, envelope: IntakeEnvelope): { database: WebDatabase; added: number } {
  const knownIds = new Set([
    ...database.intake.map((item) => item.id),
    ...database.accepted.map((item) => item.id)
  ]);
  const receivedAt = new Date().toISOString();
  const incoming = envelope.items
    .filter((item) => !knownIds.has(item.id))
    .map<StoredIntakeItem>((item) => ({
      ...item,
      envelopeId: envelope.envelopeId,
      source: envelope.source,
      receivedAt,
      status: "pending"
    }));
  return {
    database: { ...database, intake: [...database.intake, ...incoming] },
    added: incoming.length
  };
}

export function acceptIntake(database: WebDatabase, id: string): WebDatabase {
  const item = database.intake.find((candidate) => candidate.id === id && candidate.status === "pending");
  if (!item) return database;
  const acceptedAt = new Date().toISOString();
  const accepted: AcceptedItem = {
    id: item.id,
    target: item.target,
    title: item.title,
    note: item.note,
    payload: item.payload,
    source: item.source,
    acceptedAt,
    status: "active",
    updatedAt: acceptedAt
  };
  return {
    ...database,
    intake: database.intake.map((candidate) => candidate.id === id ? { ...candidate, status: "accepted" } : candidate),
    accepted: [...database.accepted, accepted]
  };
}

export interface CalendarItemInput {
  title: string;
  note?: string;
  date: string;
  time?: string;
}

function calendarPayload(input: CalendarItemInput): Record<string, unknown> {
  const payload: Record<string, unknown> = { date: input.date };
  if (input.time) {
    payload.time = input.time;
    payload.scheduledAt = new Date(`${input.date}T${input.time}:00`).toISOString();
    payload.timeZone = Intl.DateTimeFormat().resolvedOptions().timeZone;
  }
  return payload;
}

export function createCalendarItem(database: WebDatabase, input: CalendarItemInput): WebDatabase {
  const title = input.title.trim();
  if (!title || !input.date) return database;
  const now = new Date().toISOString();
  const item: AcceptedItem = {
    id: crypto.randomUUID(),
    target: "calendar",
    title,
    note: input.note?.trim() || undefined,
    payload: calendarPayload(input),
    source: { kind: "manual", label: "Memory Hub" },
    acceptedAt: now,
    updatedAt: now,
    status: "active"
  };
  return { ...database, accepted: [...database.accepted, item] };
}

export function updateCalendarItem(database: WebDatabase, id: string, input: CalendarItemInput): WebDatabase {
  const title = input.title.trim();
  if (!title || !input.date) return database;
  const updatedAt = new Date().toISOString();
  return {
    ...database,
    accepted: database.accepted.map((item) => item.id === id && item.target === "calendar"
      ? {
          ...item,
          title,
          note: input.note?.trim() || undefined,
          payload: { ...item.payload, ...calendarPayload(input), ...(input.time ? {} : { time: undefined, scheduledAt: undefined, timeZone: undefined }) },
          updatedAt
        }
      : item)
  };
}

export function setAcceptedStatus(database: WebDatabase, id: string, status: AcceptedStatus): WebDatabase {
  const updatedAt = new Date().toISOString();
  return {
    ...database,
    accepted: database.accepted.map((item) => item.id === id
      ? { ...item, status, updatedAt, deletedAt: status === "deleted" ? updatedAt : undefined }
      : item)
  };
}

export function acceptedStatus(item: AcceptedItem): AcceptedStatus {
  return item.status ?? "active";
}

export function ignoreIntake(database: WebDatabase, id: string): WebDatabase {
  return {
    ...database,
    intake: database.intake.map((item) => item.id === id ? { ...item, status: "ignored" } : item)
  };
}

export function updateIntake(database: WebDatabase, id: string, title: string, note?: string): WebDatabase {
  const cleanTitle = title.trim();
  if (!cleanTitle) return database;
  return {
    ...database,
    intake: database.intake.map((item) => item.id === id
      ? { ...item, title: cleanTitle, note: note?.trim() || undefined }
      : item)
  };
}

export const demoEnvelope: IntakeEnvelope = {
  schemaVersion: 1,
  envelopeId: "24751fb8-8109-4fe4-a785-842da1bdfcf4",
  createdAt: "2026-08-07T02:20:00.000Z",
  source: { kind: "codex", label: "旅行计划任务", threadId: "demo-travel" },
  items: [
    {
      id: "f7da2858-380b-4bb6-8db9-f22400644835",
      target: "calendar",
      title: "入住青岛海景酒店",
      note: "地址与订单信息已附上",
      payload: { scheduledAt: "2026-08-12T15:00:00+08:00", timeZone: "Asia/Shanghai" }
    }
  ]
};

export const demoPurchaseEnvelope: IntakeEnvelope = {
  schemaVersion: 1,
  envelopeId: "63e56964-53cf-46cd-aa19-532505ec8c05",
  createdAt: "2026-08-07T02:28:00.000Z",
  source: { kind: "codex", label: "购物整理任务", threadId: "demo-shopping" },
  items: [
    {
      id: "59ec4208-e123-48f0-a32c-a8881c07002e",
      target: "purchase",
      title: "充电转换插头",
      payload: { quantity: "1" }
    }
  ]
};
