import type { AcceptedItem, IntakeEnvelope, StoredIntakeItem } from "../domain/intake";

const STORAGE_KEY = "memory-hub.web.v1";

export interface WebDatabase {
  schemaVersion: 1;
  intake: StoredIntakeItem[];
  accepted: AcceptedItem[];
}

export const emptyDatabase = (): WebDatabase => ({ schemaVersion: 1, intake: [], accepted: [] });

export function isWebDatabase(value: unknown): value is WebDatabase {
  if (typeof value !== "object" || value === null) return false;
  const database = value as Partial<WebDatabase>;
  return database.schemaVersion === 1 && Array.isArray(database.intake) && Array.isArray(database.accepted);
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
    if (!current || item.acceptedAt >= current.acceptedAt) accepted.set(item.id, item);
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
  const accepted: AcceptedItem = {
    id: item.id,
    target: item.target,
    title: item.title,
    note: item.note,
    payload: item.payload,
    source: item.source,
    acceptedAt: new Date().toISOString()
  };
  return {
    ...database,
    intake: database.intake.map((candidate) => candidate.id === id ? { ...candidate, status: "accepted" } : candidate),
    accepted: [...database.accepted, accepted]
  };
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
