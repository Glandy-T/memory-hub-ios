import { useRef, useState } from "react";
import type { AcceptedItem } from "../domain/intake";

interface TaskCarouselProps {
  items: AcceptedItem[];
  onResolve: (id: string, status: "completed" | "skipped") => void;
}

function timeLabel(item: AcceptedItem): string {
  const scheduledAt = item.payload.scheduledAt;
  if (typeof scheduledAt !== "string") return "全天";
  const date = new Date(scheduledAt);
  if (Number.isNaN(date.getTime())) return "全天";
  const timeZone = typeof item.payload.timeZone === "string" ? item.payload.timeZone : undefined;
  return new Intl.DateTimeFormat("zh-CN", { hour: "2-digit", minute: "2-digit", hour12: false, timeZone }).format(date);
}

export function TaskCarousel({ items, onResolve }: TaskCarouselProps) {
  const start = useRef<{ x: number; y: number } | null>(null);
  const [offsetY, setOffsetY] = useState(0);

  if (items.length === 0) {
    return (
      <section className="today-empty" aria-label="今日事项为空">
        <p>今天没有待处理事项</p>
        <span>需要时，从日历添加一条。</span>
      </section>
    );
  }

  const onPointerDown = (event: React.PointerEvent) => {
    start.current = { x: event.clientX, y: event.clientY };
    event.currentTarget.setPointerCapture(event.pointerId);
  };

  const onPointerMove = (event: React.PointerEvent) => {
    if (!start.current) return;
    const vertical = event.clientY - start.current.y;
    const horizontal = event.clientX - start.current.x;
    if (Math.abs(vertical) > Math.abs(horizontal)) setOffsetY(Math.max(-92, Math.min(92, vertical)));
  };

  const onPointerUp = () => {
    const active = items[0];
    if (offsetY < -64) onResolve(active.id, "completed");
    if (offsetY > 64) onResolve(active.id, "skipped");
    start.current = null;
    setOffsetY(0);
  };

  return (
    <div className="task-stage">
      <div className="gesture-feedback" aria-hidden="true">
        {offsetY < -24 ? "完成" : offsetY > 24 ? "无视" : ""}
      </div>
      <div className="task-rail" role="region" aria-label="今日事项，可左右滑动">
        {items.map((item, index) => (
          <article
            className={index === 0 ? "task-card is-current" : "task-card"}
            key={item.id}
            style={index === 0 ? { transform: `translateY(${offsetY}px)` } : undefined}
            tabIndex={index === 0 ? 0 : undefined}
            aria-label={index === 0 ? `${item.title}。向上拖动或按方向键上完成，向下拖动或按方向键下无视。` : item.title}
            aria-keyshortcuts={index === 0 ? "ArrowUp ArrowDown" : undefined}
            onPointerDown={index === 0 ? onPointerDown : undefined}
            onPointerMove={index === 0 ? onPointerMove : undefined}
            onPointerUp={index === 0 ? onPointerUp : undefined}
            onPointerCancel={index === 0 ? onPointerUp : undefined}
            onKeyDown={index === 0 ? (event) => {
              if (event.key === "ArrowUp") onResolve(item.id, "completed");
              if (event.key === "ArrowDown") onResolve(item.id, "skipped");
            } : undefined}
          >
            <time>{timeLabel(item)}</time>
            <div className="task-copy">
              <h2>{item.title}</h2>
              {item.note ? <p>{item.note}</p> : null}
            </div>
          </article>
        ))}
      </div>
    </div>
  );
}
