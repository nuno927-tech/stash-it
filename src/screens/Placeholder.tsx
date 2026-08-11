import { Nutsy } from '@/components/Nutsy';

/** Stand-in for screens that aren't built yet, so the nav never dead-ends. */
export function Placeholder({ title, note }: { title: string; note: string }) {
  return (
    <div className="empty">
      <Nutsy pose="stand" height={150} motion={['float']} shadow />
      <h3>{title}</h3>
      <p>{note}</p>
    </div>
  );
}
