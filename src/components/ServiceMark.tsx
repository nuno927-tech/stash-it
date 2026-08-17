import { useLiveQuery } from 'dexie-react-hooks';
import { useEffect, useState } from 'react';
import { db } from '@/db/db';
import { findService, monogram, monogramColour } from '@/lib/services';

/**
 * A service's logo, at whatever size the list needs.
 *
 * Three sources, in order of preference: a bundled mark for one of the fifty
 * known services, a logo fetched once when the subscription was added, or the
 * service's initials on a colour derived from its name. The third is not a
 * failure state — plenty of subscriptions are a gym or a window cleaner, and
 * initials on a coloured tile are a perfectly good way to tell one row from
 * another at 34px.
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
