import { isWebDatabase, type WebDatabase } from "./repository";

export interface RemoteSnapshot {
  database: WebDatabase | null;
  revision: number;
  updatedAt: string | null;
}

export class SyncConflictError extends Error {
  constructor() {
    super("云端内容已更新");
  }
}

export async function readRemoteState(signal?: AbortSignal): Promise<RemoteSnapshot> {
  const response = await fetch("/api/state", {
    method: "GET",
    cache: "no-store",
    credentials: "same-origin",
    signal
  });
  if (!response.ok) throw new Error(`同步读取失败：${response.status}`);

  const value = await response.json() as Partial<RemoteSnapshot>;
  if (!Number.isInteger(value.revision) || (value.database !== null && !isWebDatabase(value.database))) {
    throw new Error("云端数据格式无效");
  }

  return {
    database: value.database ?? null,
    revision: value.revision as number,
    updatedAt: typeof value.updatedAt === "string" ? value.updatedAt : null
  };
}

export async function writeRemoteState(database: WebDatabase, baseRevision: number): Promise<{ revision: number; updatedAt: string }> {
  const response = await fetch("/api/state", {
    method: "PUT",
    credentials: "same-origin",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ database, baseRevision })
  });
  if (response.status === 409) throw new SyncConflictError();
  if (!response.ok) throw new Error(`同步写入失败：${response.status}`);

  const value = await response.json() as { revision?: unknown; updatedAt?: unknown };
  if (!Number.isInteger(value.revision) || typeof value.updatedAt !== "string") {
    throw new Error("同步响应格式无效");
  }
  return { revision: value.revision as number, updatedAt: value.updatedAt };
}
