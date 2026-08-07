import { useEffect, useId, useRef, useState } from "react";
import { X } from "lucide-react";
import type { CalendarItemInput } from "../data/repository";
import type { AcceptedItem } from "../domain/intake";

interface CalendarItemDialogProps {
  open: boolean;
  item: AcceptedItem | null;
  initialDate: string;
  onClose: () => void;
  onSave: (input: CalendarItemInput, id?: string) => void;
  onDelete: (id: string) => void;
}

function localDate(date: Date): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function fieldsFor(item: AcceptedItem | null, initialDate: string) {
  if (!item) return { title: "", note: "", date: initialDate, time: "", nextAction: "", dueDate: "", durationMinutes: "" };
  const scheduledAt = typeof item.payload.scheduledAt === "string" ? new Date(item.payload.scheduledAt) : null;
  const payloadDate = typeof item.payload.date === "string" ? item.payload.date : null;
  const payloadTime = typeof item.payload.time === "string" ? item.payload.time : null;
  return {
    title: item.title,
    note: item.note ?? "",
    date: payloadDate ?? (scheduledAt && !Number.isNaN(scheduledAt.getTime()) ? localDate(scheduledAt) : initialDate),
    time: payloadTime ?? (scheduledAt && !Number.isNaN(scheduledAt.getTime())
      ? `${String(scheduledAt.getHours()).padStart(2, "0")}:${String(scheduledAt.getMinutes()).padStart(2, "0")}`
      : ""),
    nextAction: typeof item.payload.nextAction === "string" ? item.payload.nextAction : "",
    dueDate: typeof item.payload.dueDate === "string" ? item.payload.dueDate : "",
    durationMinutes: typeof item.payload.durationMinutes === "string" ? item.payload.durationMinutes : ""
  };
}

export function CalendarItemDialog({ open, item, initialDate, onClose, onSave, onDelete }: CalendarItemDialogProps) {
  const dialogRef = useRef<HTMLDialogElement>(null);
  const titleId = useId();
  const noteId = useId();
  const dateId = useId();
  const timeId = useId();
  const [title, setTitle] = useState("");
  const [note, setNote] = useState("");
  const [date, setDate] = useState(initialDate);
  const [time, setTime] = useState("");
  const [nextAction, setNextAction] = useState("");
  const [dueDate, setDueDate] = useState("");
  const [durationMinutes, setDurationMinutes] = useState("");
  const [confirmDelete, setConfirmDelete] = useState(false);

  useEffect(() => {
    const dialog = dialogRef.current;
    if (open) {
      const fields = fieldsFor(item, initialDate);
      setTitle(fields.title);
      setNote(fields.note);
      setDate(fields.date);
      setTime(fields.time);
      setNextAction(fields.nextAction); setDueDate(fields.dueDate); setDurationMinutes(fields.durationMinutes);
      setConfirmDelete(false);
      if (dialog && !dialog.open) dialog.showModal();
    } else if (dialog?.open) {
      dialog.close();
    }
  }, [initialDate, item, open]);

  return (
    <dialog className="sheet-dialog calendar-dialog" ref={dialogRef} onClose={onClose}>
      <form onSubmit={(event) => {
        event.preventDefault();
        if (!title.trim() || !date) return;
        onSave({ title, note, date, time: time || undefined, nextAction, dueDate: dueDate || undefined, durationMinutes: durationMinutes || undefined }, item?.id);
        onClose();
      }}>
        <div className="sheet-header">
          <div>
            <h2>{item ? "编辑事项" : "新建事项"}</h2>
            <p>标题必填，时间和备注都可以留空。</p>
          </div>
          <button className="icon-button" type="button" aria-label="关闭" onClick={onClose}><X /></button>
        </div>

        <label className="field-label" htmlFor={titleId}>标题</label>
        <input id={titleId} autoFocus value={title} maxLength={200} onChange={(event) => setTitle(event.target.value)} />

        <div className="calendar-field-grid">
          <div>
            <label className="field-label" htmlFor={dateId}>日期</label>
            <input id={dateId} type="date" value={date} onChange={(event) => setDate(event.target.value)} />
          </div>
          <div>
            <label className="field-label" htmlFor={timeId}>时间（可选）</label>
            <input id={timeId} type="time" value={time} onChange={(event) => setTime(event.target.value)} />
          </div>
        </div>

        <label className="field-label" htmlFor={noteId}>备注（可选）</label>
        <textarea id={noteId} value={note} maxLength={4000} onChange={(event) => setNote(event.target.value)} />

        <label className="field-label">下一步动作（可选）</label>
        <input value={nextAction} maxLength={200} placeholder="例如：打开预约页面" onChange={(event) => setNextAction(event.target.value)} />
        <details className="advanced-fields"><summary>时间细节（可选）</summary><div className="calendar-field-grid"><label className="field-label">截止日期<input type="date" value={dueDate} onChange={(event) => setDueDate(event.target.value)} /></label><label className="field-label">预计用时（分钟）<input inputMode="numeric" value={durationMinutes} onChange={(event) => setDurationMinutes(event.target.value.replace(/\D/g, ""))} /></label></div></details>
        {item && date < localDate(new Date()) ? <button className="primary-quiet" type="button" onClick={() => setDate(localDate(new Date(Date.now() + 86400000)))}>顺延到明天</button> : null}

        {item ? (
          confirmDelete ? (
            <div className="delete-confirm" role="group" aria-label="确认删除事项">
              <span>移入回收状态？</span>
              <button type="button" onClick={() => setConfirmDelete(false)}>取消</button>
              <button className="danger-quiet" type="button" onClick={() => { onDelete(item.id); onClose(); }}>删除</button>
            </div>
          ) : <button className="dialog-delete" type="button" onClick={() => setConfirmDelete(true)}>删除事项</button>
        ) : null}

        <button className="primary-button" type="submit" disabled={!title.trim() || !date}>保存</button>
      </form>
    </dialog>
  );
}
