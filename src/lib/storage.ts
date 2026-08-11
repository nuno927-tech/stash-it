/**
 * Storage durability.
 *
 * A local-first app's worst failure isn't a crash, it's the browser quietly
 * evicting the database to reclaim space — which browsers will do to storage
 * marked "best effort". Asking for persistence moves the data behind a much
 * higher bar. Chrome grants it silently based on engagement signals (installed
 * as a PWA counts); Safari grants it on install.
 *
 * It can be refused, and there is nothing to do about that except make backups
 * easy — which is why the export lives one tap away in Settings.
 */

export type PersistState = 'persisted' | 'best-effort' | 'unsupported';

export async function requestPersistence(): Promise<PersistState> {
  if (!navigator.storage?.persist) return 'unsupported';
  try {
    if (await navigator.storage.persisted()) return 'persisted';
    return (await navigator.storage.persist()) ? 'persisted' : 'best-effort';
  } catch {
    return 'unsupported';
  }
}

export async function persistenceState(): Promise<PersistState> {
  if (!navigator.storage?.persisted) return 'unsupported';
  try {
    return (await navigator.storage.persisted()) ? 'persisted' : 'best-effort';
  } catch {
    return 'unsupported';
  }
}

export interface StorageUsage {
  usedBytes: number;
  quotaBytes: number;
}

export async function storageUsage(): Promise<StorageUsage | null> {
  if (!navigator.storage?.estimate) return null;
  try {
    const { usage = 0, quota = 0 } = await navigator.storage.estimate();
    return { usedBytes: usage, quotaBytes: quota };
  } catch {
    return null;
  }
}

export function formatBytes(n: number): string {
  if (n < 1024) return `${n} B`;
  const units = ['KB', 'MB', 'GB'];
  let v = n / 1024;
  let i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return `${v < 10 ? v.toFixed(1) : Math.round(v)} ${units[i]}`;
}
