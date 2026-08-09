import { CalendarDays, FileText, Flag, MapPin, Package, Refrigerator, ShoppingBasket } from "lucide-react";
import { itemSummary, targetLabels, type IntakeTarget, type StoredIntakeItem } from "../domain/intake";

const icons = {
  calendar: CalendarDays,
  deadline: Flag,
  document: FileText,
  purchase: ShoppingBasket,
  fridge: Refrigerator,
  homeItem: MapPin
} satisfies Record<IntakeTarget, typeof Package>;

interface IntakeListProps {
  items: StoredIntakeItem[];
  onAccept: (id: string) => void;
  onEdit: (item: StoredIntakeItem) => void;
  onIgnore: (id: string) => void;
}

export function IntakeList({ items, onAccept, onEdit, onIgnore }: IntakeListProps) {
  if (items.length === 0) {
    return (
      <div className="inbox-empty">
        <Package aria-hidden="true" />
        <h2>没有等待确认的内容</h2>
        <p>从其他任务导入的信息会先出现在这里。</p>
      </div>
    );
  }

  return (
    <div className="intake-list">
      {items.map((item) => {
        const Icon = icons[item.target];
        return (
          <article className="intake-card" key={item.id}>
            <p className="intake-source">来自：{item.source.label}</p>
            <div className="intake-type"><Icon aria-hidden="true" /><span>{targetLabels[item.target]}</span></div>
            <h2>{item.title}</h2>
            <div className="intake-summary">
              {itemSummary(item).map((line) => <p key={line}>{line}</p>)}
            </div>
            <div className="intake-actions">
              <button className="primary-button" type="button" onClick={() => onAccept(item.id)}>收录</button>
              <button className="secondary-button" type="button" onClick={() => onEdit(item)}>编辑</button>
              <button className="danger-quiet" type="button" onClick={() => onIgnore(item.id)}>忽略</button>
            </div>
          </article>
        );
      })}
    </div>
  );
}
