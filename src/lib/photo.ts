import { makeThumbnail, putBlob } from '@/db/repo';
import type { PhotoRefs } from './addItem';

export const MAX_PHOTO_BYTES = 25 * 1024 * 1024;

export class PhotoError extends Error {}

/**
 * Stores the original and its thumbnail, returning both blob ids.
 *
 * The full image is kept so a serial plate stays legible when zoomed; the
 * 200px WebP is what the list renders, so scrolling never decodes a 4 MB JPEG.
 * Both go through putBlob, which dedupes on content hash.
 */
export async function storePhoto(file: File): Promise<PhotoRefs> {
  if (!file.type.startsWith('image/')) {
    throw new PhotoError('That file is not an image.');
  }
  if (file.size > MAX_PHOTO_BYTES) {
    throw new PhotoError('That photo is too large. Try one under 25 MB.');
  }

  let thumb: Blob;
  try {
    thumb = await makeThumbnail(file);
  } catch {
    // HEIC from an iPhone can defeat createImageBitmap in some browsers. Losing
    // the thumbnail is survivable — losing the photo is not — so fall back to
    // the original and let the list downscale it.
    thumb = file;
  }

  const [blobId, thumbBlobId] = await Promise.all([putBlob(file), putBlob(thumb)]);
  return { blobId, thumbBlobId };
}
