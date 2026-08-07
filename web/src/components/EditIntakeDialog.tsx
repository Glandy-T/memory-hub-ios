import { useEffect, useRef, useState } from "react";
import { X } from "lucide-react";
import type { StoredIntakeItem } from "../domain/intake";

interface EditIntakeDialogProps {
  item: StoredIntakeItem | null;
  onClose: () => void;
  onSave: (id: string, title: string, note?: string) => void;
}

export function EditIntakeDialog({ item, onClose, onSave }: EditIntakeDialogProps) {
  const dialogRef = useRef<HTMLDialogElement>(null);
  const [title, setTitle] = useState("");
  const [note, setNote] = useState("");

  useEffect(() => {
    const dialog = dialogRef.current;
    if (item) {
      setTitle(item.title);
      setNote(item.note ?? "");
      if (dialog && !dialog.open) dialog.showModal();
    } else if (dialog?.open) {
      dialog.close();
    }
  }, [item]);

  return (
    <dialog className="sheet-dialog" ref={dialogRef} onClose={onClose}>
      <div className="sheet-header">
        <div>
          <h2>编辑后收录</h2>
          <p>来源和原始数据不会被覆盖。</p>
        </div>
        <button className="icon-button" type="button" aria-label="关闭" onClick={onClose}><X /></button>
      </div>
      <label className="field-label" htmlFor="edit-title">标题</label>
      <input id="edit-title" value={title} onChange={(event) => setTitle(event.target.value)} />
      <label className="field-label" htmlFor="edit-note">备注（可选）</label>
      <textarea id="edit-note" value={note} onChange={(event) => setNote(event.target.value)} />
      <button
        className="primary-button"
        type="button"
        disabled={!title.trim() || !item}
        onClick={() => {
          if (!item) return;
          onSave(item.id, title, note);
          onClose();
        }}
      >保存修改</button>
    </dialog>
  );
}
