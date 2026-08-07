import { useMemo, useState } from "react";
import { ArrowLeft, ChevronRight, FileDown, MapPin, Refrigerator, Upload } from "lucide-react";
import { BottomNavigation, type PrimaryRoute } from "./components/BottomNavigation";
import { EditIntakeDialog } from "./components/EditIntakeDialog";
import { ImportDialog } from "./components/ImportDialog";
import { IntakeList } from "./components/IntakeList";
import { TaskCarousel } from "./components/TaskCarousel";
import {
  acceptIntake,
  demoEnvelope,
  demoPurchaseEnvelope,
  emptyDatabase,
  importEnvelope,
  ignoreIntake,
  readDatabase,
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
  acceptedAt: "2026-08-07T01:00:00.000Z"
};

function currentDateLabel(): { date: string; weekday: string } {
  const now = new Date();
  const date = new Intl.DateTimeFormat("zh-CN", { month: "long", day: "numeric" }).format(now);
  const weekday = new Intl.DateTimeFormat("zh-CN", { weekday: "short" }).format(now);
  return { date, weekday };
}

function isToday(item: AcceptedItem): boolean {
  if (item.target !== "calendar") return false;
  const scheduledAt = item.payload.scheduledAt;
  if (typeof scheduledAt !== "string") return true;
  const value = new Date(scheduledAt);
  const today = new Date();
  return value.getFullYear() === today.getFullYear()
    && value.getMonth() === today.getMonth()
    && value.getDate() === today.getDate();
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
  const [resolved, setResolved] = useState<Set<string>>(() => new Set());
  const [notice, setNotice] = useState<string | null>(null);

  const pending = useMemo(() => database.intake.filter((item) => item.status === "pending"), [database.intake]);
  const todayItems = useMemo(() => {
    const accepted = database.accepted.filter(isToday).filter((item) => !resolved.has(item.id));
    return isDemo && accepted.length === 0 && !resolved.has(demoTask.id) ? [demoTask] : accepted;
  }, [database.accepted, isDemo, resolved]);

  const showNotice = (message: string) => {
    setNotice(message);
    window.setTimeout(() => setNotice(null), 2600);
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
            onResolve={(id, status) => {
              setResolved((current) => new Set(current).add(id));
              showNotice(status === "completed" ? "已完成，可在日历中查看" : "已无视，可在日历中查看");
            }}
          />
        ) : null}
        {route === "calendar" ? <CollectionPage title="日历" items={database.accepted.filter((item) => item.target === "calendar")} empty="还没有日历事项" /> : null}
        {route === "categories" ? <CollectionPage title="分类" items={database.accepted.filter((item) => item.target === "document")} empty="还没有收录文档" /> : null}
        {route === "profile" ? (
          <ProfilePage
            pendingCount={pending.length}
            acceptedCount={database.accepted.length}
            syncStatus={syncStatus}
            onImport={() => setImportOpen(true)}
            onOpenInbox={() => setRoute("inbox")}
          />
        ) : null}
        {route === "fridge" ? <SecondaryCollectionPage title="冰箱" items={database.accepted.filter((item) => item.target === "fridge" || item.target === "purchase")} empty="冰箱和待采购都还是空的" onBack={() => setRoute("home")} /> : null}
        {route === "items" ? <SecondaryCollectionPage title="物品" items={database.accepted.filter((item) => item.target === "homeItem")} empty="还没有记录物品" onBack={() => setRoute("home")} /> : null}
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
      {notice ? <div className="toast" role="status">{notice}</div> : null}
      <ImportDialog open={importOpen} onClose={() => setImportOpen(false)} onImport={handleImport} />
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
