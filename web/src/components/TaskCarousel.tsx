import { useEffect, useLayoutEffect, useRef, useState } from "react";
import type { AcceptedItem } from "../domain/intake";

interface TaskCarouselProps {
  items: AcceptedItem[];
  onResolve: (id: string, status: "completed" | "skipped") => void;
}

function timeLabel(item: AcceptedItem): string {
  if (typeof item.payload.time === "string" && item.payload.time) return item.payload.time;
  const scheduledAt = item.payload.scheduledAt;
  if (typeof scheduledAt !== "string") return "全天";
  const date = new Date(scheduledAt);
  if (Number.isNaN(date.getTime())) return "全天";
  const timeZone = typeof item.payload.timeZone === "string" ? item.payload.timeZone : undefined;
  return new Intl.DateTimeFormat("zh-CN", { hour: "2-digit", minute: "2-digit", hour12: false, timeZone }).format(date);
}

export function TaskCarousel({ items, onResolve }: TaskCarouselProps) {
  const start = useRef<{ x: number; y: number } | null>(null);
  const railRef = useRef<HTMLDivElement>(null);
  const cardRefs = useRef<Array<HTMLElement | null>>([]);
  const scrollFrame = useRef<number | null>(null);
  const [offsetY, setOffsetY] = useState(0);
  const [activeId, setActiveId] = useState<string | null>(() => items[Math.min(1, items.length - 1)]?.id ?? null);

  useEffect(() => {
    if (items.length === 0) {
      setActiveId(null);
      return;
    }
    if (!items.some((item) => item.id === activeId)) {
      setActiveId(items[Math.min(1, items.length - 1)].id);
    }
  }, [activeId, items]);

  useEffect(() => () => {
    if (scrollFrame.current !== null) cancelAnimationFrame(scrollFrame.current);
  }, []);

  const activeIndex = Math.max(0, items.findIndex((item) => item.id === activeId));

  useLayoutEffect(() => {
    if (!activeId) return;
    cardRefs.current[activeIndex]?.scrollIntoView({ block: "nearest", inline: "center" });
    setOffsetY(0);
  }, [activeId, activeIndex]);

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
    const active = items[activeIndex];
    if (!active) return;
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
      <div
        className="task-rail"
        role="region"
        aria-label="今日事项，可左右滑动"
        ref={railRef}
        onScroll={() => {
          if (scrollFrame.current !== null) cancelAnimationFrame(scrollFrame.current);
          scrollFrame.current = requestAnimationFrame(() => {
            const rail = railRef.current;
            if (!rail) return;
            const center = rail.getBoundingClientRect().left + rail.clientWidth / 2;
            let closestIndex = 0;
            let closestDistance = Number.POSITIVE_INFINITY;
            cardRefs.current.forEach((card, index) => {
              if (!card) return;
              const bounds = card.getBoundingClientRect();
              const distance = Math.abs(bounds.left + bounds.width / 2 - center);
              if (distance < closestDistance) {
                closestDistance = distance;
                closestIndex = index;
              }
            });
            const nextId = items[closestIndex]?.id;
            if (nextId && nextId !== activeId) setActiveId(nextId);
          });
        }}
      >
        {items.map((item, index) => (
          <article
            className={index === activeIndex ? "task-card is-current" : "task-card"}
            key={item.id}
            ref={(node) => { cardRefs.current[index] = node; }}
            style={index === activeIndex ? { transform: `translateY(${offsetY}px)` } : undefined}
            tabIndex={index === activeIndex ? 0 : undefined}
            aria-label={index === activeIndex ? `${item.title}。向上拖动或按方向键上完成，向下拖动或按方向键下无视。` : item.title}
            aria-keyshortcuts={index === activeIndex ? "ArrowUp ArrowDown" : undefined}
            onPointerDown={index === activeIndex ? onPointerDown : undefined}
            onPointerMove={index === activeIndex ? onPointerMove : undefined}
            onPointerUp={index === activeIndex ? onPointerUp : undefined}
            onPointerCancel={index === activeIndex ? onPointerUp : undefined}
            onKeyDown={index === activeIndex ? (event) => {
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
