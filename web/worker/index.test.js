import { describe, expect, it } from "vitest";
import worker from "./index.js";

class FakeDatabase {
  row = null;

  prepare(sql) {
    const database = this;
    return {
      async run() {
        return { meta: { changes: 0 } };
      },
      bind(...values) {
        return {
          async first() {
            if (!sql.startsWith("SELECT")) return null;
            return database.row?.userId === values[0]
              ? { payload_json: database.row.payload, revision: database.row.revision, updated_at: database.row.updatedAt }
              : null;
          },
          async run() {
            if (sql.startsWith("INSERT")) {
              if (database.row) return { meta: { changes: 0 } };
              database.row = { userId: values[0], payload: values[1], revision: values[2], updatedAt: values[3] };
              return { meta: { changes: 1 } };
            }
            if (sql.startsWith("UPDATE")) {
              if (!database.row || database.row.userId !== values[3] || database.row.revision !== values[4]) {
                return { meta: { changes: 0 } };
              }
              database.row = { userId: values[3], payload: values[0], revision: values[1], updatedAt: values[2] };
              return { meta: { changes: 1 } };
            }
            return { meta: { changes: 0 } };
          }
        };
      }
    };
  }
}

const emptyDatabase = { schemaVersion: 1, intake: [], accepted: [] };

function request(method, body) {
  return new Request("https://memory.example/api/state", {
    method,
    headers: {
      "oai-authenticated-user-id": "user-1",
      ...(body ? { "content-type": "application/json" } : {})
    },
    body: body ? JSON.stringify(body) : undefined
  });
}

describe("hosted sync worker", () => {
  it("requires the authenticated Sites user", async () => {
    const response = await worker.fetch(new Request("https://memory.example/api/state"), { DB: new FakeDatabase() });
    expect(response.status).toBe(401);
  });

  it("stores state with optimistic revisions", async () => {
    const DB = new FakeDatabase();
    const env = { DB };

    const initial = await worker.fetch(request("GET"), env);
    expect(await initial.json()).toMatchObject({ database: null, revision: 0 });

    const saved = await worker.fetch(request("PUT", { database: emptyDatabase, baseRevision: 0 }), env);
    expect(await saved.json()).toMatchObject({ revision: 1 });

    const loaded = await worker.fetch(request("GET"), env);
    expect(await loaded.json()).toMatchObject({ database: emptyDatabase, revision: 1 });

    const conflict = await worker.fetch(request("PUT", { database: emptyDatabase, baseRevision: 0 }), env);
    expect(conflict.status).toBe(409);

    const updated = await worker.fetch(request("PUT", {
      database: {
        ...emptyDatabase,
        accepted: [{
          id: "one",
          target: "calendar",
          title: "事项",
          payload: {},
          source: { kind: "manual", label: "Memory Hub" },
          acceptedAt: "2026-08-07T12:00:00.000Z",
          status: "active"
        }]
      },
      baseRevision: 1
    }), env);
    expect(await updated.json()).toMatchObject({ revision: 2 });

    const stale = await worker.fetch(request("PUT", { database: emptyDatabase, baseRevision: 1 }), env);
    expect(stale.status).toBe(409);
  });

  it("rejects malformed state without changing the stored copy", async () => {
    const DB = new FakeDatabase();
    const response = await worker.fetch(request("PUT", {
      database: { schemaVersion: 2, intake: [], accepted: [] },
      baseRevision: 0
    }), { DB });

    expect(response.status).toBe(400);
    expect(DB.row).toBeNull();
  });

  it("serves the app shell for the root and client-side routes", async () => {
    const calls = [];
    const env = {
      ASSETS: {
        async fetch(assetRequest) {
          const path = new URL(assetRequest.url).pathname;
          calls.push(path);
          return new Response(path === "/index.html" ? "app" : "missing", {
            status: path === "/index.html" ? 200 : 404
          });
        }
      }
    };

    const root = await worker.fetch(new Request("https://memory.example/"), env);
    const route = await worker.fetch(new Request("https://memory.example/categories"), env);

    expect(root.status).toBe(200);
    expect(route.status).toBe(200);
    expect(calls).toEqual(["/index.html", "/categories", "/index.html"]);
  });

  it("accepts idempotent Codex intake with a write-only token", async () => {
    const DB = new FakeDatabase();
    const env = {
      DB,
      MEMORY_HUB_INGEST_TOKEN: "secret-token",
      MEMORY_HUB_OWNER_USER_ID: "owner-user"
    };
    const envelope = {
      schemaVersion: 1,
      envelopeId: "envelope-1",
      createdAt: "2026-08-07T12:00:00.000Z",
      source: { kind: "codex", label: "测试任务", threadId: "thread-1" },
      items: [{ id: "item-1", target: "calendar", title: "测试预约", payload: {} }]
    };
    const intakeRequest = () => new Request("https://memory.example/api/intake", {
      method: "POST",
      headers: { authorization: "Bearer secret-token", "content-type": "application/json" },
      body: JSON.stringify(envelope)
    });

    const first = await worker.fetch(intakeRequest(), env);
    expect(await first.json()).toMatchObject({ added: 1, revision: 1 });
    const second = await worker.fetch(intakeRequest(), env);
    expect(await second.json()).toMatchObject({ added: 0, revision: 1 });
    expect(JSON.parse(DB.row.payload).intake[0]).toMatchObject({ id: "item-1", status: "pending" });
  });

  it("rejects Codex intake with a wrong token or schema", async () => {
    const env = {
      DB: new FakeDatabase(),
      MEMORY_HUB_INGEST_TOKEN: "secret-token",
      MEMORY_HUB_OWNER_USER_ID: "owner-user"
    };
    const wrongToken = await worker.fetch(new Request("https://memory.example/api/intake", {
      method: "POST",
      headers: { authorization: "Bearer wrong-token", "content-type": "application/json" },
      body: JSON.stringify({})
    }), env);
    expect(wrongToken.status).toBe(401);

    const invalidSchema = await worker.fetch(new Request("https://memory.example/api/intake", {
      method: "POST",
      headers: { authorization: "Bearer secret-token", "content-type": "application/json" },
      body: JSON.stringify({ schemaVersion: 2 })
    }), env);
    expect(invalidSchema.status).toBe(400);
  });
});
