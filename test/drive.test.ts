/**
 * Google Drive backup.
 *
 *   npm run test:drive
 *
 * Everything here runs against a fake DriveApi, because the parts worth
 * testing aren't the HTTP calls — they're the decisions around them. Two in
 * particular: never creating a folder as a side effect of merely looking, and
 * never pruning a backup that turns out to be the only one.
 */

import {
  backupOverdue,
  backupToDrive,
  driveState,
  FOLDER_NAME,
  isClientId,
  latestBackup,
  listDriveBackups,
  pruneable,
  sortBackups,
  type DriveApi,
  type DriveFile,
} from '@/lib/drive';

let failures = 0;

function check(label: string, ok: boolean, detail = '') {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  — ${detail}` : ''}`);
}

/** An in-memory Drive that records what was asked of it. */
function fakeDrive(seed: { folder?: string; files?: DriveFile[] } = {}) {
  const log: string[] = [];
  let folder = seed.folder ?? null;
  const files = [...(seed.files ?? [])];

  const api: DriveApi = {
    async findFolder(name) {
      log.push(`find:${name}`);
      return folder;
    },
    async createFolder(name) {
      log.push(`create:${name}`);
      folder = 'folder-1';
      return folder;
    },
    async upload(folderId, filename, blob) {
      log.push(`upload:${filename}:${folderId}`);
      const file: DriveFile = {
        id: `f${files.length + 1}`,
        name: filename,
        createdTime: new Date(2026, 0, files.length + 1).toISOString(),
        size: String(blob.size),
      };
      files.push(file);
      return file;
    },
    async list() {
      log.push('list');
      return [...files];
    },
    async download(id) {
      log.push(`download:${id}`);
      return new Blob(['x']);
    },
  };

  return { api, log, get files() { return files; } };
}

function file(name: string, createdTime: string, id = name): DriveFile {
  return { id, name, createdTime };
}

async function main() {
  /* ------------------------------------------------------------ client id */

  check(
    'a real client ID is accepted',
    isClientId('123456789012-abcdefghijklmnop.apps.googleusercontent.com'),
  );
  check('a project number is not one', !isClientId('123456789012'));
  check('an API key is not one', !isClientId('AIzaSyC-not-a-client-id'));
  // The most damaging paste: a secret in a field that syncs into backups.
  check('a client secret is not one', !isClientId('GOCSPX-abcdef123456'));
  check('whitespace is tolerated', isClientId('  1-a.apps.googleusercontent.com  '));
  check('empty is unconfigured', driveState(undefined) === 'unconfigured');
  check('a valid id is configured', driveState('1-a.apps.googleusercontent.com') === 'configured');

  /* -------------------------------------------------------------- sorting */

  const files = [
    file('stash-it-backup-2026-08-01.stashit', '2026-08-01T09:00:00Z'),
    file('stash-it-backup-2026-08-09.stashit', '2026-08-09T18:30:00Z'),
    // Same calendar day as the one above: only createdTime separates them,
    // which is why the name is not the sort key.
    file('stash-it-backup-2026-08-09.stashit', '2026-08-09T07:00:00Z', 'earlier'),
    file('notes.txt', '2026-08-10T10:00:00Z'),
  ];

  const sorted = sortBackups(files);
  check('non-backups are ignored', sorted.length === 3, String(sorted.length));
  check('newest first', sorted[0]!.createdTime === '2026-08-09T18:30:00Z');
  check('same-day backups are ordered by time', sorted[1]!.id === 'earlier');
  check('the latest is the newest', latestBackup(files)?.createdTime === '2026-08-09T18:30:00Z');
  check('nothing to be latest of', latestBackup([]) === undefined);

  /* -------------------------------------------------------------- pruning */

  const many = Array.from({ length: 14 }, (_, i) =>
    file(`stash-it-backup-2026-08-${String(i + 1).padStart(2, '0')}.stashit`,
      `2026-08-${String(i + 1).padStart(2, '0')}T09:00:00Z`),
  );
  const old = pruneable(many, 10);
  check('keeps ten', old.length === 4, String(old.length));
  check('and drops the oldest', old[0]!.createdTime === '2026-08-01T09:00:00Z');
  check('oldest first, so a partial failure loses least', old[0]!.createdTime < old[3]!.createdTime);
  // The case that would delete someone's only copy.
  check('nothing is pruneable below the limit', pruneable(many.slice(0, 10), 10).length === 0);
  check('nor with one backup', pruneable([many[0]!], 10).length === 0);

  /* -------------------------------------------------------------- overdue */

  const now = new Date('2026-08-11T12:00:00Z');
  check('never backed up is overdue', backupOverdue(undefined, 7, now));
  check('eight days is overdue on a weekly setting', backupOverdue('2026-08-03T12:00:00Z', 7, now));
  check('two days is not', !backupOverdue('2026-08-09T12:00:00Z', 7, now));
  // "Never" is an instruction, not an interval of zero days.
  check('a reminder of never never nags', !backupOverdue(undefined, 0, now));
  check('a corrupt date is treated as overdue', backupOverdue('not a date', 7, now));

  /* ----------------------------------------------------------- the upload */

  const fresh = fakeDrive();
  await backupToDrive(fresh.api, new Blob(['bundle']), new Date(2026, 7, 11));
  check('the folder is created on first use', fresh.log.includes(`create:${FOLDER_NAME}`));
  check(
    'and the bundle lands in it',
    fresh.log.some((l) => l.startsWith('upload:stash-it-backup-2026-08-11.stashit:folder-1')),
    fresh.log.join(' '),
  );

  const second = fakeDrive({ folder: 'folder-1' });
  await backupToDrive(second.api, new Blob(['bundle']), new Date(2026, 7, 12));
  check('an existing folder is reused', !second.log.some((l) => l.startsWith('create:')));

  /* ----------------------------------------------------------- the listing */

  // Looking must not create anything. Otherwise everyone who opens the screen
  // out of curiosity gets an empty folder in their Drive.
  const empty = fakeDrive();
  const nothing = await listDriveBackups(empty.api);
  check('listing with no folder returns nothing', nothing.length === 0);
  check('and creates no folder', !empty.log.some((l) => l.startsWith('create:')));
  check('and does not even list', !empty.log.includes('list'));

  const stocked = fakeDrive({ folder: 'folder-1', files });
  const listed = await listDriveBackups(stocked.api);
  check('listing returns sorted backups', listed.length === 3 && listed[0]!.id !== 'earlier');

  console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
