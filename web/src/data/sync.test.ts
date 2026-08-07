import { afterEach, describe, expect, it, vi } from "vitest";
import { emptyDatabase } from "./repository";
import { readRemoteState, SyncConflictError, writeRemoteState } from "./sync";

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("remote sync client", () => {
  it("reads a valid remote snapshot without browser caching", async () => {
    const fetchMock = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      database: emptyDatabase(),
      revision: 3,
      updatedAt: "2026-08-07T12:00:00.000Z"
    }), { status: 200, headers: { "content-type": "application/json" } }));
    vi.stubGlobal("fetch", fetchMock);

    await expect(readRemoteState()).resolves.toMatchObject({ revision: 3, database: emptyDatabase() });
    expect(fetchMock).toHaveBeenCalledWith("/api/state", expect.objectContaining({ cache: "no-store" }));
  });

  it("rejects malformed remote data", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(new Response(JSON.stringify({
      database: { schemaVersion: 9 },
      revision: 1
    }), { status: 200 })));

    await expect(readRemoteState()).rejects.toThrow("云端数据格式无效");
  });

  it("turns revision conflicts into a retryable error", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(new Response(null, { status: 409 })));
    await expect(writeRemoteState(emptyDatabase(), 2)).rejects.toBeInstanceOf(SyncConflictError);
  });
});
