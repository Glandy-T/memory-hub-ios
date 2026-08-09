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

function bearerToken(request) {
  const authorization = request.headers.get("authorization");
  return authorization?.startsWith("Bearer ") ? authorization.slice(7) : null;
}

function isDatabase(value) {
  return value !== null
    && typeof value === "object"
    && (value.schemaVersion === 1 || value.schemaVersion === 2)
    && Array.isArray(value.intake)
    && value.intake.every((item) => validStoredItem(item))
    && Array.isArray(value.accepted)
    && value.accepted.every((item) => validAcceptedItem(item))
    && (value.schemaVersion === 1 || (
      Array.isArray(value.categories) && value.categories.every(validCategory)
      && Array.isArray(value.recurringRules) && value.recurringRules.every(validRule)
      && validPreferences(value.preferences)
    ));
}

const intakeTargets = new Set(["calendar", "deadline", "document", "purchase", "fridge", "homeItem"]);
const sourceKinds = new Set(["codex", "share", "file", "manual"]);
const intakeStatuses = new Set(["pending", "accepted", "ignored"]);
const acceptedStatuses = new Set(["active", "completed", "skipped", "deleted", "archived", "removed", "purchased"]);
const themes = new Set(["light", "dark", "system"]);

function nonemptyString(value, maxLength) {
  return typeof value === "string" && value.trim().length > 0 && value.length <= maxLength;
}

function validSource(value) {
  return value && typeof value === "object" && sourceKinds.has(value.kind) && nonemptyString(value.label, 120);
}

function validBaseItem(value) {
  return value
    && typeof value === "object"
    && nonemptyString(value.id, 160)
    && intakeTargets.has(value.target)
    && nonemptyString(value.title, 200)
    && (value.note === undefined || typeof value.note === "string")
    && value.payload
    && typeof value.payload === "object"
    && !Array.isArray(value.payload)
    && validSource(value.source);
}

function validStoredItem(value) {
  return validBaseItem(value)
    && nonemptyString(value.envelopeId, 160)
    && nonemptyString(value.receivedAt, 80)
    && intakeStatuses.has(value.status);
}

function validAcceptedItem(value) {
  return validBaseItem(value)
    && nonemptyString(value.acceptedAt, 80)
    && (value.status === undefined || acceptedStatuses.has(value.status))
    && (value.updatedAt === undefined || typeof value.updatedAt === "string")
    && (value.deletedAt === undefined || typeof value.deletedAt === "string");
}

function validCategory(value) {
  return value && typeof value === "object" && nonemptyString(value.id, 160) && nonemptyString(value.name, 200)
    && nonemptyString(value.color, 40) && Number.isFinite(value.order) && nonemptyString(value.updatedAt, 80)
    && (value.deletedAt === undefined || typeof value.deletedAt === "string");
}

function validRule(value) {
  return value && typeof value === "object" && nonemptyString(value.id, 160) && nonemptyString(value.title, 200)
    && nonemptyString(value.startDate, 20) && Array.isArray(value.weekdays)
    && value.weekdays.every((day) => Number.isInteger(day) && day >= 0 && day <= 6)
    && typeof value.active === "boolean" && nonemptyString(value.updatedAt, 80);
}

function validPreferences(value) {
  return value && typeof value === "object" && themes.has(value.theme)
    && ["off", "08:00", "09:00"].includes(value.dailyCheck)
    && Array.isArray(value.reminderPoolExcluded)
    && value.reminderHiddenDates && typeof value.reminderHiddenDates === "object"
    && value.reminderSnoozedUntil && typeof value.reminderSnoozedUntil === "object"
    && nonemptyString(value.updatedAt, 80);
}

function isEnvelope(value) {
  if (!value || typeof value !== "object" || value.schemaVersion !== 1) return false;
  if (!nonemptyString(value.envelopeId, 160) || !nonemptyString(value.createdAt, 80) || Number.isNaN(Date.parse(value.createdAt))) return false;
  if (!value.source || typeof value.source !== "object" || !sourceKinds.has(value.source.kind) || !nonemptyString(value.source.label, 120)) return false;
  if (value.source.threadId !== undefined && !nonemptyString(value.source.threadId, 240)) return false;
  if (!Array.isArray(value.items) || value.items.length < 1 || value.items.length > 100) return false;

  const ids = new Set();
  return value.items.every((item) => {
    if (!item || typeof item !== "object" || !nonemptyString(item.id, 160) || ids.has(item.id)) return false;
    ids.add(item.id);
    return intakeTargets.has(item.target)
      && nonemptyString(item.title, 200)
      && (item.note === undefined || (typeof item.note === "string" && item.note.length <= 4000))
      && item.payload !== null
      && typeof item.payload === "object"
      && !Array.isArray(item.payload);
  });
}

async function tokenMatches(actual, expected) {
  if (!actual || !expected) return false;
  const [left, right] = await Promise.all([
    crypto.subtle.digest("SHA-256", new TextEncoder().encode(actual)),
    crypto.subtle.digest("SHA-256", new TextEncoder().encode(expected))
  ]);
  const leftBytes = new Uint8Array(left);
  const rightBytes = new Uint8Array(right);
  if (leftBytes.length !== rightBytes.length) return false;
  let difference = 0;
  for (let index = 0; index < leftBytes.length; index += 1) difference |= leftBytes[index] ^ rightBytes[index];
  return difference === 0;
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

async function handleIntake(request, env) {
  if (request.method !== "POST") {
    return new Response(null, { status: 405, headers: { allow: "POST" } });
  }

  const token = bearerToken(request);
  if (!await tokenMatches(token, env.MEMORY_HUB_INGEST_TOKEN) || !env.MEMORY_HUB_OWNER_USER_ID) {
    return json({ message: "投递凭证无效。" }, 401);
  }

  const length = Number(request.headers.get("content-length") || 0);
  if (length > 512 * 1024) return json({ message: "待收录数据包过大。" }, 413);

  let envelope;
  try {
    envelope = await request.json();
  } catch {
    return json({ message: "待收录数据包不是有效 JSON。" }, 400);
  }
  if (!isEnvelope(envelope)) return json({ message: "待收录数据包格式无效。" }, 400);

  await ensureSchema(env.DB);
  const userId = env.MEMORY_HUB_OWNER_USER_ID;

  for (let attempt = 0; attempt < 3; attempt += 1) {
    const row = await readState(env.DB, userId);
    let database = { schemaVersion: 2, intake: [], accepted: [], categories: [{ id: "memory-hub-default-category", name: "未分类", color: "#8F7CF6", order: 0, isDefault: true, updatedAt: new Date().toISOString() }], recurringRules: [], preferences: { theme: "light", dailyCheck: "off", reminderPoolExcluded: [], reminderHiddenDates: {}, reminderSnoozedUntil: {}, updatedAt: new Date().toISOString() } };
    if (row) {
      try {
        const parsed = JSON.parse(row.payload_json);
        if (!isDatabase(parsed)) throw new Error("invalid database");
        database = parsed;
      } catch {
        return json({ message: "云端数据暂时无法读取。" }, 500);
      }
    }

    const knownIds = new Set([
      ...database.intake.map((item) => item.id),
      ...database.accepted.map((item) => item.id)
    ]);
    const receivedAt = new Date().toISOString();
    const incoming = envelope.items
      .filter((item) => !knownIds.has(item.id))
      .map((item) => ({
        ...item,
        envelopeId: envelope.envelopeId,
        source: envelope.source,
        receivedAt,
        status: "pending"
      }));

    if (incoming.length === 0) {
      return json({ added: 0, revision: row?.revision ?? 0 });
    }

    const next = { ...database, intake: [...database.intake, ...incoming] };
    const payload = JSON.stringify(next);
    const updatedAt = new Date().toISOString();
    let result;
    let revision;

    if (!row) {
      revision = 1;
      result = await env.DB
        .prepare("INSERT OR IGNORE INTO memory_hub_state (user_id, payload_json, revision, updated_at) VALUES (?, ?, ?, ?)")
        .bind(userId, payload, revision, updatedAt)
        .run();
    } else {
      revision = row.revision + 1;
      result = await env.DB
        .prepare("UPDATE memory_hub_state SET payload_json = ?, revision = ?, updated_at = ? WHERE user_id = ? AND revision = ?")
        .bind(payload, revision, updatedAt, userId, row.revision)
        .run();
    }

    if (result.meta?.changes === 1) return json({ added: incoming.length, revision });
  }

  return json({ message: "云端内容正在更新，请稍后重试。" }, 409);
}

async function handleDeviceIntake(request, env) {
  if (!await tokenMatches(bearerToken(request), env.MEMORY_HUB_DEVICE_TOKEN) || !env.MEMORY_HUB_OWNER_USER_ID) {
    return json({ message: "设备连接凭证无效。" }, 401);
  }

  await ensureSchema(env.DB);
  const userId = env.MEMORY_HUB_OWNER_USER_ID;

  if (request.method === "GET") {
    const row = await readState(env.DB, userId);
    if (!row) return json({ items: [], revision: 0 });
    try {
      const database = JSON.parse(row.payload_json);
      if (!isDatabase(database)) throw new Error("invalid database");
      return json({
        items: database.intake.filter((item) => item.status === "pending"),
        revision: row.revision
      });
    } catch {
      return json({ message: "待收录内容暂时无法读取。" }, 500);
    }
  }

  if (request.method !== "POST") {
    return new Response(null, { status: 405, headers: { allow: "GET, POST" } });
  }

  let input;
  try {
    input = await request.json();
  } catch {
    return json({ message: "审核操作格式无效。" }, 400);
  }
  if (!nonemptyString(input?.id, 160) || !["accept", "ignore"].includes(input?.action)) {
    return json({ message: "审核操作格式无效。" }, 400);
  }

  for (let attempt = 0; attempt < 3; attempt += 1) {
    const row = await readState(env.DB, userId);
    if (!row) return json({ message: "这条待收录内容不存在。" }, 404);

    let database;
    try {
      database = JSON.parse(row.payload_json);
      if (!isDatabase(database)) throw new Error("invalid database");
    } catch {
      return json({ message: "待收录内容暂时无法读取。" }, 500);
    }

    const item = database.intake.find((candidate) => candidate.id === input.id);
    if (!item) return json({ message: "这条待收录内容不存在。" }, 404);
    if (item.status !== "pending") {
      return json({ status: item.status, revision: row.revision });
    }

    let reviewed = item;
    if (input.action === "accept" && input.item !== undefined) {
      const edit = input.item;
      if (!edit || typeof edit !== "object" || edit.id !== item.id || edit.target !== item.target
        || !nonemptyString(edit.title, 200)
        || (edit.note !== null && edit.note !== undefined && (typeof edit.note !== "string" || edit.note.length > 4000))
        || !edit.payload || typeof edit.payload !== "object" || Array.isArray(edit.payload)) {
        return json({ message: "修改后的待收录内容格式无效。" }, 400);
      }
      reviewed = {
        ...item,
        title: edit.title.trim(),
        ...(edit.note === null || edit.note === undefined || edit.note.trim() === ""
          ? { note: undefined }
          : { note: edit.note.trim() }),
        payload: edit.payload
      };
    }

    const decidedAt = new Date().toISOString();
    const status = input.action === "accept" ? "accepted" : "ignored";
    const intake = database.intake.map((candidate) =>
      candidate.id === input.id ? { ...reviewed, status } : candidate
    );
    const accepted = input.action === "accept" && !database.accepted.some((candidate) => candidate.id === input.id)
      ? [...database.accepted, { ...reviewed, acceptedAt: decidedAt, updatedAt: decidedAt, status: "active" }]
      : database.accepted;
    const next = { ...database, intake, accepted };
    const revision = row.revision + 1;
    const result = await env.DB
      .prepare("UPDATE memory_hub_state SET payload_json = ?, revision = ?, updated_at = ? WHERE user_id = ? AND revision = ?")
      .bind(JSON.stringify(next), revision, decidedAt, userId, row.revision)
      .run();
    if (result.meta?.changes === 1) return json({ status, revision });
  }

  return json({ message: "云端内容正在更新，请稍后重试。" }, 409);
}

function handleDeviceConnection(request, env) {
  if (request.method !== "GET") {
    return new Response(null, { status: 405, headers: { allow: "GET" } });
  }
  const userId = request.headers.get("oai-authenticated-user-id");
  if (!userId || userId !== env.MEMORY_HUB_OWNER_USER_ID) {
    return json({ message: "只有所有者可以创建设备连接文件。" }, 403);
  }
  if (!env.MEMORY_HUB_DEVICE_TOKEN || !env.MEMORY_HUB_SITE_BYPASS_TOKEN) {
    return json({ message: "设备连接尚未配置。" }, 503);
  }
  const url = new URL(request.url);
  return new Response(JSON.stringify({
    schemaVersion: 1,
    baseUrl: url.origin,
    deviceToken: env.MEMORY_HUB_DEVICE_TOKEN,
    siteBypassToken: env.MEMORY_HUB_SITE_BYPASS_TOKEN
  }), {
    status: 200,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "content-disposition": "attachment; filename=\"memory-hub-android-connection.json\"",
      "cache-control": "no-store"
    }
  });
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

    if (url.pathname === "/api/intake") {
      if (!env.DB) return json({ message: "同步服务尚未配置。" }, 503);
      return handleIntake(request, env);
    }

    if (url.pathname === "/api/device/intake") {
      if (!env.DB) return json({ message: "同步服务尚未配置。" }, 503);
      return handleDeviceIntake(request, env);
    }

    if (url.pathname === "/api/device-connection") {
      return handleDeviceConnection(request, env);
    }

    const assetRequest = url.pathname === "/"
      ? new Request(new URL("/index.html", url), request)
      : request;
    const response = await env.ASSETS.fetch(assetRequest);

    if (response.status !== 404 || request.method !== "GET") return response;
    return env.ASSETS.fetch(new Request(new URL("/index.html", url), request));
  }
};
