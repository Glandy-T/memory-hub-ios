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
  });
});
