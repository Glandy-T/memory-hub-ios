import { afterEach, describe, expect, it, vi } from "vitest";
import { emptyDatabase } from "./repository";
import { readRemoteState, SyncConflictError, writeRemoteState } from "./sync";

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("remote sync client", () => {
  it("reads a valid remote snapshot without browser caching", async () => {
    const database = emptyDatabase();
    const fetchMock = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      database,
      revision: 3,
      updatedAt: "2026-08-07T12:00:00.000Z"
    }), { status: 200, headers: { "content-type": "application/json" } }));
    vi.stubGlobal("fetch", fetchMock);

    await expect(readRemoteState()).resolves.toMatchObject({ revision: 3, database });
    expect(fetchMock).toHaveBeenCalledWith("/api/state", expect.objectContaining({ cache: "no-store" }));
  });

  it("rejects malformed remote data", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(new Response(JSON.stringify({
      database: { schemaVersion: 9 },
      revision: 1
    }), { status: 200 })));

    await expect(readRemoteState()).rejects.toThrow("云端数据格式无效");
  });

  it("reports a readable error when a development fallback returns HTML", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(new Response("<!doctype html>", { status: 200 })));
    await expect(readRemoteState()).rejects.toThrow("同步服务响应无效");
  });

  it("turns revision conflicts into a retryable error", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(new Response(null, { status: 409 })));
    await expect(writeRemoteState(emptyDatabase(), 2)).rejects.toBeInstanceOf(SyncConflictError);
  });
});
