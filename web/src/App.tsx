import { useMemo, useRef, useState } from "react";
import { ArrowLeft, ChevronRight, FileDown, MapPin, Plus, Refrigerator, Upload } from "lucide-react";
import { BottomNavigation, type PrimaryRoute } from "./components/BottomNavigation";
import { CalendarItemDialog } from "./components/CalendarItemDialog";
import { EditIntakeDialog } from "./components/EditIntakeDialog";
import { ImportDialog } from "./components/ImportDialog";
import { IntakeList } from "./components/IntakeList";
import { TaskCarousel } from "./components/TaskCarousel";
import {
  acceptIntake,
  acceptedStatus,
  createCalendarItem,
  demoEnvelope,
  demoPurchaseEnvelope,
  emptyDatabase,
  importEnvelope,
  ignoreIntake,
  readDatabase,
  setAcceptedStatus,
  updateCalendarItem,
  updateIntake,
  type WebDatabase
} from "./data/repository";
import { useSyncedDatabase, type SyncStatus } from "./data/useSyncedDatabase";
import type { AcceptedItem, IntakeEnvelope, StoredIntakeItem } from "./domain/intake";

type Route = PrimaryRoute | "inbox" | "fridge" | "items";

const demoTask: AcceptedItem = {
  id: "cf86a2c1-94dd-46ad-b6c7-393b249e4076",
  target: "calendar",
  title: "整理体检资料",
  note: "带上上次检查报告和用药清单",
  payload: { scheduledAt: "2026-08-07T14:00:00+09:00", timeZone: "Asia/Tokyo" },
  source: { kind: "manual", label: "Memory Hub" },
  acceptedAt: "2026-08-07T01:00:00.000Z",
  status: "active",
  updatedAt: "2026-08-07T01:00:00.000Z"
};

function localDateKey(date = new Date()): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function calendarDate(item: AcceptedItem): string {
  if (typeof item.payload.date === "string") return item.payload.date;
  if (typeof item.payload.scheduledAt === "string") {
    const value = new Date(item.payload.scheduledAt);
    if (!Number.isNaN(value.getTime())) return localDateKey(value);
  }
  return localDateKey(new Date(item.acceptedAt));
}

function currentDateLabel(): { date: string; weekday: string } {
  const now = new Date();
  const date = new Intl.DateTimeFormat("zh-CN", { month: "long", day: "numeric" }).format(now);
  const weekday = new Intl.DateTimeFormat("zh-CN", { weekday: "short" }).format(now);
  return { date, weekday };
}

function isToday(item: AcceptedItem): boolean {
  return item.target === "calendar" && acceptedStatus(item) === "active" && calendarDate(item) === localDateKey();
}

function App() {
  const isDemo = new URLSearchParams(window.location.search).has("demo");
  const initialDatabase = useMemo<WebDatabase>(() => {
    const initial = new URLSearchParams(window.location.search).get("demo") === "reset" ? emptyDatabase() : readDatabase();
    if (!isDemo || initial.intake.length > 0) return initial;
    const travel = importEnvelope(initial, demoEnvelope).database;
    return importEnvelope(travel, demoPurchaseEnvelope).database;
  }, [isDemo]);
  const { database, commit, syncStatus } = useSyncedDatabase(initialDatabase, !isDemo);
  const [route, setRoute] = useState<Route>("home");
  const [importOpen, setImportOpen] = useState(false);
  const [editing, setEditing] = useState<StoredIntakeItem | null>(null);
  const [calendarDialogOpen, setCalendarDialogOpen] = useState(false);
  const [calendarEditing, setCalendarEditing] = useState<AcceptedItem | null>(null);
  const [selectedDate, setSelectedDate] = useState(localDateKey);
  const [notice, setNotice] = useState<string | null>(null);
  const [undo, setUndo] = useState<{ id: string; previousStatus: ReturnType<typeof acceptedStatus>; message: string } | null>(null);
  const noticeTimer = useRef<number | null>(null);
  const undoTimer = useRef<number | null>(null);

  const pending = useMemo(() => database.intake.filter((item) => item.status === "pending"), [database.intake]);
  const todayItems = useMemo(() => {
    const accepted = database.accepted.filter(isToday);
    return isDemo && accepted.length === 0 ? [demoTask] : accepted;
  }, [database.accepted, isDemo]);

  const showNotice = (message: string) => {
    if (noticeTimer.current !== null) window.clearTimeout(noticeTimer.current);
    setNotice(message);
    noticeTimer.current = window.setTimeout(() => setNotice(null), 2600);
  };

  const resolveWithUndo = (id: string, status: "completed" | "skipped" | "deleted") => {
    const item = database.accepted.find((candidate) => candidate.id === id);
    if (!item) return;
    const previousStatus = acceptedStatus(item);
    commit(setAcceptedStatus(database, id, status));
    if (undoTimer.current !== null) window.clearTimeout(undoTimer.current);
    setUndo({
      id,
      previousStatus,
      message: status === "completed" ? "已完成" : status === "skipped" ? "已无视" : "已删除"
    });
    undoTimer.current = window.setTimeout(() => setUndo(null), 4200);
  };

  const handleImport = (envelope: IntakeEnvelope) => {
    const result = importEnvelope(database, envelope);
    commit(result.database);
    showNotice(result.added > 0 ? `已加入 ${result.added} 条待收录内容` : "这些内容已经导入过了");
    if (result.added > 0) setRoute("inbox");
  };

  const accept = (id: string) => {
    commit(acceptIntake(database, id));
    showNotice("已写入正式内容");
  };

  const primaryRoute: PrimaryRoute = route === "inbox" || route === "fridge" || route === "items" ? "home" : route;

  return (
    <div className="app-shell">
      <main className={route === "inbox" || route === "fridge" || route === "items" ? "page secondary-page" : "page"}>
        {route === "home" ? (
          <HomePage
            pendingCount={pending.length}
            todayItems={todayItems}
            onOpenInbox={() => setRoute("inbox")}
            onOpenFridge={() => setRoute("fridge")}
            onOpenItems={() => setRoute("items")}
            onResolve={resolveWithUndo}
          />
        ) : null}
        {route === "calendar" ? (
          <CalendarPage
            items={database.accepted.filter((item) => item.target === "calendar" && acceptedStatus(item) !== "deleted")}
            selectedDate={selectedDate}
            onSelectDate={setSelectedDate}
            onAdd={() => { setCalendarEditing(null); setCalendarDialogOpen(true); }}
            onEdit={(item) => { setCalendarEditing(item); setCalendarDialogOpen(true); }}
          />
        ) : null}
        {route === "categories" ? <CollectionPage title="分类" items={database.accepted.filter((item) => item.target === "document" && acceptedStatus(item) !== "deleted")} empty="还没有收录文档" /> : null}
        {route === "profile" ? (
          <ProfilePage
            pendingCount={pending.length}
            acceptedCount={database.accepted.length}
            syncStatus={syncStatus}
            onImport={() => setImportOpen(true)}
            onOpenInbox={() => setRoute("inbox")}
          />
        ) : null}
        {route === "fridge" ? <SecondaryCollectionPage title="冰箱" items={database.accepted.filter((item) => (item.target === "fridge" || item.target === "purchase") && acceptedStatus(item) !== "deleted")} empty="冰箱和待采购都还是空的" onBack={() => setRoute("home")} /> : null}
        {route === "items" ? <SecondaryCollectionPage title="物品" items={database.accepted.filter((item) => item.target === "homeItem" && acceptedStatus(item) !== "deleted")} empty="还没有记录物品" onBack={() => setRoute("home")} /> : null}
        {route === "inbox" ? (
          <InboxPage
            items={pending}
            onBack={() => setRoute("home")}
            onImport={() => setImportOpen(true)}
            onAccept={accept}
            onAcceptAll={() => {
              let next = database;
              for (const item of pending) next = acceptIntake(next, item.id);
              commit(next);
              showNotice(`已收录 ${pending.length} 条内容`);
            }}
            onEdit={setEditing}
            onIgnore={(id) => {
              commit(ignoreIntake(database, id));
              showNotice("已忽略这条内容");
            }}
          />
        ) : null}
      </main>

      {route !== "inbox" && route !== "fridge" && route !== "items" ? <BottomNavigation route={primaryRoute} onNavigate={setRoute} /> : null}
      {undo ? (
        <div className="toast action-toast" role="status">
          <span>{undo.message}</span>
          <button type="button" onClick={() => {
            commit(setAcceptedStatus(database, undo.id, undo.previousStatus));
            if (undoTimer.current !== null) window.clearTimeout(undoTimer.current);
            setUndo(null);
            showNotice("已撤销");
          }}>撤销</button>
        </div>
      ) : notice ? <div className="toast" role="status">{notice}</div> : null}
      <ImportDialog open={importOpen} onClose={() => setImportOpen(false)} onImport={handleImport} />
      <CalendarItemDialog
        open={calendarDialogOpen}
        item={calendarEditing}
        initialDate={selectedDate}
        onClose={() => { setCalendarDialogOpen(false); setCalendarEditing(null); }}
        onSave={(input, id) => {
          commit(id ? updateCalendarItem(database, id, input) : createCalendarItem(database, input));
          showNotice(id ? "事项已更新" : "事项已创建");
        }}
        onDelete={(id) => resolveWithUndo(id, "deleted")}
      />
      <EditIntakeDialog
        item={editing}
        onClose={() => setEditing(null)}
        onSave={(id, title, note) => {
          commit(updateIntake(database, id, title, note));
          showNotice("修改已保存");
        }}
      />
    </div>
  );
}

interface HomePageProps {
  pendingCount: number;
  todayItems: AcceptedItem[];
  onOpenInbox: () => void;
  onOpenFridge: () => void;
  onOpenItems: () => void;
  onResolve: (id: string, status: "completed" | "skipped") => void;
}

function HomePage({ pendingCount, todayItems, onOpenInbox, onOpenFridge, onOpenItems, onResolve }: HomePageProps) {
  const date = currentDateLabel();
  return (
    <>
      <header className="date-header"><strong>{date.date}</strong><span>{date.weekday}</span></header>
      <section className="today-heading">
        <h1>今日事项</h1>
        <p><i aria-hidden="true" />{todayItems.length} 件待处理</p>
      </section>
      <TaskCarousel items={todayItems} onResolve={onResolve} />
      <button className="inbox-entry" type="button" onClick={onOpenInbox}>
        <span className="inbox-entry-icon"><FileDown aria-hidden="true" /></span>
        <span><strong>待收录</strong><small>{pendingCount > 0 ? `${pendingCount} 条来自其他任务的信息` : "外部信息会先在这里等待确认"}</small></span>
        <ChevronRight aria-hidden="true" />
      </button>
      <section className="life-links" aria-label="生活管理">
        <button type="button" onClick={onOpenFridge}><Refrigerator aria-hidden="true" /><span><strong>冰箱</strong><small>食材与待采购</small></span></button>
        <button type="button" onClick={onOpenItems}><MapPin aria-hidden="true" /><span><strong>物品</strong><small>位置与库存</small></span></button>
      </section>
    </>
  );
}

interface InboxPageProps {
  items: StoredIntakeItem[];
  onBack: () => void;
  onImport: () => void;
  onAccept: (id: string) => void;
  onAcceptAll: () => void;
  onEdit: (item: StoredIntakeItem) => void;
  onIgnore: (id: string) => void;
}

function InboxPage({ items, onBack, onImport, onAccept, onAcceptAll, onEdit, onIgnore }: InboxPageProps) {
  return (
    <>
      <header className="top-bar">
        <button className="icon-button" type="button" aria-label="返回首页" onClick={onBack}><ArrowLeft /></button>
        <h1>待收录</h1>
        <button className="text-button" type="button" onClick={onImport}><Upload aria-hidden="true" />导入</button>
      </header>
      <div className="inbox-intro">
        <p>确认后才会写入正式内容</p>
        {items.length > 1 ? <button type="button" onClick={onAcceptAll}>全部收录</button> : null}
      </div>
      <IntakeList items={items} onAccept={onAccept} onEdit={onEdit} onIgnore={onIgnore} />
    </>
  );
}

function calendarTime(item: AcceptedItem): string | null {
  if (typeof item.payload.time === "string" && item.payload.time) return item.payload.time;
  if (typeof item.payload.scheduledAt !== "string") return null;
  const value = new Date(item.payload.scheduledAt);
  if (Number.isNaN(value.getTime())) return null;
  return new Intl.DateTimeFormat("zh-CN", { hour: "2-digit", minute: "2-digit", hour12: false }).format(value);
}

const calendarStatusLabels = {
  completed: "已完成",
  skipped: "已无视"
} as const;

interface CalendarPageProps {
  items: AcceptedItem[];
  selectedDate: string;
  onSelectDate: (date: string) => void;
  onAdd: () => void;
  onEdit: (item: AcceptedItem) => void;
}

function CalendarPage({ items, selectedDate, onSelectDate, onAdd, onEdit }: CalendarPageProps) {
  const selectedItems = useMemo(() => items
    .filter((item) => calendarDate(item) === selectedDate)
    .sort((left, right) => (calendarTime(left) ?? "99:99").localeCompare(calendarTime(right) ?? "99:99")), [items, selectedDate]);
  const formattedDate = new Intl.DateTimeFormat("zh-CN", { month: "long", day: "numeric", weekday: "short" })
    .format(new Date(`${selectedDate}T12:00:00`));

  return (
    <>
      <header className="simple-header calendar-header">
        <div><h1>日历</h1><p>{formattedDate}</p></div>
        <button className="calendar-add" type="button" aria-label="新增事项" onClick={onAdd}><Plus /></button>
      </header>
      <label className="calendar-date-control">
        <span>查看日期</span>
        <input type="date" value={selectedDate} onChange={(event) => onSelectDate(event.target.value)} />
      </label>
      {selectedItems.length === 0 ? (
        <button className="calendar-empty" type="button" onClick={onAdd}>
          <Plus aria-hidden="true" />
          <strong>这一天还没有事项</strong>
          <span>添加一条简短事项</span>
        </button>
      ) : (
        <div className="calendar-list">
          {selectedItems.map((item) => {
            const status = acceptedStatus(item);
            return (
              <button className="calendar-row" type="button" key={item.id} onClick={() => onEdit(item)}>
                <span className="calendar-row-time">{calendarTime(item) ?? ""}</span>
                <span className="calendar-row-copy">
                  <strong>{item.title}</strong>
                  {item.note ? <small>{item.note}</small> : null}
                </span>
                {status === "completed" || status === "skipped"
                  ? <span className={`status-chip is-${status}`}>{calendarStatusLabels[status]}</span>
                  : <ChevronRight aria-hidden="true" />}
              </button>
            );
          })}
        </div>
      )}
    </>
  );
}

function CollectionPage({ title, items, empty }: { title: string; items: AcceptedItem[]; empty: string }) {
  return (
    <>
      <header className="simple-header"><h1>{title}</h1></header>
      {items.length === 0 ? (
        <div className="simple-empty"><h2>{empty}</h2><p>收录的相关内容会显示在这里。</p></div>
      ) : (
        <div className="accepted-list">
          {items.map((item) => <article key={item.id}><h2>{item.title}</h2>{item.note ? <p>{item.note}</p> : null}</article>)}
        </div>
      )}
    </>
  );
}

function SecondaryCollectionPage({ title, items, empty, onBack }: { title: string; items: AcceptedItem[]; empty: string; onBack: () => void }) {
  return (
    <>
      <header className="top-bar secondary-heading">
        <button className="icon-button" type="button" aria-label="返回首页" onClick={onBack}><ArrowLeft /></button>
        <h1>{title}</h1>
        <span />
      </header>
      {items.length === 0 ? (
        <div className="simple-empty"><h2>{empty}</h2><p>从待收录确认的内容会显示在这里。</p></div>
      ) : (
        <div className="accepted-list">
          {items.map((item) => <article key={item.id}><h2>{item.title}</h2>{item.note ? <p>{item.note}</p> : null}</article>)}
        </div>
      )}
    </>
  );
}

const syncStatusLabels: Record<SyncStatus, string> = {
  local: "演示数据仅保存在本机",
  syncing: "正在与其他设备同步",
  synced: "已与此账号的其他设备同步",
  offline: "当前离线，恢复网络后自动同步"
};

function ProfilePage({ pendingCount, acceptedCount, syncStatus, onImport, onOpenInbox }: { pendingCount: number; acceptedCount: number; syncStatus: SyncStatus; onImport: () => void; onOpenInbox: () => void }) {
  return (
    <>
      <header className="simple-header"><h1>我的</h1></header>
      <section className="settings-group">
        <button type="button" onClick={onOpenInbox}><span><strong>待收录</strong><small>{pendingCount} 条等待确认</small></span><ChevronRight /></button>
        <button type="button" onClick={onImport}><span><strong>导入数据包</strong><small>文件或粘贴 JSON</small></span><ChevronRight /></button>
      </section>
      <section className="settings-group">
        <div><span><strong>本机副本</strong><small>{acceptedCount} 条正式内容，可离线使用</small></span></div>
        <div><span><strong>同步状态</strong><small>{syncStatusLabels[syncStatus]}</small></span></div>
      </section>
    </>
  );
}

export default App;
