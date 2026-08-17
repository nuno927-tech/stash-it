import { useLiveQuery } from 'dexie-react-hooks';
import { useEffect, useState } from 'react';
import { db } from '@/db/db';
import { findService, monogram, monogramColour } from '@/lib/services';

/**
 * A service's logo, at whatever size the list needs.
 *
 * Two sources: a bundled mark for one of the known services, or the service's
 * initials on a colour derived from its name. `logoBlobId` is still read for
 * records saved while logo fetching briefly existed, but nothing writes one
 * any more — see lib/services.ts for why that went.
 *
 * Initials are not a failure state. Plenty of subscriptions are a gym or a
 * window cleaner, and two letters on a coloured tile tell one row from another
 * at 34px perfectly well.
 *
 * The colour is derived rather than random so the same service is the same
 * colour on every device and after every restore.
 */
export function ServiceMark({
  serviceId,
  logoBlobId,
  name,
  size = 34,
}: {
  serviceId?: string;
  logoBlobId?: string;
  name: string;
  size?: number;
}) {
  const service = findService(serviceId);
  const blob = useLiveQuery(
    async () => (logoBlobId ? db.blobs.get(logoBlobId) : undefined),
    [logoBlobId],
  );
  const [url, setUrl] = useState<string>();

  useEffect(() => {
    if (!blob) return;
    const made = URL.createObjectURL(blob.data);
    setUrl(made);
    return () => URL.revokeObjectURL(made);
  }, [blob]);

  const box = { width: size, height: size, borderRadius: Math.round(size * 0.26) };

  if (service && service.path) {
    return (
      <span className="servicemark" style={{ ...box, background: service.colour }} aria-hidden="true">
        <svg width={size * 0.62} height={size * 0.62} viewBox="0 0 24 24" fill="#fff">
          <path d={service.path} />
        </svg>
      </span>
    );
  }

  if (url) {
    return (
      <span className="servicemark plain" style={box} aria-hidden="true">
        <img src={url} alt="" width={size} height={size} />
      </span>
    );
  }

  return (
    <span
      className="servicemark mono"
      style={{ ...box, background: monogramColour(name), fontSize: Math.round(size * 0.36) }}
      aria-hidden="true"
    >
      {monogram(name)}
    </span>
  );
}
