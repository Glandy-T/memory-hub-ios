export const INTAKE_SCHEMA_VERSION = 1 as const;

export type IntakeTarget = "calendar" | "document" | "purchase" | "fridge" | "homeItem";
export type IntakeSourceKind = "codex" | "share" | "file" | "manual";
export type IntakeStatus = "pending" | "accepted" | "ignored";
export type AcceptedStatus = "active" | "completed" | "skipped" | "deleted";

export interface IntakeSource {
  kind: IntakeSourceKind;
  label: string;
  threadId?: string;
}

export interface IntakeItem {
  id: string;
  target: IntakeTarget;
  title: string;
  note?: string;
  payload: Record<string, unknown>;
}

export interface IntakeEnvelope {
  schemaVersion: typeof INTAKE_SCHEMA_VERSION;
  envelopeId: string;
  createdAt: string;
  source: IntakeSource;
  items: IntakeItem[];
}

export interface StoredIntakeItem extends IntakeItem {
  envelopeId: string;
  source: IntakeSource;
  receivedAt: string;
  status: IntakeStatus;
}

export interface AcceptedItem extends IntakeItem {
  source: IntakeSource;
  acceptedAt: string;
  status?: AcceptedStatus;
  updatedAt?: string;
  deletedAt?: string;
}

export type ValidationResult =
  | { ok: true; value: IntakeEnvelope }
  | { ok: false; message: string };

const targets = new Set<IntakeTarget>(["calendar", "document", "purchase", "fridge", "homeItem"]);
const sourceKinds = new Set<IntakeSourceKind>(["codex", "share", "file", "manual"]);

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isNonemptyString(value: unknown, maxLength: number): value is string {
  return typeof value === "string" && value.trim().length > 0 && value.length <= maxLength;
}

export function validateEnvelope(input: unknown): ValidationResult {
  if (!isRecord(input)) return { ok: false, message: "数据包不是有效对象。" };
  if (input.schemaVersion !== INTAKE_SCHEMA_VERSION) {
    return { ok: false, message: "数据包版本不受支持，请更新 Memory Hub。" };
  }
  if (!isNonemptyString(input.envelopeId, 160)) return { ok: false, message: "数据包缺少 envelopeId。" };
  if (!isNonemptyString(input.createdAt, 80) || Number.isNaN(Date.parse(input.createdAt))) {
    return { ok: false, message: "数据包的创建时间无效。" };
  }
  if (!isRecord(input.source)) return { ok: false, message: "数据包缺少来源。" };
  if (!sourceKinds.has(input.source.kind as IntakeSourceKind)) return { ok: false, message: "数据包来源类型无效。" };
  if (!isNonemptyString(input.source.label, 120)) return { ok: false, message: "数据包来源名称无效。" };
  if (!Array.isArray(input.items) || input.items.length === 0 || input.items.length > 100) {
    return { ok: false, message: "数据包必须包含 1–100 条内容。" };
  }

  const seen = new Set<string>();
  for (const rawItem of input.items) {
    if (!isRecord(rawItem)) return { ok: false, message: "存在无效的待收录内容。" };
    if (!isNonemptyString(rawItem.id, 160) || seen.has(rawItem.id)) {
      return { ok: false, message: "待收录内容的 id 缺失或重复。" };
    }
    seen.add(rawItem.id);
    if (!targets.has(rawItem.target as IntakeTarget)) return { ok: false, message: "存在不支持的目标类型。" };
    if (!isNonemptyString(rawItem.title, 200)) return { ok: false, message: "待收录标题不能为空。" };
    if (rawItem.note !== undefined && (typeof rawItem.note !== "string" || rawItem.note.length > 4000)) {
      return { ok: false, message: "待收录备注无效或过长。" };
    }
    if (!isRecord(rawItem.payload)) return { ok: false, message: "待收录内容缺少 payload。" };
  }

  return { ok: true, value: input as unknown as IntakeEnvelope };
}

export function parseEnvelope(text: string): ValidationResult {
  try {
    return validateEnvelope(JSON.parse(text));
  } catch {
    return { ok: false, message: "无法读取 JSON 数据包。" };
  }
}

export const targetLabels: Record<IntakeTarget, string> = {
  calendar: "日历事项",
  document: "文档",
  purchase: "待采购",
  fridge: "冰箱",
  homeItem: "物品"
};

export function itemSummary(item: IntakeItem): string[] {
  const lines: string[] = [];
  const scheduledAt = item.payload.scheduledAt;
  const quantity = item.payload.quantity;
  const location = item.payload.location;
  if (typeof scheduledAt === "string") {
    const date = new Date(scheduledAt);
    if (!Number.isNaN(date.getTime())) {
      const timeZone = typeof item.payload.timeZone === "string" ? item.payload.timeZone : undefined;
      lines.push(new Intl.DateTimeFormat("zh-CN", { month: "long", day: "numeric", hour: "2-digit", minute: "2-digit", hour12: false, timeZone }).format(date));
    }
  }
  if (typeof quantity === "string" && quantity.trim()) lines.push(`数量 ${quantity.trim()}`);
  if (typeof location === "string" && location.trim()) lines.push(`位置 ${location.trim()}`);
  if (item.note?.trim()) lines.push(item.note.trim());
  return lines.slice(0, 2);
}
