import { useEffect, useState } from 'react';
import { db } from '@/db/db';

/**
 * An object URL for a stored thumbnail, revoked on unmount.
 *
 * Shared rather than duplicated per component: every place that forgets the
 * revoke leaks a blob for the lifetime of the tab, and a list that scrolls
 * through a hundred items forgets it a hundred times.
 */
export function useThumbUrl(blobId: string | undefined): string | undefined {
  const [url, setUrl] = useState<string>();

  useEffect(() => {
    if (!blobId) {
      setUrl(undefined);
      return;
    }
    let revoked = false;
    let made: string | undefined;

    db.blobs.get(blobId).then((rec) => {
      if (!rec || revoked) return;
      made = URL.createObjectURL(rec.data);
      setUrl(made);
    });

    return () => {
      revoked = true;
      if (made) URL.revokeObjectURL(made);
    };
  }, [blobId]);

  return url;
}
