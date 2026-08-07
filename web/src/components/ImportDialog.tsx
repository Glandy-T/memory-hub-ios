import { useEffect, useRef, useState } from "react";
import { FileJson2, X } from "lucide-react";
import { parseEnvelope, type IntakeEnvelope } from "../domain/intake";

interface ImportDialogProps {
  open: boolean;
  onClose: () => void;
  onImport: (envelope: IntakeEnvelope) => void;
}

export function ImportDialog({ open, onClose, onImport }: ImportDialogProps) {
  const dialogRef = useRef<HTMLDialogElement>(null);
  const [text, setText] = useState("");
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const dialog = dialogRef.current;
    if (!dialog) return;
    if (open && !dialog.open) dialog.showModal();
    if (!open && dialog.open) dialog.close();
  }, [open]);

  const submit = () => {
    const result = parseEnvelope(text);
    if (!result.ok) {
      setError(result.message);
      return;
    }
    onImport(result.value);
    setText("");
    setError(null);
    onClose();
  };

  const readFile = async (file?: File) => {
    if (!file) return;
    setText(await file.text());
    setError(null);
  };

  return (
    <dialog className="sheet-dialog" ref={dialogRef} onClose={onClose}>
      <div className="sheet-header">
        <div>
          <h2>导入待收录数据</h2>
          <p>支持 Memory Hub intake v1 JSON。</p>
        </div>
        <button className="icon-button" type="button" aria-label="关闭" onClick={onClose}><X /></button>
      </div>
      <label className="file-control">
        <FileJson2 aria-hidden="true" />
        <span>选择 JSON 文件</span>
        <input type="file" accept="application/json,.json,.memoryhub" onChange={(event) => void readFile(event.target.files?.[0])} />
      </label>
      <label className="field-label" htmlFor="intake-json">或粘贴数据包</label>
      <textarea
        id="intake-json"
        value={text}
        spellCheck={false}
        placeholder={'{"schemaVersion":1,"envelopeId":"…"}'}
        onChange={(event) => { setText(event.target.value); setError(null); }}
      />
      {error ? <p className="form-error" role="alert">{error}</p> : null}
      <button className="primary-button" type="button" disabled={!text.trim()} onClick={submit}>加入待收录</button>
    </dialog>
  );
}
