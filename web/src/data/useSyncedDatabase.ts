import { useCallback, useEffect, useRef, useState } from "react";
import { mergeDatabases, readDatabase, writeDatabase, type WebDatabase } from "./repository";
import { readRemoteState, SyncConflictError, writeRemoteState } from "./sync";

export type SyncStatus = "local" | "syncing" | "synced" | "offline";

function sameDatabase(left: WebDatabase, right: WebDatabase): boolean {
  return JSON.stringify(left) === JSON.stringify(right);
}

export function useSyncedDatabase(initial: WebDatabase, enabled: boolean) {
  const [database, setDatabase] = useState(initial);
  const [syncStatus, setSyncStatus] = useState<SyncStatus>(enabled ? "syncing" : "local");
  const databaseRef = useRef(initial);
  const queueRef = useRef(Promise.resolve());
  const mountedRef = useRef(true);

  const applyDatabase = useCallback((next: WebDatabase) => {
    databaseRef.current = next;
    writeDatabase(next);
    if (mountedRef.current) setDatabase(next);
  }, []);

  const syncNow = useCallback(() => {
    if (!enabled) return;

    queueRef.current = queueRef.current
      .catch(() => undefined)
      .then(async () => {
        if (mountedRef.current) setSyncStatus("syncing");

        for (let attempt = 0; attempt < 2; attempt += 1) {
          const remote = await readRemoteState();
          const merged = remote.database
            ? mergeDatabases(databaseRef.current, remote.database)
            : databaseRef.current;

          if (!sameDatabase(merged, databaseRef.current)) applyDatabase(merged);
          if (remote.database && sameDatabase(merged, remote.database)) {
            if (mountedRef.current) setSyncStatus("synced");
            return;
          }

          try {
            await writeRemoteState(merged, remote.revision);
            if (mountedRef.current) setSyncStatus("synced");
            return;
          } catch (error) {
            if (!(error instanceof SyncConflictError) || attempt === 1) throw error;
          }
        }
      })
      .catch(() => {
        if (mountedRef.current) setSyncStatus("offline");
      });
  }, [applyDatabase, enabled]);

  const commit = useCallback((next: WebDatabase) => {
    applyDatabase(next);
    syncNow();
  }, [applyDatabase, syncNow]);

  useEffect(() => {
    mountedRef.current = true;
    if (enabled) syncNow();

    const handleOnline = () => syncNow();
    window.addEventListener("online", handleOnline);
    return () => {
      mountedRef.current = false;
      window.removeEventListener("online", handleOnline);
    };
  }, [enabled, syncNow]);

  return { database, commit, syncStatus };
}

export function localDatabase(): WebDatabase {
  return readDatabase();
}
