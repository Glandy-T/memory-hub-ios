const STATE_SCHEMA = `CREATE TABLE IF NOT EXISTS memory_hub_state (
  user_id TEXT PRIMARY KEY NOT NULL,
  payload_json TEXT NOT NULL,
  revision INTEGER NOT NULL DEFAULT 1,
  updated_at TEXT NOT NULL
)`;

function json(value, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store"
    }
  });
}

function isDatabase(value) {
  return value !== null
    && typeof value === "object"
    && value.schemaVersion === 1
    && Array.isArray(value.intake)
    && Array.isArray(value.accepted);
}

async function ensureSchema(database) {
  await database.prepare(STATE_SCHEMA).run();
}

async function readState(database, userId) {
  return database
    .prepare("SELECT payload_json, revision, updated_at FROM memory_hub_state WHERE user_id = ?")
    .bind(userId)
    .first();
}

async function handleState(request, env, userId) {
  await ensureSchema(env.DB);

  if (request.method === "GET") {
    const row = await readState(env.DB, userId);
    if (!row) return json({ database: null, revision: 0, updatedAt: null });

    try {
      const database = JSON.parse(row.payload_json);
      if (!isDatabase(database)) throw new Error("invalid database");
      return json({ database, revision: row.revision, updatedAt: row.updated_at });
    } catch {
      return json({ message: "云端数据暂时无法读取。" }, 500);
    }
  }

  if (request.method !== "PUT") {
    return new Response(null, { status: 405, headers: { allow: "GET, PUT" } });
  }

  const length = Number(request.headers.get("content-length") || 0);
  if (length > 1024 * 1024) return json({ message: "同步数据过大。" }, 413);

  let input;
  try {
    input = await request.json();
  } catch {
    return json({ message: "同步数据格式无效。" }, 400);
  }

  if (!isDatabase(input?.database) || !Number.isInteger(input?.baseRevision) || input.baseRevision < 0) {
    return json({ message: "同步数据格式无效。" }, 400);
  }

  const payload = JSON.stringify(input.database);
  if (payload.length > 1024 * 1024) return json({ message: "同步数据过大。" }, 413);

  const updatedAt = new Date().toISOString();
  let result;
  let revision;

  if (input.baseRevision === 0) {
    revision = 1;
    result = await env.DB
      .prepare("INSERT OR IGNORE INTO memory_hub_state (user_id, payload_json, revision, updated_at) VALUES (?, ?, ?, ?)")
      .bind(userId, payload, revision, updatedAt)
      .run();
  } else {
    revision = input.baseRevision + 1;
    result = await env.DB
      .prepare("UPDATE memory_hub_state SET payload_json = ?, revision = ?, updated_at = ? WHERE user_id = ? AND revision = ?")
      .bind(payload, revision, updatedAt, userId, input.baseRevision)
      .run();
  }

  if (result.meta?.changes !== 1) {
    const current = await readState(env.DB, userId);
    return json({ message: "云端内容已更新，请先合并。", revision: current?.revision ?? 0 }, 409);
  }

  return json({ revision, updatedAt });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname === "/api/state") {
      const userId = request.headers.get("oai-authenticated-user-id");
      if (!userId) return json({ message: "请先登录后再同步。" }, 401);
      if (!env.DB) return json({ message: "同步服务尚未配置。" }, 503);
      return handleState(request, env, userId);
    }

    const assetRequest = url.pathname === "/"
      ? new Request(new URL("/index.html", url), request)
      : request;
    const response = await env.ASSETS.fetch(assetRequest);

    if (response.status !== 404 || request.method !== "GET") return response;
    return env.ASSETS.fetch(new Request(new URL("/index.html", url), request));
  }
};
